-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "devin", "--resume", "{id}" },
  events = { "sessionstart", "userpromptsubmit", "pretooluse", "posttooluse", "permissionrequest", "stop", "" },
  id_fields = { "session_id", "sessionId" },
  install = {
    dir = { env = "XDG_CONFIG_HOME", suffix = "devin", default = ".config/devin" },
    file = "config.json",
    lists = {
      { "hooks", "SessionStart" }, { "hooks", "UserPromptSubmit" }, { "hooks", "PreToolUse" },
      { "hooks", "PostToolUse" }, { "hooks", "PermissionRequest" }, { "hooks", "Stop" },
    },
    entry = function(cmd) return { hooks = { { type = "command", command = cmd, timeout = 10 } } } end,
  },
}
