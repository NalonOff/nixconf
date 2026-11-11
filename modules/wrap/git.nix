{ self, vars, ... }:
{
  flake.wrappers.git =
    {
      wlib,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) neovim;
    in
    {
      imports = [ wlib.wrapperModules.git ];

      settings = {
        user = {
          inherit (vars) email;
          name = vars.fullName;
        };

        core.editor = lib.getExe neovim;
        init.defaultBranch = "main";
        pull.rebase = false;

        url."git@github.com:".insteadOf = "https://github.com/";

        alias = {
          st = "status";
          co = "checkout";
          br = "branch";
          ci = "commit";
          unstage = "reset HEAD --";
          last = "log -1 HEAD";
        };
      };
    };
}
