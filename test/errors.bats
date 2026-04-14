#!/usr/bin/env bats
# Unit tests for lib/errors.lua

setup() {
  LIB="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/lib/errors.lua"
}

run_lua() {
  lua -e "dofile('$LIB'); $1"
}

@test "strip_terminal_noise removes ANSI color codes" {
  run run_lua "print(Errors.strip_terminal_noise('\27[31mERROR\27[0m: bad'))"
  [ "$output" = "ERROR: bad" ]
}

@test "strip_terminal_noise removes cursor and mode sequences" {
  run run_lua "print(Errors.strip_terminal_noise('\27[?25l\27[?2004hvisible\27[?25h'))"
  [ "$output" = "visible" ]
}

@test "strip_terminal_noise removes gum cursor control" {
  run run_lua "print(Errors.strip_terminal_noise('hello[D[2Kworld'))"
  [ "$output" = "helloworld" ]
}

@test "strip_boilerplate removes mise verbose hint" {
  run run_lua "print(Errors.strip_boilerplate('real error\nRun with --verbose or MISE_VERBOSE=1 for more information'))"
  [ "$output" = "real error" ]
}

@test "strip_boilerplate removes Lua stack traces" {
  run run_lua "print(Errors.strip_boilerplate('real error\nstack traceback:\n\t[C]: in ?\n\t[C]: in function pcall\n\t(...tail calls...)'))"
  [ "$output" = "real error" ]
}

@test "clean_error handles full noisy output" {
  run run_lua "print(Errors.clean_error('\27[31mmise\27[0m \27[31mERROR\27[0m HTTP 401: Requires authentication\nRun with --verbose or MISE_VERBOSE=1 for more information'))"
  [ "$output" = "mise ERROR HTTP 401: Requires authentication" ]
}

@test "clean_error falls back to raw when cleaning empties the string" {
  run run_lua "print(Errors.clean_error('stack traceback:\n\t[C]: in ?'))"
  # Should fall back to raw input since boilerplate removal leaves nothing
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
