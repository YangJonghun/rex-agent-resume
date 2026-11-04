local util = require("rex-agent-resume.util")
local agents = require("rex-agent-resume.agents")

local M = {}

local KEEP_SNAPSHOTS = 5
local SNAPSHOT_MAX_AGE = 3 * 24 * 3600
local UNCONFIRMED_RESUME_TTL = 60
local RECORD_TTL = 7 * 24 * 3600
local RESUME_ONLY_WITHIN = 120
local SAVE_DELAY = 2
local SAVE_EVERY = 300
local STAMP_EVERY = 2
local SHELL_WAIT_TRIES, SHELL_WAIT_STEP = 20, 0.25
local LAUNCH_GAP = 0.1

-- server.status gives UTC timestamps; os.time reads a table as local time.
local function parse_utc(text)
  local y, mo, d, h, mi, s = (text or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return nil end
  local t = { year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) }
  local local_epoch = os.time(t)
  return local_epoch + (local_epoch - os.time(os.date("!*t", local_epoch)))
end

function M.server()
  local status = rex.call("server.status")
  return {
    instance = status.instance_id,
    started = parse_utc(status.started_at) or os.time(),
    api_revision = status.api_revision or 0,
    command = util.run({ "ps", "-o", "command=", "-p", tostring(status.pid) }).stdout,
  }
end

function M.restore_enabled(server)
  if server.api_revision < 8 then
    return false, "Rex API revision " .. server.api_revision .. " has no session restore (needs 8 or later)"
  end
  local value = (server.command or ""):match("%-%-restore=(%S+)")
  if value and (value:lower() == "false" or value == "0" or value:lower() == "f") then
    return false, "the server runs with --restore=" .. value
  end
  return true
end

function M.pane_agent(rec, fg, command, started, now)
  local key = select(2, agents.resume_of(rec)) or (rec.pending and rec.pending.id)
  if not key or not fg or (rec.updated_at or 0) < started then return false end
  if rec.pid then return fg.pid == rec.pid end
  if command and command:find(key, 1, true) then return true, fg.pid end
  return now - (rec.updated_at or 0) < UNCONFIRMED_RESUME_TTL
end

function M.take_snapshot(server)
  local panes, out, procs = util.terminal_panes(), {}, nil
  for _, pane in ipairs(panes) do
    local path = util.record_path(pane.block_id)
    local rec = util.read_json(path)
    if rec and agents.promote(rec, util.matches_file) then util.write_json(path, rec) end
    if rec and (agents.resume_of(rec) or rec.pending) then
      local process = util.process(pane.block_id, pane.session_id)
      local fg = process and process.foreground
      local command
      if fg and not rec.pid then
        procs = procs or util.processes()
        command = procs[fg.pid] and procs[fg.pid].command
      end
      local counted, confirm = M.pane_agent(rec, fg, command, server.started, os.time())
      if confirm then
        rec.pid = confirm
        util.write_json(path, rec)
      end
      if counted then
        out[#out + 1] = {
          block_id = pane.block_id, where = pane.where, agent = rec.agent, id = rec.id, argv = rec.argv,
          pending = rec.pending, cwd = rec.cwd or fg.cwd,
        }
      end
    end
  end
  return { instance = server.instance, saved_at = os.time(), agents = out }
end

