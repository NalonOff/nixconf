{ self, ... }:
{
  flake.wrappers.kitty = { wlib, pkgs, lib, ... }:
    let
      zsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh;
    in
    {
      imports = [ wlib.wrapperModules.kitty ];

      themeFile = "Catppuccin-Mocha";
      font = {
        name = "FiraCode Nerd Font";
        size = 12;
      };

      settings = {
        shell = lib.getExe zsh;
        background_opacity = 0.9;
        cursor_shape = "beam";
        cursor_blink_interval = 0;
        scrollback_lines = 10000;
        enable_audio_bell = false;
        confirm_os_window_close = 0;
      };
    };
}
