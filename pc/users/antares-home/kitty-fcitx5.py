from subprocess import DEVNULL


def on_set_user_var(boss, window, data):
    if (
        data.get("key") == "nvim_ime"
        and data.get("value") == "off"
        and window.is_focused
    ):
        boss.run_background_process(
            ["@fcitx5_remote@", "--check", "-c"], stdout=DEVNULL, stderr=DEVNULL
        )
