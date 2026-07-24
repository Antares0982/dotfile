{
  description = "macbook (nix-darwin) — per-host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    myXray = {
      url = "github:Antares0982/rules-dat-xray-flake";
      inputs.nixpkgs.follows = "nixpkgs-old";
    };
    renewal = {
      url = "github:Antares0982/renewal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # The mac config is built directly with nix-darwin (it bypasses systemMap.nix),
  # so this output mirrors the darwinConfigurations block of the old root flake.
  outputs =
    inputs@{
      nix-darwin,
      myXray,
      renewal,
      ...
    }:
    let
      currentDevice = import ../../mac.nix;
      mac-system = currentDevice.system;
    in
    {
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        system = mac-system;
        specialArgs = {
          inherit (inputs) self;
          inherit currentDevice;
          myXray = myXray.packages.${mac-system}.default;
          renewal = renewal.packages.${mac-system}.default;
        };
        modules = [
          ../../mac
        ];
      };
    };
}
