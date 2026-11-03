local T = "com.superlogical.terminal"
local commands = {}
for command in (rex.args.commands or ""):gmatch("[^,]+") do commands[#commands + 1] = command end
local windows = {}
for i = 1, #commands do windows[i] = { layout = { block = { flavor = T .. ".shell" } } } end
local created = rex.call("session.create", { label = "e2e", initial_windows = windows })
local session_id = created.session_id or created.session.session_id
rex.call("session.attach", { session_id = session_id })
rex.sleep(2)
for i, window in ipairs(created.initial_windows) do
  rex.block.call(T, "write", { block_id = window.block_ids[1], session_id = session_id, data = commands[i] .. "\r" })
end
