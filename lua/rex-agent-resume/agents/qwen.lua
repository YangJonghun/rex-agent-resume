-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "qwen", "--resume", "{id}" },
  replace_on = { "startup", "clear", "resume", "compact", "branch" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  install = {
    dir = { env = "QWEN_HOME", default = ".qwen" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { matcher = "*", hooks = { { type = "command", command = cmd, timeout = 10000 } } } end,
  },
}
