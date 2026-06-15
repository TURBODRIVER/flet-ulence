:::: Build requirements

CHCP 65001
SET PYTHONUTF8=1
SET PYTHONIOENCODING=utf-8

:::: Vars

SET FLET_DIR="C:\Input\Path\To\Flet\flet-ulence"

:::: Deleting existing build

RMDIR /s /q build

:::: Preparing assets

"%~dp0.venv\Scripts\python.exe" prepare_assets.py

:::: Building app

"%~dp0.venv\Scripts\pip.exe" install -e "%FLET_DIR%\sdk\python\packages\flet-desktop"
"%~dp0.venv\Scripts\pip.exe" install -e "%FLET_DIR%\sdk\python\packages\flet-cli"
"%~dp0.venv\Scripts\pip.exe" install -e "%FLET_DIR%\sdk\python\packages\flet"

"%~dp0.venv\Scripts\flet.exe" build windows --template "%FLET_DIR%\sdk\python\templates\build" --verbose
