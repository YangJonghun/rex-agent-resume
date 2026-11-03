#!/bin/sh
# Install or update:
#   curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh -s uninstall
# From a checkout, ./install.sh and ./install.sh uninstall use the checkout in place.
set -eu

repo=${REX_AGENT_RESUME_REPO:-YangJonghun/rex-agent-resume}
ref=${REX_AGENT_RESUME_REF:-main}
url=${REX_AGENT_RESUME_URL:-https://codeload.github.com/$repo/tar.gz/$ref}
dest=${REX_AGENT_RESUME_DIR:-$HOME/.local/share/rex-agent-resume}
marker=.installed-by-install-sh
mode=${1:-install}
prefix="[rex-agent-resume]"
say() { echo "$prefix $*"; }
fail() { say "$*" >&2; exit 1; }

case $mode in
  install | uninstall) ;;
  *) say "usage: install.sh [install | uninstall]" >&2; exit 2 ;;
esac

rex=${REX_AGENT_RESUME_REX:-}
[ -z "$rex" ] && [ -n "${REX_BIN_DIR:-}" ] && rex="$REX_BIN_DIR/rex"
[ -z "$rex" ] && rex=$(command -v rex 2>/dev/null || true)
mac="$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
[ -z "$rex" ] && [ -x "$mac" ] && rex=$mac
[ -n "$rex" ] || fail "rex not found; set REX_AGENT_RESUME_REX"
command -v jq >/dev/null || fail "jq is required"

run_lua() {
  "$rex" --autostart=false do "$1/lua/rex-agent-resume/run.lua" mode="$mode"
}

# Piped into sh, $0 is the shell's name; run as a file, it is this script's path.
case $0 in
  */install.sh | install.sh)
    run_lua "$(cd "$(dirname "$0")" && pwd -P)"
    exit
    ;;
esac

if [ "$mode" = uninstall ]; then
  [ -f "$dest/$marker" ] || fail "nothing installed by install.sh at $dest"
  run_lua "$dest"
  rm -rf "$dest"
  say "removed $dest"
  exit
fi

if [ -e "$dest" ] && [ ! -f "$dest/$marker" ]; then
  fail "$dest exists and was not created by install.sh; move it away or set REX_AGENT_RESUME_DIR"
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/src" "$tmp/out"
say "downloading $url"
curl -fsSL "$url" | tar -xzf - -C "$tmp/src" --strip-components 1
[ -f "$tmp/src/lua/rex-agent-resume/run.lua" ] || fail "the download does not look like rex-agent-resume"
for path in plugin.lua bin lua integrations; do cp -R "$tmp/src/$path" "$tmp/out/"; done
touch "$tmp/out/$marker"
mkdir -p "$(dirname "$dest")"
rm -rf "$dest"
mv "$tmp/out" "$dest"
run_lua "$dest"
