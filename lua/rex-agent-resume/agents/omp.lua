-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "omp", "--resume={id}" },
  replace_on = { "startup", "new", "resume", "fork" },
  replace_paths = true,
  events = { "sessionstart" },
  id_fields = { "session_id" },
  skip_env = { "OMPCODE" },
  install = {
    dir = { env = "PI_CODING_AGENT_DIR", home_env = "PI_CONFIG_DIR", home_suffix = "agent", default = ".omp/agent" },
    files = { { "extensions/rex-agent-resume-omp.ts", "omp/rex-agent-resume.ts" } },
    not_with = "pi",
  },
}
