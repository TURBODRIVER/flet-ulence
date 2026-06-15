const errorExitCode = 100;

// language=Python
const pythonScript = """
import os, runpy, socket, sys, traceback

# fix for cryptography package
os.environ["CRYPTOGRAPHY_OPENSSL_NO_LEGACY"] = "1"

# fix for: https://github.com/flet-dev/serious-python/issues/85#issuecomment-2065000974
os.environ["OPENBLAS_NUM_THREADS"] = "1"

def initialize_ctypes():
    import ctypes.util
    import os
    import pathlib
    import sys

    def find_library_override_imp(name: str):
        if name is None:
            return None
        if pathlib.Path(name).exists():
            return name

        return None

    find_library_original = ctypes.util.find_library

    def find_library_override(name):
        return find_library_override_imp(name) or find_library_original(name)

    ctypes.util.find_library = find_library_override

    CDLL_init_original = ctypes.CDLL.__init__

    def CDLL_init_override(self, name, *args, **kwargs):
        CDLL_init_original(
            self, find_library_override_imp(name) or name, *args, **kwargs
        )

    ctypes.CDLL.__init__ = CDLL_init_override

initialize_ctypes()

out_file = open("{outLogFilename}", "w+", buffering=1)

callback_socket_addr = os.getenv("FLET_PYTHON_CALLBACK_SOCKET_ADDR")
if ":" in callback_socket_addr:
    addr, port = callback_socket_addr.split(":")
    callback_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    callback_socket.connect((addr, int(port)))
else:
    callback_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    callback_socket.connect(callback_socket_addr)

sys.stdout = sys.stderr = out_file

def flet_exit(code=0):
    callback_socket.sendall(str(code).encode())
    out_file.close()
    callback_socket.close()

sys.exit = flet_exit

ex = None
try:
    sys.argv = {argv}
    runpy.run_module("{module_name}", run_name="__main__")
except Exception as e:
    ex = e
    traceback.print_exception(e)

sys.exit(0 if ex is None else 100)
""";
