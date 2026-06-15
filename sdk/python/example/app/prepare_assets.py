import os
import shutil
import subprocess
import sys

from PIL import Image

releases_dir = os.path.join(os.path.dirname(__file__), "releases")
icon_file_path = os.path.join(releases_dir, "icon.png")

icon_image = Image.open(icon_file_path)

# Windows icon
if os.name == 'nt':
    icon_image.save(os.path.join(releases_dir, "favicon.ico"), format="ICO", sizes=[
        (16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)
    ])

# macOS icon
if sys.platform == 'darwin':
    MAC_ICON_SIZES = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    iconset_dir = os.path.join(releases_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    for filename, size in MAC_ICON_SIZES:
        resized_icon = icon_image.resize((size, size), Image.Resampling.LANCZOS)
        resized_icon.save(os.path.join(iconset_dir, filename), "PNG")

    subprocess.run(["iconutil", "-c", "icns", iconset_dir], check=True)
    shutil.rmtree(iconset_dir)
