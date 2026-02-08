{ lib, hostname, userSettings, ... }:

let
  pubkeys = import ../../modules/pubkeys.nix { inherit lib; };
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = hostname;
  services.qemuGuest.enable = true;

  users.users.${userSettings.username}.openssh.authorizedKeys.keys = pubkeys.readAll ./.;

  system.autoUpgrade = {
    enable = true;
    dates = "02:35";
    randomizedDelaySec = "30min";

    flake = "github:sakuexe/nixos_cloud#${hostname}";

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
    options = "--delete-older-than 7d";
  };
}
