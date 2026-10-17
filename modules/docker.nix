{
  userSettings,
  pkgs,
  ...
}:

{
  # Only enable the rootless daemon; no rootful daemon or docker group is needed.
  virtualisation.docker.rootless = {
    enable = true;
    package = pkgs.docker_29;
    setSocketVariable = true;
  };

  # Periodically prune the rootless daemon in the user's systemd instance.
  systemd.user.services.docker-prune = {
    unitConfig.ConditionUser = userSettings.username;
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker_29}/bin/docker --host=unix://%t/docker.sock system prune -f";
    };
  };
  systemd.user.timers.docker-prune = {
    wantedBy = [ "timers.target" ];
    unitConfig.ConditionUser = userSettings.username;
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
