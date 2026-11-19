{ ... }:
{
  flake.wrappers.spotify = { wlib, pkgs, ... }:
    let
      # Pinned by hand, no flake input
      spicetify = import (builtins.fetchGit {
        url = "https://github.com/Gerg-L/spicetify-nix";
        rev = "13e6fed4eb99f809d390fb50f591bed6cb716dc0";
      }) { inherit pkgs; };

      spicePkgs = spicetify.packages;
    in
    {
      imports = [ wlib.modules.default ];

      package = spicetify.lib.mkSpicetify pkgs {
        wayland = true;

        theme = spicePkgs.themes.catppuccin;
        colorScheme = "mocha";

        enabledExtensions = with spicePkgs.extensions; [
          adblockify
          featureShuffle
          history
          volumePercentage
        ];

        enabledCustomApps = with spicePkgs.apps; [
          newReleases
        ];

        enabledSnippets = with spicePkgs.snippets; [
          removeGradient

          # Hide the theme's equalizer gif
          ''
            :root .view-homeShortcutsGrid-equaliser,
            :root .main-trackList-playingIcon {
              background-image: none !important;
            }
          ''
        ];
      };

      binName = "spotify";
      exePath = "bin/spotify";
    };
}
