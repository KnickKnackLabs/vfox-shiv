#!/usr/bin/env bats

setup() {
  load helpers
  install_plugin
  ensure_bootstrap
}

@test "shiv bootstrap creates clone at expected path" {
  local shiv_path="${VFOX_SHIV_PATH:-$HOME/.local/share/mise/shiv-backend/shiv}"
  [ -d "$shiv_path/.git" ]
}

@test "bootstrapped shiv is pinned to expected ref" {
  local shiv_path="${VFOX_SHIV_PATH:-$HOME/.local/share/mise/shiv-backend/shiv}"
  local expected_ref="${VFOX_SHIV_REF:-v0.2.3}"

  run git -C "$shiv_path" describe --tags --exact-match HEAD
  [ "$status" -eq 0 ]
  [ "$output" = "$expected_ref" ]
}

@test "bootstrapped shiv has sources.json" {
  local shiv_path="${VFOX_SHIV_PATH:-$HOME/.local/share/mise/shiv-backend/shiv}"
  [ -f "$shiv_path/sources.json" ]
}

@test "bootstrap respects MISE_DATA_DIR" {
  # Regression for vfox-shiv#7: the shiv clone + bootstrap lock must live
  # under MISE_DATA_DIR when set, not under HOME. Otherwise one hung mise
  # session blocks every other session on the machine via a global lock.
  #
  # We isolate both MISE_DATA_DIR (plugin + backend state) and
  # MISE_CONFIG_DIR (to skip the user's global config, which would otherwise
  # drag in every tool in ~/.config/mise/config.toml). The install step is
  # expected to fail today on a separate `Errors` nil bug after the clone
  # succeeds — that's fine: the assertion only cares about the clone path.
  local isolated="$BATS_TEST_TMPDIR/mise-isolated"
  local cfgdir="$BATS_TEST_TMPDIR/mise-config"
  local expected="$isolated/shiv-backend/shiv"
  mkdir -p "$isolated" "$cfgdir"

  local tmpdir="$BATS_TEST_TMPDIR/mise-data-dir-trigger"
  mkdir -p "$tmpdir"
  cat > "$tmpdir/mise.toml" <<MISE
[settings]
experimental = true
[tools]
"shiv:readme" = "latest"
MISE
  MISE_DATA_DIR="$isolated" MISE_CONFIG_DIR="$cfgdir" \
    mise trust "$tmpdir/mise.toml" 2>/dev/null
  MISE_DATA_DIR="$isolated" MISE_CONFIG_DIR="$cfgdir" \
    mise plugins link --force shiv "$PLUGIN_DIR" 2>/dev/null

  (
    cd "$tmpdir"
    unset VFOX_SHIV_PATH
    MISE_DATA_DIR="$isolated" MISE_CONFIG_DIR="$cfgdir" \
      mise install 2>/dev/null
  ) || true

  [ -d "$expected/.git" ]
}
