-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "cursor-agent", "--resume", "{id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id", "sessionId", "conversation_id", "conversationId" },
  install = {
    -- Its config dir follows CURSOR_CONFIG_DIR and XDG_CONFIG_HOME, but user hooks are
    -- read from ~/.cursor/hooks.json only.
    dir = { default = ".cursor" },
    file = "hooks.json",
    defaults = { version = 1 },
    lists = { { "hooks", "sessionStart" } },
    entry = function(cmd) return { command = cmd } end,
  },
}
