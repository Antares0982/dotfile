import runpy
from pathlib import Path
from subprocess import DEVNULL
from types import SimpleNamespace

watcher = Path(__file__).resolve().parents[1] / "pc/users/antares-home/kitty-fcitx5.py"
callback = runpy.run_path(str(watcher))["on_set_user_var"]
calls = []
boss = SimpleNamespace(
    run_background_process=lambda cmd, **opts: calls.append((cmd, opts))
)
window = SimpleNamespace(is_focused=True)
signal = {"key": "nvim_ime", "value": "off"}
for data in (
    {},
    {"key": "other", "value": "off"},
    {"key": "nvim_ime", "value": None},
    {"key": "nvim_ime", "value": "arbitrary command"},
):
    callback(boss, window, data)
window.is_focused = False
callback(boss, window, signal)
assert not calls
window.is_focused = True
callback(boss, window, signal)
callback(boss, window, signal)
assert (
    calls
    == [(["@fcitx5_remote@", "--check", "-c"], {"stdout": DEVNULL, "stderr": DEVNULL})]
    * 2
)
print("Kitty input method checks passed")
