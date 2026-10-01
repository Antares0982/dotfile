{
  config,
  pkgs,
  agenix,
  lib,
  currentDevice,
  ...
}:
let
  isPc = currentDevice.pc;
  isRpi = currentDevice.rpi;
  isHkServer = currentDevice.server.hk or false;
in
{
  environment.systemPackages = [ agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  age = {
    secrets = {
      password = {
        file = ../secrets/password.age;
      };
      serverPassword = {
        file = ../secrets/serverPassword.age;
      };
    }
    # ---- PC only ----
    // lib.optionalAttrs isPc {
      ghToken = {
        file = ../secrets/gh-token.age;
        owner = "antares";
        group = "users";
        mode = "400";
      };
    }
    # ---- RPi only ----
    // lib.optionalAttrs isRpi {
      # Stays root-owned. systemd reads EnvironmentFile= before dropping
      # privileges, so the agent uid never gets read access to the file.
      # The relay's broker credentials, owned by the relay's uid rather than
      # the agent's. F19: the sandbox blocks writes outside cwd but not reads,
      # so anything the agent uid can read, the model can read. Same
      # certificate the (now retired) hermes bridge used.
      # Host, port, vhost and credentials for the relay's broker connection --
      # the retired hermes bridge's values, reused wholesale. Its own file
      # rather than a second owner on hermes-env.age, which carries a good deal
      # more than these five lines.
    }
    # ---- HK server only ----
    // lib.optionalAttrs isHkServer {
    };
    identityPaths = [ "/etc/ssh/agenix" ];
  };
}
