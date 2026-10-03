{
  config,
  lib,
  pkgs,
  myXray,
  xray-sub,
  ...
}:
let
  xrayDir = "/var/xray";
  xs = (import ../../packages { inherit pkgs myXray; }).xs.override {
    inherit xrayDir;
    configPath = "${xrayDir}/config.json";
    systemdScope = "system";
  };
  lockedXs = pkgs.writeShellApplication {
    name = "xs";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      umask 077
      exec flock ${xrayDir}/update.lock ${xs}/bin/xs "$@"
    '';
  };
  proxyEnv = {
    http_proxy = config.antares.proxy.httpUrl;
    https_proxy = config.antares.proxy.httpUrl;
    HTTP_PROXY = config.antares.proxy.httpUrl;
    HTTPS_PROXY = config.antares.proxy.httpUrl;
    all_proxy = config.antares.proxy.socksUrl;
    ALL_PROXY = config.antares.proxy.socksUrl;
    no_proxy = "localhost,127.0.0.1,::1";
    NO_PROXY = "localhost,127.0.0.1,::1";
  };
in
{
  imports = [ ../../modules/proxy.nix ];
  config = lib.mkMerge [
    (lib.mkIf config.antares.proxy.enable {
      environment.variables = proxyEnv;
      systemd.services.nix-daemon.environment = proxyEnv;
    })
    (lib.mkIf config.services.xray.enable {
      services.xray = {
        package = myXray;
        settingsFile = "${xrayDir}/config.json";
      };
      environment.systemPackages = [ lockedXs ];
      systemd.tmpfiles.rules = [ "d ${xrayDir} 0700 antares users - -" ];
      systemd.services.xray.unitConfig.ConditionPathExists = "${xrayDir}/config.json";
      systemd.services.xray-sub = {
        description = "Xray subscription update";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = [
          "/run/wrappers"
          pkgs.systemd
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "antares";
          Group = "users";
          UMask = "0077";
          TimeoutStartSec = "infinity";
          ExecStart = lib.escapeShellArgs [
            "${pkgs.python3}/bin/python3"
            "${../../resource/xray-update.py}"
            xrayDir
            config.age.secrets.xraySubUrl.path
            config.age.secrets.xrayTemplateJson.path
            "${xray-sub}/bin/xray_sub"
            "${myXray}/bin/xray"
            "${xs}/bin/xs"
          ];
        };
      };
      systemd.timers.xray-sub = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnCalendar = "daily";
          Persistent = true;
        };
      };
      age.secrets = {
        xraySubUrl = {
          file = ../../secrets/xraysub.age;
          owner = "antares";
          mode = "0400";
        };
        xrayTemplateJson = {
          file = ../../secrets/xray-template-gz.age;
          owner = "antares";
          mode = "0400";
        };
      };
    })
  ];
}
