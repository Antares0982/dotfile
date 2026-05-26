{
  config,
  pkgs,
  lib,
  myXray,
  xray-sub,
  ...
}:
let
  xrayDir = "/var/lib/xray";
  subsDir = "${xrayDir}/subscriptions";
in
{
  # ── shared group for xray management ──
  users.groups.xray = {
    members = [ "antares" "hermes" ];
  };

  # ── directories ──
  systemd.tmpfiles.rules = [
    "d ${xrayDir} 0775 root xray - -"
    "d ${subsDir} 0775 root xray - -"
    "d /home/hermes/.cache/xray-mgr/trigger 0700 hermes hermes - -"
  ];

  # ── migrate old config.json to subscription-based symlink ──
  system.activationScripts.xrayMigrate = {
    text = ''
      mkdir -p "${subsDir}"

      # Migrate: if config.json is a regular file (old setup), move it in
      if [ -f "${xrayDir}/config.json" ] && [ ! -L "${xrayDir}/config.json" ]; then
        mv "${xrayDir}/config.json" "${subsDir}/_bootstrap.json"
        chown root:xray "${subsDir}/_bootstrap.json"
        chmod 440 "${subsDir}/_bootstrap.json"
      fi

      # Create active.json if missing (prefer non-bootstrap if available)
      if [ ! -e "${subsDir}/active.json" ]; then
        FIRST=$(ls -1 "${subsDir}"/*.json 2>/dev/null | grep -v _bootstrap | head -1)
        [ -z "$FIRST" ] && FIRST=$(ls -1 "${subsDir}"/*.json 2>/dev/null | head -1)
        if [ -n "$FIRST" ]; then
          ln -sf "$FIRST" "${subsDir}/active.json"
        fi
      fi

      # Ensure config.json is a symlink
      if [ ! -L "${xrayDir}/config.json" ] && [ -e "${subsDir}/active.json" ]; then
        ln -sf "${subsDir}/active.json" "${xrayDir}/config.json"
      fi
    '';
    deps = [ ];
  };

  # ── subscription updater (oneshot + daily timer) ──
  systemd.services.xray-sub = {
    description = "Xray Subscription Updater";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "antares";
      Group = "xray";
    };
    script = ''
      set -euo pipefail
      ln -sf "${config.age.secrets.xraySubUrl.path}" "${xrayDir}/sub_url.txt"
      ln -sf "${config.age.secrets.xrayTemplateJson.path}" "${xrayDir}/template.json"
      trap 'rm -f "${xrayDir}/sub_url.txt" "${xrayDir}/template.json"' EXIT
      export XRAY_CONF_DIR="${xrayDir}"
      export XRAY_TEMPLATE="${xrayDir}/template.json"
      ${xray-sub}/bin/xray_sub --headless
    '';
  };

  systemd.timers.xray-sub = {
    description = "Daily Xray Subscription Update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # ── hermes-triggered xray actions (bypasses sandbox sudo restriction) ──
  systemd.services.xray-helper = {
    description = "Xray Action Helper (triggered by hermes)";
    serviceConfig.Type = "oneshot";
    script = ''
      TRIGGER=/home/hermes/.cache/xray-mgr/trigger
      shopt -s nullglob
      for f in "$TRIGGER"/*; do
        action=$(basename "$f")
        case "$action" in
          restart)
            ${pkgs.systemd}/bin/systemctl restart xray
            ;;
          update)
            ${pkgs.systemd}/bin/systemctl start xray-sub
            ;;
          switch:*)
            node="''${action#switch:}"
            ln -sf "$node" "${subsDir}/active.json"
            ${pkgs.systemd}/bin/systemctl restart xray
            ;;
        esac
        rm -f "$f"
      done
    '';
  };

  systemd.paths.xray-helper = {
    description = "Watch for xray trigger files";
    wantedBy = [ "paths.target" ];
    pathConfig = {
      DirectoryNotEmpty = "/home/hermes/.cache/xray-mgr/trigger";
    };
  };

  # ── xray proxy service ──
  systemd.services.xray = {
    description = "Xray Proxy Service";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStartPre = toString (
        pkgs.writeShellScript "xray-ensure-config" ''
          if [ ! -e "${xrayDir}/config.json" ] && [ -e "${subsDir}/active.json" ]; then
            ln -sf "${subsDir}/active.json" "${xrayDir}/config.json"
          fi
        ''
      );
      ExecStart = "${myXray}/bin/xray -c ${xrayDir}/config.json";
      User = "antares";
      Group = "xray";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
