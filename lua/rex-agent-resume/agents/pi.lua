-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "pi", "--session", "{id}" },
  replace_on = { "new", "resume", "fork" },
  replace_paths = true,
  events = { "sessionstart" },
  id_fields = { "session_id" },
  install = {
    dir = { env = "PI_CODING_AGENT_DIR", default = ".pi/agent" },
    files = { { "extensions/rex-agent-resume.ts", "pi/rex-agent-resume.ts" } },
  },
}
