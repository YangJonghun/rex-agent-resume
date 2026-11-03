local util = require("rex-agent-resume.util")
local agents = require("rex-agent-resume.agents")

local M = {}

local MARKER = "rex-agent-resume-hook"

local JQ_EDIT = [[
def ours: tostring | contains($marker);
def strip: if type == "object" and (.hooks | type) == "array"
  then .hooks |= map(select(ours | not)) | select(.hooks != [])
  else select(ours | not) end;
def prune($p): if ($p | length) > 0 and (getpath($p) | . == [] or . == {}) then delpaths([$p]) | prune($p[:-1]) else . end;
($defaults + .)
| reduce $lists[] as $p (.; if getpath($p) == null and ($entry | not) then . else setpath($p; ((getpath($p) // []) | map(strip)) + (if $entry then [$entry] else [] end)) end)
| if $entry then . else reduce $lists[] as $p (.; prune($p)) end
]]

local function quote_toml(s) return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end

local function is_dir(path) return util.run({ "test", "-d", path }).ok end

-- Install backs up the original once. Without a backup, install created the file, so
-- uninstall deletes it once nothing but ours was in it.
local function overwrite_in_place(path, old, new, install, empty)
  if old == new then return false end
  local backup = path .. ".bak-rex-agent-resume"
  if not install and empty and not util.exists(backup) then
    os.remove(path)
    return true
  end
  if install and old and not util.exists(backup) then
    local f = assert(io.open(backup, "w"))
    f:write(old)
    f:close()
  end
  util.mkdir_p(util.dirname(path))
  local f = assert(io.open(path, "w"))
  f:write(new)
  f:close()
  return true
end

local function only_defaults(text, defaults)
  for key, value in pairs(rex.json.decode(text)) do
    if not (defaults and defaults[key] == value) then return false end
  end
  return true
end

local function edit_json(path, target, command, install)
  local old = util.read_file(path)
  if not install and not (old and old:find(MARKER, 1, true)) then return "not installed" end
  local entry = install and rex.json.encode(target.entry(command)) or "false"
  local r = util.run({
    "jq", "--indent", "2",
    "--arg", "marker", MARKER,
    "--argjson", "entry", entry,
    "--argjson", "lists", rex.json.encode(target.lists),
    "--argjson", "defaults", install and target.defaults and rex.json.encode(target.defaults) or "{}",
    JQ_EDIT,
  }, (old and old:find("%S")) and old or "{}")
  if not r.ok then error("cannot edit " .. path .. " (not plain JSON?): " .. r.stderr) end
  if target.own_file and not install and r.stdout:match("^%s*{%s*}%s*$") then
    os.remove(path)
    os.remove(path .. ".bak-rex-agent-resume")
    return "removed"
  end
  return overwrite_in_place(path, old, r.stdout, install, only_defaults(r.stdout, target.defaults))
    and (install and "installed" or "removed") or "unchanged"
end

local function strip_block(text, begin_line, end_line)
  local s = text:find(begin_line, 1, true)
  if not s then return text end
  local _, e = text:find(end_line, s, true)
  if not e then error("found '" .. begin_line .. "' without '" .. end_line .. "'") end
  return (text:sub(1, s - 1):gsub("\n+$", "\n") .. text:sub(e + 1):gsub("^\n+", "")):gsub("^\n$", "")
end

local function edit_marked(path, begin_line, end_line, body, install)
  local old = util.read_file(path)
  if not old and not install then return "not installed" end
  local new = strip_block(old or "", begin_line, end_line)
  if install then
    new = new .. (new ~= "" and not new:find("\n$") and "\n" or "") .. (new ~= "" and "\n" or "")
      .. begin_line .. "\n" .. body .. end_line .. "\n"
  end
  return overwrite_in_place(path, old, new, install, new == "") and (install and "installed" or "removed") or "unchanged"
end

local JQ_PLUGIN_LIST = [[
def ours: . == $spec or (type == "array" and .[0] == $spec);
if (.[$key] // []) | type != "array" then error("\($key) is not a list") else . end
| if $add then (if any(.[$key][]?; ours) then . else .[$key] = ((.[$key] // []) + [$spec]) end)
  elif .[$key] == null then .
  else .[$key] |= map(select(ours | not)) | if .[$key] == [] then del(.[$key]) else . end end
]]

local function edit_plugin_list(path, key, spec, install)
  local old = util.read_file(path)
  if not install and not (old and old:find(spec, 1, true)) then return false end
  local r = util.run({
    "jq", "--indent", "2", "--arg", "key", key, "--arg", "spec", spec, "--argjson", "add", tostring(install), JQ_PLUGIN_LIST,
  }, (old and old:find("%S")) and old or "{}")
  if not r.ok then
    error("cannot edit " .. path .. " (not plain JSON?); add \"" .. spec .. "\" to its \"" .. key .. "\" list yourself: " .. r.stderr)
  end
  return overwrite_in_place(path, old, r.stdout, install, r.stdout:match("^%s*{%s*}%s*$"))
end

local function opencode_state_dir()
  local xdg = os.getenv("XDG_STATE_HOME")
  return ((xdg and xdg ~= "") and xdg or (util.home() .. "/.local/state")) .. "/opencode"
end

local function register_opencode(dir, plugins, install)
  local changed, listed = false, false
  for _, name in ipairs({ "tui.jsonc", "tui.json" }) do
    local path = dir .. "/" .. name
    if (util.read_file(path) or ""):find(plugins.tui, 1, true) then listed = true end
    if not install then changed = edit_plugin_list(path, "plugin", plugins.tui, false) or changed end
  end
  if install and not listed then changed = edit_plugin_list(dir .. "/tui.jsonc", "plugin", plugins.tui, true) or changed end
  local cli = dir .. "/cli.json"
  -- OpenCode 2 imports tui.json and kv.json into cli.json on its first start, but only while
  -- cli.json is absent, so creating it early would skip that import.
  local migrating = not util.exists(cli) and (util.exists(dir .. "/tui.json") or util.exists(opencode_state_dir() .. "/kv.json"))
  if not (install and migrating) then changed = edit_plugin_list(cli, "plugins", plugins.cli, install) or changed end
  return changed
end

local function yaml_indent(line)
  if line:match("^%s*$") or line:match("^%s*#") then return nil end
  return #line:match("^( *)")
end

local function yaml_key(line, indent)
  if yaml_indent(line) ~= indent then return nil end
  return line:match("^%s*([%w_%-]+):%s*(.-)%s*$")
end

local function yaml_scalar(text)
  text = text:gsub("%s+#.*$", ""):match("^%s*(.-)%s*$")
  return text:match('^"(.*)"$') or text:match("^'(.*)'$") or text
end

local function yaml_item(line, indent)
  if yaml_indent(line) ~= indent then return nil end
  return line:match("^%s*%-%s+(.-)%s*$") or (line:match("^%s*%-%s*$") and "")
end

local function edit_yaml_flow(lines, i, name, enable)
  local head, inner, tail = lines[i]:match("^(.-:)%s*%[(.-)%](.*)$")
  local items, found = {}, false
  for item in inner:gmatch("[^,]+") do
    item = item:match("^%s*(.-)%s*$")
    if yaml_scalar(item) == name then found = true elseif item ~= "" then items[#items + 1] = item end
  end
  if found == enable then return false end
  if enable then table.insert(items, 1, name) end
  lines[i] = head .. " [" .. table.concat(items, ", ") .. "]" .. tail
  return true
end

local function edit_yaml_block(lines, k, key_indent, stop, name, enable)
  local seq_indent, items = nil, {}
  for i = k + 1, stop - 1 do
    local indent = yaml_indent(lines[i])
    if indent then
      if not seq_indent and lines[i]:match("^%s*%-") and indent >= key_indent then seq_indent = indent end
      if indent < (seq_indent or key_indent + 1) or (indent == seq_indent and not yaml_item(lines[i], indent)) then break end
      local value = seq_indent and yaml_item(lines[i], seq_indent)
      if value then items[#items + 1] = { i = i, value = yaml_scalar(value) } end
    end
  end
  local matches = {}
  for _, item in ipairs(items) do
    if item.value == name then matches[#matches + 1] = item.i end
  end
  if enable then
    if #matches > 0 then return false end
    table.insert(lines, k + 1, string.rep(" ", seq_indent or key_indent + 2) .. "- " .. name)
    return true
  end
  if #matches == 0 then return false end
  for j = #matches, 1, -1 do table.remove(lines, matches[j]) end
  if #matches == #items then lines[k] = lines[k]:gsub(":%s*$", ": []") end
  return true
end

function M.hermes_yaml(text, name, enable)
  local lines = {}
  for line in text:gmatch("([^\n]*)\n?") do lines[#lines + 1] = line end
  if lines[#lines] == "" then lines[#lines] = nil end
  local p
  for i = 1, #lines do
    if yaml_key(lines[i], 0) == "plugins" then p = i break end
  end
  if not p then
    if not enable then return text end
    return text:gsub("\n*$", "") .. (text:find("%S") and "\n" or "") .. "plugins:\n  enabled:\n    - " .. name .. "\n"
  end
  local stop = #lines + 1
  for i = p + 1, #lines do
    if yaml_key(lines[i], 0) then stop = i break end
  end
  local child
  for i = p + 1, stop - 1 do
    if yaml_indent(lines[i]) then child = i break end
  end
  local _, value = yaml_key(lines[p], 0)
  local changed
  if value:match("^%[") then
    changed = edit_yaml_flow(lines, p, name, enable)
  elseif child and lines[child]:match("^%s*%-") then
    changed = edit_yaml_block(lines, p, 0, stop, name, enable)
  else
    local indent = child and yaml_indent(lines[child]) or 2
    local k
    for i = p + 1, stop - 1 do
      if yaml_key(lines[i], indent) == "enabled" then k = i break end
    end
    if k then
      local _, enabled = yaml_key(lines[k], indent)
      if enabled:match("^%[") then changed = edit_yaml_flow(lines, k, name, enable)
      else changed = edit_yaml_block(lines, k, indent, stop, name, enable) end
    elseif enable then
      table.insert(lines, p + 1, string.rep(" ", indent) .. "enabled:")
      table.insert(lines, p + 2, string.rep(" ", indent + 2) .. "- " .. name)
      changed = true
    end
  end
  if not changed then return text end
  return table.concat(lines, "\n") .. "\n"
end

local function register_hermes(dir, name, install)
  local path = dir .. "/config.yaml"
  local old = util.read_file(path)
  if not install and not (old and old:find(name, 1, true)) then return false end
  local new = M.hermes_yaml(old or "", name, install)
  return overwrite_in_place(path, old, new, install, new == "plugins:\n  enabled: []\n")
end

local function js_string(s)
  if s:find("%c") then error("path has control characters: " .. s) end
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function render(root, source, hook)
  local text = assert(util.read_file(root .. "/integrations/" .. source), "missing integrations/" .. source)
  local placeholder = '"__REX_AGENT_RESUME_HOOK__"'
  local s, e = text:find(placeholder, 1, true)
  if not s then return text end
  return text:sub(1, s - 1) .. js_string(hook) .. text:sub(e + 1)
end

local function place_files(root, dir, files, hook, install)
  local changed = false
  for _, file in ipairs(files) do
    local path = dir .. "/" .. file[1]
    local old = util.read_file(path)
    local ours = old and old:find("rex-agent-resume", 1, true)
    if install then
      local new = render(root, file[2], hook)
      if old and not ours then error(path .. " already exists and was not written by rex-agent-resume") end
      if old ~= new then
        util.run({ "mkdir", "-p", util.dirname(path) })
        util.write_file(path, new)
        changed = true
      end
    elseif ours then
      os.remove(path)
      local parent = util.dirname(path)
      if parent:match("rex%-agent%-resume[^/]*$") then
        util.run({ "rm", "-rf", parent .. "/__pycache__" })
        util.run({ "rmdir", parent })
      end
      changed = true
    end
  end
  return changed
end

local function enable_codex_hooks(path)
  local old = util.read_file(path) or ""
  if old:find("\n%s*features%s*[%.=]") or old:find("^%s*features%s*[%.=]") then
    error("features is a dotted key or inline table in " .. path .. "; add hooks = true to it yourself")
  end
  local lines, header, section_end = {}, nil, nil
  for line in (old .. (old:find("\n$") and "" or "\n")):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  for i, line in ipairs(lines) do
    if line:match("^%s*%[features%]%s*$") or line:match("^%s*%[features%]%s*#") then header = i
    elseif header and not section_end and line:match("^%s*%[") then section_end = i end
  end
  if not header then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[features]"
    lines[#lines + 1] = "hooks = true"
  else
    -- Like herdr, also drop `codex_hooks`, the name codex used before `hooks`.
    local kept, found = {}, false
    for i, line in ipairs(lines) do
      local inside = i > header and i < (section_end or #lines + 1)
      if inside and line:match("^%s*hooks%s*=") then
        kept[#kept + 1] = "hooks = true"
        found = true
      elseif not (inside and line:match("^%s*codex_hooks%s*=")) then
        kept[#kept + 1] = line
      end
    end
    if not found then table.insert(kept, header + 1, "hooks = true") end
    lines = kept
  end
  local new = table.concat(lines, "\n"):gsub("^\n+", "") .. "\n"
  overwrite_in_place(path, old ~= "" and old or nil, new, true)
end

local function apply_plugin(root, name, dir, target, hook, install)
  if install and target.not_with then
    local other = agents.config_dir(agents.specs[target.not_with], os.getenv, util.home())
    if other == dir then error(name .. " and " .. target.not_with .. " share " .. dir .. "; give " .. name .. " its own directory first") end
  end
  local changed = place_files(root, dir, target.files, hook, install)
  if target.opencode_plugins then changed = register_opencode(dir, target.opencode_plugins, install) or changed end
  if target.hermes_plugin then changed = register_hermes(dir, target.hermes_plugin, install) or changed end
  if changed then return install and "installed" or "removed" end
  return install and "unchanged" or "not installed"
end

function M.apply(name, root, install)
  local spec = agents.specs[name]
  local target = spec.install
  local dir = agents.config_dir(spec, os.getenv, util.home())
  if not is_dir(dir) then return nil end
  local hook = root .. "/bin/" .. MARKER
  if target.files then return apply_plugin(root, name, dir, target, hook, install), dir end
  local command = util.shell_quote(hook) .. " " .. name
  local path = dir .. "/" .. target.file
  if target.kimi_toml then
    local body = "[[hooks]]\nevent = \"SessionStart\"\ncommand = " .. quote_toml(command) .. "\ntimeout = 10\n"
    return edit_marked(path, "# >>> rex-agent-resume kimi integration", "# <<< rex-agent-resume kimi integration", body, install), path
  end
  local result = edit_json(path, target, command, install)
  if target.codex_features then
    local config = dir .. "/config.toml"
    if install then
      enable_codex_hooks(config)
    elseif util.read_file(config) == "[features]\nhooks = true\n" and not util.exists(config .. ".bak-rex-agent-resume") then
      os.remove(config)
    end
  end
  return result, path
end

function M.rex_config_path()
  local explicit = os.getenv("REX_CONFIG")
  if explicit and explicit ~= "" then return explicit end
  local xdg = os.getenv("XDG_CONFIG_HOME")
  return ((xdg and xdg ~= "") and xdg or (util.home() .. "/.config")) .. "/rex/init.lua"
end

function M.edit_rex_config(root, install)
  local body = "-- Starts the rex-agent-resume watcher whenever the server loads this file.\n"
    .. "dofile(" .. string.format("%q", root .. "/plugin.lua") .. ")\n"
    .. (util.resume_on() and "" or "-- Agent resume on startup is off.\n")
  local path = M.rex_config_path()
  return edit_marked(path, "-- >>> rex-agent-resume", "-- <<< rex-agent-resume", body, install), path
end

function M.run(root, install)
  local lines = {}
  for _, name in ipairs(agents.order) do
    local ok, result, path = pcall(M.apply, name, root, install)
    if not ok then
      lines[#lines + 1] = name .. ": failed: " .. tostring(result)
    elseif result and result ~= "not installed" then
      lines[#lines + 1] = name .. ": " .. result .. " (" .. path .. ")"
    end
  end
  local result, path = M.edit_rex_config(root, install)
  lines[#lines + 1] = "rex: " .. result .. " (" .. path .. ")"
  require("rex-agent-resume.watch").stop()
  return lines
end

return M
