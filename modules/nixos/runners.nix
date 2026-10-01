{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.antares-runners;
  active = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
  commonEnvs = import ../../common/shellEnv.nix;
  units = lib.concatMap (
    instance:
    map (index: {
      inherit instance;
      name = instance.serviceName + lib.optionalString (instance.indexed) "-${toString index}";
      home = instance.directory + lib.optionalString (instance.indexed) "/runner-${toString index}";
    }) (lib.range 1 instance.count)
  ) (builtins.attrValues active);
in
{
  options.services.antares-runners.instances = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }: {
          options = {
            enable = lib.mkEnableOption "runner instance";
            user = lib.mkOption { type = lib.types.str; };
            package = lib.mkOption { type = lib.types.package; };
            serviceName = lib.mkOption {
              type = lib.types.str;
              default = name;
            };
            directory = lib.mkOption {
              type = lib.types.str;
              default = "/home/${config.user}";
            };
            indexed = lib.mkOption {
              type = lib.types.bool;
              default = config.count > 1;
            };
            count = lib.mkOption {
              type = lib.types.ints.positive;
              default = 1;
            };
            authorizedKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            proxy = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            restartAt = lib.mkOption {
              type = lib.types.str;
              default = "*-*-* 06:00:00";
            };
          };
        }
      )
    );
  };
  config = {
    assertions = [
      {
        assertion =
          lib.length (lib.unique (map (i: i.user) (builtins.attrValues active)))
          == lib.length (builtins.attrValues active);
        message = "Runner instances must have distinct users.";
      }
      {
        assertion = lib.length (lib.unique (map (unit: unit.name) units)) == lib.length units;
        message = "Runner service names must be unique.";
      }
    ];
    users.users = lib.mapAttrs' (
      _: instance:
      lib.nameValuePair instance.user {
        isNormalUser = true;
        home = "/home/${instance.user}";
        description = "github action runner";
        useDefaultShell = true;
        linger = true;
        openssh.authorizedKeys.keys = instance.authorizedKeys;
      }
    ) active;
    systemd.services = lib.listToAttrs (
      lib.concatMap (
        {
          instance,
          name,
          home,
        }:
        [
          (lib.nameValuePair name {
            script = ''
              export PATH=$PATH:${commonEnvs.sysBin}
            ''
            + lib.optionalString (instance.proxy != null) ''
              export http_proxy=${lib.escapeShellArg instance.proxy}
              export https_proxy=${lib.escapeShellArg instance.proxy}
            ''
            + ''
              set -eu
            ''
            + lib.optionalString (instance.indexed) ''
              export HOME=${lib.escapeShellArg home}
              mkdir -p "$HOME"
            ''
            + ''
              cd ${lib.escapeShellArg home}
              bash ${instance.package}/bin/run.sh
            '';
            serviceConfig.User = instance.user;
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
          })
          (lib.nameValuePair "restart-${name}" {
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.systemd}/bin/systemctl restart ${name}";
            };
          })
        ]
      ) units
    );
    systemd.timers = lib.listToAttrs (
      map (
        { instance, name, ... }:
        lib.nameValuePair "restart-${name}" {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = instance.restartAt;
            Persistent = true;
            Unit = "restart-${name}.service";
          };
        }
      ) units
    );
  };
}
