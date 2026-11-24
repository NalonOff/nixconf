{ ... }:
{
  flake.wrappers.discord = { wlib, pkgs, lib, ... }:
    let
      colors = lib.mapAttrs (_: c: c.hex)
        (lib.importJSON "${pkgs.catppuccin.override { themeList = [ "palette" ]; }}/palette/palette.json").mocha.colors;

      # variables Discord forcées sur le fond de base
      baseVars = [
        "app-frame-background"
        "background-base-lowest"
        "background-base-lower"
        "background-base-low"
        "background-secondary-alt"
        "bg-surface-raised"
        "background-gradient-highest"
      ];
      cssVars = lib.genAttrs baseVars (_: colors.base) // {
        input-background-default = colors.surface0;
      };
      cssDecls = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: hex: "  --${name}: ${hex} !important;") cssVars
      );

      # read-only data dir: settings and quick CSS come from the store
      vencordData = pkgs.linkFarm "vencord-data" {
        "settings/settings.json" = pkgs.writeText "settings.json" (builtins.toJSON {
          autoUpdate = false;
          notifyAboutUpdates = false;
          useQuickCss = true;
          themeLinks = [ "https://catppuccin.github.io/discord/dist/catppuccin-mocha-lavender.theme.css" ];
          plugins = lib.genAttrs [ "FakeNitro" "MessageLogger" "ImageZoom" ] (_: { enabled = true; });
        });
        "settings/quickCss.css" = pkgs.writeText "quickCss.css" ''
          .visual-refresh.theme-dark.theme-dark,
          .visual-refresh .theme-dark.theme-dark {
          ${cssDecls}
          }
        '';
        themes = pkgs.emptyDirectory;
      };
    in
    {
      imports = [ wlib.modules.default ];

      package = pkgs.discord.override { withVencord = true; };
      binName = "discord";
      exePath = "bin/discord";

      env = {
        VENCORD_USER_DATA_DIR = "${vencordData}";
        NIXOS_OZONE_WL = "1";
      };
    };
}
