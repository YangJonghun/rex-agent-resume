-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "qodercli", "--resume", "{id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  install = {
    dir = { env = "QODER_CONFIG_DIR", default = ".qoder" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { matcher = "*", hooks = { { type = "command", command = cmd, timeout = 10 } } } end,
  },
}
