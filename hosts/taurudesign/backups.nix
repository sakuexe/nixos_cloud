{ config, lib, pkgs, userSettings, ... }:

let
  user = config.users.users.${userSettings.username};
  home = user.home;
  volumes = "${home}/.local/share/docker/volumes";
  staging = "${home}/.cache/restic-staging";
  dockerHost = "unix:///run/user/${toString user.uid}/docker.sock";
  # A sub-account chrooted to its own directory, so the VPS's key can't reach the rest of the box
  boxHost = "u711159-sub1.your-storagebox.de";
  box = "u711159-sub1@${boxHost}";
  cfg = config.services.restic.backups.taurudesign;

  # Restores a snapshot onto production. Built from the same values as the
  # backup, so the two can't drift apart. Usage: taurudesign-restore [all|cms|keycloak]
  restore = pkgs.writeShellApplication {
    name = "taurudesign-restore";
    runtimeInputs = [ cfg.package pkgs.docker_29 pkgs.fzf pkgs.jq ];
    text = ''
      what=''${1:-all}
      case "$what" in
        all | cms | keycloak) ;;
        *) echo "usage: taurudesign-restore [all|cms|keycloak]" >&2; exit 1 ;;
      esac

      red=$'\e[1;31m' reset=$'\e[0m'
      [ -t 1 ] || red="" reset=""
      die() { echo "$red$*$reset" >&2; exit 1; }

      export DOCKER_HOST=${dockerHost}
      export RESTIC_REPOSITORY=${lib.escapeShellArg cfg.repository}
      export RESTIC_PASSWORD_FILE=${lib.escapeShellArg cfg.passwordFile}
      restic() { command restic${lib.concatMapStrings (o: " -o ${o}") cfg.extraOptions} "$@"; }

      # Newest first
      snapshot=$(restic snapshots --json |
        jq -r 'sort_by(.time) | reverse | .[] | "\(.short_id)  \(.time[:16] | sub("T"; " "))"' |
        fzf --prompt 'Restore which snapshot? ' | cut -d' ' -f1) || die Aborted

      read -r -p "$red""Replace$reset $what on $red""production$reset with snapshot $snapshot? Type $red""restore$reset to continue: " answer
      [ "$answer" = restore ] || die Aborted

      # Not /tmp, which can be a small tmpfs
      mkdir -p "$HOME/.cache"
      dir=$(mktemp -d "$HOME/.cache/restic-restore.XXXXXX")
      trap 'rm -rf "$dir"' EXIT
      # -E so the ERR trap also fires inside the functions below
      set -E
      trap 'echo "$red""Restore failed.$reset Services stay stopped on purpose; check docker ps." >&2' ERR

      restic restore "$snapshot" --target "$dir"

      restore_cms() {
        echo "Restoring the CMS"
        docker compose -f "$HOME/cms/docker-compose.yml" stop cms
        # The host user can't write to the rootless volumes, so a container does
        # the file work. Everything in Data goes, so no stale -wal file or search
        # index survives
        docker run --rm \
          -v cms_data:/data -v cms_media:/media -v cms_attachments:/attachments \
          -v "$dir":/in:ro alpine:3.22 sh -euc '
            find /data /media /attachments -mindepth 1 -delete
            cp /in${staging}/Umbraco.sqlite.db /data/
            cp -a /in${volumes}/cms_media/_data/. /media/
            cp -a /in${volumes}/cms_attachments/_data/. /attachments/
            chown -R 1654:1654 /data /media /attachments
          '
        docker compose -f "$HOME/cms/docker-compose.yml" start cms
      }

      restore_keycloak() {
        echo "Restoring Keycloak"
        # Postgres keeps running; stopping Keycloak drops its connections and caches
        docker compose -f "$HOME/keycloak/docker-compose.yml" stop keycloak
        # One transaction, so a failure leaves the database as it was
        # shellcheck disable=SC2016 # expands inside the container
        docker exec -i keycloak-postgres sh -c \
          'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner --single-transaction' \
          < "$dir${staging}/keycloak.dump"
        docker compose -f "$HOME/keycloak/docker-compose.yml" start keycloak
      }

      case "$what" in
        all) restore_cms; restore_keycloak ;;
        cms) restore_cms ;;
        keycloak) restore_keycloak ;;
      esac

      echo "Restored $what from $snapshot. Re-apply any erasure requests made since"
      echo "that snapshot, then check the backoffice and Keycloak."
    '';
  };
in
{
  environment.systemPackages = [ restore ];

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
      export DOCKER_HOST=${dockerHost}
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
