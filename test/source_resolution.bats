#!/usr/bin/env bats

# Tests for source resolution: remote fetch, caching, and fallback chain.
# Spins up a local HTTP server to simulate the remote sources.json.

setup() {
  load helpers
  install_plugin

  # Isolated cache dir per test
  export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$XDG_CACHE_HOME/mise/shiv-backend"

  # Mock HTTP server serving a custom sources.json
  MOCK_DIR="$BATS_TEST_TMPDIR/mock-server"
  mkdir -p "$MOCK_DIR"
  cat > "$MOCK_DIR/sources.json" <<'EOF'
{
  "remote-only-pkg": "TestOrg/remote-only-pkg",
  "shimmer": "KnickKnackLabs/shimmer"
}
EOF

  MOCK_PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
  python3 -m http.server "$MOCK_PORT" --directory "$MOCK_DIR" &>/dev/null &
  MOCK_PID=$!

  # Wait for server readiness
  for _ in $(seq 1 30); do
    curl -sf "http://localhost:$MOCK_PORT/sources.json" &>/dev/null && break
    sleep 0.1
  done

  export VFOX_SHIV_SOURCES_URL="http://localhost:$MOCK_PORT/sources.json"
  export VFOX_SHIV_CACHE_TTL=300

  # Point user sources at an empty dir so only remote + bundled are checked
  export SHIV_SOURCES_DIR="$BATS_TEST_TMPDIR/empty-sources"
  mkdir -p "$SHIV_SOURCES_DIR"
}

teardown() {
  [[ -n "${MOCK_PID:-}" ]] && kill "$MOCK_PID" 2>/dev/null || true
}

# ── Remote fetch ──────────────────────────────────────────────

@test "resolves package from remote sources" {
  run mise ls-remote shiv:remote-only-pkg
  [ "$status" -eq 0 ]
  # remote-only-pkg has no tags, but should still have "latest"
  echo "$output" | grep -q "latest"
}

@test "remote resolution also works for packages in bundled sources" {
  run mise ls-remote shiv:shimmer
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "0.0.1-alpha"
}

# ── Caching ───────────────────────────────────────────────────

@test "caches remote sources to disk after fetch" {
  mise ls-remote shiv:shimmer 2>/dev/null

  local cache_file="$XDG_CACHE_HOME/mise/shiv-backend/sources.json"
  [ -f "$cache_file" ]

  # Cache should contain our mock data
  run jq -r '.["remote-only-pkg"]' "$cache_file"
  [ "$output" = "TestOrg/remote-only-pkg" ]
}

@test "uses cache on subsequent calls (no refetch needed)" {
  # Prime the cache
  mise ls-remote shiv:shimmer 2>/dev/null

  # Kill the server
  kill "$MOCK_PID" 2>/dev/null; MOCK_PID=""
  sleep 0.3

  # Should still resolve remote-only-pkg from cache
  run mise ls-remote shiv:remote-only-pkg
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "refetches when cache exceeds TTL" {
  # Seed cache with stale data (missing remote-only-pkg)
  local cache_file="$XDG_CACHE_HOME/mise/shiv-backend/sources.json"
  echo '{"stale-pkg": "TestOrg/stale-pkg"}' > "$cache_file"

  # Set TTL to 0 so cache is always considered stale
  export VFOX_SHIV_CACHE_TTL=0

  # Should refetch and find remote-only-pkg from mock server
  run mise ls-remote shiv:remote-only-pkg
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "cache file is updated after refetch" {
  # Seed stale cache
  local cache_file="$XDG_CACHE_HOME/mise/shiv-backend/sources.json"
  echo '{"stale-pkg": "TestOrg/stale-pkg"}' > "$cache_file"
  export VFOX_SHIV_CACHE_TTL=0

  mise ls-remote shiv:shimmer 2>/dev/null

  # Cache should now have mock server's data
  run jq -r '.["remote-only-pkg"]' "$cache_file"
  [ "$output" = "TestOrg/remote-only-pkg" ]
}

# ── Fallback chain ────────────────────────────────────────────

@test "falls back to user sources when remote is unreachable" {
  export VFOX_SHIV_SOURCES_URL="http://localhost:1/sources.json"

  # Put shimmer in a user source file
  echo '{"shimmer": "KnickKnackLabs/shimmer"}' > "$SHIV_SOURCES_DIR/test.json"

  run mise ls-remote shiv:shimmer
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "falls back to bundled sources when remote and user sources miss" {
  export VFOX_SHIV_SOURCES_URL="http://localhost:1/sources.json"

  # User sources dir is empty (set in setup)
  # shimmer should resolve from the bundled shiv sources.json
  run mise ls-remote shiv:shimmer
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "errors when package not found in any source" {
  run mise ls-remote shiv:nonexistent-package-xyz-12345
  [ "$status" -ne 0 ]
}

# ── Edge cases ────────────────────────────────────────────────

@test "corrupt cache file triggers refetch" {
  local cache_file="$XDG_CACHE_HOME/mise/shiv-backend/sources.json"
  echo "not json" > "$cache_file"

  # TTL is fine but content is garbage — should refetch
  run mise ls-remote shiv:remote-only-pkg
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "empty cache file triggers refetch" {
  local cache_file="$XDG_CACHE_HOME/mise/shiv-backend/sources.json"
  touch "$cache_file"

  run mise ls-remote shiv:remote-only-pkg
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}
