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
  -- Claude restores model and permission mode itself but not effort. It drops
  -- bypassPermissions on purpose, and brings Manual back as the settings' defaultMode.
  transcript_options = function(last)
    local options = {}
    local turn = last('"effort":"', function(r)
      return r.type == "assistant" and r.isSidechain ~= true and type(r.effort) == "string"
    end)
    if turn then options[#options + 1] = { args = { "--effort", turn.effort } } end
    local mode = last('"permissionMode":"', function(r)
      return (r.type == "permission-mode" or r.type == "user") and type(r.permissionMode) == "string"
    end)
    mode = mode and mode.permissionMode
    if mode == "default" or mode == "bypassPermissions" then
      options[#options + 1] = { args = { "--permission-mode", mode }, skips_approval = mode == "bypassPermissions" }
    end
    return options
  end,
  install = {
    dir = { env = "CLAUDE_CONFIG_DIR", default = ".claude" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd)
      return { matcher = "^(startup|resume|clear|compact|fork)$", hooks = { { type = "command", command = cmd, timeout = 10 } } }
    end,
  },
}
