local M = {}

local function command(name, path)
  vim.cmd(name .. " " .. vim.fn.fnameescape(path))
end

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

function M.describe_single(path)
  return "edit " .. vim.fn.fnameescape(path)
end

function M.open_current(path)
  command("edit", path)
end

local function open_many(paths, command_name)
  if #paths == 0 then
    return
  end
  for _, path in ipairs(paths) do
    command(command_name, path)
  end
end

function M.open_vertical(paths)
  open_many(paths, "vertical split")
end

function M.open_horizontal(paths)
  open_many(paths, "split")
end

function M.open_tab(paths)
  open_many(paths, "tabedit")
end

function M.open_default(paths)
  if #paths == 1 then
    return M.open_current(paths[1])
  end
  for _, path in ipairs(paths) do
    command("argadd", path)
  end
  if #paths > 0 then
    vim.cmd("first")
  end
end

function M.quickfix_items(paths)
  local items = {}
  for _, path in ipairs(paths) do
    local filename = path
    if is_directory(path) and path:sub(-1) ~= "/" then
      filename = path .. "/"
    end
    items[#items + 1] = { filename = filename }
  end
  return items
end

function M.to_quickfix(paths)
  vim.fn.setqflist({}, "r", { title = "Elio", items = M.quickfix_items(paths) })
  vim.cmd("copen")
end

function M.copy_relative(paths, register, base_dir)
  local relative = {}
  base_dir = base_dir or vim.fn.getcwd()
  for _, path in ipairs(paths) do
    local value
    if vim.fs and vim.fs.relpath then
      value = vim.fs.relpath(base_dir, path)
    end
    if not value then
      local normalized_base = base_dir:gsub("/+$", "")
      if normalized_base == "" then
        normalized_base = "/"
      end
      local prefix = normalized_base == "/" and "/" or normalized_base .. "/"
      if path == normalized_base then
        value = "."
      elseif path:sub(1, #prefix) == prefix then
        value = path:sub(#prefix + 1)
      else
        value = path
      end
    end
    relative[#relative + 1] = value
  end
  vim.fn.setreg(register, table.concat(relative, "\n"), "c")
end

function M.change_directory(path)
  if path and vim.fn.isdirectory(path) == 1 then
    vim.cmd.cd(vim.fn.fnameescape(path))
  end
end

return M
