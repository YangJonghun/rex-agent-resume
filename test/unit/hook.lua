local t = require("unit.lib")
local util = require("rex-agent-resume.util")
local hook = require("rex-agent-resume.hook")
local eq = t.eq

local procs = {
  [10] = { ppid = 1, command = "-zsh" },
  [11] = { ppid = 10, command = "claude" },
  [12] = { ppid = 11, command = "sh -c hook" },
  [13] = { ppid = 11, command = "zsh -c -l eval claude -p hi" },
  [14] = { ppid = 13, command = "claude -p hi" },
  [15] = { ppid = 14, command = "sh -c hook" },
  [20] = { ppid = 1, command = "-zsh" },
  [21] = { ppid = 20, command = "node /x/codex" },
  [22] = { ppid = 21, command = "/x/codex-native" },
  [30] = { ppid = 1, command = "-zsh" },
  [31] = { ppid = 30, command = "claude -p hi" },
}
eq(hook.pane_owner(12, procs, 11), 11, "agent in front owns the pane")
eq(hook.pane_owner(15, procs, 11), nil, "agent started by an agent does not")
eq(hook.pane_owner(31, procs, 30), nil, "background agent behind a shell does not")
eq(hook.pane_owner(22, procs, 21), 21, "wrapper process in front counts")
eq(util.is_bare_shell("bash ./script.sh"), false, "script run by bash is not a shell")
