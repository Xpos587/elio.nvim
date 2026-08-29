local M = {}

function M.normalize_path(path)
  if not path or path == "" then
    return ""
  end
  if vim.fs and vim.fs.normalize then
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  end
  return vim.fn.fnamemodify(path, ":p")
end

function M.read_lines(path)
  if not path or vim.fn.filereadable(path) ~= 1 then
    return {}
  end
  return vim.fn.readfile(path)
end

function M.is_executable(executable)
  return executable and executable ~= "" and vim.fn.executable(executable) == 1
end

function M.cleanup_files(...)
  for _, path in ipairs({ ... }) do
    if path and path ~= "" and vim.fn.filereadable(path) == 1 then
      vim.fn.delete(path)
    end
  end
end

return M
