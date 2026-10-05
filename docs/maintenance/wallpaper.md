# PC wallpaper

PC wallpaper configuration lives in `pc/wallpaper.nix` and is gated by the
desktop switch. Assets and selected workshop directories live outside Nix at
`/var/lib/we-layerd/{assets,workshop/<ID>}`; provision them separately with read
access for the desktop user and greeter. HM owns the three period configs and
user timer. Run `bash scripts/check-wallpaper.sh`; optionally pass the generated
config directory to also validate TOML using Python 3.11 or newer.
