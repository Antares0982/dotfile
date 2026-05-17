{
  config,
  pkgs,
  lib,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
  nix = "${pkgs.nix}/bin/nix";
  git_credential_refresher = pkgs.callPackage ../../../common/_git_credential_refresher.nix { };
in
{
  systemd.user.services.git-credential-refresher = {
    Unit = {
      Description = "${envs.usernameCap} Git Credential Refresh Service";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = "${envs.userhome}";
      ExecStart = ''
        ${git_credential_refresher}/bin/git_credential_refresher
      '';
      Environment = [
        "HOME=${envs.userhome}"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
