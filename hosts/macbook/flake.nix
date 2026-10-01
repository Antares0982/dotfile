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

  outputs =
    inputs:
    let
      currentDevice = import ../../mac.nix;
    in
    {
      darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
        system = currentDevice.system;
        specialArgs = {
          inherit inputs currentDevice;
          inherit (inputs) self;
        };
        modules = [ ./configuration.nix ];
      };
    };
}
