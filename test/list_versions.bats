#!/usr/bin/env bats

setup() {
  load helpers
  install_plugin
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
