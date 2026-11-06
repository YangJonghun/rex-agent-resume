local util = require("rex-agent-resume.util")
local agents = require("rex-agent-resume.agents")
local detect = require("rex-agent-resume.detect")

local M = {}

function M.pane_owner(start_pid, procs, foreground_pid)
  local pid, seen_agent = start_pid, false
  while pid and pid > 1 and procs[pid] do
    if util.is_bare_shell(procs[pid].command) then
      if seen_agent then return nil end
    else
      seen_agent = true
      if pid == foreground_pid then return pid end
    end
    pid = procs[pid].ppid
  end
  return nil
end

local function record_key(rec)
  local _, key = agents.resume_of(rec)
  return tostring(key) .. "|" .. tostring(rec.pending and rec.pending.id)
end

local function ask_watcher_to_save()
  local list = rex.call("client.list")
  for _, client in ipairs(list and list.clients or {}) do
    if client.info and client.info.label == util.WATCHER_LABEL then
      rex.call("client.perform", { client_id = client.client_id, action = util.RECORDED_ACTION, timeout_ms = 500 })
    end
  end
end

local function record(ppid, procs, pane, report)
  local process = util.process(pane.block_id, pane.session_id)
  local fg = process and process.foreground
  local owner = fg and M.pane_owner(ppid, procs, fg.pid)
  if not owner then return false, "the calling program is not in front of pane " .. pane.block_id end
  if report.agent and detect.agent(procs[owner] and procs[owner].command or "") ~= report.agent then
    return false, "the program in front of pane " .. pane.block_id .. " is not " .. report.agent
  end
  local path = util.record_path(pane.block_id)
  local old = util.read_json(path)
  local rec = agents.merge_report(old, report, owner, report.transcript == nil or util.matches_file(report.transcript))
  if old and old.pid == owner and record_key(old) == record_key(rec) then return true end
  rec.block_id, rec.session_id, rec.cwd, rec.updated_at = pane.block_id, pane.session_id, report.cwd or rec.cwd or fg.cwd, os.time()
  util.write_json(path, rec)
  ask_watcher_to_save()
  return true
end

function M.run(agent, ppid)
  local spec = agents.specs[agent]
  if not spec then return util.log("hook: unknown agent " .. tostring(agent)) end
  local pane = { block_id = os.getenv("REX_BLOCK"), session_id = os.getenv("REX_SESSION") }
  if not pane.block_id or not pane.session_id then return end
  local ok, data = pcall(rex.json.decode, io.read("*a") or "")
  if not ok or type(data) ~= "table" then data = {} end
  local id, transcript, source = agents.parse(spec, data, os.getenv)
  if not id then return end
  local cwd = type(data.cwd) == "string" and data.cwd ~= "" and data.cwd or nil
  local report = { agent = agent, id = id, transcript = transcript, source = source, cwd = cwd }
  local written, why = record(ppid, util.processes(), pane, report)
  if not written then util.log("hook: " .. agent .. ": " .. why) end
end

function M.hint(client_id, argv)
  if not agents.valid_argv(argv) then
    error("argv must be a list of at most 64 words without control characters, like argv='[\"pi\",\"--session\",\"x\"]'", 0)
  end
  local info = rex.call("client.inspect", { client_id = client_id })
  local caller = info and info.client and info.client.principal and info.client.principal.pid
  local procs = util.processes()
  local ppid = caller and procs[caller] and procs[caller].ppid
  if not ppid then error("cannot tell which process called agent_resume_hint", 0) end
  local ancestors, pid = {}, ppid
  while pid and pid > 1 and procs[pid] do
    ancestors[pid] = true
    pid = procs[pid].ppid
  end
  for _, pane in ipairs(util.terminal_panes()) do
    local process = util.process(pane.block_id, pane.session_id)
    local fg = process and process.foreground
    if fg and ancestors[fg.pid] then
      local written, why = record(ppid, procs, pane, { argv = argv })
      if not written then error(why, 0) end
      return { block_id = pane.block_id, command = util.shell_join(argv) }
    end
  end
  error("agent_resume_hint must be called by the program in front of a Rex pane, not from a shell prompt", 0)
end

return M
