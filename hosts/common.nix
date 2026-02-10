{
  userSettings,
  ...
}:

{
  imports = [
    ../modules/docker.nix
    ../modules/shell.nix
    ../modules/ssh.nix
    ../modules/motd.nix
  ];

  motd.enable = true;

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

  system.stateVersion = "25.11";
}
