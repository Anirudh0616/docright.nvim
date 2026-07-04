#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

XDG_STATE_HOME=/private/tmp \
XDG_CACHE_HOME=/private/tmp \
XDG_DATA_HOME=/private/tmp \
nvim --clean --headless -u NONE \
  --cmd "set rtp^=$ROOT" \
  "+lua dofile('$ROOT/test/run.lua')" \
  +qa!
