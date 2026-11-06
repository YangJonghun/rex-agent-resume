#!/bin/sh
# Runs a separate Rex server with the stand-in agents in test/fixtures/bin, then checks that
# they are recorded and reopened after the server is killed and after it is stopped.
# Needs node and python3. REX_AGENT_RESUME_REX picks the rex binary, for trying a Rex build
# before installing it.
set -u
root=$(cd "$(dirname "$0")/.." && pwd -P)
rex=${REX_AGENT_RESUME_REX:-$(command -v rex || echo "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")}
node=$(command -v node) || { echo "e2e needs node"; exit 1; }
python=$(command -v python3) || { echo "e2e needs python3"; exit 1; }

tmp=$(mktemp -d /tmp/rar-e2e.XXXXXX)
sock=$tmp/s.sock
home=$tmp/home
state=$tmp/state
bin=$root/test/fixtures/bin

server_pid() { pgrep -f "server run --listen $sock" | head -1; }
stop_fakes() { pkill -f "$bin/" 2>/dev/null; sleep 1; }
server_gone() { [ -z "$(server_pid)" ]; }
cleanup() {
  "$rex" -S "$sock" api call server.stop >/dev/null 2>&1
  wait_for 20 server_gone
  pid=$(server_pid)
  [ -n "$pid" ] && kill -9 "$pid"
  stop_fakes
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

checks=0
failures=0
check() {
  checks=$((checks + 1))
  if [ "$1" = ok ]; then return; fi
  failures=$((failures + 1))
  echo "FAIL $2"
}
wait_for() {
  tries=$1
  shift
  while [ "$tries" -gt 0 ]; do
    "$@" && return 0
    sleep 0.5
    tries=$((tries - 1))
  done
  return 1
}

mkdir -p "$home/.factory" "$home/.pi/agent" "$home/.config/kilo" "$home/.hermes" "$state"
: >"$tmp/init.lua"
# Pane shells read this instead of your zsh files, so the stand-ins run with the node and python3 found here.
cat >"$tmp/.zprofile" <<'EOF'
export PATH="$E2E_PATH:$PATH"
[ -e "$E2E_TMP/hold-new-shells" ] && sleep 8
[ -e "$E2E_TMP/hold-until-typed" ] && python3 -c 'import os, sys, time
while os.path.exists(sys.argv[1]): time.sleep(0.05)' "$E2E_TMP/hold-until-typed"
EOF

agents="droid pi kilo hermes notes"
count=5

start_server() {
  (env -i HOME="$HOME" USER="$USER" SHELL=/bin/zsh PATH="$bin:${node%/*}:${python%/*}:/usr/bin:/bin:/usr/sbin:/sbin" ZDOTDIR="$tmp" LANG=en_US.UTF-8 TMPDIR="${TMPDIR:-/tmp}" \
    REX_SERVER="$sock" REX_AGENT_RESUME_HOME="$home" REX_AGENT_RESUME_STATE_DIR="$state" REX_CONFIG="$tmp/init.lua" \
    E2E_PATH="$bin:${node%/*}:${python%/*}" E2E_HOME="$home" E2E_TMP="$tmp" E2E_HOOK="$root/bin/rex-agent-resume-hook" \
    "$rex" server run --listen "$sock" --state-dir "$tmp/rex-state" --config "$tmp/init.lua" >>"$tmp/server.log" 2>&1 &)
  wait_for 20 "$rex" -S "$sock" api call server.status >/dev/null 2>&1
}
in_rex() { REX_SERVER="$sock" REX_AGENT_RESUME_HOME="$home" REX_AGENT_RESUME_STATE_DIR="$state" REX_CONFIG="$tmp/init.lua" "$rex" --autostart=false "$@"; }
records() { ls "$state/agents" 2>/dev/null | wc -l | tr -d ' '; }
has_records() { [ "$(records)" -ge "$count" ]; }
snapshot_full() {
  latest=$(ls -t "$state"/snapshots/*.json 2>/dev/null | head -1)
  [ -n "$latest" ] && [ "$(grep -o '"block_id"' "$latest" | wc -l | tr -d ' ')" -ge "$count" ]
}
resumed() { [ "$(grep -c "resumed $count agent(s)" "$state/rex-agent-resume.log" 2>/dev/null)" -ge "$1" ]; }
running() { ps -axo command= | grep -F "$bin/$1 $2" | grep -v grep >/dev/null; }
restart() {
  stop_fakes
  start_server || check fail "server restarts"
}

start_server || { echo "cannot start a Rex server with $rex"; exit 1; }
echo "e2e: $("$rex" version | head -1), api revision $("$rex" -S "$sock" api call server.status | sed -n 's/.*"api_revision":\([0-9]*\).*/\1/p')"
in_rex do "$root/lua/rex-agent-resume/run.lua" mode=install >/dev/null
check "$(grep -q rex-agent-resume-hook "$home/.factory/settings.json" && echo ok)" "hook installed for droid"
check "$(test -f "$home/.pi/agent/extensions/rex-agent-resume.ts" && echo ok)" "plugin installed for pi"

in_rex do "$root/test/fixtures/open-panes.lua" commands="$(echo $agents | tr ' ' ',')" >/dev/null
check "$(wait_for 40 has_records && echo ok)" "all $count panes recorded ($(records) recorded)"
for agent in $agents; do
  check "$(grep -lq "\"$agent\"" "$state"/agents/*.json && echo ok)" "$agent recorded"
done
check "$(wait_for 20 snapshot_full && echo ok)" "snapshot holds all $count panes"

id_of() { grep -h "\"agent\":\"$1\"" "$state"/agents/*.json | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1; }
droid_id=$(id_of droid) pi_id=$(id_of pi) kilo_id=$(id_of kilo) hermes_id=$(id_of hermes)
expect_running() {
  check "$(wait_for 20 running droid "--resume $droid_id" && echo ok)" "$1: droid --resume $droid_id"
  check "$(running pi "--session $pi_id" && echo ok)" "$1: pi --session $pi_id"
  check "$(running kilo "--session $kilo_id" && echo ok)" "$1: kilo --session $kilo_id"
  check "$(running hermes "--resume $hermes_id" && echo ok)" "$1: hermes --resume $hermes_id"
  check "$(running notes "$tmp/todo.txt" && echo ok)" "$1: notes $tmp/todo.txt"
}

kill -9 "$(server_pid)"
restart
check "$(wait_for 40 resumed 1 && echo ok)" "after kill -9: resumed $count"
expect_running "after kill -9"
wait_for 20 snapshot_full >/dev/null

"$rex" -S "$sock" api call server.stop >/dev/null 2>&1
wait_for 20 server_gone
restart
check "$(wait_for 40 resumed 2 && echo ok)" "after server.stop: resumed $count"
expect_running "after server.stop"
wait_for 20 snapshot_full >/dev/null

resume_starts() { grep -c "resume: snapshot" "$state/rex-agent-resume.log" 2>/dev/null; }
starting_resume() { [ "$(resume_starts)" -gt "$started" ]; }
kill_server_while_it_resumes() {
  started=$(resume_starts)
  : >"$tmp/hold-new-shells"
  kill -9 "$(server_pid)"
  wait_for 20 server_gone
  restart
  wait_for 40 starting_resume
  kill -9 "$(server_pid)"
  wait_for 20 server_gone
  rm -f "$tmp/hold-new-shells"
}
kill_server_while_it_resumes
restart
check "$(wait_for 40 resumed 3 && echo ok)" "after a crash mid-resume: the next server resumed $count"
expect_running "after a crash mid-resume"
wait_for 20 snapshot_full >/dev/null

type_before_the_prompt() {
  started=$(resume_starts)
  : >"$tmp/hold-until-typed"
  kill -9 "$(server_pid)"
  wait_for 20 server_gone
  restart
  wait_for 40 starting_resume
  in_rex do "$root/test/fixtures/type-in-panes.lua" text=half-typed >/dev/null
  rm -f "$tmp/hold-until-typed"
}
type_before_the_prompt
check "$(wait_for 40 resumed 4 && echo ok)" "with text typed before the prompt: resumed $count"
expect_running "with text typed before the prompt"
wait_for 20 snapshot_full >/dev/null

droid_ids() { sed -n 's/.*"agent":"droid".*"id":"\([^"]*\)".*/\1/p' "$state"/agents/*.json 2>/dev/null; }
new_droid() { droid_ids | grep -vx "$droid_id" | head -1; }
has_new_droid() { [ -n "$(new_droid)" ]; }
in_rex do "$root/test/fixtures/open-panes.lua" commands=droid >/dev/null
wait_for 40 has_new_droid
new_id=$(new_droid)
sleep 0.5
kill -9 "$(server_pid)"
wait_for 20 server_gone
restart
check "$(wait_for 40 running droid "--resume $new_id" && echo ok)" "killed half a second after its hook ran: droid --resume $new_id"

[ "$failures" -gt 0 ] && tail -20 "$state/rex-agent-resume.log"
echo "e2e: $checks checks, $failures failure(s)"
[ "$failures" -eq 0 ]
