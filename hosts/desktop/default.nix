{ inputs, config, vars, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./impermanence.nix
  ];

  users.mutableUsers = false;
  users.users.${vars.username}.hashedPasswordFile = "/persist/secrets/${vars.username}.hash";

  system.stateVersion = "26.05"; # DO NOT TOUCH IT AFTER THE FIRST INSTALLATION
}
