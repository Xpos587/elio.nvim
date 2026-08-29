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
print("process smoke test passed")
vim.cmd("qa!")
