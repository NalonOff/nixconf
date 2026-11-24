{ ... }:
{
  flake.wrappers.firefox = { wlib, pkgs, lib, ... }:
    let
      # Single knob for the browser UI corner radius
      radius = "2px";

      # Catppuccin Mocha Lavender (official AMO theme), pinned by hash
      themeId = "{8446b178-c865-4f5c-8ccc-1d7887811ae3}";
      themeXpi = pkgs.fetchurl {
        url = "https://addons.mozilla.org/firefox/downloads/file/3990315/catppuccin_mocha_lavender_git-2.0.xpi";
        hash = "sha256-cCkrC4ZSy6tAjRXSYdxRUPaQ+1u6+W9OcxclbH2beTM=";
      };

      mkPref = name: value: ''pref("${name}", ${builtins.toJSON value});'';

      prefs = {
        # Native vertical tabs
        "sidebar.verticalTabs" = true;
        "sidebar.revamp" = true;
        "browser.tabs.tabmanager.enabled" = true;
        "browser.toolbars.bookmarks.visibility" = "always";

        "ui.systemUsesDarkTheme" = 1;

        # Privacy
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "privacy.sanitize.sanitizeOnShutdown" = false;

        # Telemetry (the rest is covered by the DisableTelemetry policy)
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;

        # General
        "browser.startup.homepage" = "about:home";
        "browser.newtabpage.enabled" = true;
        "browser.download.useDownloadDir" = false;
        "browser.tabs.loadInBackground" = true;
        "browser.urlbar.suggest.searches" = true;
        "browser.urlbar.suggest.topsites" = false;

        # Security
        "dom.security.https_only_mode" = true;
        "network.dns.disablePrefetch" = true;
        "network.prefetch-next" = false;

        # Desktop integration
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "widget.use-xdg-desktop-portal.mime-handler" = 1;
      };

      # CSS variables overridden with the single radius value
      radiusVars = [
        "--border-radius-circle"
        "--border-radius-xsmall"
        "--border-radius-small"
        "--border-radius-medium"
        "--border-radius-large"
        "--tab-border-radius"
        "--toolbarbutton-border-radius"
        "--panel-border-radius"
      ];

      # Slightly rounded corners in the browser UI (web content is left untouched)
      userChrome = pkgs.writeText "userChrome.css" ''
        @-moz-document url-prefix("chrome://browser/content/browser.xhtml"), url-prefix("about:") {
          :root {
            ${lib.concatMapStringsSep "\n    " (v: "${v}: ${radius} !important;") radiusVars}
          }
          *, *::before, *::after {
            border-radius: ${radius} !important;
          }
        }
      '';

      loadUserChrome = ''
        try {
          let sss = Components.classes["@mozilla.org/content/style-sheet-service;1"]
            .getService(Components.interfaces.nsIStyleSheetService);
          let uri = Services.io.newURI("file://${userChrome}");
          if (!sss.sheetRegistered(uri, sss.USER_SHEET)) {
            sss.loadAndRegisterSheet(uri, sss.USER_SHEET);
          }
        } catch (e) {}
      '';
    in
    {
      imports = [ wlib.modules.default ];

      package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
        extraPrefs = lib.concatStringsSep "\n" (
          lib.mapAttrsToList mkPref prefs ++ [ loadUserChrome ]
        );

        extraPolicies = {
          DisableTelemetry = true;

          ExtensionSettings.${themeId} = {
            installation_mode = "force_installed";
            install_url = "file://${themeXpi}";
          };

          SearchEngines = {
            Default = "DuckDuckGo";
          };
        };
      };

      binName = "firefox";
      exePath = "bin/firefox";
    };
}
