#!/usr/bin/env bash
set -eu
for heading in Installation Configuration Keymaps API Limitations Troubleshooting; do
  rg -q "^## ${heading}$" README.md
done
rg -q 'Xpos587/elio.nvim' README.md
rg -q 'chooser-file' README.md
rg -q 'cwd-file' README.md
