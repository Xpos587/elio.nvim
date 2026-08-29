local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

vim.opt.loadplugins = false
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
vim.opt.rtp:prepend(root)
