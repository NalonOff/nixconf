{ ... }:
{
  flake.wrappers.rofi = { wlib, ... }:
    let
      # Unquoted Rasi value (colors, sizes, @var references)
      lit = value: { _type = "literal"; inherit value; };
    in
    {
      imports = [ wlib.wrapperModules.rofi ];

      settings = {
        modi = "drun,run";
        show-icons = true;
        font = "FiraCode Nerd Font 12";
        display-drun = "Apps";
        display-run = "Run";
      };

      theme = {
        "*" = {
          bg = lit "#1e1e2e";
          bg-alpha = lit "#1e1e2ee6"; # #1e1e2e à 90 % (comme kitty)
          fg = lit "#cdd6f4";
          accent = lit "#b4befe";
          # Surcouches très transparentes : posées sur le fond de la fenêtre (déjà à 90 %),
          # elles ne le rendent presque pas plus opaque (0.9 -> ~0.91)
          select-overlay = lit "#b4befe33"; # accent à 20 %, pour la sélection / hover
          background-color = lit "transparent";
          text-color = lit "@fg";
        };

        window = {
          width = lit "500px";
          background-color = lit "@bg-alpha";
          border = lit "2px";
          border-color = lit "@accent";
        };

        mainbox.padding = lit "12px";
        inputbar = {
          background-color = lit "transparent"; # laisse voir le fond de la fenêtre
          padding = lit "8px";
          border = lit "2px";
          border-color = lit "@accent";
          spacing = lit "8px";
        };
        listview = {
          lines = 8;
          margin = lit "12px 0 0 0";
          scrollbar = false;
        };
        element = {
          padding = lit "8px";
          spacing = lit "8px";
          # bordure invisible au repos : évite que la liste "saute" quand la sélection change
          border = lit "2px";
          border-color = lit "transparent";
        };
        "element selected" = {
          background-color = lit "@select-overlay";
          text-color = lit "@accent";
          border = lit "2px";
          border-color = lit "@accent";
        };

        # "*" fixe text-color sur tous les widgets : sans ceci, le texte
        # de l'entrée sélectionnée pourrait garder @fg au lieu de l'accent
        element-text = {
          background-color = lit "transparent";
          text-color = lit "inherit";
          vertical-align = lit "0.5";
        };
        element-icon = {
          size = lit "32px";
          background-color = lit "transparent";
        };
      };
    };
}
