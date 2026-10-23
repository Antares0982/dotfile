{
  pkgs,
  myXray,
  xrayDir ? null,
}:
pkgs.writeShellApplication {
  name = "xray-speed-test";
  runtimeInputs = [
    myXray
    pkgs.curl
    pkgs.python3
  ];
  text =
    pkgs.lib.optionalString (xrayDir != null) ''
      export XRAY_CONF_DIR=${pkgs.lib.escapeShellArg xrayDir}
    ''
    + ''
      exec python3 ${../resource/xray-speed-test.py} "$@"
    '';
}
