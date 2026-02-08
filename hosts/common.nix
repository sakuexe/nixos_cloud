{
  userSettings,
  ...
}:

{
  imports = [
    ../modules/docker.nix
    ../modules/shell.nix
    ../modules/ssh.nix
  ];

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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # basic sane defaults for vms
  boot.loader.grub.enable = true;
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 80; # or 0 to allow all ports
  };

  users.users.${userSettings.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      # todo: update to use another global key,
      # like a yubikey
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/wnpQ9j6f5Wqk+jyZHSKxaCp34UMQUDVZlovV2yb3j"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  networking.useDHCP = true;

  time.timeZone = "UTC";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git.enable = true;
  programs.git.config = {
    user.name = userSettings.username;
    user.email = userSettings.email;
  };

  system.stateVersion = "25.11";
}
