{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  enabled = config.antares.agent.enable || config.services.qq-codex-agent.enable;
  app = import (inputs.qq-codex-agent + "/nix/package.nix") {
    inherit inputs;
    system = pkgs.stdenv.hostPlatform.system;
  };
  environment = {
    http_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
    https_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
    no_proxy = "127.0.0.1,localhost,::1";
  };
  importer = pkgs.writeShellApplication {
    name = "codex-auth-import";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      test "$(id -u)" = 0 || { echo '需要 root' >&2; exit 1; }
      for unit in qq-codex-agent antares-agent codex-auth codex-login qq-codex-auth; do
        if systemctl is-active --quiet "$unit.service"; then
          echo "请先停止 $unit.service" >&2
          exit 1
        fi
      done
      source=/var/lib/qq-codex-agent/codex/auth.json
      target=/var/lib/codex-auth/codex/auth.json
      backup=/var/backups/codex-auth/qq-auth.json
      test -f "$source" && test ! -L "$source"
      test ! -e "$target" && test ! -L "$target"
      test ! -e "$backup" && test ! -L "$backup"
      install -d -m 0700 -o codex-auth -g codex-auth-clients /var/lib/codex-auth /var/lib/codex-auth/codex
      install -d -m 0700 /var/backups/codex-auth
      install -m 0600 "$source" "$backup"
      install -m 0600 -o codex-auth -g codex-auth-clients "$source" "$target"
      rm "$source"
      echo '认证已迁移；请启动 codex-auth、qq-codex-agent 和 antares-agent。'
    '';
  };
  service = {
    User = "codex-auth";
    Group = "codex-auth-clients";
    StateDirectory = "codex-auth";
    StateDirectoryMode = "0700";
    RuntimeDirectory = "codex-auth";
    RuntimeDirectoryMode = "0750";
    RuntimeDirectoryPreserve = "restart";
    UMask = "0077";
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    KillMode = "control-group";
  };
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = [ importer ];
    users.groups.codex-auth-clients = { };
    users.users.codex-auth = {
      isSystemUser = true;
      group = "codex-auth-clients";
      home = "/var/lib/codex-auth";
    };
    systemd.services.codex-auth = {
      description = "Shared Codex authentication";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ] ++ lib.optional config.antares.xray.enable "xray.service";
      wants = [ "network-online.target" ];
      inherit environment;
      serviceConfig = service // {
        ExecStart = "${app}/bin/codex-auth";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
    systemd.services.codex-login = {
      description = "Shared Codex device login";
      conflicts = [ "codex-auth.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      inherit environment;
      serviceConfig = service // {
        Type = "oneshot";
        ExecStart = "${app}/bin/codex-auth --login";
        TimeoutStartSec = "15min";
      };
    };
  };
}
