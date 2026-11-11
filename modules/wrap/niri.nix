{ self, ... }:
{
  flake.wrappers.niri = { wlib, pkgs, lib, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      inherit (self.packages.${system}) kitty rofi waybar mako hyprlock;

      wpctl = lib.getExe' pkgs.wireplumber "wpctl";
      wlCopy = lib.getExe' pkgs.wl-clipboard "wl-copy";
      wlPaste = lib.getExe' pkgs.wl-clipboard "wl-paste";
      cliphist = lib.getExe pkgs.cliphist;
      polkitAgent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      wallpaper = ../../assets/wallpaper.jpg;

      cursorPackage = pkgs.posy-cursors;
      cursorTheme = "Posy_Cursor";

      # Argument-less niri node
      flag = _: { };

      # Bind with extra properties (omitted when empty)
      bind = props: content: _:
        { inherit content; } // lib.optionalAttrs (props != { }) { inherit props; };

      whenLocked = bind { allow-when-locked = true; };
      # Cooldown so one scroll notch doesn't skip several workspaces
      onWheel = bind { cooldown-ms = 150; };
      plain = bind { };

      # Turn { "Key" = "action"; } into { "Key" = wrap { action = flag; }; }
      flagBindsWith = wrap: lib.mapAttrs (_: action: wrap { ${action} = flag; });
      flagBinds = flagBindsWith lib.id;

      exeCmd = pkg: args: [ (lib.getExe pkg) ] ++ args;
      sh = script: [ "${pkgs.bash}/bin/bash" "-c" script ];

      sink = "@DEFAULT_AUDIO_SINK@";
      wpctlLocked = args: whenLocked { spawn = [ wpctl ] ++ args; };

      # Keep wallpaper and waybar hidden until hyprlock is up
      delayed = cmd: sh "sleep 1 && exec ${cmd}";

      workspaceIds = lib.range 1 4;

      workspaceBinds = lib.listToAttrs (lib.concatMap (n: [
        { name = "Mod+${toString n}";       value.focus-workspace = n; }
        { name = "Mod+Shift+${toString n}"; value.move-column-to-workspace = n; }
      ]) workspaceIds);

      appBinds = {
        "Mod+Return".spawn = exeCmd kitty [ ];
        "Mod+R".spawn = exeCmd rofi [ "-show" "drun" ];
        "Mod+L".spawn = exeCmd hyprlock [ ];
      };

      clipboardBinds = {
        "Mod+V".spawn = sh "${cliphist} list | ${lib.getExe rofi} -dmenu | ${cliphist} decode | ${wlCopy}";
      };

      sessionBinds = flagBinds {
        "Mod+Q" = "close-window";
        "Mod+Shift+E" = "quit";
        "Mod+Shift+Slash" = "show-hotkey-overlay";
        "Mod+Tab" = "toggle-overview";
      };

      screenshotBinds = flagBinds {
        "Mod+S" = "screenshot";
        "Mod+Shift+S" = "screenshot-screen";
        "Mod+Ctrl+S" = "screenshot-window";
      };

      focusBinds = flagBinds {
        "Mod+Left" = "focus-column-left";
        "Mod+Right" = "focus-column-right";
        "Mod+Up" = "focus-window-up";
        "Mod+Down" = "focus-window-down";
        "Mod+Home" = "focus-column-first";
        "Mod+End" = "focus-column-last";
        "Mod+Page_Down" = "focus-workspace-down";
        "Mod+Page_Up" = "focus-workspace-up";
      };

      windowBinds = flagBinds {
        "Mod+Shift+Left" = "move-column-left";
        "Mod+Shift+Right" = "move-column-right";
        "Mod+Shift+Up" = "move-window-up";
        "Mod+Shift+Down" = "move-window-down";
        "Mod+Shift+Home" = "move-column-to-first";
        "Mod+Shift+End" = "move-column-to-last";
        "Mod+Shift+Page_Down" = "move-column-to-workspace-down";
        "Mod+Shift+Page_Up" = "move-column-to-workspace-up";
        "Mod+Comma" = "consume-or-expel-window-left";
        "Mod+Period" = "consume-or-expel-window-right";
        "Mod+D" = "switch-preset-column-width";
        "Mod+C" = "center-column";
        "Mod+F" = "maximize-column";
        "Mod+Shift+F" = "fullscreen-window";
      } // {
        "Mod+Minus".set-column-width = "-10%";
        "Mod+Equal".set-column-width = "+10%";
      };

      floatingBinds = flagBinds {
        "Mod+Space" = "toggle-window-floating";
        "Mod+Shift+Space" = "switch-focus-between-floating-and-tiling";
      };

      monitorBinds = flagBinds {
        "Mod+Ctrl+Left" = "focus-monitor-left";
        "Mod+Ctrl+Right" = "focus-monitor-right";
        "Mod+Ctrl+Shift+Left" = "move-column-to-monitor-left";
        "Mod+Ctrl+Shift+Right" = "move-column-to-monitor-right";
      };

      wheelBinds =
        flagBindsWith onWheel {
          "Mod+WheelScrollDown" = "focus-workspace-down";
          "Mod+WheelScrollUp" = "focus-workspace-up";
          "Mod+Ctrl+WheelScrollDown" = "move-column-to-workspace-down";
          "Mod+Ctrl+WheelScrollUp" = "move-column-to-workspace-up";
        }
        // flagBindsWith plain {
          "Mod+WheelScrollRight" = "focus-column-right";
          "Mod+WheelScrollLeft" = "focus-column-left";
          "Mod+Shift+WheelScrollDown" = "focus-column-right";
          "Mod+Shift+WheelScrollUp" = "focus-column-left";
        };

      mediaBinds = {
        "XF86AudioRaiseVolume" = wpctlLocked [ "set-volume" sink "0.05+" ];
        "XF86AudioLowerVolume" = wpctlLocked [ "set-volume" sink "0.05-" ];
        "XF86AudioMute" = wpctlLocked [ "set-mute" sink "toggle" ];
      };
    in
    {
      imports = [ wlib.wrapperModules.niri ];

      settings = {
        prefer-no-csd = flag;
        hotkey-overlay.skip-at-startup = flag;
        input.keyboard.xkb.layout = "us";
        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
        workspaces = lib.genAttrs (map toString workspaceIds) (_: flag);

        screenshot-path = "~/Images/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

        cursor = {
          xcursor-theme = cursorTheme;
          xcursor-size = 24;
        };

        outputs."DP-1" = {
          mode = "1920x1080";
        };

        environment = {
          # Electron/Chromium apps in native Wayland
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          GTK_THEME = "Adwaita:dark";
          XCURSOR_PATH = "${cursorPackage}/share/icons";
        };

        layout = {
          gaps = 8;
          background-color = "#000000";
          focus-ring.off = flag;
          border = {
            width = 2;
            active-color = "#b4befe";
            inactive-color = "#313244";
          };
          default-column-width.proportion = 0.5;
          preset-column-widths = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];
        };

        window-rules = [
          {
            matches = [
              { app-id = "^(pinentry.*|polkit-gnome-authentication-agent-1)$"; }
              { title = "^Picture-in-Picture$"; }
            ];
            open-floating = true;
          }
        ];

        spawn-at-startup = [
          (exeCmd hyprlock [ ])
          [ polkitAgent ]
          # Export the Wayland session to systemd/dbus so portals work
          [ (lib.getExe' pkgs.dbus "dbus-update-activation-environment") "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" ]
          [ wlPaste "--type" "text" "--watch" cliphist "store" ]
          [ wlPaste "--type" "image" "--watch" cliphist "store" ]
          (delayed "${pkgs.swaybg}/bin/swaybg -i ${wallpaper} -m fill")
          (delayed (lib.getExe waybar))
          (exeCmd mako [ ])
        ];

        binds =
          appBinds
          // clipboardBinds
          // sessionBinds
          // screenshotBinds
          // focusBinds
          // windowBinds
          // floatingBinds
          // monitorBinds
          // mediaBinds
          // workspaceBinds
          // wheelBinds;
      };
    };
}
