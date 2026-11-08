{
  pkgs,
  mihomo ? pkgs.mihomo,
  clashtui ? pkgs.clashtui,
}:
let
  terminal =
    if pkgs.stdenv.hostPlatform.isDarwin then
      clashtui.overrideAttrs (old: {
        meta = old.meta // {
          platforms = old.meta.platforms ++ pkgs.lib.platforms.darwin;
        };
      })
    else
      clashtui;
in
pkgs.runCommand "mihomo-tools"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    passthru.clashtui = terminal;
  }
  ''
    mkdir -p $out/bin $out/lib
    cp ${../resource/mihomo-tools.py} $out/lib/mihomo-tools.py
    cp ${../resource/test_mihomo_tools.py} test_mihomo_tools.py
    ln -s $out/lib/mihomo-tools.py mihomo-tools.py
    ${pkgs.python3}/bin/python3 test_mihomo_tools.py
    for name in mihomoctl mihomo-speed-test; do
      makeWrapper ${pkgs.python3}/bin/python3 $out/bin/$name \
        --add-flags "$out/lib/mihomo-tools.py" \
        --set MIHOMO_COMMAND "$name" \
        --set MIHOMO_BIN ${mihomo}/bin/mihomo \
        --set CLASHTUI_BIN ${terminal}/bin/clashtui \
        --prefix PATH : ${
          pkgs.lib.makeBinPath (
            [
              pkgs.curl
              pkgs.fzf
            ]
            ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.systemd
          )
        }
    done
  ''
