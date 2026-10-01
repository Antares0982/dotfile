{ pkgs, agenix, ... }:
{
  environment.systemPackages = [ agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  age = {
    identityPaths = [ "/etc/ssh/agenix" ];
    secrets = {
      password.file = ../secrets/password.age;
      serverPassword.file = ../secrets/serverPassword.age;
    };
  };
}
