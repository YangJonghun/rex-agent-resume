-- Ported from herdr v0.9.5: src/detect/mod.rs (telling which agent a process is).
local util = require("rex-agent-resume.util")

local M = {}

local ALIASES = {
  ["pi"] = "pi",
  ["claude"] = "claude", ["claude-code"] = "claude",
  ["codex"] = "codex",
  ["cursor"] = "cursor", ["cursor-agent"] = "cursor",
  ["devin"] = "devin", ["devin-cli"] = "devin", ["devin cli"] = "devin",
  ["agy"] = "antigravity-cli", ["antigravity"] = "antigravity-cli", ["antigravity-cli"] = "antigravity-cli",
  ["omp"] = "omp",
  ["mastracode"] = "mastracode", ["mastra-code"] = "mastracode", ["mastra code"] = "mastracode",
  ["opencode"] = "opencode", ["opencode2"] = "opencode", ["open-code"] = "opencode",
  ["copilot"] = "copilot", ["github-copilot"] = "copilot", ["ghcs"] = "copilot",
  ["kimi"] = "kimi", ["kimi-code"] = "kimi", ["kimi code"] = "kimi",
  ["droid"] = "droid",
  ["grok"] = "grok", ["grok-build"] = "grok",
  ["hermes"] = "hermes", ["hermes-agent"] = "hermes",
  ["kilo"] = "kilo", ["kilo-code"] = "kilo", ["kilo code"] = "kilo",
  ["qodercli"] = "qodercli", ["qoderclicn"] = "qodercli", ["qoder"] = "qodercli", ["qodercn"] = "qodercli",
  ["qwen"] = "qwen", ["qwen-code"] = "qwen", ["qwen code"] = "qwen",
  ["letta"] = "letta", ["letta-code"] = "letta", ["letta code"] = "letta",
}

local SHELLS = { sh = true, bash = true, zsh = true, fish = true }

local function basename(path)
  return path:match("([^/\\]+)[/\\]*$") or path
end

local function normalize(name)
  name = name:match("^%s*(.-)%s*$"):lower()
  for _, suffix in ipairs({ ".exe", ".cmd", ".bat", ".ps1", ".js" }) do
    if #name > #suffix and name:sub(-#suffix) == suffix then return name:sub(1, -#suffix - 1) end
  end
  return name
end

local function lookup(name)
  return ALIASES[normalize(basename(name))]
end

local function is_python(name)
  if name == "python" then return true end
  local version = name:match("^python(.+)$")
  if not version then return false end
  for part in (version .. "."):gmatch("([^.]*)%.") do
    if not part:match("^%d+$") then return false end
  end
  return true
end

local function is_generic(name)
  return is_python(name) or SHELLS[name] or name == "tmux" or name == "node" or name == "bun"
end

local PACKAGE_PATHS = {
  { "pi", { "node_modules", "@earendil-works", "pi-coding-agent", "dist", "cli.js" } },
  { "pi", { "node_modules", "@earendil-works", "pi-coding-agent", "dist", "bundle", "cli.js" } },
  { "omp", { "node_modules", "@oh-my-pi", "pi-coding-agent", "dist", "cli.js" } },
  { "kimi", { "node_modules", "@moonshot-ai", "kimi-code", "dist", "main.mjs" } },
}

local PACKAGE_WINDOWS = {
  { "qwen", { "node_modules", "@qwen-code", "qwen-code", "dist", "index" } },
  { "mastracode", { "node_modules", "mastracode", "dist", "cli" } },
  { "letta", { "node_modules", "@letta-ai", "letta-code", "letta" } },
}

