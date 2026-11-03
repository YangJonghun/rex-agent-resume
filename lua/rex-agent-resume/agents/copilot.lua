-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "copilot", "--resume={id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id", "sessionId" },
  bare_guard = { "prompt", "tool_name", "toolName", "notification_type", "stop_reason", "reason", "notificationType", "stopReason" },
  install = {
    dir = { env = "COPILOT_HOME", default = ".copilot" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { type = "command", bash = cmd, timeoutSec = 10 } end,
  },
}
