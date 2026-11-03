-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "cursor-agent", "--resume", "{id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id", "sessionId", "conversation_id", "conversationId" },
  install = {
    dir = { env = "CURSOR_CONFIG_DIR", default = ".cursor" },
    file = "hooks.json",
    defaults = { version = 1 },
    lists = { { "hooks", "sessionStart" } },
    entry = function(cmd) return { command = cmd } end,
  },
}
