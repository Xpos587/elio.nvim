local M = {}

function M.build(opts, path, chooser_file, cwd_file)
  local argv = { opts.executable }
  if path and path ~= "" then
    argv[#argv + 1] = path
  end
  argv[#argv + 1] = "--chooser-file"
  argv[#argv + 1] = chooser_file
  argv[#argv + 1] = "--cwd-file"
  argv[#argv + 1] = cwd_file
  return argv
end

return M
