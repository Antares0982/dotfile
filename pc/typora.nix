{
  config,
  lib,
  pkgs,
  ...
}:
let
  waylandTypora = (
    pkgs.typora.overrideAttrs (oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs or [ ] ++ [ pkgs.makeWrapper ];
      postInstall =
        assert !(oldAttrs ? postInstall);
        ''
          wrapProgram $out/bin/typora  --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime}}"
        '';
    })
  );
in
{
  environment.systemPackages = [
    waylandTypora
  ];
}
