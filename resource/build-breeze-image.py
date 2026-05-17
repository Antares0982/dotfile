#!/usr/bin/env python3
# find /nix/store -name "5120x2880.png" | grep breeze
files = "/nix/store/il8hy5jmc1myz8ncslv5anljg62p1xnx-breeze-6.0.5/share/wallpapers/Next/contents/images/"

import os
import subprocess


os.makedirs("breeze", exist_ok=True)
for file in os.listdir(files):

    if file.endswith(".png"):
        pixels = file[:-4]
        w, h = pixels.split('x')
        if int(h) > int(w):
            print(file)
            move = int(w) * 200 // 360
            subprocess.call(["convert", "arona.png", "-resize", f"{pixels}^", "-gravity",
                            "center", "-crop", f"{pixels}-{move}+0", "+repage", f"breeze/{file}"])
        else:
            print(file)
            subprocess.call(["convert", "arona.png", "-resize", f"{pixels}^", "-gravity", "center", "-crop", f"{pixels}+0+0", "+repage", f"breeze/{file}"])
