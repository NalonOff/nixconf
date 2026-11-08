{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    wget
    curl
    unzip
    zip
    tree
    btop
    jq
    bat
    eza
    fzf

    pciutils
    usbutils
    lshw
    gcc
  ];
}
