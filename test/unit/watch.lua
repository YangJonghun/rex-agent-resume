local t = require("unit.lib")
local util = require("rex-agent-resume.util")
local watch = require("rex-agent-resume.watch")
local eq, env = t.eq, t.env

local panes = {
  { block_id = "block:a", session_id = "s", where = "s / w1" },
  { block_id = "block:b", session_id = "s", where = "s / w1" },
  { block_id = "block:c", session_id = "s", where = "s / w2" },
}
local snap = { agents = {
  { block_id = "block:a", agent = "claude", id = "c1" },
  { block_id = "block:gone", agent = "claude", id = "c2" },
  { block_id = "block:b", agent = "claude", id = "c3" },
  { block_id = "block:c", agent = "claude", id = "c1" },
  { block_id = "block:b", agent = "nope", id = "c4" },
} }
local running = { c3 = true }
local launches, lines = watch.plan_resume(snap, panes, running)
eq(running.c1, nil, "planning leaves the caller's running set alone")
eq(#launches, 1, "one pane resumed")
eq(launches[1] and launches[1].command, "claude --resume c1", "resume command typed")
eq(launches[1] and launches[1].entry.block_id, "block:a", "into the same block")
eq(lines[2], "skip claude block:gone (?): pane is not on this server", "missing pane skipped")
eq(lines[3], "skip claude block:b (?): session is already running", "running session skipped")
eq(lines[4], "skip claude block:c (?): session is already running", "same session resumed once")
eq(lines[5], "skip nope block:b (?): no resume command", "unknown agent skipped")
eq(watch.command_line("claude --resume c1", "/p/a", "/p/a", {}), "claude --resume c1", "typed as is in the right directory")
eq(watch.command_line("claude --resume c1", "/p/a b", "/h", {}), "cd -- '/p/a b' && claude --resume c1", "back to the session's directory first")
eq(watch.command_line("claude --resume c1", nil, "/h", { "CLAUDECODE" }), "env -u CLAUDECODE claude --resume c1", "inherited agent variables are dropped")
eq(table.concat(watch.inherited_env(env({ CLAUDE_CODE_CHILD_SESSION = "1" })), ","), "CLAUDE_CODE_CHILD_SESSION", "inherited agent variables are found")
local _, gone = watch.plan_resume({ agents = { { block_id = "block:a", agent = "claude", id = "c8", no_transcript = true } } }, panes, {})
eq(gone[1], "skip claude block:a (?): its conversation has no transcript yet", "a conversation without a transcript is not resumed")

local hsnap = { agents = {
  { block_id = "block:a", argv = { "pi", "--session", "/s/x" } },
  { block_id = "block:b", argv = { "vim", "notes.md" } },
} }
local hlaunches, hlines = watch.plan_resume(hsnap, panes, { ["vim notes.md"] = true })
eq(#hlaunches, 1, "hint pane resumed")
eq(hlaunches[1] and hlaunches[1].command, "pi --session /s/x", "hint command typed")
eq(hlines[2], "skip vim block:b (?): session is already running", "hint already on a command line skipped")

local function restore(rev, command) return (watch.restore_enabled({ api_revision = rev, command = command })) end
eq(restore(7, "rex server run --listen x"), false, "no restore before API revision 8")
eq(restore(8, "rex server run --listen x"), true, "restore is on by default from revision 8")
eq(restore(8, "rex server run --restore=false --listen x"), false, "--restore=false turns it off")
eq(restore(8, "rex server run --restore=true"), true, "--restore=true keeps it on")

local started, now = 1000, 1100
local fg = { pid = 50 }
eq(watch.pane_agent({ agent = "claude", pid = 50, id = "c1", updated_at = 1001 }, fg, nil, started, now), true, "agent still in front")
eq(watch.pane_agent({ agent = "claude", pid = 49, id = "c1", updated_at = 1001 }, fg, nil, started, now), false, "agent gone")
eq(watch.pane_agent({ agent = "claude", pid = 50, id = "c1", updated_at = 999 }, fg, nil, started, now), false, "record from the previous server ignored")
eq(watch.pane_agent({ agent = "claude", id = "c1", updated_at = 1090 }, fg, "-zsh", started, now), true, "just resumed, agent still starting")
eq(watch.pane_agent({ agent = "claude", id = "c1", updated_at = 1001 }, fg, "-zsh", started, now), false, "resume that never started expires")
local counted, confirm = watch.pane_agent({ agent = "claude", id = "c1", updated_at = 1001 }, fg, "claude --resume c1", started, now)
eq(counted and confirm, 50, "resumed agent confirmed from its command line")
local hcounted, hconfirm = watch.pane_agent({ argv = { "pi", "--session", "/s/x" }, updated_at = 1001 }, fg, "pi --session /s/x", started, now)
eq(hcounted and hconfirm, 50, "resumed hint confirmed from its command line")

util.write_json(util.path("snapshots/old.json"), { instance = "old", saved_at = os.time() - 4 * 24 * 3600, agents = {} })
eq(watch.pick_snapshot("now", os.time()), nil, "snapshots older than 3 days are not resumed")
util.write_json(util.path("snapshots/prev.json"), { instance = "prev", saved_at = os.time() - 60, agents = {} })
util.write_json(util.path("snapshots/now.json"), { instance = "now", saved_at = os.time(), agents = {} })
eq(watch.pick_snapshot("now", os.time()).instance, "prev", "latest snapshot of another server")
