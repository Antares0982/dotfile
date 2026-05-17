{ ... }:
{
  imports = [
    ../common/ssh.nix
  ];
  programs.ssh.startAgent = true;
}
