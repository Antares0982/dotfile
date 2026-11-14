{
  description = "rpi5 (Raspberry Pi 5) — per-host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # RPi keeps nixos-raspberrypi's own nixpkgs (only flake-compat is followed),
    # matching the original root flake.
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.flake-compat.follows = "flake-compat";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    napcat-nix = {
      url = "github:Antares0982/napcat.nix/ddeb30e659ef9e45c702def65feb36c6bfa22f9c";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    simple-moderation = {
      url = "github:Antares0982/simple-moderation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qq-codex-agent = {
      url = "github:Antares0982/qq-codex-agent";
      flake = false;
    };
    antares-monitor = {
      url = "github:antares0982/telegram-output-monitor-bot";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        pyproject-build-systems.follows = "pyproject-build-systems";
      };
    };
    antares-rpc-client = {
      url = "github:antares0982/antares-rpc-client";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    renewal = {
      url = "github:Antares0982/renewal";
      inputs.nixpkgs.follows = "nixpkgs";
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
  };

  outputs = inputs: {
    nixosConfigurations.rpi5 =
      (import ../../systemMap.nix inputs (import ../../rpi5.nix)).extendModules
        {
          modules = [ ./configuration.nix ];
        };
  };
}
