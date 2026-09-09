{
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    codex
    cmake
    opencode
  ];
}
