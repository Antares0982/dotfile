{
  description = "macbook (nix-darwin) — per-host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
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
