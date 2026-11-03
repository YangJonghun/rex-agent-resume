-- Ported from herdr v0.9.5: src/agent_resume.rs (resume argv),
-- src/integration/assets/* (hook payload rules) and src/integration/targets.rs (install targets).
local detect = require("rex-agent-resume.detect")

local M = {}

M.order = {
  "claude", "codex", "copilot", "devin", "droid", "kimi", "qodercli", "qwen",
  "letta", "cursor", "mastracode", "antigravity-cli", "grok",
  "opencode", "kilo", "hermes", "pi", "omp",
}

M.specs = {}
for _, name in ipairs(M.order) do
  M.specs[name] = require("rex-agent-resume.agents." .. name)
end

local function text(value)
  if type(value) == "string" and value ~= "" then return value end
  if type(value) == "number" then return tostring(value) end
  return nil
end

local function first_text(data, keys)
  for _, key in ipairs(keys or {}) do
    local value = text(data[key])
    if value then return value end
  end
  return nil
end

local function normalize_event(name)
  return (name or ""):gsub("[_%-]", ""):lower()
end

local function valid_id(id)
  return type(id) == "string" and id ~= "" and #id <= 512 and not id:find("%c")
end

function M.parse(spec, data, getenv)
  local event = normalize_event(first_text(data, { "hook_event_name", "hookEventName", "event" }))
  local accepted = spec.events == nil
  for _, name in ipairs(spec.events or {}) do
    if name == event then accepted = true end
  end
  if not accepted then return nil, "event " .. (event == "" and "(none)" or event) end
  for _, key in ipairs(spec.skip_if or {}) do
    if data[key] ~= nil and data[key] ~= "" then return nil, "payload has " .. key end
  end
  for _, name in ipairs(spec.skip_env or {}) do
    if getenv(name) then return nil, "env has " .. name end
  end
  for _, key in ipairs(spec.require or {}) do
    if not text(data[key]) then return nil, "payload lacks " .. key end
  end
  if event == "" and first_text(data, spec.bare_guard) then return nil, "not a session event" end

  local id = (spec.id_env and text(getenv(spec.id_env))) or first_text(data, spec.id_fields)
  if spec.default_agent and id == "default" then
    local agent_id = text(data[spec.default_agent])
    if not agent_id then return nil, "default conversation without " .. spec.default_agent end
    id = "default:" .. agent_id
  end
  if not valid_id(id) then return nil, "no valid session id" end
  local thread = spec.thread_env and text(getenv(spec.thread_env))
  if thread and thread ~= id then return nil, "child thread " .. thread end
  local source = first_text(data, { "source", "session_start_source" })
  return id, first_text(data, spec.transcript_fields), source and source:lower()
end

function M.resume_argv(spec, id)
  if not valid_id(id) then return nil end
  local template, rest = spec.resume, nil
  if spec.resume_default and id:sub(1, 8) == "default:" then
    template, rest = spec.resume_default, id:sub(9)
    if rest == "" then return nil end
  end
  local argv = { template[1] }
  for _, flag in ipairs(spec.launch_flags or {}) do argv[#argv + 1] = flag end
  for i = 2, #template do
    argv[#argv + 1] = template[i]:gsub("{id}", function() return id end):gsub("{rest}", function() return rest end)
  end
  return argv
end

function M.config_dir(spec, getenv, home)
  local dir = spec.install.dir
  for _, name in ipairs({ dir.env, dir.env2 }) do
    local value = name and getenv(name)
    if value and value ~= "" then return dir.suffix and (value .. "/" .. dir.suffix) or value end
  end
  local relative = dir.home_env and getenv(dir.home_env)
  if relative and relative ~= "" then
    return (relative:sub(1, 1) == "/" and relative or (home .. "/" .. relative)) .. "/" .. dir.home_suffix
  end
  return home .. "/" .. dir.default
end

function M.transcript_pattern(spec, id, getenv, home)
  if not (spec.transcript and valid_id(id)) then return nil end
  return M.config_dir(spec, getenv, home) .. "/" .. spec.transcript:gsub("{id}", function() return id end)
end

local function id_from_command(template, words)
  for start = 2, #words do
    local id, matched = nil, true
    for k = 2, #template do
      local want, word = template[k], words[start + k - 2]
      local prefix = want:match("^(.-){id}$")
      if not word then matched = false
      elseif prefix then
        if word:sub(1, #prefix) == prefix and #word > #prefix then id = word:sub(#prefix + 1) else matched = false end
      elseif want ~= word then matched = false end
      if not matched then break end
    end
    if matched and valid_id(id) and id:sub(1, 1) ~= "-" then return id end
  end
  return nil
end

function M.discover(command, pid, read_json, getenv, home)
  local name = detect.agent(command)
  local spec = name and M.specs[name]
  if not spec then return nil end
  local file = spec.session_file
  if file then
    local dir = M.config_dir(spec, getenv, home)
    local data = read_json(dir .. "/" .. file.path:gsub("{pid}", tostring(pid)))
    local id = data and data[file.field]
    if valid_id(id) then return name, id, M.transcript_pattern(spec, id, getenv, home) end
  end
  local words = {}
  for word in command:gmatch("%S+") do words[#words + 1] = word end
  local id = id_from_command(spec.resume, words)
  if id then return name, id end
  return nil
end

-- Kept under macOS's 1024-byte line limit, which can cut input typed while a shell starts.
local MAX_COMMAND = 1000

function M.valid_argv(argv)
  if type(argv) ~= "table" or #argv == 0 or #argv > 64 or argv[1] == "" then return false end
  local length = 0
  for _, word in ipairs(argv) do
    if type(word) ~= "string" or word:find("%c") then return false end
    length = length + #word + 1
  end
  return length <= MAX_COMMAND
end

function M.resume_of(rec)
  if rec.argv ~= nil then
    if not M.valid_argv(rec.argv) then return nil end
    return rec.argv, table.concat(rec.argv, " ")
  end
  local spec = M.specs[rec.agent]
  local argv = spec and M.resume_argv(spec, rec.id)
  if not argv then return nil end
  return argv, rec.id
end

local function may_replace(spec, source, current, id)
  if spec and spec.replace_paths and (current:sub(1, 1) == "/" or id:sub(1, 1) == "/") then return true end
  for _, allowed in ipairs(spec and spec.replace_on or {}) do
    if allowed == source then return true end
  end
  return false
end

-- An agent reports a new session before it has written anything to resume (Claude Code on
-- startup, /clear or --resume). Until its transcript exists the report waits as pending, and
-- the last resumable session of the same running agent stays in place.
function M.merge_report(old, report, pid, transcript_exists)
  if old and report.agent and old.agent == report.agent and old.pid == pid then
    local current = old.pending and old.pending.id or old.id
    if current and current ~= report.id and not may_replace(M.specs[report.agent], report.source, current, report.id) then
      return old
    end
  end
  local rec = { agent = report.agent, argv = report.argv, pid = pid }
  if report.transcript and not transcript_exists then
    rec.pending = { id = report.id, transcript = report.transcript }
    if old and old.agent == report.agent and (old.pid == nil or old.pid == pid) then rec.id = old.id end
  else
    rec.id = report.id
  end
  return rec
end

function M.promote(rec, transcript_exists)
  if not (rec.pending and transcript_exists(rec.pending.transcript)) then return false end
  rec.id, rec.pending = rec.pending.id, nil
  return true
end

function M.label(rec)
  return rec.agent or (rec.argv and rec.argv[1] and rec.argv[1]:match("([^/]*)$")) or "?"
end

return M
