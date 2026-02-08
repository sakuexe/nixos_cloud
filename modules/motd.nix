{ lib, config, ... }:
let
  cfg = config.motd;

  # Helper to build attrsets only when enabled
  mkIfNonEmpty = cond: val: if cond then val else { };

  fsEntries = builtins.listToAttrs (
    map (fs: {
      name = fs.name;
      value = fs.mountPoint;
    }) cfg.filesystems
  );

  dockerComposeStacks = builtins.listToAttrs (
    map (s: {
      name = s.name;
      value = s.path;
    }) cfg.dockerCompose.stacks
  );
in
{
  options.motd = {
    enable = lib.mkEnableOption "Enable rust-motd login greeting";

    # Core blocks
    showLastLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    showUptime = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    showMemory = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    filesystems = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { ... }:
          {
            options = {
              name = lib.mkOption { type = lib.types.str; };
              mountPoint = lib.mkOption { type = lib.types.str; };
            };
          }
        )
      );
      default = [
        {
          name = "root";
          mountPoint = "/";
        }
      ];
      description = "Filesystems to show (mount points).";
    };

    showLastRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    dockerCompose = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      stacks = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule (
            { ... }:
            {
              options = {
                name = lib.mkOption { type = lib.types.str; };
                path = lib.mkOption { type = lib.types.str; };
              };
            }
          )
        );
        default = [ ];
        description = "Compose stacks (name + directory containing docker-compose.yml).";
      };
    };

    fail2ban = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.rust-motd.enable = true;
    programs.rust-motd.enableMotdInSSHD = true;

    programs.rust-motd.order = [
      "global"
      "uptime"
      "memory"
      "filesystems"
      "docker_compose"
      "fail_2_ban"
      "last_run"
    ];

    programs.rust-motd.settings = {
      global = {
        show_legacy_warning = false;
      };
    }
    // mkIfNonEmpty cfg.showUptime {
      uptime = {
        prefix = "Uptime";
      };
    }
    // mkIfNonEmpty cfg.showMemory {
      memory = {
        swap_pos = "beside";
      };
    }
    // mkIfNonEmpty (cfg.filesystems != [ ]) {
      filesystems = fsEntries;
    }
    // mkIfNonEmpty cfg.dockerCompose.enable {
      docker_compose = dockerComposeStacks;
    }
    // mkIfNonEmpty cfg.fail2ban.enable {
      fail_2_ban = {
        jails = [ "sshd" ];
      };
    }
    // mkIfNonEmpty cfg.showLastRun { last_run = { }; };
  };
}
