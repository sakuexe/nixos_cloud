{
  lib,
  hostname,
  userSettings,
  pkgs,
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

  systemd.user.timers."ci-batch" = {
    description = "Run CI jobs every 10 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:0/10:00";
      Persistent = true;
      Unit = "ci-batch.target";
    };
  };

  systemd.user.targets."ci-batch" = {
    description = "Run all CI jobs";
    wants = [
      "helmiala-ci.service"
      "mikromet-ci.service"
    ];
  };

  systemd.user.services."helmiala-ci" = {
    path = [ pkgs.git pkgs.openssh pkgs.docker ];

    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/${userSettings.username}/website";

      Environment = [
        "XDG_RUNTIME_DIR=/run/user/1000"
        "DOCKER_HOST=unix:///run/user/1000/docker.sock"
      ];
    };

    script = ''
      set -euo pipefail

      git fetch
      LOCAL="$(git rev-parse HEAD)"
      REMOTE="$(git rev-parse origin/main)"
      if [ "$LOCAL" = "$REMOTE" ]; then
        exit 0
      fi
      echo "Changes from origin/main, pulling and building"
      git pull --ff-only

      docker compose build
      docker compose down
      docker compose up -d
    '';
  };

  systemd.services."mikromet-ci" = {
    path = [ pkgs.git pkgs.openssh pkgs.docker ];

    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/${userSettings.username}/mikromet";
      Environment = [
        "XDG_RUNTIME_DIR=/run/user/1000"
        "DOCKER_HOST=unix:///run/user/1000/docker.sock"
      ];
    };

    script = ''
      set -euo pipefail

      git fetch
      LOCAL="$(git rev-parse HEAD)"
      REMOTE="$(git rev-parse origin/main)"
      if [ "$LOCAL" = "$REMOTE" ]; then
        exit 0
      fi
      echo "Changes from origin/main, pulling and building"
      git pull --ff-only

      docker compose build
      docker compose down
      docker compose up -d
    '';
  };
}
