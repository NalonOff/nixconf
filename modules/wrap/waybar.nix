{ self, ... }:
{
  flake.wrappers.waybar =
    { wlib, pkgs, lib, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      inherit (self.packages.${system}) rofi hyprlock;

      # Builds a Nerd Font glyph from its hex code point, avoiding invisible
      # characters in the file. Code points outside the BMP (nf-md-*) must be
      # encoded as a surrogate pair for JSON parsing.
      glyph =
        hex:
        let
          cp = lib.fromHexString hex;
          v = cp - 65536;
          unit = n: "\\u${lib.fixedWidthString 4 "0" (lib.toHexString n)}";
          escaped = if cp < 65536 then unit cp else unit (55296 + v / 1024) + unit (56320 + lib.mod v 1024);
        in
        builtins.fromJSON ''"${escaped}"'';

      icons = {
        nixos = glyph "f313";
        cpu = glyph "f061a";
        memory = glyph "efc5";
        wifi = glyph "f05a9";
        ethernet = glyph "f0200";
        networkOff = glyph "f0c9b";
        volumeMuted = glyph "f075f";
        headphone = glyph "f02cb";
        volume = map glyph [
          "f057f"
          "f0580"
          "f057e"
        ];
        play = glyph "f040a";
        pause = glyph "f03e4";
        stop = glyph "f04db";
        spotify = glyph "f04c7";
        firefox = glyph "f0239";
        vlc = glyph "f057c";
        player = glyph "f0386";
      };

      # Catppuccin Mocha
      colors = {
        base = "#1e1e2e";
        text = "#cdd6f4";
        accent = "#b4befe";
        surface = "#313244";
        muted = "#6c7086";
      };

      # Keep in sync with the system font
      font = "FiraCode Nerd Font";

      borderStyle = "2px solid ${colors.accent}";
      modulePadding = "0 12px";
      iconModules = "#cpu, #memory, #pulseaudio, #network";

      playerctl = cmd: "${lib.getExe pkgs.playerctl} ${cmd}";

      statModule = icon: field: {
        format = "${icon} {${field}}%";
        interval = 5;
      };
    in
    {
      imports = [ wlib.wrapperModules.waybar ];

      settings = {
        layer = "top";
        position = "top";
        height = 32;
        exclusive = true;
        margin-top = 8;
        margin-left = 8;
        margin-right = 8;

        modules-left = [
          "custom/nixos"
          "niri/workspaces"
          "mpris"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "cpu"
          "memory"
          "pulseaudio"
          "network"
        ];

        "custom/nixos" = {
          format = icons.nixos;
          tooltip = false;
          on-click = "${lib.getExe rofi} -show drun";
          on-click-right = lib.getExe hyprlock;
        };

        "niri/workspaces".format = "{index}";

        mpris = {
          format = "{player_icon} {dynamic}";
          format-paused = "{status_icon} {dynamic}";
          player-icons = {
            default = icons.player;
            inherit (icons) spotify firefox vlc;
          };
          status-icons = {
            playing = icons.play;
            paused = icons.pause;
            stopped = icons.stop;
          };
          dynamic-order = [
            "title"
            "artist"
          ];
          dynamic-separator = " - ";
          dynamic-len = 40;
          tooltip-format = "{player}: {dynamic}";
          on-click = playerctl "play-pause";
          on-click-right = playerctl "next";
          on-scroll-up = playerctl "previous";
          on-scroll-down = playerctl "next";
        };

        clock = {
          format = "{:%H:%M}";
          tooltip-format = "{:%A %d %B %Y}";
        };

        tray = {
          icon-size = 16;
          spacing = 8;
        };

        cpu = statModule icons.cpu "usage";
        memory = statModule icons.memory "percentage";

        pulseaudio = {
          format = "{icon}";
          format-muted = icons.volumeMuted;
          format-icons = {
            headphone = icons.headphone;
            default = icons.volume;
          };
          max-volume = 150;
          scroll-step = 5;
          tooltip-format = "{desc}\n{volume}%";
          on-click = lib.getExe pkgs.pavucontrol;
          on-click-right = "${lib.getExe pkgs.pamixer} -t";
        };

        # Waybar picks Wi-Fi or Ethernet automatically
        network = {
          format-wifi = icons.wifi;
          format-ethernet = icons.ethernet;
          format-disconnected = icons.networkOff;
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}";
          tooltip-format-disconnected = "Déconnecté";
        };
      };

      "style.css".content = ''
        * {
          font-family: "${font}", "Symbols Nerd Font";
          font-size: 12pt;
          font-weight: 600;
          border: none;
          border-radius: 0;
          box-shadow: none;
          text-shadow: none;
          min-height: 0;
        }

        tooltip {
          background: ${colors.base};
          border: ${borderStyle};
        }

        tooltip label {
          color: ${colors.text};
        }

        menu {
          background: ${colors.base};
          color: ${colors.text};
          border: ${borderStyle};
          padding: 4px;
        }

        menuitem {
          padding: 4px 12px;
          background: transparent;
        }

        menuitem:hover {
          background: ${colors.surface};
          color: ${colors.accent};
        }

        menuitem:disabled {
          color: ${colors.muted};
        }

        menu separator {
          background: ${colors.surface};
          min-height: 2px;
          margin: 4px 0;
        }

        window#waybar {
          background: transparent;
        }

        window#waybar > box {
          background: ${colors.base};
          color: ${colors.text};
          border: ${borderStyle};
        }

        #custom-nixos, #workspaces button, #mpris, #clock, ${iconModules}, #tray {
          padding: ${modulePadding};
          margin: 0;
          min-width: 0;
        }

        #workspaces button {
          color: ${colors.muted};
          background: transparent;
        }

        #workspaces button.active {
          color: ${colors.accent};
          background: ${colors.surface};
        }

        #pulseaudio.muted {
          color: ${colors.muted};
        }

        #mpris.paused {
          color: ${colors.muted};
        }

        #custom-nixos:hover, #pulseaudio:hover, #network:hover, #mpris:hover {
          background: ${colors.surface};
        }
      '';
    };
}
