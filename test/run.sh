#!/bin/sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for v in CLAUDE_CONFIG_DIR CODEX_HOME COPILOT_HOME XDG_CONFIG_HOME KIMI_CODE_HOME QODER_CONFIG_DIR QWEN_HOME \
  CURSOR_CONFIG_DIR ANTIGRAVITY_CLI_CONFIG_DIR GROK_CONFIG_DIR GROK_HOME CODEX_THREAD_ID CURSOR_VERSION GROK_SESSION_ID \
  HERMES_HOME PI_CODING_AGENT_DIR PI_CONFIG_DIR OMPCODE XDG_STATE_HOME; do
  unset "$v"
done
export REX_AGENT_RESUME_HOME="$tmp/home" REX_AGENT_RESUME_STATE_DIR="$tmp/state" REX_CONFIG="$tmp/rex/init.lua"
mkdir -p "$REX_AGENT_RESUME_HOME"
rex=${REX_AGENT_RESUME_REX:-$(command -v rex || echo "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")}
"$rex" --autostart=false do "$root/test/run.lua"