local function fingerprint(snap)
  local parts = {}
  for _, a in ipairs(snap.agents) do
    local _, key = agents.resume_of(a)
    parts[#parts + 1] = a.block_id .. "|" .. tostring(key) .. "|" .. tostring(a.pending and a.pending.id) .. "|" .. a.where
  end
  return table.concat(parts, "\n")
end

function M.list_snapshots()
  local snaps = {}
  for _, name in ipairs(util.list_dir(util.path("snapshots"))) do
    local snap = name:match("%.json$") and util.read_json(util.path("snapshots/" .. name))
    if snap and snap.instance and snap.saved_at then
      snap.file = util.path("snapshots/" .. name)
      snaps[#snaps + 1] = snap
    end
  end
  table.sort(snaps, function(a, b) return a.saved_at > b.saved_at end)
  return snaps
end

function M.pick_snapshot(instance, now)
  for _, snap in ipairs(M.list_snapshots()) do
    if snap.instance ~= instance then
      if now - snap.saved_at <= SNAPSHOT_MAX_AGE then return snap end
      return nil
    end
  end
end

function M.prune(panes)
  for i, snap in ipairs(M.list_snapshots()) do
    if i > KEEP_SNAPSHOTS then os.remove(snap.file) end
  end
  local live = {}
  for _, pane in ipairs(panes) do live[util.record_path(pane.block_id)] = true end
  for _, name in ipairs(util.list_dir(util.path("agents"))) do
    local path = util.path("agents/" .. name)
    local rec = util.read_json(path)
    if not rec or (not live[path] and os.time() - (rec.updated_at or 0) > RECORD_TTL) then os.remove(path) end
  end
end

function M.running_keys(procs, started)
  local running = {}
  for _, proc in pairs(procs) do
    running[proc.command] = true
    for word in proc.command:gmatch("[^%s=]+") do running[word] = true end
  end
  for _, name in ipairs(util.list_dir(util.path("agents"))) do
    local rec = util.read_json(util.path("agents/" .. name))
    local key = rec and select(2, agents.resume_of(rec))
    if key and (rec.updated_at or 0) >= started and procs[rec.pid] then running[key] = true end
  end
  return running
end

function M.plan_resume(snap, panes, running)
  local by_block, claimed, launches, lines = {}, {}, {}, {}
  for _, pane in ipairs(panes) do by_block[pane.block_id] = pane end
  for _, a in ipairs(snap.agents or {}) do
    local label = agents.label(a) .. " " .. a.block_id .. " (" .. (a.where or "?") .. ")"
    local pane = by_block[a.block_id]
    local argv, key = agents.resume_of(a)
    if not pane then
      lines[#lines + 1] = "skip " .. label .. ": pane is not on this server"
    elseif not argv and a.pending then
      lines[#lines + 1] = "skip " .. label .. ": its conversation has no transcript yet"
    elseif not argv then
      lines[#lines + 1] = "skip " .. label .. ": no resume command"
    elseif a.no_transcript then
      lines[#lines + 1] = "skip " .. label .. ": its conversation has no transcript yet"
    elseif running[key] or claimed[(a.argv and (a.cwd or "") .. "\0" or "") .. key] then
      lines[#lines + 1] = "skip " .. label .. ": session is already running"
    else
      claimed[(a.argv and (a.cwd or "") .. "\0" or "") .. key] = true
      local command = util.shell_join(argv)
      lines[#lines + 1] = "run " .. command .. " in " .. a.block_id .. " (" .. pane.where .. ")"
      launches[#launches + 1] = { entry = a, session_id = pane.session_id, command = command }
    end
  end
  return launches, lines
end

-- A restored pane shows login, then the shell, then whatever the shell's rc files run.
-- Wait until the shell itself is in front; the tty buffers what we type after that.
local function wait_for_shell(launch)
  local front
  for _ = 1, SHELL_WAIT_TRIES do
    local process = util.process(launch.entry.block_id, launch.session_id)
    local fg = process and process.foreground
    front = fg and (fg.argv0 or fg.name)
    if front and util.is_bare_shell(front) then return true, fg end
    rex.sleep(SHELL_WAIT_STEP)
  end
  return false, nil, front
end

-- Agent variables that make a nested session out of anything started under them. herdr
-- removes them from every pane it starts; here the watcher inherits the server's
-- environment, which is what the panes get, so finding them here means the panes have them.
local INHERITED = {
  "CLAUDECODE", "CLAUDE_CODE_CHILD_SESSION", "CLAUDE_CODE_SESSION_ID", "CLAUDE_CODE_MESSAGING_TOKEN",
  "CODEX_THREAD_ID", "OMPCODE",
}

function M.inherited_env(getenv)
  local found = {}
  for _, name in ipairs(INHERITED) do
    if getenv(name) then found[#found + 1] = name end
  end
  return found
end

function M.command_line(command, cwd, shell_cwd, strip)
  local line = command
  if #strip > 0 then line = "env -u " .. table.concat(strip, " -u ") .. " " .. line end
  if cwd and cwd ~= shell_cwd then line = "cd -- " .. util.shell_quote(cwd) .. " && " .. line end
  return line
end

function M.resume(server)
  local snap = M.pick_snapshot(server.instance, os.time())
  if not snap then return util.log("resume: no recent snapshot from an earlier server") end
  util.log("resume: snapshot " .. snap.instance .. " saved " .. os.date("%Y-%m-%d %H:%M:%S", snap.saved_at))
  for _, entry in ipairs(snap.agents or {}) do
    agents.promote(entry, util.matches_file)
    local spec = agents.specs[entry.agent]
    local transcript = spec and agents.transcript_pattern(spec, entry.id, os.getenv, util.home())
    entry.no_transcript = transcript ~= nil and not util.matches_file(transcript)
  end
  local launches, lines = M.plan_resume(snap, util.terminal_panes(), M.running_keys(util.processes(), server.started))
  for _, line in ipairs(lines) do util.log(line) end
  local strip = M.inherited_env(os.getenv)
  local count = 0
  for _, launch in ipairs(launches) do
    local entry = launch.entry
    local ready, shell, front = wait_for_shell(launch)
    if ready and entry.cwd and not util.run({ "test", "-d", entry.cwd }).ok then
      util.log("skip " .. entry.block_id .. ": its directory " .. entry.cwd .. " is gone")
    elseif ready then
      util.write_json(util.record_path(entry.block_id), {
        agent = entry.agent, id = entry.id, argv = entry.argv,
        block_id = entry.block_id, session_id = launch.session_id, cwd = entry.cwd, updated_at = os.time(),
      })
      local line = M.command_line(launch.command, entry.cwd, shell.cwd, strip)
      rex.block.call(util.TERMINAL, "write", { block_id = entry.block_id, session_id = launch.session_id, data = line .. "\r" })
      count = count + 1
      rex.sleep(LAUNCH_GAP)
    else
      util.log("skip " .. entry.block_id .. ": pane runs " .. tostring(front))
    end
  end
  util.log("resumed " .. count .. " agent(s)")
end

function M.discover_running(server)
  local procs = util.processes()
  for _, pane in ipairs(util.terminal_panes()) do
    local path = util.record_path(pane.block_id)
    local process = util.process(pane.block_id, pane.session_id)
    local fg = process and process.foreground
    local rec = util.read_json(path)
    local current = rec and (rec.updated_at or 0) >= server.started and (rec.pid == nil or (fg and rec.pid == fg.pid))
    local command = fg and procs[fg.pid] and procs[fg.pid].command
    if command and not current and not util.is_bare_shell(command) then
      local agent, id, transcript = agents.discover(command, fg.pid, util.read_json, os.getenv, util.home())
      if agent then
        local report = { agent = agent, id = id, transcript = transcript }
        local found = agents.merge_report(rec, report, fg.pid, transcript == nil or util.matches_file(transcript))
        found.block_id, found.session_id, found.cwd, found.updated_at = pane.block_id, pane.session_id, fg.cwd, os.time()
        util.write_json(path, found)
        util.log("found running " .. agent .. " " .. id .. (found.pending and " (no transcript yet)" or "") .. " in " .. pane.block_id .. " (" .. pane.where .. ")")
      end
    end
  end
end

local function mark_resumed(server)
  local marker = util.path("resumed-instance")
  if util.read_file(marker) == server.instance then return false end
  util.write_file(marker, server.instance)
  return true
end

local function auto_resume(server)
  if util.read_file(util.path("resumed-instance")) == server.instance then return end
  if not util.resume_on() then return util.log("resume: off") end
  mark_resumed(server)
  if os.time() - server.started > RESUME_ONLY_WITHIN then return util.log("resume: server started too long ago") end
  M.resume(server)
end

function M.resume_now()
  local server = M.server()
  if not M.restore_enabled(server) then return end
  if not mark_resumed(server) then return util.log("resume: this server was already resumed") end
  M.resume(server)
end

-- watch.lock is a symlink to "<pid> <server instance>", so ln -s takes it atomically.
local LOCK = "watch.lock"

local function lock_holder()
  local pid, instance = util.run({ "readlink", util.path(LOCK) }).stdout:match("^(%d+)%s*(%S*)")
  local command = pid and util.run({ "ps", "-o", "command=", "-p", pid }).stdout or ""
  if command:find("mode=watch", 1, true) then return tonumber(pid), instance end
end

function M.stop()
  local holder = lock_holder()
  if holder then util.run({ "kill", tostring(holder) }) end
  os.remove(util.path(LOCK))
end

local function take_lock(instance)
  local own = util.run({ "sh", "-c", "echo $PPID" }).stdout:match("%d+")
  for _ = 1, 2 do
    if util.run({ "ln", "-s", own .. " " .. instance, util.path(LOCK) }).ok then return true end
    local holder, held_for = lock_holder()
    if holder and held_for == instance then return false, holder end
    if holder then
      util.log("taking over from the watcher of server " .. (held_for ~= "" and held_for or "?") .. " (pid " .. holder .. ")")
      util.run({ "kill", tostring(holder) })
    end
    os.remove(util.path(LOCK))
  end
  return false
end

function M.watch()
  local server = M.server()
  local enabled, why = M.restore_enabled(server)
  if not enabled then
    util.log("off: " .. why)
    return rex.stop(0)
  end
  util.mkdir_p(util.path("snapshots"))
  local locked, holder = take_lock(server.instance)
  if not locked then
    util.log("watcher already running (pid " .. tostring(holder) .. ")")
    return rex.stop(0)
  end
  util.log("watching server " .. server.instance)
  local inherited = M.inherited_env(os.getenv)
  if #inherited > 0 then
    util.log("warning: the Rex server was started with " .. table.concat(inherited, ", ")
      .. " set, probably from inside an agent; panes inherit them and Claude Code stops saving transcripts")
  end
  M.prune(util.terminal_panes())
  local ok, err = pcall(auto_resume, server)
  if not ok then util.log("resume failed: " .. tostring(err)) end
  ok, err = pcall(M.discover_running, server)
  if not ok then util.log("discovery failed: " .. tostring(err)) end

  local timer, last = nil, nil
  local stamp = util.read_file(util.path("agents.stamp"))

  local function save()
    timer = nil
    local snap = M.take_snapshot(server)
    local key = fingerprint(snap)
    if key == last then return end
    util.write_json(util.path("snapshots/" .. server.instance .. ".json"), snap)
    last = key
  end

  local function schedule_once(delay)
    if timer then return end
    timer = rex.after(delay, function()
      local ok2, err2 = pcall(save)
      if not ok2 then util.log("save failed: " .. tostring(err2)) end
    end)
  end

  local function in_recorded_pane(event)
    return not (event and event.block_id) or util.exists(util.record_path(event.block_id))
  end

  for _, name in ipairs({ "terminal.process_changed", "terminal.child_exited" }) do
    rex.on(name, function(event)
      if in_recorded_pane(event) then schedule_once(SAVE_DELAY) end
    end)
  end
  for _, name in ipairs({ "session_view_changed", "block_created", "block_closed", "session_destroyed" }) do
    rex.on(name, function() schedule_once(SAVE_DELAY) end)
  end
  rex.every(STAMP_EVERY, function()
    local now = util.read_file(util.path("agents.stamp"))
    if now ~= stamp then
      stamp = now
      schedule_once(1)
    end
  end)
  rex.every(SAVE_EVERY, function() schedule_once(0) end)
  rex.after(UNCONFIRMED_RESUME_TTL + 1, function() schedule_once(0) end)
  schedule_once(0)
end

return M
