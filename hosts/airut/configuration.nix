{ config, pkgs, hostname, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = hostname;

  # recommended for virtualized Hetzner hosts
  services.qemuGuest.enable = true;

  system.autoUpgrade = {
    enable = true;
    dates = "daily";
    randomizedDelaySec = "30min";

    flake = "github:your-org/nixos-hetzner#${hostname}";

    operation = "boot";
    allowReboot = true;
    rebootWindow = {
      lower = "01:00";
      upper = "03:00";
    };

    runGarbageCollection = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
