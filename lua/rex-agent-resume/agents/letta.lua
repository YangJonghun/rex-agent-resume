-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "letta", "--conversation", "{id}" },
  resume_default = { "letta", "--conversation", "default", "--agent", "{rest}" },
  events = { "sessionstart", "" },
  id_fields = { "conversation_id" },
  default_agent = "agent_id",
  install = {
    dir = { default = ".letta" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { hooks = { { type = "command", command = cmd, timeout = 10000, quiet = true } } } end,
  },
}
