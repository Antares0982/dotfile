{
  description = "PC NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/release-26.05";
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
    hermes-agent = {
      url = "github:Antares0982/hermes-agent/antares";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        pyproject-build-systems.follows = "pyproject-build-systems";
        npm-lockfile-fix.follows = "npm-lockfile-fix";
      };
    };
    linyinfeng-nur = {
      url = "github:linyinfeng/nur-packages";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixos-stable.follows = "nixpkgs-old";
        flake-parts.follows = "flake-parts";
      };
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
      };
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
      };
    };
    npm-lockfile-fix = {
      url = "github:jeslie0/npm-lockfile-fix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      hermes-agent,
      nixos-raspberrypi,
      linyinfeng-nur,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systemMap = import ./systemMap.nix (
        input
        // {
          inherit lib;
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
