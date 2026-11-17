-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
local SKIPS_APPROVAL = {
  normal = false, auto = false, ["accept-edits"] = false, smart = false,
  dangerous = true, yolo = true, bypass = true,
}

return {
  resume = { "devin", "--resume", "{id}" },
  events = { "sessionstart", "userpromptsubmit", "pretooluse", "posttooluse", "permissionrequest", "stop", "" },
  id_fields = { "session_id", "sessionId" },
  -- Devin takes the permission mode and sandbox from flags or config, not from the session.
  launch_value_flags = { "--permission-mode" },
  launch_options = function(flag)
    local options, mode = {}, flag["--permission-mode"]
    if flag["--sandbox"] then options[#options + 1] = { args = { "--sandbox" } } end
    if SKIPS_APPROVAL[mode] ~= nil then
      options[#options + 1] = { args = { "--permission-mode", mode }, skips_approval = SKIPS_APPROVAL[mode] }
    elseif mode == "autonomous" and flag["--sandbox"] then
      options[#options + 1] = { args = { "--permission-mode", mode } }
    end
    return options
  end,
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
