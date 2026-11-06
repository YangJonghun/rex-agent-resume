local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/test/fixtures/[^/]*$")
package.path = root .. "/lua/?.lua;" .. package.path
local util = require("rex-agent-resume.util")

for _, pane in ipairs(util.terminal_panes()) do
  rex.block.call(util.TERMINAL, "write", { block_id = pane.block_id, session_id = pane.session_id, data = rex.args.text })
end
