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
  xrayTemplate = ./xray-template.json;
in
{
  # ── shared group for xray management ──
  users.groups.xray = {
    members = [ "antares" "hermes" ];
  };

  # ── directories, template symlink ──
  systemd.tmpfiles.rules = [
    "d ${xrayDir} 0775 root xray - -"
    "d ${subsDir} 0775 root xray - -"
    "L+ ${xrayDir}/template.json - - - - ${xrayTemplate}"
  ];

  # ── migrate old config.json to subscription-based symlink ──
  system.activationScripts.xrayMigrate = {
    text = ''
      [ -d "${subsDir}" ] || exit 0

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
      trap 'rm -f "${xrayDir}/sub_url.txt"' EXIT
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
