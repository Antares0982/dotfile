{
  config,
  lib,
  pkgs,
  hermes-agent-pwa,
  ...
}:
{
  imports = [ hermes-agent-pwa.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    createUser = false;
    user = "pwa";
    group = "pwa";
    stateDir = "/home/pwa";
    workingDirectory = "/home/pwa/workspace";

    environmentFiles = [
      config.age.secrets.pwaEnv.path
    ];

    extraPackages = with pkgs; [
      python3
      uv
      curl
      git
      wget
      fzf
      bat
    ];

    settings = {
      model.context_length = 1000000;
      auxiliary.compression.context_length = 1000000;
      display.busy_input_mode = "steer";
    };
  };

  systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = lib.mkForce "210";

  # systemd PATH includes /run/current-system/sw
  systemd.services.hermes-agent.path = lib.mkBefore [ "/run/current-system/sw" ];

  # Nginx virtualHost for PWA static files + WebSocket proxy
  services.nginx.virtualHosts."pwa.chr.fan" = {
    addSSL = true;
    enableACME = true;
    root = let
      pwaPkg = hermes-agent-pwa.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in "${pwaPkg}/share/hermes-agent/pwa_static";
    locations."/ws" = {
      proxyPass = "http://127.0.0.1:61234";
      proxyWebsockets = true;
    };
    extraConfig = ''
      location = /manifest.json {
        add_header Content-Type application/manifest+json;
      }
      location = /sw.js {
        add_header Service-Worker-Allowed /;
      }
    '';
  };
}
