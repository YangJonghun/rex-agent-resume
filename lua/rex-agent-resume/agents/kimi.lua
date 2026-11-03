-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "kimi", "--session", "{id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  install = { dir = { env = "KIMI_CODE_HOME", default = ".kimi-code" }, file = "config.toml", kimi_toml = true },
}
