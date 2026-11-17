-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "qwen", "--resume", "{id}" },
  replace_on = { "startup", "clear", "resume", "compact", "branch" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  transcript = "projects/*/chats/{id}.jsonl",
  -- The interactive CLI takes model and approval mode from flags and settings, not from the
  -- session it resumes; each prompt records the ones it ran with.
  transcript_options = function(last)
    local prompt = last('"executionContext"', function(r) return r.type == "user" and type(r.executionContext) == "table" end)
    local context = prompt and prompt.executionContext or {}
    local options = {}
    if type(context.modelId) == "string" then options[#options + 1] = { args = { "--model", context.modelId } } end
    if type(context.authType) == "string" then options[#options + 1] = { args = { "--auth-type", context.authType } } end
    if type(context.approvalMode) == "string" then
      options[#options + 1] = { args = { "--approval-mode", context.approvalMode }, skips_approval = context.approvalMode == "yolo" }
    end
    return options
  end,
  install = {
    dir = { env = "QWEN_HOME", default = ".qwen" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { matcher = "*", hooks = { { type = "command", command = cmd, timeout = 10000 } } } end,
  },
}
