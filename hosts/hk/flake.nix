{
  description = "hk (Hong Kong server) — per-host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-compat.url = "github:edolstra/flake-compat";

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
    visitor-badge = {
      url = "github:antares0982/visitor-badge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hugo source for chr.fan. Lives in its own repo so publishing a post does
    # not churn this host's lock file, and so giscus has a public repo to hang
    # its Discussions on.
    blog = {
      url = "github:Antares0982/blog";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    renewal = {
      url = "github:Antares0982/renewal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        git-hooks.follows = "git-hooks";
      };
    };

    # antares-monitor python stack (follows kept to pin against this host's nixpkgs)
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
    nixosConfigurations.hk = import ../../systemMap.nix inputs (import ../../hk.nix);
  };
}
