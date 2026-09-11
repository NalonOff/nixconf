{ ... }:
{
  virtualisation.vmVariant = {
    virtualisation.sharedDirectories.sopskeys = {
      source = "/var/lib/sops-nix";
      target = "/var/lib/sops-nix";
    };
  };
}
