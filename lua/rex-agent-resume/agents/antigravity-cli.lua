-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "agy", "--conversation", "{id}" },
  id_fields = { "conversationId" },
  install = {
    dir = { env = "ANTIGRAVITY_CLI_CONFIG_DIR", default = ".gemini/config" },
    file = "hooks.json",
    lists = { { "rex-agent-resume", "PreInvocation" } },
    entry = function(cmd) return { type = "command", command = cmd, timeout = 10 } end,
  },
}
