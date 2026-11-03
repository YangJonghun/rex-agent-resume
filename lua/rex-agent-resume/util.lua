local M = {}

math.randomseed(os.time() + math.floor(os.clock() * 1e6))

M.TERMINAL = "com.superlogical.terminal"
M.LOG_PREFIX = "[rex-agent-resume] "

function M.home()
  return os.getenv("REX_AGENT_RESUME_HOME") or os.getenv("HOME")
end

function M.state_dir()
  local dir = os.getenv("REX_AGENT_RESUME_STATE_DIR")
  if dir and dir ~= "" then return dir end
  return M.home() .. "/.local/state/rex-agent-resume"
end

function M.path(name) return M.state_dir() .. "/" .. name end

function M.resume_on() return not M.exists(M.path("resume-off")) end

function M.record_path(block_id)
  return M.path("agents/" .. block_id:gsub("[:/]", "_") .. ".json")
end

function M.run(argv, stdin)
  return rex.exec(argv, stdin and { stdin = stdin } or nil)
end

function M.read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

function M.exists(path)
  local f = io.open(path, "r")
  if f then f:close() end
  return f ~= nil
end

function M.matches_file(pattern)
  if not pattern:find("*", 1, true) then return M.exists(pattern) end
  return M.run({ "sh", "-c", 'for f in $1; do [ -e "$f" ] && exit 0; done; exit 1', "sh", pattern }).ok
end

function M.mkdir_p(path)
  M.run({ "mkdir", "-p", "-m", "700", path })
end

function M.dirname(path) return (path:match("^(.*)/[^/]*$")) or "." end

local function open_creating(path, mode)
  local f = io.open(path, mode)
  if f then return f end
  M.mkdir_p(M.dirname(path))
  return io.open(path, mode)
end

function M.write_file(path, data)
  local tmp = path .. ".tmp" .. tostring({}):match("%x+$") .. math.random(1e6)
  local f = assert(open_creating(tmp, "w"))
  f:write(data)
  f:close()
  assert(os.rename(tmp, path))
end

function M.read_json(path)
  local data = M.read_file(path)
  if not data then return nil end
  local ok, value = pcall(rex.json.decode, data)
  return ok and value or nil
end

function M.write_json(path, value) M.write_file(path, rex.json.encode(value)) end

function M.list_dir(path)
  local r = M.run({ "ls", "-1A", path })
  local names = {}
  if r.ok then
    for name in r.stdout:gmatch("[^\n]+") do names[#names + 1] = name end
  end
  return names
end

function M.log(message)
  local f = open_creating(M.path("rex-agent-resume.log"), "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), M.LOG_PREFIX, message, "\n")
    f:close()
  end
end

function M.processes()
  local procs = {}
  local r = M.run({ "ps", "-axo", "pid=,ppid=,command=" })
  for line in r.stdout:gmatch("[^\n]+") do
    local pid, ppid, command = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
    if pid then procs[tonumber(pid)] = { ppid = tonumber(ppid), command = command } end
  end
  return procs
end

local SHELLS = { sh = true, bash = true, zsh = true, dash = true, ksh = true, fish = true }

function M.is_bare_shell(command)
  local first, second = command:match("^(%S+)%s*(%S*)")
  if not first then return false end
  local name = first:match("([^/]+)$"):gsub("^%-", "")
  return SHELLS[name] == true and (second == "" or second:sub(1, 1) == "-")
end

function M.rex_bin()
  local explicit = os.getenv("REX_AGENT_RESUME_REX")
  if explicit and explicit ~= "" then return explicit end
  local dir = os.getenv("REX_BIN_DIR")
  if dir and dir ~= "" then return dir .. "/rex" end
  local host = M.run({ "sh", "-c", 'readlink "/proc/$PPID/exe" 2>/dev/null || ps -o comm= -p $PPID' }).stdout
  local path = host:match("^(/.*/rex)%s*$")
  if path then return path end
  local found = M.run({ "sh", "-c", "command -v rex" }).stdout:match("^(%S.-)%s*$")
  return found
end

function M.shell_quote(word)
  if word ~= "" and not word:find("[^%w_%-%./:@%%+=]") then return word end
  return "'" .. word:gsub("'", "'\\''") .. "'"
end

function M.shell_join(argv)
  local words = {}
  for i, word in ipairs(argv) do words[i] = M.shell_quote(word) end
  return table.concat(words, " ")
end

-- Session methods answer only on a connection attached to that session.
local attached = {}
local function attach(session_id)
  if not attached[session_id] then
    rex.call("session.attach", { session_id = session_id })
    attached[session_id] = true
  end
end

function M.session_view(session_id)
  attach(session_id)
  return rex.call("session.view", { session_id = session_id })
end

function M.terminal_panes()
  local panes = {}
  for _, session in ipairs(rex.call("session.list").sessions or {}) do
    local view = M.session_view(session.session_id)
    for _, window in ipairs(view and view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          if block.creator_name == M.TERMINAL then
            panes[#panes + 1] = {
              block_id = block.block_id,
              session_id = session.session_id,
              where = (session.label or "?") .. " / " .. (window.label or "?"),
            }
          end
        end
      end
    end
  end
  return panes
end

function M.process(block_id, session_id)
  attach(session_id)
  return rex.block.call(M.TERMINAL, "process", { block_id = block_id, session_id = session_id })
end

return M
