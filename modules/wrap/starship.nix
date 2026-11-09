{ ... }:
{
  flake.wrappers.starship = { wlib, ... }: {
    imports = [ wlib.wrapperModules.starship ];

    settings.add_newline = false;
  };
}
