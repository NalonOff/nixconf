{ vars, ... }:
{
  imports = [
    ./boot.nix
    ./network.nix
    ./users.nix
    ./locale.nix
    ./nix-settings.nix
    ./security.nix
    ./tpm.nix
    ./ssh.nix
    ./${vars.gpu}.nix
    ./audio.nix
    ./packages.nix
  ];
}
