if vim.g.loaded_elio then
  return
end
vim.g.loaded_elio = true

local elio = require("elio")
if elio.config == nil then
  elio.setup()
end
