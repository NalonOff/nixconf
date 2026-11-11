{ ... }:
let
  # Catppuccin Mocha
  palette = {
    base = "#1e1e2e";
    text = "#cdd6f4";
    lavender = "#b4befe";
  };
in
{
  flake.wrappers.mako = { wlib, ... }: {
    imports = [ wlib.wrapperModules.mako ];

    settings = {
      font = "FiraCode Nerd Font 12";
      anchor = "top-right";
      width = 360;
      margin = 8;
      padding = 12;
      default-timeout = 5000;

      border-size = 2;
      border-radius = 0;
      background-color = palette.base;
      text-color = palette.text;
      border-color = palette.lavender;

      "urgency=critical".default-timeout = 0;
    };
  };
}
