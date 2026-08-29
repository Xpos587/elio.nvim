#!/usr/bin/env bash
set -eu
for heading in Installation Configuration Keymaps API Limitations Troubleshooting; do
  grep -Fqx "## ${heading}" README.md
done
grep -Fq 'Xpos587/elio.nvim' README.md
grep -Fq 'chooser-file' README.md
grep -Fq 'cwd-file' README.md
