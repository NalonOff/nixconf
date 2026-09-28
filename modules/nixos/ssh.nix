{ config, pkgs, lib, ... }:
{
  # SSH client config (system-wide)
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github.com
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519
        IdentitiesOnly yes

      Host *
        ServerAliveInterval 60
        ServerAliveCountMax 3
        ControlMaster auto
        # Requires: mkdir -p ~/.ssh/sockets
        ControlPath ~/.ssh/sockets/%r@%h:%p
        ControlPersist 600
        PasswordAuthentication no
        PubkeyAuthentication yes
    '';
  };

  # SSH server config (system-wide). Host keys also feed sops-nix (age identity).
  services.openssh = {
    enable = true;
    openFirewall = lib.mkDefault false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
