{
  lib,
  userSettings,
  ...
}:

let
  pubkeys = import ../../modules/pubkeys.nix { inherit lib; };
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./uptime-monitoring.nix
    ../../modules/motd.nix
  ];

  services.qemuGuest.enable = true;
  users.users.${userSettings.username}.openssh.authorizedKeys.keys = pubkeys.readAll ./.;

  networking.interfaces.enp1s0.ipv6.addresses = [
    {
      address = "2a01:4f9:c014:750f::1";
      prefixLength = 64;
    }
  ];

  # 8 GiB swapfile, created on first activation
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024; # MiB
    }
  ];
}
