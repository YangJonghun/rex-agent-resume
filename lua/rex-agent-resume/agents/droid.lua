-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "droid", "--resume", "{id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  install = {
    dir = { default = ".factory" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { hooks = { { type = "command", command = cmd, timeout = 10 } } } end,
  },
}
