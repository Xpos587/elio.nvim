local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local process = require("elio.process")
local config = require("elio.config").merge({ executable = root .. "/tests/fixtures/fake-elio" })
local received

process.start(config, "/tmp/start.txt", {
  env = { FAKE_ELIO_SELECTION = "/tmp/chosen.txt", FAKE_ELIO_CWD = "/tmp/project" },
  on_exit = function(result)
    received = result
  end,
})

vim.wait(2000, function()
  return received ~= nil
end, 20)
assert(received, "process callback did not run")
assert(vim.deep_equal(received.selected_files, { "/tmp/chosen.txt" }), vim.inspect(received))
assert(received.cwd == "/tmp/project", vim.inspect(received))
local failed
process.start(config, "/tmp/start.txt", {
  env = {
    FAKE_ELIO_SELECTION = "/tmp/should-not-open.txt",
    FAKE_ELIO_CWD = "/tmp/should-not-cd",
    FAKE_ELIO_EXIT = "7",
  },
  on_exit = function(result)
    failed = result
  end,
})
vim.wait(2000, function()
  return failed ~= nil
end, 20)
assert(failed.code == 7, vim.inspect(failed))
assert(vim.deep_equal(failed.selected_files, {}), vim.inspect(failed))
assert(failed.cwd == nil, vim.inspect(failed))

local elio = require("elio")
elio.setup({
  executable = root .. "/tests/fixtures/fake-elio",
  env = { FAKE_ELIO_SELECTION = "/tmp/chosen.txt", FAKE_ELIO_CWD = "/tmp/project" },
  keymaps = {
    open_file_in_vertical_split = false,
    open_file_in_horizontal_split = false,
  },
})
assert(vim.fn.exists(":Elio") == 2)
assert(vim.fn.exists(":ElioToggle") == 2)
assert(vim.fn.exists(":ElioClose") == 2)
local active = elio.open("/tmp/start.txt")
assert(active, "public open did not return context")
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(active.buffer, "t")) do
  assert(mapping.lhs ~= "<C-v>" and mapping.lhs ~= "<C-x>", vim.inspect(mapping))
end
vim.wait(2000, function()
  return not elio.is_open()
end, 20)
assert(not elio.is_open(), "public process did not close")
elio.setup({ executable = "__elio_missing__" })
assert(elio.open("/tmp/start.txt") == nil)
assert(not elio.is_open(), "missing executable opened window")

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local directory_buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(directory_buffer, directory)
vim.api.nvim_set_current_buf(directory_buffer)
elio.setup({ executable = "__elio_missing__", open_for_directories = true })
vim.api.nvim_exec_autocmds("BufEnter", { buffer = directory_buffer, modeline = false })
vim.wait(100)
assert(vim.api.nvim_buf_is_valid(directory_buffer), "directory buffer deleted after Elio startup failure")
vim.fn.delete(directory, "d")
print("process smoke test passed")
vim.cmd("qa!")
