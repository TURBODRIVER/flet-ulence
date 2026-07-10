:::: Env

CHCP 65001
SET PYTHONUTF8=1
SET PYTHONIOENCODING=utf-8

:::: Vars

SET FLET_DIR="C:\Input\Path\To\Flet\flet-ulence"
SET VENV=%~dp0.venv\Scripts

:::: Delete

RMDIR /s /q build

:::: Flet

"%VENV%\pip.exe" uninstall -y flet-desktop flet-cli flet -v
"%VENV%\pip.exe" install --no-deps -e "%FLET_DIR%\sdk\python\packages\flet" --no-cache-dir -v
"%VENV%\pip.exe" install --no-deps -e "%FLET_DIR%\sdk\python\packages\flet-cli" --no-cache-dir -v
"%VENV%\pip.exe" install --no-deps -e "%FLET_DIR%\sdk\python\packages\flet-desktop" --no-cache-dir -v

:::: Verify

"%VENV%\python.exe" -c "import importlib.metadata as m; print(m.version('flet'))"
"%VENV%\flet.exe" --version

:::: Prepare

"%~dp0.venv\Scripts\python.exe" prepare_assets.py

:::: Build

"%~dp0.venv\Scripts\flet.exe" build windows --template "%FLET_DIR%\sdk\python\templates\build" --verbose
