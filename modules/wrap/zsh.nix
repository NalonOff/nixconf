{ self, ... }:
{
  flake.wrappers.zsh = { wlib, pkgs, lib, ... }:
    let
      starship = self.packages.${pkgs.stdenv.hostPlatform.system}.starship;
      nvim = self.packages.${pkgs.stdenv.hostPlatform.system}.neovim;
    in
    {
      imports = [ wlib.wrapperModules.zsh ];

      skipGlobalRC = true;

      zshAliases = {
        ll = "ls -lah";
        ".." = "cd ..";
        "..." = "cd ../..";
        grep = "grep --color=auto";

        c = "clear";
        n = lib.getExe nvim;

        rbb = ''f() { sudo nixos-rebuild boot --flake "$HOME/nixconf#''${1:-desktop}"; }; f'';
        update = ''nix flake update --flake "$HOME/nixconf" && rbb'';
      };

      zshrc.content = ''
        HISTFILE="$HOME/.zsh_history"
        HISTSIZE=10000
        SAVEHIST=10000
        setopt SHARE_HISTORY HIST_IGNORE_DUPS

        autoload -Uz compinit && compinit

        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        export EDITOR=${lib.getExe nvim}
        export VISUAL=$EDITOR

        ${lib.getExe pkgs.pfetch}

        eval "$(${lib.getExe starship} init zsh)"
      '';
    };
}
