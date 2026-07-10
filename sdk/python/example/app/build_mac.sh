#!/bin/sh
set -e

#### Env

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

export PATH="$HOME/fvm/default/bin:$PATH"
export PATH="$HOME/.pub-cache/bin:$PATH"

#### Vars

FLET_DIR="$HOME/Documents/flet-ulence"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV="$APP_DIR/.venv/bin"

#### Delete

rm -rf "$APP_DIR/build"

#### Flet

"$VENV/pip" uninstall -y flet-desktop flet-cli flet -v
"$VENV/pip" install --no-deps -e "$FLET_DIR/sdk/python/packages/flet" --no-cache-dir -v
"$VENV/pip" install --no-deps -e "$FLET_DIR/sdk/python/packages/flet-cli" --no-cache-dir -v
"$VENV/pip" install --no-deps -e "$FLET_DIR/sdk/python/packages/flet-desktop" --no-cache-dir -v

### Verify

"$VENV/python" -c "import importlib.metadata as m; print(m.version('flet'))"
"$VENV/flet" --version

#### Prepare

"$VENV/python" prepare_assets.py

#### Build

"$VENV/flet" build macos --template "$FLET_DIR/sdk/python/templates/build" --verbose
