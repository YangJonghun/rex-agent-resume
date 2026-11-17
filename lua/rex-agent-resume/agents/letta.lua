-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "letta", "--conversation", "{id}" },
  resume_default = { "letta", "--conversation", "default", "--agent", "{rest}" },
  events = { "sessionstart", "" },
  id_fields = { "conversation_id" },
  default_agent = "agent_id",
  -- Letta keeps the permission mode in memory only.
  launch_value_flags = { "--permission-mode" },
  launch_options = function(flag)
    local mode = flag["--permission-mode"]
    if flag["--yolo"] or mode == "unrestricted" or mode == "bypassPermissions" or mode == "fullAccess" then
      return { { args = { "--permission-mode", "unrestricted" }, skips_approval = true } }
    end
    if mode == "standard" or mode == "acceptEdits" or mode == "strict" or mode == "plan" or mode == "default" then
      return { { args = { "--permission-mode", mode } } }
    end
    return {}
  end,
  install = {
    dir = { default = ".letta" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { hooks = { { type = "command", command = cmd, timeout = 10000, quiet = true } } } end,
  },
}