local function from_package_path(path)
  local parts = {}
  for part in path:gmatch("[^/\\]+") do parts[#parts + 1] = part end
  for _, known in ipairs(PACKAGE_PATHS) do
    local tail, matched = known[2], #parts >= #known[2]
    for i = 1, matched and #tail or 0 do
      if parts[#parts - #tail + i]:lower() ~= tail[i]:lower() then matched = false break end
    end
    if matched then return known[1] end
  end
  local normalized = {}
  for i, part in ipairs(parts) do normalized[i] = normalize(part) end
  for _, known in ipairs(PACKAGE_WINDOWS) do
    local window = known[2]
    for start = 1, #normalized - #window + 1 do
      local matched = true
      for i = 1, #window do
        if normalized[start + i - 1] ~= window[i] then matched = false break end
      end
      if matched then return known[1] end
    end
  end
  return nil
end

local function from_path_token(token)
  token = token:gsub("^[\"']+", ""):gsub("[\"']+$", "")
  if token == "" or token:sub(1, 1) == "-" then return nil end
  local found = lookup(token) or from_package_path(token)
  if found or not token:find("/", 1, true) then return found end
  local resolved = util.run({ "realpath", token }).stdout:match("^(.-)%s*$")
  return resolved ~= "" and lookup(resolved) or nil
end

local function flag_matches(arg, flags)
  for _, flag in ipairs(flags) do
    if arg == flag then return true end
    if flag:sub(1, 2) ~= "--" and #arg > #flag and arg:sub(1, #flag) == flag then return true end
    if flag:sub(1, 2) == "--" and arg:sub(1, #flag + 1) == flag .. "=" then return true end
  end
  return false
end

local TAKES_VALUE = {
  ["-r"] = true, ["--require"] = true, ["--loader"] = true, ["--import"] = true,
  ["--experimental-loader"] = true, ["--inspect-port"] = true,
  ["-W"] = true, ["-X"] = true, ["-S"] = true, ["-L"] = true, ["-o"] = true,
}

local function script_arg(words, eval_flags, module_flags)
  local i = 2
  while words[i] do
    local arg = words[i]
    if arg == "--" then return words[i + 1] and from_path_token(words[i + 1]) end
    if flag_matches(arg, eval_flags) or flag_matches(arg, module_flags) then return nil end
    if arg:sub(1, 1) == "-" then
      i = i + (TAKES_VALUE[arg] and 2 or 1)
    else
      return from_path_token(arg)
    end
  end
  return nil
end

-- The bootstrap Hermes's installer runs with `python -I -c`; only the install root varies.
local HERMES_PREFIX = [==[import os, re, sys
os.environ.pop('PYTHONHOME', None)
os.environ.pop('PYTHONPATH', None)
sys.path.insert(0, ']==]
local HERMES_MIDDLE = [==[if sys.argv[1:2] == ['--print-runtime-command']: sys.dont_write_bytecode = True
from hermes_constants import get_default_hermes_root
os.environ['HERMES_HOME'] = os.environ.get('HERMES_HOME') or str(get_default_hermes_root())
if sys.argv[1:2] == ['--print-runtime-command']:
    from pathlib import Path
    from hermes_cli._launchers import print_runtime_command
    print_runtime_command(Path(']==]
local HERMES_SUFFIX = [==['), sys.argv[2:])
    sys.exit(0)
import hermes_bootstrap
if sys.argv[1:2] == ['--run-module']:
    import runpy
    if len(sys.argv) < 3: sys.exit('hermes: --run-module needs a module')
    module = sys.argv.pop(2)
    del sys.argv[1]
    runpy.run_module(module, run_name='__main__', alter_sys=True)
    sys.exit(0)
from hermes_cli.main import main
sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
sys.exit(main())
]==]

local function as_ps(text) return (text:gsub("\n", "\\012")) end

local function starts(text, prefix) return text:sub(1, #prefix) == prefix and text:sub(#prefix + 1) or nil end

local function hermes_installer(command)
  local rest = command:match("^%S+%s+(.*)$")
  rest = rest and starts(rest, "-I -c " .. as_ps(HERMES_PREFIX))
  if not rest then return nil end
  local root, after = rest:match("^(.-)'%)\\012(.*)$")
  if not root or root == "" or root:find("['\\]") then return nil end
  after = starts(after, as_ps(HERMES_MIDDLE) .. root .. as_ps(HERMES_SUFFIX))
  if not after then return nil end
  local first = after:match("^%s+(%S+)")
  if after ~= "" and not first then return nil end
  if first == "--run-module" or first == "--print-runtime-command" then return nil end
  return "hermes"
end

local function wrapped(runtime, words, command)
  if runtime == "node" or runtime == "bun" then return script_arg(words, { "-e", "--eval", "-p", "--print" }, {}) end
  if is_python(runtime) then return hermes_installer(command) or script_arg(words, { "-c" }, { "-m" }) end
  if SHELLS[runtime] then return script_arg(words, { "-c" }, {}) end
  return nil
end

function M.agent(command)
  local words = {}
  for word in command:gmatch("%S+") do words[#words + 1] = word end
  if not words[1] then return nil end
  local runtime = normalize(basename(words[1]))
  if is_generic(runtime) then
    local found = wrapped(runtime, words, command)
    if found then return found end
  end
  return lookup(words[1]) or from_path_token(words[1])
end

return M
