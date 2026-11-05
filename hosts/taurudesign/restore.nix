# Restores a snapshot onto production. Built from the same values as the
# backup, so the two can't drift apart. Usage: taurudesign-restore [all|cms|keycloak]
{ pkgs, lib, cfg, staging, volumes, dockerHost }:

pkgs.writeShellApplication {
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
}
