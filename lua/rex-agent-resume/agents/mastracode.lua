-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "mastracode", "--thread", "{id}" },
  replace_on = { "startup" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  install = {
    dir = { default = ".mastracode" },
    file = "hooks.json",
    lists = { { "SessionStart" } },
    entry = function(cmd)
      return { type = "command", command = cmd, timeout = 10000, description = "Record the MastraCode session for rex-agent-resume" }
    end,
  },
}
