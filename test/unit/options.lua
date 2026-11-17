local t = require("unit.lib")
local util = require("rex-agent-resume.util")
local agents = require("rex-agent-resume.agents")
local eq, no_env = t.eq, t.no_env

local function transcript(path, records)
  local lines = {}
  for i, record in ipairs(records) do lines[i] = rex.json.encode(record) end
  util.write_file(util.home() .. "/" .. path, table.concat(lines, "\n") .. "\n")
end

local function restored(agent, id, skip_approvals)
  local rec = { agent = agent, id = id }
  local found = agents.transcript_options(agents.specs[agent], id, no_env, util.home(), util.newest_records)
  rec.transcript_options = agents.kept_options(found, skip_approvals)
  local argv = agents.resume_of(rec)
  return argv and util.shell_join(argv)
end

transcript(".claude/projects/-p/c1.jsonl", {
  { type = "user", permissionMode = "plan" },
  { type = "assistant", effort = "low" },
  { type = "assistant", effort = "high", isSidechain = false },
  { type = "assistant", effort = "max", isSidechain = true },
  { type = "system", tools = { { input_schema = { effort = { type = "string" } } } } },
  { type = "user", permissionMode = "default" },
  { type = "permission-mode", permissionMode = "bypassPermissions" },
})
eq(restored("claude", "c1", false), "claude --resume c1 --effort high", "claude effort from the newest main-thread turn, bypass left out")
eq(restored("claude", "c1", true), "claude --resume c1 --effort high --permission-mode bypassPermissions", "bypass restored when asked")
transcript(".claude/projects/-p/c2.jsonl", {
  { type = "permission-mode", permissionMode = "bypassPermissions" },
  { type = "user", permissionMode = "default" },
})
eq(restored("claude", "c2", false), "claude --resume c2 --permission-mode default", "Manual is restored, not left to defaultMode")
transcript(".claude/projects/-p/c3.jsonl", {
  { type = "assistant", effort = "medium" },
  { type = "user", permissionMode = "auto" },
})
eq(restored("claude", "c3", true), "claude --resume c3 --effort medium", "modes Claude restores itself get no flag")
transcript(".claude/projects/-p/c4.jsonl", { { type = "assistant", effort = "--dangerously-skip-permissions" } })
eq(restored("claude", "c4", true), "claude --resume c4", "a value that looks like a flag is dropped")
eq(restored("claude", "c5", true), "claude --resume c5", "no transcript, no options")
eq(restored("codex", "x1", true), "codex --no-daemon resume x1", "agents that restore everything get nothing")

transcript(".qwen/projects/-p/chats/q1.jsonl", {
  { type = "user", executionContext = { modelId = "old", authType = "qwen-oauth", approvalMode = "plan" } },
  { type = "assistant", model = "qwen3-coder" },
  { type = "user", executionContext = { modelId = "qwen3-coder", authType = "openai", approvalMode = "yolo" } },
})
eq(restored("qwen", "q1", false), "qwen --resume q1 --model qwen3-coder --auth-type openai", "qwen model and auth from the newest prompt, yolo left out")
eq(restored("qwen", "q1", true), "qwen --resume q1 --model qwen3-coder --auth-type openai --approval-mode yolo", "yolo as --approval-mode when asked")
transcript(".qwen/projects/-p/chats/q2.jsonl", { { type = "user", executionContext = { modelId = "m", approvalMode = "auto-edit" } } })
eq(restored("qwen", "q2", false), "qwen --resume q2 --model m --approval-mode auto-edit", "no auth type, no --auth-type")

transcript(".qoder/projects/-p/d1.jsonl", {
  { type = "user", permissionMode = "yolo" },
  { type = "user", permissionMode = "acceptEdits" },
})
eq(restored("qodercli", "d1", false), "qodercli --resume d1 --permission-mode acceptEdits", "qodercli mode from the newest prompt")
transcript(".qoder/projects/-p/d2.jsonl", { { type = "user", permissionMode = "yolo" } })
eq(restored("qodercli", "d2", false), "qodercli --resume d2", "qodercli yolo left out")
eq(restored("qodercli", "d2", true), "qodercli --resume d2 --permission-mode yolo", "and restored when asked")
transcript(".qoder/projects/-p/d3.jsonl", { { type = "user", permissionMode = "auto" } })
eq(restored("qodercli", "d3", false), "qodercli --resume d3 --permission-mode auto", "a classifier-gated mode is not skips_approval")
