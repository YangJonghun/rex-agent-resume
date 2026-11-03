-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "hermes", "--resume", "{id}" },
  replace_on = { "startup", "new", "resume" },
  events = { "sessionstart" },
  id_fields = { "session_id" },
  install = {
    dir = { env = "HERMES_HOME", default = ".hermes" },
    files = {
      { "plugins/rex-agent-resume/plugin.yaml", "hermes/plugin.yaml" },
      { "plugins/rex-agent-resume/__init__.py", "hermes/__init__.py" },
    },
    hermes_plugin = "rex-agent-resume",
  },
}
