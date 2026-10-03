{ config, lib, pkgs, utils, ... }:
let
  # Root block device, derived from the config instead of hardcoded
  rootDev = config.fileSystems."/".device;
  rootUnit = "${utils.escapeSystemdPath rootDev}.device";
in
{
  fileSystems."/persist".neededForBoot = true;

  # Fail at build time (not at boot) if root is not a mapper device
  assertions = [
    {
      assertion = lib.hasPrefix "/dev/mapper/" rootDev;
      message = "impermanence: expected root on /dev/mapper/*, got ${rootDev}";
    }
  ];

  # Wipe @ on every boot (systemd initrd)
  boot.initrd.systemd.initrdBin = [ pkgs.btrfs-progs ];

  boot.initrd.systemd.services.rollback-root = {
    description = "Recreate an empty btrfs @ subvolume";
    wantedBy = [ "initrd.target" ];
    requires = [ rootUnit ];
    after = [ rootUnit ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt
      mount -t btrfs -o subvolid=5 ${rootDev} /mnt

      delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
          delete_subvolume_recursively "/mnt/$i"
        done
        btrfs subvolume delete "$1"
      }

      if [ -e /mnt/@ ]; then
        delete_subvolume_recursively /mnt/@
      fi

      btrfs subvolume create /mnt/@
      umount /mnt
      echo "rollback: done"
    '';
  };

  # --- Selective persistence ---
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"   # keep timer stamps, avoids catch-up runs at every boot
      "/etc/ssh"                  # host keys, needed by sops.age.sshKeyPaths
      "/var/lib/NetworkManager"
    ];

    files = [
      "/etc/machine-id"
    ];
  };
}
