{ vars, ... }:
{
  # imports = [ ];

  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  home.stateVersion = "26.05"; # DO NOT CHANGE AFTER THE FIRST INSTALLATION
}
