-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "opencode", "--session", "{id}" },
  replace_on = { "select" },
  events = { "sessionstart" },
  id_fields = { "session_id" },
  install = {
    dir = { default = ".config/opencode" },
    files = {
      { "plugins/rex-agent-resume.js", "opencode/rex-agent-resume.js" },
      { "rex-agent-resume-tui.js", "opencode/rex-agent-resume-tui.js" },
      { "rex-agent-resume-opencode/tui.js", "opencode/tui.js" },
    },
    opencode_plugins = { tui = "./rex-agent-resume-tui.js", cli = "./rex-agent-resume-opencode" },
  },
}
