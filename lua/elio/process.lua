local command = require("elio.command")
local results = require("elio.results")
local utils = require("elio.utils")
local window = require("elio.window")

local M = {}

local function notify(message, level)
  if vim.notify then
    vim.notify(message, level or vim.log.levels.ERROR, { title = "elio.nvim" })
  end
end

local function normalize_paths(paths)
  local normalized = {}
  for _, path in ipairs(paths) do
    normalized[#normalized + 1] = utils.normalize_path(path)
  end
  return normalized
end

local function dispatch(callbacks, result)
  if not callbacks or not callbacks.on_exit then
    return
  end
  vim.schedule(function()
    callbacks.on_exit(result)
  end)
end

local function cleanup(context)
  if context.cleaned then
    return
  end
  context.cleaned = true
  utils.cleanup_files(context.chooser_file, context.cwd_file)
  window.close(context.window_context)
end

function M.start(opts, path, callbacks)
  callbacks = callbacks or {}
  local context = {
    chooser_file = vim.fn.tempname() .. "-chooser",
    cwd_file = vim.fn.tempname() .. "-cwd",
    input_path = path,
  }

  local ok, window_context = pcall(window.open, opts)
  if not ok then
    utils.cleanup_files(context.chooser_file, context.cwd_file)
    notify("could not open Elio window: " .. tostring(window_context))
    dispatch(callbacks, { code = -1, selected_files = {}, cwd = nil })
    return nil
  end
  context.window_context = window_context
  context.window = window_context.window
  context.buffer = window_context.buffer

  local argv = command.build(opts, path, context.chooser_file, context.cwd_file)
  local job_opts = {
    term = true,
    on_exit = function(_, code)
      if context.cleaned then
        return
      end
      local selected_files = {}
      local cwd
      if code == 0 then
        selected_files = normalize_paths(results.read_chooser(context.chooser_file))
        cwd = results.read_cwd(context.cwd_file)
        if cwd then
          cwd = utils.normalize_path(cwd)
        end
      end
      local result = { code = code, selected_files = selected_files, cwd = cwd }
      cleanup(context)
      dispatch(callbacks, result)
    end,
  }
  if callbacks.env or opts.env then
    job_opts.env = callbacks.env or opts.env
  end

  local started, job_id = pcall(vim.fn.jobstart, argv, job_opts)
  if not started or type(job_id) ~= "number" or job_id <= 0 then
    cleanup(context)
    notify("could not start Elio process")
    dispatch(callbacks, { code = -1, selected_files = {}, cwd = nil })
    return nil
  end

  context.job_id = job_id
  window_context.job_id = job_id
  return context
end

function M.send_key(context, key)
  if not context or not context.job_id or context.cleaned then
    return false
  end
  local ok = pcall(vim.api.nvim_chan_send, context.job_id, key)
  return ok
end

function M.resize(context, width, height)
  if context and context.window_context then
    window.resize(context.window_context, width, height)
  end
end

function M.is_running(context)
  if not context or not context.job_id or context.cleaned then
    return false
  end
  local status = vim.fn.jobwait({ context.job_id }, 0)
  return status[1] == -1
end

function M.stop(context)
  if not context or context.cleaned then
    return
  end
  context.stopped = true
  if context.job_id and M.is_running(context) then
    pcall(vim.fn.jobstop, context.job_id)
    if vim.fn.jobwait then
      pcall(vim.fn.jobwait, { context.job_id }, 100)
    end
  end
  cleanup(context)
end

function M.cleanup(context)
  cleanup(context)
end

return M
