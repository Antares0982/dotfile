let
  commonEnv = import ../../../../common/shellEnv.nix;
  localFileDef = import ../../../../common/localFileDef.nix { username = "alice"; };
in
rec {
  inherit (commonEnv) aliases sysBin;
  home = localFileDef.userhome;
  inherit (localFileDef) userhome;
  rabbitClientCfgPath = "/run/agenix/rabbitClientCfgAlice";
  monitorCfgPath = "/run/agenix/monitorCfgAlice";
}
