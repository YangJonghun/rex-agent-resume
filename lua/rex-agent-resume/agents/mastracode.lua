-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  -- --thread works only headless; the TUI ignores it and opens the project's newest thread.
  resume = { "mastracode", "resume", "{id}" },
  -- A new thread (first message, /new, a switch) reports itself as thread_change; until then
  -- the session id is the placeholder session-init.
  replace_on = { "startup", "thread_change" },
  ignore_ids = { "session-init" },
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
