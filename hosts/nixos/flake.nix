{
  description = "nixos (desktop PC) — per-host flake";

  # Only the inputs the PC config actually forces. Its own nixpkgs pin lives
  # here, independent from every other machine's flake.lock.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-26.05";

    # follows helpers, kept only to dedup linyinfeng-nur's transitive inputs
    flake-compat.url = "github:edolstra/flake-compat";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
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
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    myXray = {
      url = "github:Antares0982/rules-dat-xray-flake";
      inputs.nixpkgs.follows = "nixpkgs-old";
    };
    # antares-monitor's uv2nix python stack (follows kept to pin against this
    # host's nixpkgs so the venv build dedups with the rest of the system).
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
        flake-parts.follows = "flake-parts";
      };
    };
  };

  # Shared code lives at the repo root. The whole repo is copied to the store
  # as one source path, so `import ../../<file>` reaches it directly — no
  # `shared` path input needed.
  outputs = inputs: {
    nixosConfigurations.nixos = import ../../systemMap.nix inputs (import ../../pc.nix);
  };
}
