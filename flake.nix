{
  description = "PC NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-utils.url = "github:numtide/flake-utils";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    myXray = {
      url = "github:Antares0982/rules-dat-xray-flake";
      inputs.nixpkgs.follows = "nixpkgs-old";
    };
    wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antares-monitor = {
      url = "github:antares0982/telegram-output-monitor-bot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antares-rpc-client = {
      url = "github:antares0982/antares-rpc-client";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    visitor-badge = {
      url = "github:antares0982/visitor-badge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
    };
    pull-all = {
      url = "github:Antares0982/pull-all";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    renewal = {
      url = "github:Antares0982/renewal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    linyinfeng-nur = {
      url = "github:linyinfeng/nur-packages";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixos-stable.follows = "nixpkgs-old";
      };
    };
    hermes-agent = {
      url = "github:nousresearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-antares-bridge = {
      url = "github:Antares0982/hermes-antares-bridge";
    };
  };

  outputs =
    input@{
      self,
      nixpkgs,
      nixpkgs-old,
      # nixpkgs-for-chrome,
      nix-darwin,
      home-manager,
      agenix,
      myXray,
      wsl,
      vscode-server,
      rust-overlay,
      antares-monitor,
      antares-rpc-client,
      visitor-badge,
      pull-all,
      renewal,
      nixos-raspberrypi,
      linyinfeng-nur,
      hermes-agent,
      hermes-antares-bridge,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systemMap = import ./systemMap.nix (
        input
        // {
          inherit lib;
          inherit hermes-agent hermes-antares-bridge;
        }
      );
    in
    {
      nixosConfigurations = {
        nixos = systemMap (import ./pc.nix);
        hk = systemMap (import ./hk.nix);
        rpi5 = systemMap (import ./rpi5.nix);
        wsl = systemMap (import ./wsl.nix);
      };
      darwinConfigurations =
        let
          macDevice = import ./mac.nix;
          mac-system = macDevice.system;
        in
        {
          macbook = nix-darwin.lib.darwinSystem {
            system = mac-system;
            specialArgs = {
              inherit self;
              currentDevice = macDevice;
              myXray = myXray.packages.${mac-system}.default;
              renewal = renewal.packages.${mac-system}.default;
            };
            modules = [
              ./mac
            ];
          };
        };
    };
}
