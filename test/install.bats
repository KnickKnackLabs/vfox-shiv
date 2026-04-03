#!/usr/bin/env bats

setup() {
  load helpers
  install_plugin
}

@test "install a tagged version" {
  setup_mise_project '"shiv:shimmer" = "0.0.1-alpha"'

  run mise install
  [ "$status" -eq 0 ]

  # Verify the install path exists with the expected structure
  local install_path
  install_path=$(mise where shiv:shimmer@0.0.1-alpha 2>/dev/null)
  [ -d "$install_path/bin" ]
  [ -d "$install_path/packages" ]
  [ -x "$install_path/bin/shimmer" ]
}

@test "installed shim is executable and has correct repo path" {
  setup_mise_project '"shiv:shimmer" = "0.0.1-alpha"'
  mise install 2>/dev/null

  local install_path
  install_path=$(mise where shiv:shimmer@0.0.1-alpha 2>/dev/null)

  # Shim should point to the package inside the install path
  grep -q "REPO=" "$install_path/bin/shimmer"
  grep -q "$install_path/packages/shimmer" "$install_path/bin/shimmer"
}

@test "installed tool runs through mise exec" {
  setup_mise_project '"shiv:shimmer" = "0.0.1-alpha"'
  mise install 2>/dev/null

  run mise exec -- shimmer tasks
  [ "$status" -eq 0 ]
  # shimmer should list its tasks
  echo "$output" | grep -q "agent"
}

@test "install latest (no ref) for untagged package" {
  setup_mise_project '"shiv:readme" = "latest"'

  run mise install
  [ "$status" -eq 0 ]

  local install_path
  install_path=$(mise where shiv:readme@latest 2>/dev/null)
  [ -x "$install_path/bin/readme" ]
}

@test "install latest for tagged package tracks default branch" {
  setup_mise_project '"shiv:shimmer" = "latest"'

  run mise install
  [ "$status" -eq 0 ]

  local install_path
  install_path=$(mise where shiv:shimmer@latest 2>/dev/null)
  [ -x "$install_path/bin/shimmer" ]

  # Should be on a branch (not detached HEAD)
  local branch
  branch=$(git -C "$install_path/packages/shimmer" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$branch" != "HEAD" ]
}
