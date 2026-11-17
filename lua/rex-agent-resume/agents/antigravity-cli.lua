-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "agy", "--conversation", "{id}" },
  id_fields = { "conversationId" },
  -- agy reloads model and mode from its global settings, so only launch flags are lost.
  -- --model is left out: /model saves a newer choice there.
  launch_value_flags = { "--mode" },
  launch_options = function(flag)
    local options, mode = {}, flag["--mode"]
    if flag["--sandbox"] then options[#options + 1] = { args = { "--sandbox" } } end
    if mode == "plan" or mode == "accept-edits" or mode == "auto" then
      options[#options + 1] = { args = { "--mode", mode } }
    end
    if flag["--dangerously-skip-permissions"] then
      options[#options + 1] = { args = { "--dangerously-skip-permissions" }, skips_approval = true }
    end
    return options
  end,
  install = {
    dir = { env = "ANTIGRAVITY_CLI_CONFIG_DIR", default = ".gemini/config" },
    file = "hooks.json",
    lists = { { "rex-agent-resume", "PreInvocation" } },
    entry = function(cmd) return { type = "command", command = cmd, timeout = 10 } end,
  },
}
