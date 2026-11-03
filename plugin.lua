local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$")
package.path = root .. "/lua/?.lua;" .. package.path

local util = require("rex-agent-resume.util")

local rex_bin = util.rex_bin()

-- An action cannot reload the file that defines it, so a separate client does it a moment
-- later. The app keeps its own copy of action titles; when the action came from its palette
-- or a key, ask that app to reload as well so it shows the new title.
local function reload_later(ctx)
  if rex_bin then
    rex.exec.start({ "sh", "-c", 'sleep 0.3; exec "$0" --autostart=false config reload', rex_bin }, { detach = true })
  end
  if ctx and (ctx.origin == "palette" or ctx.origin == "key") then
    pcall(rex.client.queue, "client.config.reload")
  end
end

rex.action{
  name = "agent_resume_toggle",
  title = (util.resume_on() and "Turn Off" or "Turn On") .. " Agent Resume on Startup",
  run = function(ctx)
    local on = util.resume_on()
    if on then
      util.write_file(util.path("resume-off"), "")
    else
      os.remove(util.path("resume-off"))
    end
    require("rex-agent-resume.install").edit_rex_config(root, true)
    reload_later(ctx)
    if not on and rex_bin then
      rex.exec.start({ rex_bin, "--autostart=false", "do", root .. "/lua/rex-agent-resume/run.lua", "mode=resume" }, { detach = true })
    end
    return "Agent resume on startup is now " .. (on and "off" or "on") .. "."
  end,
}

rex.action{
  name = "agent_resume_uninstall",
  title = "Uninstall rex-agent-resume",
  run = function(ctx)
    local lines = require("rex-agent-resume.install").run(root, false)
    reload_later(ctx)
    return table.concat(lines, "\n")
  end,
}

-- Programs call this to say how to reopen their pane:
--   rex do agent_resume_hint 'argv=["pi","--session","/path/abc.jsonl"]'
rex.action{
  name = "agent_resume_hint",
  title = "Register Resume Command for This Pane",
  args = { argv = "array" },
  run = function(ctx, args)
    return require("rex-agent-resume.hook").hint(ctx.client_id, args.argv)
  end,
}

if rex_bin then
  rex.exec.start({ rex_bin, "--autostart=false", "do", root .. "/lua/rex-agent-resume/run.lua", "--all", "mode=watch" }, { detach = true })
else
  rex.log("warn", util.LOG_PREFIX .. "cannot find the rex binary; set REX_AGENT_RESUME_REX")
end
