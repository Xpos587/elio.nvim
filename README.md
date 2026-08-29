# elio.nvim

Embed [Elio](https://github.com/Xpos587/elio) in a native Neovim floating terminal. Elio keeps ownership of its terminal UI, previews, mouse support, and file operations; this plugin handles launch, cleanup, and returned paths.

## Installation

Requirements:

- Neovim 0.10 or newer.
- Elio 1.12 or newer installed and available on `PATH`, or configured with an absolute executable path.

Lazy.nvim spec:

```lua
return {
  {
    "Xpos587/elio.nvim",
    opts = {
      change_neovim_cwd_on_close = true,
    },
    keys = {
      { "<leader>e", function() require("elio").toggle() end, desc = "Elio" },
    },
  },
}
```

Install Elio separately using its release instructions. This plugin launches its executable directly, without Kitty, a shell command, or Yazi.

## Configuration

Defaults:

```lua
require("elio").setup({
  executable = "elio",
  floating_window_scaling_factor = 0.9,
  floating_window_border = "rounded",
  floating_window_winblend = 0,
  change_neovim_cwd_on_close = false,
  open_for_directories = false,
  clipboard_register = "*",
})
```

`floating_window_scaling_factor` accepts one number or `{ width = 0.9, height = 0.8 }`. Values from 0 through 1 are screen fractions; larger values are cell dimensions.

`open_file_function` and `open_multiple_files_function` accept custom functions for single and multiple selections. `open_for_directories = true` replaces directory buffers entered through `BufEnter` with Elio.

Use an alternate binary with:

```lua
require("elio").setup({ executable = "/opt/elio/bin/elio" })
```

## Keymaps

Mappings are terminal-local and can be disabled individually with `false`:

| Mapping | Action |
| --- | --- |
| Enter | Confirm selection with default action |
| `<C-v>` | Confirm and open in vertical split |
| `<C-x>` | Confirm and open in horizontal split |
| `<C-t>` | Confirm and open in a new tab |
| `<C-q>` | Confirm and send paths to quickfix |
| `<C-y>` | Confirm and copy relative paths to configured register |
| `<C-\>` | Exit and change Neovim working directory |
| `<F1>` | Show help overlay |
| `<Esc>` | Elio cancel behavior |

Override mappings with `keymaps = { open_file_in_tab = "<leader>t" }`. Set any listed key to `false` to disable it.

## API

```lua
local elio = require("elio")

elio.setup(opts)
elio.open(path)
elio.toggle(path)
elio.close()
local open = elio.is_open()
```

`:Elio [path]`, `:ElioToggle [path]`, and `:ElioClose` are also available after setup. With no path, Elio starts at the current buffer path or Neovim working directory.

Elio receives paths as argv entries and uses its `--chooser-file` and `--cwd-file` options. On successful exit, one selected file opens in the previous window. Multiple files are added to the argument list by default. Custom actions can replace either behavior.

## Limitations

- Elio exposes no Yazi DDS/IPC equivalent, so rename, move, and delete changes synchronize only when Neovim runs `checktime` after Elio exits.
- Non-zero or cancelled Elio exits discard chooser results and preserve Neovim's editing state.
- One Elio session is supported at a time; duplicate opens focus the existing floating window.
- Clipboard behavior depends on Neovim's configured register and clipboard provider.

## Troubleshooting

**Elio executable not found**

Install Elio and verify `command -v elio`. For a non-standard location, set `executable` to its absolute path. The plugin checks this before opening a floating window.

**Selection does not open**

Confirm Elio can write its chooser file and that its version supports `--chooser-file` and `--cwd-file`. Run `:messages` for startup errors.

**Working directory does not change**

Use the `<C-\>` mapping or set `change_neovim_cwd_on_close = true`. The returned directory must exist when Elio exits.

**Files changed outside Neovim are stale**

The plugin runs `:checktime` after successful Elio exit. Configure Neovim's `autoread` options if you need different external-change behavior.

See `CONTRIBUTING.md` for local checks.
