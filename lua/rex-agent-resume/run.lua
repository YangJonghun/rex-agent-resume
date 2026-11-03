local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/lua/rex%-agent%-resume/[^/]*$")
package.path = root .. "/lua/?.lua;" .. package.path

local mode = rex.args.mode
if mode == "watch" then
  require("rex-agent-resume.watch").watch()
elseif mode == "resume" then
  require("rex-agent-resume.watch").resume_now()
elseif mode == "hook" then
  require("rex-agent-resume.hook").run(rex.args.agent, tonumber(rex.args.ppid))
elseif mode == "install" or mode == "uninstall" then
  local prefix = require("rex-agent-resume.util").LOG_PREFIX
  for _, line in ipairs(require("rex-agent-resume.install").run(root, mode == "install")) do print(prefix .. line) end
  rex.call("server.config_reload")
else
  error("mode must be watch, resume, hook, install or uninstall")
end
