{ inputs, config, vars, ... }:
{
  imports = [
    ../../modules/nixos
    ./hardware-configuration.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets/user-password.yaml;
    age.keyFile = "/var/lib/sops-nix/keys.txt";

    secrets."password-hash" = {
      neededForUsers = true;
    };
  };

  users.mutableUsers = false;
  users.users.${vars.username}.hashedPasswordFile = config.sops.secrets."password-hash".path;

  home-manager.users.${vars.username} = import ../../modules/home;

  system.stateVersion = "26.05"; # DO NOT TOUCH IT AFTER THE FIRST INSTALLATION
}
