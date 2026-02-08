{
  lib,
  userSettings,
  ...
}:

let
  pubkeys = import ../../modules/pubkeys.nix { inherit lib; };
in
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # basic sane defaults for vms
  boot.loader.grub.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # todo: update to use another global key,
    # like a yubikey
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/wnpQ9j6f5Wqk+jyZHSKxaCp34UMQUDVZlovV2yb3j"
  ];

  users.users.${userSettings.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      # todo: update to use another global key,
      # like a yubikey
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/wnpQ9j6f5Wqk+jyZHSKxaCp34UMQUDVZlovV2yb3j"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  networking.useDHCP = true;

  time.timeZone = "UTC";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  system.stateVersion = "25.11";
}
