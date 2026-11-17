-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "omp", "--resume={id}" },
  replace_on = { "startup", "new", "resume", "fork" },
  replace_paths = true,
  events = { "sessionstart" },
  id_fields = { "session_id" },
  skip_env = { "OMPCODE" },
  -- omp never saves the approval mode, and a session lives in the profile it ran under.
  launch_value_flags = { "--approval-mode", "--profile" },
  launch_options = function(flag)
    local options, mode = {}, flag["--approval-mode"]
    if type(flag["--profile"]) == "string" then options[#options + 1] = { args = { "--profile", flag["--profile"] } } end
    if mode == "yolo" or flag["--auto-approve"] or flag["--yolo"] then
      options[#options + 1] = { args = { "--approval-mode", "yolo" }, skips_approval = true }
    elseif mode == "always-ask" or mode == "always-ask-cached" or mode == "write" then
      options[#options + 1] = { args = { "--approval-mode", mode } }
    end
    return options
  end,
  install = {
    dir = { env = "PI_CODING_AGENT_DIR", home_env = "PI_CONFIG_DIR", home_suffix = "agent", default = ".omp/agent" },
    files = { { "extensions/rex-agent-resume-omp.ts", "omp/rex-agent-resume.ts" } },
    not_with = "pi",
  },
}
