{ ... }:
{
  boot.initrd.availableKernelModules = [ "tpm_tis" ];
  security.tpm2.enable = true;
}
