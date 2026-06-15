#!/bin/bash

#### Build requirements

set -e
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

export PATH="$HOME/fvm/default/bin:$PATH"
export PATH="$HOME/.pub-cache/bin:$PATH"

#### Vars

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLET_DIR="$HOME/Input/Path/To/Flet/flet-ulence"

#### Deleting existing build

rm -rf "$APP_DIR/build"

#### Preparing assets

"$APP_DIR/.venv/bin/python" prepare_assets.py

#### Building app

"$APP_DIR/.venv/bin/pip" install -e "$FLET_DIR/sdk/python/packages/flet-desktop"
"$APP_DIR/.venv/bin/pip" install -e "$FLET_DIR/sdk/python/packages/flet-cli"
"$APP_DIR/.venv/bin/pip" install -e "$FLET_DIR/sdk/python/packages/flet"

"$APP_DIR/.venv/bin/flet" build macos --template "$FLET_DIR/sdk/python/templates/build" --verbose
