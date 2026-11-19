{
  description = "Declarative NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrappers = {
      url = "github:nix-community/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:denful/import-tree";
  };

  outputs = inputs @ { nixpkgs, flake-parts, import-tree, wrappers, disko, impermanence, ... }:
    let
      system = "x86_64-linux";
      vars = import ./vars.nix;

      # Single nixpkgs instance shared by the wrappers and the system
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkHost = hostname:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs vars; };
          modules = [
            ./hosts/${hostname}
            ./modules/nixos
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            {
              networking.hostName = hostname;
              nixpkgs.pkgs = pkgs;
            }
          ];
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; specialArgs = { inherit vars; }; } {
      imports = [
        wrappers.flakeModules.wrappers
        (import-tree ./modules/wrap)
      ];

      systems = [ system ];

      perSystem = _: {
        _module.args.pkgs = pkgs;
        wrappers.pkgs = pkgs;
      };

      flake.nixosConfigurations = {
        desktop = mkHost "desktop";
      };
    };
}
