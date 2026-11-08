{
  description = "gz (Guangzhou server) per-host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    l4d2-plugins = {
      url = "github:Antares0982/l4d2-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations.gz = (import ../../systemMap.nix inputs (import ../../gz.nix)).extendModules {
      modules = [
        inputs.disko.nixosModules.disko
        ./configuration.nix
      ];
    };
  };
}
