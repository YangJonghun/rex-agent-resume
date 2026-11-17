local t = require("unit.lib")
local util = require("rex-agent-resume.util")
local agents = require("rex-agent-resume.agents")
local watch = require("rex-agent-resume.watch")
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

local function launched(agent, command, skip_approvals)
  local options = agents.launch_options(agents.specs[agent], command)
  local rec = { agent = agent, id = "s1", options = agents.kept_options(options, skip_approvals) }
  local argv = agents.resume_of(rec)
  return argv and util.shell_join(argv)
end

local flags = agents.read_flags({ "omp", "--profile", "work", "--approval-mode=write", "--yolo", "--profile", "home", "prompt" }, { "--profile" })
eq(flags["--profile"], "home", "--flag value, the last one wins")
eq(flags["--approval-mode"], "write", "--flag=value")
eq(flags["--yolo"], true, "a bare flag is true")
eq(flags.prompt, nil, "words that are not flags are left out")
eq(agents.read_flags({ "x", "--profile" }, { "--profile" })["--profile"], true, "a value flag at the end has no value")

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

local rec = { agent = "claude", id = "c1", options = { { args = { "--effort", "high" } } } }
eq(select(2, agents.resume_of(rec)), "c1", "options never change the key")
local _, already = watch.plan_resume({ agents = { { block_id = "block:a", agent = "claude", id = "c1", options = rec.options } } },
  { { block_id = "block:a", session_id = "s", where = "w" } }, { c1 = true })
eq(already[1], "skip claude block:a (?): session is already running", "a running session with options is still found by its id")

local report = { agent = "claude", id = "c1", options = rec.options }
local merged = agents.merge_report(nil, report, 7, true)
eq(merged.options, rec.options, "options come with the report")
local pending = agents.merge_report({ agent = "claude", id = "c0", pid = 7 }, { agent = "claude", id = "c1", transcript = "/t", source = "clear", options = rec.options }, 7, false)
agents.promote(pending, function() return true end)
eq(pending.id == "c1" and pending.options, rec.options, "and stay through promotion")
local entry = watch.snapshot_entry(merged, { block_id = "block:a", where = "w" }, { cwd = "/p" })
eq(entry.options, rec.options, "a snapshot keeps the options")
eq(watch.resumed_record(entry, "s", 1).options[1].args[2], "high", "so does the record written when the resume is typed")

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

eq(launched("omp", "omp --profile work --approval-mode write", false), "omp --resume=s1 --profile work --approval-mode write", "omp profile and approval mode")
eq(launched("omp", "omp --approval-mode=always-ask-cached", false), "omp --resume=s1 --approval-mode always-ask-cached", "omp --flag=value")
eq(launched("omp", "omp --yolo", false), "omp --resume=s1", "omp yolo left out")
eq(launched("omp", "omp --auto-approve", true), "omp --resume=s1 --approval-mode yolo", "omp auto-approve restored as yolo when asked")
eq(launched("omp", "omp --plan-yolo", true), "omp --resume=s1", "omp plan-yolo is a one-shot flow")

eq(launched("letta", "letta --permission-mode acceptEdits", false), "letta --conversation s1 --permission-mode acceptEdits", "letta mode")
eq(launched("letta", "letta --yolo", false), "letta --conversation s1", "letta yolo left out")
eq(launched("letta", "letta --permission-mode bypassPermissions", true), "letta --conversation s1 --permission-mode unrestricted", "letta legacy names restored as unrestricted")
eq(launched("letta", "letta", true), "letta --conversation s1", "letta without a flag gets none")

eq(launched("devin", "devin --permission-mode smart", false), "devin --resume s1 --permission-mode smart", "devin mode")
eq(launched("devin", "devin --permission-mode dangerous", false), "devin --resume s1", "devin dangerous left out")
eq(launched("devin", "devin --permission-mode yolo", true), "devin --resume s1 --permission-mode yolo", "and restored when asked")
eq(launched("devin", "devin --sandbox --permission-mode autonomous", false), "devin --resume s1 --sandbox --permission-mode autonomous", "devin autonomous with its sandbox")
eq(launched("devin", "devin --permission-mode autonomous", true), "devin --resume s1", "never autonomous without the sandbox")

eq(launched("kilo", "node /x/kilo --auto", false), "kilo --session s1", "kilo auto-approve left out")
eq(launched("kilo", "node /x/kilo --auto", true), "kilo --session s1 --auto", "and restored when asked")
eq(launched("opencode", "opencode --dangerously-skip-permissions", true), "opencode --session s1 --auto", "opencode aliases restored as --auto")
eq(launched("antigravity-cli", "agy --sandbox --mode accept-edits --model gemini-pro", false), "agy --conversation s1 --sandbox --mode accept-edits", "agy sandbox and mode, not the model /model may have changed")
eq(launched("antigravity-cli", "agy --mode=auto --dangerously-skip-permissions", false), "agy --conversation s1 --mode auto", "agy skip-permissions left out")
eq(launched("antigravity-cli", "agy --dangerously-skip-permissions", true), "agy --conversation s1 --dangerously-skip-permissions", "and restored when asked")
eq(launched("cursor", "cursor-agent --force", true), "cursor-agent --resume s1", "agents that restore everything get nothing")
