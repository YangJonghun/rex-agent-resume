local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/test/[^/]*$")
package.path = root .. "/lua/?.lua;" .. root .. "/test/?.lua;" .. package.path

local util = require("rex-agent-resume.util")
assert(util.home() ~= os.getenv("HOME"), "run through test/run.sh so the real home is never touched")

for _, name in ipairs({ "agents", "detect", "hook", "watch", "install" }) do
  require("unit." .. name)
end

if not require("unit.lib").report() then rex.stop(1) end
