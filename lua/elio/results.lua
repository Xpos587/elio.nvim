local utils = require("elio.utils")

local M = {}

local function read(path)
  return utils.read_lines(path)
end

function M.read_chooser(path)
  local output = {}
  for _, line in ipairs(read(path)) do
    line = line:gsub("\r$", "")
    if line ~= "" then
      output[#output + 1] = line
    end
  end
  return output
end

function M.read_cwd(path)
  local lines = read(path)
  if not lines[1] then
    return nil
  end
  local cwd = lines[1]:gsub("\r$", "")
  if cwd == "" then
    return nil
  end
  return cwd
end

return M
