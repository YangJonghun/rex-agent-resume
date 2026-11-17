-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "kilo", "--session", "{id}" },
  events = { "sessionstart" },
  id_fields = { "session_id" },
  -- Auto-approve lives only in the running TUI.
  launch_options = function(flag)
    if flag["--auto"] or flag["--yolo"] or flag["--dangerously-skip-permissions"] then
      return { { args = { "--auto" }, skips_approval = true } }
    end
    return {}
  end,
  install = {
    dir = { default = ".config/kilo" },
    files = { { "plugin/rex-agent-resume.js", "kilo/rex-agent-resume.js" } },
  },
}
