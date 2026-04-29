#!/usr/bin/env bats

setup() {
  load helpers
  install_plugin

  export SHIV_SOURCES_DIR="$BATS_TEST_TMPDIR/sources"
  mkdir -p "$SHIV_SOURCES_DIR"
  cat > "$SHIV_SOURCES_DIR/test.json" <<'EOF'
{
  "readme": "KnickKnackLabs/readme",
  "shimmer": "KnickKnackLabs/shimmer"
}
EOF

  local mock_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${!#}"
case "$url" in
  https://api.github.com/repos/KnickKnackLabs/shimmer/tags)
    printf '[{"name":"v0.0.1-alpha"}]\n'
    ;;
  https://api.github.com/repos/KnickKnackLabs/readme/tags)
    printf '[]\n'
    ;;
  *)
    exit 22
    ;;
esac
EOF
  chmod +x "$mock_bin/curl"
  export PATH="$mock_bin:$PATH"
  export VFOX_SHIV_SOURCES_URL="http://localhost:1/sources.json"
}

@test "lists versions for a package with tags" {
  run mise ls-remote shiv:shimmer
  [ "$status" -eq 0 ]
  # shimmer has a v0.0.1-alpha tag, which should appear as 0.0.1-alpha
  echo "$output" | grep -q "0.0.1-alpha"
}

@test "version list includes latest pseudo-version" {
  run mise ls-remote shiv:shimmer
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "package with no tags still has latest" {
  run mise ls-remote shiv:readme
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "latest"
}

@test "unknown package errors" {
  run mise ls-remote shiv:nonexistent-package-that-does-not-exist
  [ "$status" -ne 0 ]
}
