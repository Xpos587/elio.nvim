# Contributing

## Development

Clone repository and keep changes dependency-free. Plugin targets Neovim 0.10+ and current Elio CLI flags.

Run checks from repository root:

```bash
./tests/check_docs.sh
stylua --check lua plugin tests
nvim --headless -u tests/minimal_init.lua -l tests/run.lua
nvim --headless -u tests/minimal_init.lua -l tests/smoke.lua
nvim --headless -u NONE -c 'set rtp^=.' -c 'lua require("elio").setup()' -c 'qa!'
git diff --check
```

Format Lua with:

```bash
stylua lua plugin tests
```

Add focused tests for pure behavior in `tests/run.lua` and lifecycle coverage in `tests/smoke.lua`. Do not add Yazi IPC or a detached terminal dependency.
