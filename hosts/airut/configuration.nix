{ lib, hostname, userSettings, ... }:

let
  pubkeys = import ../../modules/pubkeys.nix { inherit lib; };
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/motd.nix
  ];

  motd.dockerCompose.stacks = [
    { name = "Airut"; path = "~/airut"; }
  ];

  services.qemuGuest.enable = true;

  users.users.${userSettings.username}.openssh.authorizedKeys.keys = pubkeys.readAll ./.;

  networking.interfaces.enp1s0.ipv6.addresses = [
    {
      address = "2a01:4f9:c013:f4c0::1";
      prefixLength = 64;
    }
  ];
}
