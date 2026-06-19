{
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    claude-code
    cmake
    opencode
  ];
}
