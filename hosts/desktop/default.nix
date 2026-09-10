{ inputs, config, vars, ... }:
{
  imports = [
    ../../modules/nixos
    ./hardware-configuration.nix
  ];

  home-manager.users.${vars.username} = import ../../modules/home;

  system.stateVersion = "26.05"; # DO NOT TOUCH IT AFTER THE FIRST INSTALLATION
}
