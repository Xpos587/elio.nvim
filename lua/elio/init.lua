local actions = require("elio.actions")
local config_module = require("elio.config")
local process = require("elio.process")
local utils = require("elio.utils")

local M = {
  config = nil,
  active = nil,
  last_path = nil,
  help = nil,
}

local function notify(message, level)
  if vim.notify then
    vim.notify(message, level or vim.log.levels.ERROR, { title = "elio.nvim" })
  end
end

local function delete_group(group)
  if group then
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end
end

local function current_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return vim.fn.getcwd()
  end
  return name
end

local function resolve_path(path)
  if path == nil or path == "" then
    path = current_path()
  end
  return utils.normalize_path(vim.fn.expand(path))
end

local function close_help()
  if not M.help then
    return
  end
  local help = M.help
  M.help = nil
  if help.window and vim.api.nvim_win_is_valid(help.window) then
    vim.api.nvim_win_close(help.window, true)
  end
  if help.buffer and vim.api.nvim_buf_is_valid(help.buffer) then
    vim.api.nvim_buf_delete(help.buffer, { force = true })
  end
end

local function show_help()
  close_help()
  local keymaps = M.config.keymaps
  local lines = {
    "Elio controls",
    "",
    "Enter       Open selected file",
    (keymaps.open_file_in_vertical_split or "disabled") .. "  Vertical split",
    (keymaps.open_file_in_horizontal_split or "disabled") .. "  Horizontal split",
    (keymaps.open_file_in_tab or "disabled") .. "  New tab",
    (keymaps.send_to_quickfix_list or "disabled") .. "  Quickfix list",
    (keymaps.copy_relative_path_to_selected_files or "disabled") .. "  Copy relative paths",
    (keymaps.change_working_directory or "disabled") .. "  Change Neovim cwd",
    "Esc         Close help",
  }
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  local window = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width + 2,
    height = #lines,
    row = math.max(0, math.floor((vim.o.lines - #lines) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
  })
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].filetype = "elio-help"
  vim.wo[window].winblend = M.config.floating_window_winblend or 0
  local function close()
    close_help()
  end
  vim.keymap.set("n", "q", close, { buffer = buffer, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buffer, silent = true })
  M.help = { buffer = buffer, window = window }
end

local function set_terminal_keymap(context, lhs, callback)
  if lhs == false or lhs == nil then
    return
  end
  vim.keymap.set("t", lhs, callback, { buffer = context.buffer, silent = true })
end

local function setup_terminal_keymaps(context)
  local keymaps = M.config.keymaps
  local function confirm(action)
    return function()
      context.pending_action = action
      process.send_key(context, "\r")
    end
  end

  set_terminal_keymap(context, keymaps.open_file_in_vertical_split, confirm("vertical"))
  set_terminal_keymap(context, keymaps.open_file_in_horizontal_split, confirm("horizontal"))
  set_terminal_keymap(context, keymaps.open_file_in_tab, confirm("tab"))
  set_terminal_keymap(context, keymaps.send_to_quickfix_list, confirm("quickfix"))
  set_terminal_keymap(context, keymaps.copy_relative_path_to_selected_files, confirm("copy"))
  set_terminal_keymap(context, keymaps.change_working_directory, function()
    context.pending_action = "cwd"
    process.send_key(context, "q")
  end)
  set_terminal_keymap(context, keymaps.show_help, show_help)
end

local function restore_window(context)
  if context.previous_window and vim.api.nvim_win_is_valid(context.previous_window) then
    vim.api.nvim_set_current_win(context.previous_window)
  end
end

local function apply_cwd(cwd)
  if cwd and vim.fn.isdirectory(cwd) == 1 then
    actions.change_directory(cwd)
  end
end

