{ ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-CT1000P3PSSD8_2250E6922EC1";

      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          luks = {
            size = "100%";
            content = {
              # LUKS2 container wrapping the whole btrfs volume.
              # Formatted with a passphrase first; TPM2 is enrolled
              # afterwards via systemd-cryptenroll (passphrase kept as fallback).
              type = "luks";
              name = "cryptroot";
              extraOpenArgs = [ "--allow-discards" ]; # needed for SSD TRIM
              settings = {
                crypttabExtraOpts = [ "tpm2-device=auto" ];
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # force, useful for repeated installations
                subvolumes = {
                  # System root, mounted on /
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  # /home separated from root
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  # /nix separated: the store doesn't need to be in the
                  # same snapshots as the rest of the system
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
