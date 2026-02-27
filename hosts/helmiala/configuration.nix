{
  lib,
  hostname,
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
    ../../modules/motd.nix
  ];

  services.qemuGuest.enable = true;
  users.users.${userSettings.username}.openssh.authorizedKeys.keys = pubkeys.readAll ./.;

  networking.interfaces.enp1s0.ipv6.addresses = [
    {
      address = "2a01:4f9:c013:15e3::1";
      prefixLength = 64;
    }
  ];

  systemd.timers."ci-batch" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:0/10:00";
      Persistent = true;
      Unit = "ci-batch.target";
    };
  };

  systemd.targets."ci-batch" = {
    description = "Run all CI jobs";
    wants = [
      "helmiala-ci.service"
      "mikromet-ci.service"
    ];
  };

  systemd.services."helmiala-ci" = {
    script = ''
      set -euo pipefail

      git fetch

      if git diff --quiet origin/main; then
        exit 0 # no changes
      fi

      git pull

      docker compose build
      docker compose down
      docker compose up -d
    '';
    serviceConfig = {
      Type = "oneshot";
      User = userSettings.username;
      WorkingDirectory = "/home/${userSettings.username}/website";
    };
  };

  systemd.services."mikromet-ci" = {
    script = ''
      set -euo pipefail

      git fetch
      if git diff --quiet origin/main; then
        exit 0 # no changes
      fi
      git pull

      docker compose build
      docker compose down
      docker compose up -d
    '';
    serviceConfig = {
      Type = "oneshot";
      User = userSettings.username;
      WorkingDirectory = "/home/${userSettings.username}/mikromet";
    };
  };
}
