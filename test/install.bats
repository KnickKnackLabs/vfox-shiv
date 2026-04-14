#!/usr/bin/env bats

setup() {
  load helpers
  install_plugin
  ensure_bootstrap
}

@test "install a tagged version" {
  setup_mise_project '"shiv:readme" = "0.1.0"'

  run mise install
  [ "$status" -eq 0 ]

  # Verify the install path exists with the expected structure
  local install_path
  install_path=$(mise where shiv:readme@0.1.0 2>/dev/null)
  [ -d "$install_path/bin" ]
  [ -d "$install_path/packages" ]
  [ -x "$install_path/bin/readme" ]
}

@test "installed shim is executable and has correct repo path" {
  setup_mise_project '"shiv:readme" = "0.1.0"'
  mise install 2>/dev/null

  local install_path
  install_path=$(mise where shiv:readme@0.1.0 2>/dev/null)

  # Shim should point to the package inside the install path
  grep -q "REPO=" "$install_path/bin/readme"
  grep -q "$install_path/packages/readme" "$install_path/bin/readme"
}

@test "installed shim delegates to mise run" {
  setup_mise_project '"shiv:readme" = "0.1.0"'
  mise install 2>/dev/null

  local install_path
  install_path=$(mise where shiv:readme@0.1.0 2>/dev/null)

  # Shim should be a bash script that delegates to mise run
  [ -x "$install_path/bin/readme" ]
  grep -q 'mise.*run' "$install_path/bin/readme"
}

@test "install latest (no ref) for untagged package" {
  setup_mise_project '"shiv:readme" = "latest"'

  run mise install
  [ "$status" -eq 0 ]

  local install_path
  install_path=$(mise where shiv:readme@latest 2>/dev/null)
  [ -x "$install_path/bin/readme" ]
}

@test "install latest for tagged package" {
  setup_mise_project '"shiv:readme" = "latest"'

  run mise install
  [ "$status" -eq 0 ]

  local install_path
  install_path=$(mise where shiv:readme@latest 2>/dev/null)
  [ -x "$install_path/bin/readme" ]
}
