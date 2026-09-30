{
  pkgs,
  myXray,
  xrayDir ? null,
  configPath ? null,
  systemdScope ? "user",
}:
let
  inherit (pkgs) lib;
in
assert builtins.elem systemdScope [
  "user"
  "system"
];
pkgs.writeShellApplication {
  name = "xs";
  runtimeInputs = [
    myXray
    pkgs.jq
    pkgs.curl
    pkgs.systemd
  ];
  text =
    lib.optionalString (xrayDir != null) ''
      export XRAY_CONF_DIR=${lib.escapeShellArg xrayDir}
    ''
    + lib.optionalString (configPath != null) ''
      export XS_CONFIG_PATH=${lib.escapeShellArg configPath}
    ''
    + ''
      export XS_SYSTEMD_SCOPE=${lib.escapeShellArg systemdScope}
    ''
    + builtins.readFile ../resource/xs.sh;
}
