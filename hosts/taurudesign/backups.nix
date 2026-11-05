{ config, pkgs, userSettings, ... }:

let
  user = config.users.users.${userSettings.username};
  home = user.home;
  volumes = "${home}/.local/share/docker/volumes";
  staging = "${home}/.cache/restic-staging";
  # A sub-account chrooted to its own directory, so the VPS's key can't reach the rest of the box
  boxHost = "u711159-sub1.your-storagebox.de";
  box = "u711159-sub1@${boxHost}";
in
{
  # The unit can't answer a host key prompt, so pin the Storage Box key system-wide.
  # Get it with `ssh-keyscan -p 23 -t ed25519 <box>.your-storagebox.de` and check it
  # against the fingerprints in Hetzner's Storage Box docs
  programs.ssh.knownHosts.storagebox = {
    hostNames = [ "[${boxHost}]:23" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };

  services.restic.backups.taurudesign = {
    # The rootless Docker user: reads the volumes and owns the Docker socket, nothing runs as root
    user = userSettings.username;
    initialize = true;
    # Relative, so it lands in the login directory (/home, the sub-account's base
    # directory). The sub-account's / is root-owned and not writable
    repository = "sftp:${box}:restic";
    extraOptions = [
      "sftp.command='ssh -p 23 -i ${home}/.config/restic/storagebox_ed25519 ${box} -s sftp'"
    ];
    # Created by hand, never in this repo or the Nix store
    passwordFile = "${home}/.config/restic/password";

    # The module writes this with writeScript, which adds no shebang
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      set -eu
      export DOCKER_HOST=unix:///run/user/${toString user.uid}/docker.sock
      rm -rf ${staging} && mkdir -p ${staging}

      # Consistent snapshot while Umbraco runs; needs cms up (read-only WAL)
      ${pkgs.sqlite}/bin/sqlite3 -readonly ${volumes}/cms_data/_data/Umbraco.sqlite.db \
        ".backup ${staging}/Umbraco.sqlite.db"
      [ "$(${pkgs.sqlite}/bin/sqlite3 ${staging}/Umbraco.sqlite.db 'PRAGMA integrity_check')" = ok ]

      # The container's own pg_dump always matches the server version
      ${pkgs.docker_29}/bin/docker exec keycloak-postgres \
        sh -c 'pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB"' > ${staging}/keycloak.dump
    '';
    backupCleanupCommand = "rm -rf ${staging}";

    paths = [
      staging
      "${volumes}/cms_media/_data"
      "${volumes}/cms_attachments/_data"
    ];

    pruneOpts = [ "--keep-within 21d" ];
    # check only runs when checkOpts is non-empty; reading a sample also catches bit rot.
    # %% because this lands in ExecStart, where a bare % is a systemd specifier
    checkOpts = [ "--read-data-subset=5%%" ];

    timerConfig = {
      # After the autoUpgrade reboot window (01:00–02:30 UTC)
      OnCalendar = "04:00";
      RandomizedDelaySec = "15min";
      Persistent = true;
    };
  };
}
