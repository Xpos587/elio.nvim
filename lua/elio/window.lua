local M = {}

local function dimensions(opts)
  local factor = opts.floating_window_scaling_factor or 0.9
  local width_factor = type(factor) == "table" and factor.width or factor
  local height_factor = type(factor) == "table" and factor.height or factor
  width_factor = tonumber(width_factor) or 0.9
  height_factor = tonumber(height_factor) or 0.9

  local max_width = vim.o.columns
  local max_height = vim.o.lines - (vim.o.cmdheight == 0 and 1 or 0)
  local width = width_factor <= 1 and math.floor(max_width * width_factor) or math.min(width_factor, max_width)
  local height = height_factor <= 1 and math.floor(max_height * height_factor) or math.min(height_factor, max_height)
  width = math.max(1, math.min(width, max_width))
  height = math.max(1, math.min(height, max_height))
  return width, height, math.floor((max_height - height) / 2), math.floor((max_width - width) / 2)
end

function M.open(opts)
  local width, height, row, col = dimensions(opts)
  local buffer = vim.api.nvim_create_buf(false, true)
  local window = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    row = row,
    col = col,
    border = opts.floating_window_border,
  })
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].filetype = "elio"
  vim.wo[window].winblend = opts.floating_window_winblend or 0

  local context = {
    buffer = buffer,
    window = window,
    width = width,
    height = height,
    opts = opts,
  }
  context.augroup = vim.api.nvim_create_augroup("ElioWindow" .. buffer, { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = context.augroup,
    callback = function()
      if vim.api.nvim_win_is_valid(window) then
        M.resize(context)
      end
    end,
  })
  return context
end

function M.resize(context, width, height)
  local target = context.window_context or context
  if not target.window or not vim.api.nvim_win_is_valid(target.window) then
    return
  end

  if not width or not height then
    width, height = dimensions(target.opts or {})
  end
  width = math.max(1, math.floor(width))
  height = math.max(1, math.floor(height))
  local max_height = vim.o.lines - (vim.o.cmdheight == 0 and 1 or 0)
  vim.api.nvim_win_set_config(target.window, {
    relative = "editor",
    width = math.min(width, vim.o.columns),
    height = math.min(height, max_height),
    row = math.floor((max_height - math.min(height, max_height)) / 2),
    col = math.floor((vim.o.columns - math.min(width, vim.o.columns)) / 2),
  })
  target.width = math.min(width, vim.o.columns)
  target.height = math.min(height, max_height)
  if target.job_id and vim.fn.jobresize then
    pcall(vim.fn.jobresize, target.job_id, target.width, target.height)
  end
end

function M.close(context)
  local target = context and (context.window_context or context)
  if not target then
    return
  end
  if target.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, target.augroup)
    target.augroup = nil
  end
  if target.window and vim.api.nvim_win_is_valid(target.window) then
    vim.api.nvim_win_close(target.window, true)
  end
  if target.buffer and vim.api.nvim_buf_is_valid(target.buffer) then
    vim.api.nvim_buf_delete(target.buffer, { force = true })
  end
end

return M