local function dispatch_result(context, result)
  if M.active == context then
    M.active = nil
  end
  restore_window(context)
  M.last_path = result.cwd or context.input_path or M.last_path

  if result.code ~= 0 then
    return
  end
  pcall(vim.cmd, "silent! checktime")

  local paths = result.selected_files or {}
  local action = context.pending_action
  if action == "cwd" then
    apply_cwd(result.cwd)
  elseif #paths == 1 then
    if action == "vertical" then
      actions.open_vertical(paths)
    elseif action == "horizontal" then
      actions.open_horizontal(paths)
    elseif action == "tab" then
      actions.open_tab(paths)
    elseif action == "quickfix" then
      actions.to_quickfix(paths)
    elseif action == "copy" then
      actions.copy_relative(paths, M.config.clipboard_register, result.cwd)
    elseif M.config.open_file_function then
      M.config.open_file_function(paths[1])
    else
      actions.open_current(paths[1])
    end
  elseif #paths > 1 then
    if action == "vertical" then
      actions.open_vertical(paths)
    elseif action == "horizontal" then
      actions.open_horizontal(paths)
    elseif action == "tab" then
      actions.open_tab(paths)
    elseif action == "quickfix" then
      actions.to_quickfix(paths)
    elseif action == "copy" then
      actions.copy_relative(paths, M.config.clipboard_register, result.cwd)
    elseif M.config.open_multiple_files_function then
      M.config.open_multiple_files_function(paths)
    else
      actions.open_default(paths)
    end
  elseif M.config.change_neovim_cwd_on_close then
    apply_cwd(result.cwd)
  end
end

local function setup_commands()
  local commands = { "Elio", "ElioToggle", "ElioClose" }
  for _, name in ipairs(commands) do
    pcall(vim.api.nvim_del_user_command, name)
  end
  vim.api.nvim_create_user_command("Elio", function(command)
    M.open(command.args ~= "" and vim.fn.expand(command.args) or nil)
  end, { nargs = "?", complete = "file" })
  vim.api.nvim_create_user_command("ElioToggle", function(command)
    M.toggle(command.args ~= "" and vim.fn.expand(command.args) or nil)
  end, { nargs = "?", complete = "file" })
  vim.api.nvim_create_user_command("ElioClose", function()
    M.close()
  end, {})
end

local function setup_shutdown_autocmd()
  delete_group(M.shutdown_group)
  M.shutdown_group = vim.api.nvim_create_augroup("ElioLifecycle", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = M.shutdown_group,
    callback = function()
      close_help()
      if M.active then
        process.stop(M.active)
        M.active = nil
      end
    end,
  })
end

local function setup_directory_autocmd()
  delete_group(M.directory_group)
  M.directory_group = nil
  if not M.config.open_for_directories then
    return
  end
  M.directory_group = vim.api.nvim_create_augroup("ElioDirectories", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = M.directory_group,
    callback = function(args)
      local buffer = args.buf
      if vim.b[buffer].elio_terminal or vim.bo[buffer].filetype == "elio" then
        return
      end
      local name = vim.api.nvim_buf_get_name(buffer)
      if name == "" or vim.fn.isdirectory(name) ~= 1 then
        return
      end
      vim.schedule(function()
        if M.is_open() or not vim.api.nvim_buf_is_valid(buffer) then
          return
        end
        M.open(name)
        if vim.api.nvim_buf_is_valid(buffer) then
          pcall(vim.api.nvim_buf_delete, buffer, { force = true })
        end
      end)
    end,
  })
end

function M.setup(opts)
  M.config = config_module.merge(opts)
  setup_commands()
  setup_shutdown_autocmd()
  setup_directory_autocmd()
  return M.config
end

function M.is_open()
  return M.active ~= nil and M.active.window ~= nil and vim.api.nvim_win_is_valid(M.active.window)
end

function M.open(path)
  if not M.config then
    M.setup({})
  end
  if M.active then
    if M.is_open() then
      vim.api.nvim_set_current_win(M.active.window)
      return M.active
    end
    process.stop(M.active)
    M.active = nil
  end
  if not utils.is_executable(M.config.executable) then
    notify("Elio executable not found: " .. tostring(M.config.executable))
    return nil
  end

  local input_path = resolve_path(path)
  local previous_window = vim.api.nvim_get_current_win()
  local context
  context = process.start(M.config, input_path, {
    env = M.config.env,
    on_exit = function(result)
      if context then
        dispatch_result(context, result)
      end
    end,
  })
  if not context then
    return nil
  end
  context.previous_window = previous_window
  context.input_path = input_path
  M.active = context
  M.last_path = input_path
  vim.b[context.buffer].elio_terminal = true
  setup_terminal_keymaps(context)
  return context
end

function M.close()
  if not M.active then
    return
  end
  if process.is_running(M.active) then
    process.send_key(M.active, "q")
  else
    process.stop(M.active)
    M.active = nil
  end
end

function M.toggle(path)
  if M.is_open() then
    M.close()
    return
  end
  return M.open(path or M.last_path)
end

return M
