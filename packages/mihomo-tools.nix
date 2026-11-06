{
  pkgs,
  mihomo ? pkgs.mihomo,
  clashtui ? pkgs.clashtui,
}:
pkgs.runCommand "mihomo-tools" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/bin $out/lib
  cp ${../resource/mihomo-tools.py} $out/lib/mihomo-tools.py
  for name in mihomoctl mihomo-speed-test; do
    makeWrapper ${pkgs.python3}/bin/python3 $out/bin/$name \
      --add-flags "$out/lib/mihomo-tools.py" \
      --set MIHOMO_COMMAND "$name" \
      --set MIHOMO_BIN ${mihomo}/bin/mihomo \
      --set CLASHTUI_BIN ${clashtui}/bin/clashtui \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.curl
          pkgs.systemd
          pkgs.fzf
        ]
      }
  done
''
