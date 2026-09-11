{ config, pkgs, lib, vars,... }:
{
  users.mutableUsers = lib.mkDefault true;

  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    shell = pkgs.zsh;

    hashedPasswordFile = config.sops.secrets."password-hash".path;
  };

  programs.zsh.enable = true;
}
