-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "qodercli", "--resume", "{id}" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  transcript = "projects/*/{id}.jsonl",
  -- qodercli restores model and effort itself, but starts in the default permission mode.
  transcript_options = function(last)
    local prompt = last('"permissionMode":"', function(r) return r.type == "user" and type(r.permissionMode) == "string" end)
    if not prompt then return {} end
    return { { args = { "--permission-mode", prompt.permissionMode }, skips_approval = prompt.permissionMode == "yolo" } }
  end,
  install = {
    dir = { env = "QODER_CONFIG_DIR", default = ".qoder" },
    file = "settings.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { matcher = "*", hooks = { { type = "command", command = cmd, timeout = 10 } } } end,
  },
}
