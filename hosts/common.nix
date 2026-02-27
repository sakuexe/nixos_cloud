{
  userSettings,
  hostname,
  pkgs,
  ...
}:

{
  imports = [
    ../modules/docker.nix
    ../modules/shell.nix
    ../modules/ssh.nix
    ../modules/motd.nix
  ];

  networking.hostName = hostname;

  # a backup, os level firewall if one is
  # not set in the hetzner dashboard
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      2001
    ];
  };

  # ipv6 support for hetzner
  networking.enableIPv6 = true;
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "enp1s0";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # basic sane defaults for vms
  boot.loader.grub.enable = true;
  boot.kernel.sysctl = {
    # allow exposing of port 80 and above
    "net.ipv4.ip_unprivileged_port_start" = 80;
  };

  users.users.${userSettings.username} = {
    isNormalUser = true;
    # keeps the user processes running
    # even when not logged in
    # (needed for rootless docker to work)
    linger = true;
    extraGroups = [
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      # todo: add a global authorization key between all vms
      # like a yubikey or something
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzNnTuvUw8pHAXIVOUISHCVfKlMTbNTwrLhazYC65vl"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  networking.useDHCP = true;

  time.timeZone = "UTC";

  # btw
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git.enable = true;
  programs.git.config = {
    user.name = userSettings.username;
    user.email = userSettings.email;
  };

  motd.enable = true;

  environment.systemPackages = with pkgs; [
    btop
  ];

  system.autoUpgrade = {
    enable = true;
    dates = "00:30"; # 03:30 / 02:30, Helsinki time (winter / summer)
    randomizedDelaySec = "30min";

    flake = "github:sakuexe/nixos_cloud#${hostname}";

    operation = "boot";
    allowReboot = true;
    rebootWindow = {
      lower = "01:00";
      upper = "02:30";
    };

    runGarbageCollection = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # 128 MiB
  nix.settings.download-buffer-size = 128 * 1024 * 1024;

  system.stateVersion = "25.11";
}
