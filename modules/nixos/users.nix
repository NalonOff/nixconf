{ pkgs, lib, vars, ... }:
{
  users.mutableUsers = lib.mkDefault true;

  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
