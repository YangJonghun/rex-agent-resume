local M = {}

M.root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/test/unit/[^/]*$")

local checks, failures = 0, {}

function M.eq(got, want, name)
  checks = checks + 1
  if got ~= want then failures[#failures + 1] = name .. ": got " .. tostring(got) .. ", want " .. tostring(want) end
end

function M.no_env() return nil end
function M.env(t) return function(k) return t[k] end end
function M.files(t) return function(path) return t[path] end end

function M.report()
  for _, f in ipairs(failures) do print("FAIL " .. f) end
  print(checks .. " checks, " .. #failures .. " failure(s)")
  return #failures == 0
end

return M
