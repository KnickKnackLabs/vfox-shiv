# Test helpers for vfox-shiv BATS tests

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Install the plugin locally under a given name for testing.
# Uses a fresh mise plugin link each time.
install_plugin() {
  local name="${1:-shiv}"
  mise plugins link --force "$name" "$PLUGIN_DIR" 2>/dev/null
}

# Uninstall the plugin.
uninstall_plugin() {
  local name="${1:-shiv}"
  mise plugins uninstall "$name" 2>/dev/null || true
}

# Create a temporary mise.toml with the given tools section.
# Sets TESTDIR and cd's into it.
# Usage: setup_mise_project '"shiv:shimmer" = "0.0.1-alpha"'
setup_mise_project() {
  local tools_lines="$1"
  TESTDIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$TESTDIR"
  cat > "$TESTDIR/mise.toml" <<EOF
[settings]
experimental = true

[tools]
$tools_lines
EOF
  cd "$TESTDIR"
  mise trust "$TESTDIR/mise.toml" 2>/dev/null
}

# Suppress the git remote warning noise in test output
export MISE_QUIET=1
