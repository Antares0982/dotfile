{
  config,
  lib,
  pkgs,
  hermes-agent-pwa,
  ...
}:
{
  imports = [ hermes-agent-pwa.nixosModules.default ];

  nix.settings = {
    substituters = [
      "https://hermes-agent.cachix.org"
    ];
    trusted-public-keys = [
      "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
    ];
  };

  services.hermes-agent = {
    enable = true;
    createUser = false;
    user = "pwa";
    group = "users";
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
      agent.disabled_toolsets = [
        "terminal" "file" "code_execution" "skills"
        "image_gen" "video_gen" "video" "tts"
        "homeassistant" "kanban" "computer_use"
        "discord" "discord_admin" "yuanbao"
        "feishu_doc" "feishu_drive" "spotify"
        "moa" "x_search"
      ];
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
