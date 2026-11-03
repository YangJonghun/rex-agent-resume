-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "kilo", "--session", "{id}" },
  events = { "sessionstart" },
  id_fields = { "session_id" },
  install = {
    dir = { default = ".config/kilo" },
    files = { { "plugin/rex-agent-resume.js", "kilo/rex-agent-resume.js" } },
  },
}
