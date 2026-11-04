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
  };

  outputs = inputs @ { self, nixpkgs, disko, impermanence, ... }:
    let
      system = "x86_64-linux";
      vars = import ./vars.nix;

      mkHost = hostname:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs vars; };
          modules = [
            ./hosts/${hostname}
            ./modules/nixos
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            { networking.hostName = hostname; }
          ];
        };
    in
    {
      nixosConfigurations = {
        desktop = mkHost "desktop";
      };
    };
}
