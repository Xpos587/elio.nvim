# elio.nvim Design

## Intent

**Why:** Bring Elio's rich terminal file-manager experience into Neovim without forcing users into a separate Kitty window or a different file manager.

**Human outcome:** Pressing one Neovim mapping opens Elio in a native floating terminal, and leaving Elio returns selected paths to normal Neovim editing workflows.

**Experience invariants:**
- Elio remains the file-manager UI and keeps its previews, mouse support, and file actions.
- Opening and closing Elio never leaves orphaned terminal jobs or scratch buffers.
- A selected file opens in the previous Neovim window by default.
- Public users can install and configure plugin without copying personal dotfiles.

**Betrayal condition:** A technically working launcher that opens a detached Kitty window, loses selected paths, or replaces Elio's UI with a generic picker would violate this intent.

## Goal

Build `Xpos587/elio.nvim`, a standalone MIT-licensed Neovim plugin that embeds the Elio terminal file manager in a floating terminal and provides the core workflow of `yazi.nvim`.

## Research Basis

`yazi.nvim` creates a scratch floating terminal buffer, starts its file manager with `jobstart(..., { term = true })`, passes temporary chooser and cwd files, handles process exit, and opens returned paths through configurable actions.

Elio 1.12.0 provides the compatible CLI flags:

- `--chooser-file FILE`: writes selected paths, one path per line; `-` writes stdout.
- `--cwd-file FILE`: writes final browsed directory without a trailing newline.
- A path argument starts in a directory or focuses a file in its parent directory.

Elio has no Yazi DDS/IPC equivalent. Therefore, live external event synchronization for rename/move/delete is explicitly out of scope for v1. The plugin will provide exit-time synchronization through `:checktime` and returned chooser/cwd files.

## Architecture

The plugin is dependency-free and targets Neovim 0.10+.

- `lua/elio/config.lua`: defaults and option merging.
- `lua/elio/utils.lua`: path resolution, temporary file handling, command validation, and safe cleanup.
- `lua/elio/window.lua`: floating terminal window creation, resizing, and buffer cleanup.
- `lua/elio/process.lua`: Elio command construction, terminal job lifecycle, chooser/cwd result parsing, and exit callback.
- `lua/elio/actions.lua`: current-window, vertical split, horizontal split, tab, quickfix, and clipboard actions.
- `lua/elio/init.lua`: public API, active context, toggle state, commands, and optional directory integration.
- `plugin/elio.lua`: lazy-safe command bootstrap if needed by Neovim runtime loading.

The public module is `require("elio")`. One active Elio session is supported initially. The active context stores the job id, terminal buffer/window, previous window, temporary result paths, input path, and pending post-exit action.

## Lifecycle

1. `elio.open(path?)` resolves current buffer path or cwd.
2. It validates `elio` is executable and creates unique chooser/cwd temp files.
3. It creates a minimal floating terminal buffer and starts:

   ```text
   elio <path> --chooser-file <temp chooser> --cwd-file <temp cwd>
   ```

4. Elio owns terminal input and UI until it exits.
5. On exit, the plugin reads chooser paths and final cwd, normalizes paths, runs `checktime`, closes the floating window, restores the previous window, and dispatches the pending/default action.
6. Temporary files and terminal state are cleaned on success, cancellation, startup failure, and Neovim shutdown.

For split/tab/quickfix/clipboard mappings, the plugin sends Elio's chooser confirmation key through the terminal channel, then applies the requested action to returned paths. This avoids requiring an Elio IPC protocol.

## Public API

```lua
local elio = require("elio")

elio.setup({
  executable = "elio",
  floating_window_scaling_factor = 0.9,
  floating_window_border = "rounded",
  change_neovim_cwd_on_close = true,
  open_for_directories = false,
})

elio.open(path?)
elio.toggle(path?)
elio.close()
elio.is_open()
```

Configuration options:

