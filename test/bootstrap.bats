#!/usr/bin/env bats

setup() {
  load helpers
  install_plugin
}

@test "shiv bootstrap creates clone at expected path" {
  # The bootstrap should have happened during earlier install tests.
  # Verify the shiv clone exists.
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
