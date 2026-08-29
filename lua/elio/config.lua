local M = {}

function M.defaults()
  return {
    executable = "elio",
    floating_window_scaling_factor = 0.9,
    floating_window_border = "rounded",
    floating_window_winblend = 0,
    change_neovim_cwd_on_close = false,
    open_for_directories = false,
    clipboard_register = "*",
    keymaps = {
      open_file_in_vertical_split = "<C-v>",
      open_file_in_horizontal_split = "<C-x>",
      open_file_in_tab = "<C-t>",
      send_to_quickfix_list = "<C-q>",
      copy_relative_path_to_selected_files = "<C-y>",
      change_working_directory = "<C-\\>",
      show_help = "<F1>",
    },
  }
end

function M.merge(user_opts)
  return vim.tbl_deep_extend("force", M.defaults(), user_opts or {})
end

return M
