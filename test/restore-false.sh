#!/bin/sh
# Starts its own Rex server with --restore=false and checks that rex-agent-resume stays off.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd -P)
rex=${REX_AGENT_RESUME_REX:-$(command -v rex || echo "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")}
tmp=$(mktemp -d /tmp/rar.XXXXXX)
server=""
trap '[ -n "$server" ] && kill "$server" 2>/dev/null; rm -rf "$tmp"' EXIT

export REX_SERVER="$tmp/s.sock" REX_AGENT_RESUME_HOME="$tmp/home" REX_AGENT_RESUME_STATE_DIR="$tmp/state" REX_CONFIG="$tmp/init.lua"
mkdir -p "$REX_AGENT_RESUME_HOME/.claude"
: > "$REX_CONFIG"
"$rex" server run --restore=false --listen "$REX_SERVER" --state-dir "$tmp/server" --config "$REX_CONFIG" > "$tmp/server.log" 2>&1 &
server=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S "$REX_SERVER" ] && break; sleep 0.5; done

"$rex" --autostart=false do "$root/lua/rex-agent-resume/run.lua" mode=install > /dev/null
sleep 3

fail() { echo "FAIL $1"; exit 1; }
grep -q 'off: the server runs with --restore=false' "$REX_AGENT_RESUME_STATE_DIR/rex-agent-resume.log" || fail "the watcher did not say restore is off"
[ ! -e "$REX_AGENT_RESUME_STATE_DIR/watch.lock" ] || fail "the watcher kept running"
[ -z "$(ls -A "$REX_AGENT_RESUME_STATE_DIR/snapshots" 2> /dev/null)" ] || fail "a snapshot was written"
echo "restore=false: rex-agent-resume stays off"
