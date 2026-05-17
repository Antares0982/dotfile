{
  config,
  pkgs,
  renewal,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    claude-code
    cmake
    opencode
  ];
}
