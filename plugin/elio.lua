if vim.g.loaded_elio then
  return
end
vim.g.loaded_elio = true

require("elio").setup()
