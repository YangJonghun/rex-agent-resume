-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "grok", "--resume", "{id}" },
  replace_on = { "new" },
  events = { "sessionstart", "" },
  id_fields = { "session_id", "sessionId" },
  id_env = "GROK_SESSION_ID",
  install = {
    dir = { env = "GROK_CONFIG_DIR", env2 = "GROK_HOME", default = ".grok" },
    file = "hooks/rex-agent-resume.json",
    own_file = true,
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { hooks = { { type = "command", command = cmd, timeout = 10 } } } end,
  },
}
