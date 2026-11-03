-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "claude", "--resume", "{id}" },
  replace_on = { "clear", "resume", "compact" },
  events = { "sessionstart" },
  id_fields = { "session_id" },
  skip_if = { "agent_id", "cursor_version" },
  skip_env = { "CURSOR_VERSION" },
  transcript_fields = { "transcript_path" },
  transcript = "projects/*/{id}.jsonl",
  session_file = { path = "sessions/{pid}.json", field = "sessionId" },
  install = {
    dir = { env = "CLAUDE_CONFIG_DIR", default = ".claude" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd)
      return { matcher = "^(startup|resume|clear|compact|fork)$", hooks = { { type = "command", command = cmd, timeout = 10 } } }
    end,
  },
}
