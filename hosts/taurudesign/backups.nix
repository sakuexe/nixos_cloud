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

  restore = import ./restore.nix { inherit pkgs lib cfg staging volumes dockerHost; };

  # Last backup result as "<up|down> <epoch> <msg>". On disk because systemd's own
  # unit state is wiped by the nightly autoUpgrade reboot
  lastRun = "${home}/.local/state/restic/last-run";

  # Usage: kuma-push <up|down> <msg>
  kumaPush = pkgs.writeShellScript "kuma-push" ''
    # Created by hand like the password: the token lets anyone mark the monitor up
    url=$(cat ${home}/.config/restic/kuma-push-url) || exit 0
    # A Kuma outage shouldn't count as a failed backup
    ${pkgs.curl}/bin/curl -fsS -m 10 --retry 3 -o /dev/null -G \
      --data-urlencode "status=$1" --data-urlencode "msg=$2" "$url" || true
  '';

  # Re-reports the last result so Kuma notices silence (dead VPS, timer never firing)
  # within its heartbeat interval, not only when a run happens
  kumaHeartbeat = pkgs.writeShellScript "restic-kuma-heartbeat" ''
    if ! read -r status ts msg < ${lastRun}; then
      exec ${kumaPush} down "no backup recorded"
    fi
    age=$(( $(date +%s) - ts ))
    if [ "$status" != up ]; then
      exec ${kumaPush} down "last backup failed: $msg"
    # Daily run + randomized delay + runtime, with slack
    elif [ "$age" -gt $(( 26 * 3600 )) ]; then
      exec ${kumaPush} down "stale: last backup $(( age / 3600 ))h ago"
    else
      exec ${kumaPush} up "OK, last backup $(( age / 3600 ))h ago"
    fi
  '';
in
{
  environment.systemPackages = [ restore ];

  # Push at half of Kuma's 60 min heartbeat interval, so one lost push doesn't alert
  systemd.services.restic-kuma-heartbeat = {
    startAt = "*:0/30";
    serviceConfig = {
      Type = "oneshot";
      User = userSettings.username;
      ExecStart = kumaHeartbeat;
    };
  };

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
    # Runs after every run (ExecStopPost): records the result for the heartbeat and
    # pushes it right away, so a failure alerts now rather than at the next heartbeat
    backupCleanupCommand = ''
      #!${pkgs.runtimeShell}
      rm -rf ${staging}

      # systemd sets these for ExecStopPost; success means backup, prune and check all passed
      if [ "$SERVICE_RESULT" = success ]; then status=up msg=OK
      else status=down msg="$SERVICE_RESULT ($EXIT_STATUS)"; fi

      mkdir -p "$(dirname ${lastRun})"
      # tmp + mv so the heartbeat never reads a half-written file
      echo "$status $(date +%s) $msg" > ${lastRun}.tmp && mv ${lastRun}.tmp ${lastRun}
      ${kumaPush} "$status" "$msg"
    '';

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
