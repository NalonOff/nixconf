{ ... }:
{
  imports = [
    ./boot.nix
    ./network.nix
    ./users.nix
    ./locale.nix
    ./nix-settings.nix
    ./security.nix
  ];
}