- `executable`: Elio executable name or absolute path.
- `floating_window_scaling_factor`: number or `{ width = ..., height = ... }`.
- `floating_window_border`: value accepted by `nvim_open_win`.
- `floating_window_winblend`: integer passed to `winblend`.
- `change_neovim_cwd_on_close`: use Elio's final cwd when no file is opened.
- `open_for_directories`: optional directory opening integration.
- `open_file_function`: custom single-file opener.
- `open_multiple_files_function`: custom multi-file opener.
- `keymaps`: configurable terminal mappings, with `false` disabling a mapping.

Commands:

- `:Elio [path]`: open Elio at optional path.
- `:ElioToggle [path]`: close active session or reopen at the last known path.
- `:ElioClose`: close active session.

## Default Actions

- Normal confirmation opens one file with `:edit`.
- Multiple selected files are added to the argument list and the first is opened.
- `<C-v>` confirms and opens selected file(s) in a vertical split.
- `<C-x>` confirms and opens selected file(s) in a horizontal split.
- `<C-t>` confirms and opens selected file(s) in a new tab.
- `<C-q>` confirms and sends selected file(s) to quickfix.
- `<C-y>` confirms and copies selected relative paths to the configured clipboard register.
- `<C-\\>` exits Elio and changes Neovim cwd to Elio's final cwd.
- `<F1>` opens an in-Neovim help overlay.
- `<Esc>` and Elio's normal quit/cancel behavior remain available.

## Lazy.nvim Integration

The repository includes a minimal setup example:

```lua
return {
  {
    "Xpos587/elio.nvim",
    opts = {},
    keys = {
      { "<leader>e", function() require("elio").toggle() end, desc = "Elio" },
    },
  },
}
```

The user's LazyVim configuration will disable `Snacks.explorer` and use this plugin after the standalone repository is locally validated.

## Failure Handling

- Missing executable: notify actionable error and do not create a window.
- Failed job start: close floating window, remove temp files, restore previous window, notify.
- Non-zero/cancelled exit: discard chooser paths, clean resources, preserve Neovim state.
- Invalid or missing result files: treat as no selection, optionally apply cwd change.
- Closed or invalid previous window: clean resources and skip window restoration.
- Duplicate open request: focus existing Elio window instead of starting another job.

## Testing

Use busted with a small Neovim-compatible test harness for pure modules and headless Neovim smoke tests for lifecycle behavior.

Required coverage:

- command construction uses configured executable and both result-file flags;
- chooser and cwd files parse empty, single, multiple, and newline-free outputs;
- paths with spaces, quotes, and Unicode-safe byte handling are passed without shell interpolation;
- single-file actions use escaped paths;
- multi-file actions populate quickfix and argument list predictably;
- missing executable and failed job start clean up state;
- resize updates terminal dimensions;
- `:Elio`, `:ElioToggle`, and `:ElioClose` exist after setup;
- headless startup loads the plugin without errors.

## Non-Goals

- Reimplementing Elio's UI, previews, filesystem operations, or themes.
- Copying Yazi-specific DDS/IPC or Yazi configuration files.
- Live rename/move/delete buffer synchronization without an Elio event API.
- Mandatory Kitty dependency; Elio runs in Neovim's terminal backend.
- Replacing Snacks picker, Telescope, or other unrelated Neovim tools.

## Acceptance Criteria

- A fresh Lazy.nvim installation can load `Xpos587/elio.nvim` with `opts = {}`.
- `<leader>e` opens Elio inside Neovim, not a detached external Kitty window.
- Confirming a file returns to Neovim and opens it in the previous window.
- Split, tab, quickfix, cwd, toggle, close, resize, and cleanup workflows work.
- Missing Elio produces a clear notification and no broken buffer.
- Tests and headless smoke checks pass.
- README documents installation, configuration, keymaps, API, limitations, and troubleshooting.
- GitHub Actions run formatting, lint, and tests on supported Neovim versions.
