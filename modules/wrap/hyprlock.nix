{ ... }: {
  flake.wrappers.hyprlock = { wlib, ... }: {
    imports = [ wlib.wrapperModules.hyprlock ];

    settings = {
      general.grace = 0;

      background = [
        {
          path = "${../../assets/wallpaper.jpg}";
          blur_passes = 3;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "170, 45";
          rounding = 0;
          outline_thickness = 2;
          dots_size = 0.2;
          dots_spacing = 0.2;
          dots_center = true;
          outer_color = "rgb(180, 190, 254)";
          inner_color = "rgba(100, 114, 125, 0.4)";
          font_color = "rgb(200, 200, 200)";
          font_family = "SF Pro Text Semibold";
          font_size = 12;
          fade_on_empty = true;
          hide_input = false;
          placeholder_text = "🔑 <span foreground=\"##ffffff99\">Enter Password</span>";
          position = "0, -400";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgba(216, 222, 233, 0.70)";
          font_size = 100;
          font_family = "SF Pro Display Bold";
          position = "0, 400";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "cmd[update:60000] date '+%A, %B %d'";
          color = "rgba(216, 222, 233, 0.70)";
          font_size = 20;
          font_family = "SF Pro Display Semibold";
          position = "0, 310";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "$USER";
          color = "rgba(216, 222, 233, 0.70)";
          font_size = 20;
          font_family = "SF Pro Text Semibold";
          position = "0, -335";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
