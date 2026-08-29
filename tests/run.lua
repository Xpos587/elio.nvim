local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local command = require("elio.command")
local config = require("elio.config")
local results = require("elio.results")
local utils = require("elio.utils")
local actions = require("elio.actions")

local function assert_equal(actual, expected, message)
  assert(
    vim.deep_equal(actual, expected),
    (message or "values differ")
      .. "\nactual: "
      .. vim.inspect(actual)
      .. "\nexpected: "
      .. vim.inspect(expected)
  )
end

local temp = vim.fn.tempname()
vim.fn.writefile({ "/tmp/one file.txt", "/tmp/two.txt", "" }, temp)
assert_equal(results.read_chooser(temp), { "/tmp/one file.txt", "/tmp/two.txt" }, "chooser parser ignores blank lines")
vim.fn.writefile({ "/tmp/project\r" }, temp)
assert_equal(results.read_cwd(temp), "/tmp/project", "cwd parser strips CRLF")

local argv = command.build(config.defaults(), "/tmp/one file.txt", "/tmp/choose", "/tmp/cwd")
assert_equal(argv, {
  "elio",
  "/tmp/one file.txt",
  "--chooser-file",
  "/tmp/choose",
  "--cwd-file",
  "/tmp/cwd",
}, "command uses argv entries instead of shell quoting")

assert_equal(results.read_chooser(vim.fn.tempname()), {}, "missing chooser file is empty")
assert_equal(utils.normalize_path("/tmp/one file.txt"), "/tmp/one file.txt", "absolute path stays absolute")
assert_equal(utils.read_lines(vim.fn.tempname()), {}, "missing lines file is empty")
assert(actions.describe_single("/tmp/a b.txt") == "edit /tmp/a\\ b.txt")
assert(actions.describe_single('/tmp/a"b.txt') == "edit /tmp/a\\\"b.txt")
local folder = vim.fn.tempname()
vim.fn.mkdir(folder, "p")
local quickfix = actions.quickfix_items({ "/tmp/a.txt", folder })
assert(quickfix[1].filename == "/tmp/a.txt")
assert(quickfix[2].filename == folder .. "/")
vim.fn.delete(folder, "d")
local copied = vim.fn.tempname()
local previous_cwd = vim.fn.getcwd()
vim.fn.mkdir(copied, "p")
actions.copy_relative({ copied .. "/nested.txt" }, "z", "/tmp")
assert(vim.fn.getreg("z") == vim.fn.fnamemodify(copied .. "/nested.txt", ":p"))
vim.cmd.cd(previous_cwd)
vim.fn.delete(copied, "rf")
local window = require("elio.window").open(config.defaults())
require("elio.window").resize(window, 20, 10)
local window_config = vim.api.nvim_win_get_config(window.window)
assert(window_config.width == 20)
assert(window_config.height == 10)
require("elio.window").close(window)
print("action unit tests passed")
print("core unit tests passed")
vim.cmd("qa!")
