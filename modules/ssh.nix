{ userSettings, ... }:

# https://wiki.nixos.org/wiki/SSH
{
  services.openssh = {
    enable = true;
    ports = [ 2001 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      AllowUsers = [ userSettings.username ];
    };
  };

  # slow down malicious ssh connection attempts
  # https://github.com/skeeto/endlessh
  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
  };

  # ban repeatedly failing hosts
  # http://www.fail2ban.org/
  services.fail2ban.enable = true;
}
