{ ... }:
{
  imports = [
    ../../server
    ../../server/gz
  ];
  networking.hostName = "gz";
  environment.etc."zsh/p10k.zsh".source = ../../resource/hk-p10k.zsh;
  system.stateVersion = "26.11";
}
