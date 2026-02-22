# NixOS configurations for the cloud

This repository contains the files for my NixOS virtual machines.

I mostly use Hetzner Cloud, so they are optimized for that.

## Features

- All server configurations in one place
- Setting up new servers is Blazingly Fast™
- Improved security with declerative hardening with configuration files
- All VMs running the same version thanks to the [flake.lock](./flake.lock) file
- Automated updates once a day with Github Actions

## Updates

The system checks for updates once a day and applies them to the 
configuration if there are any.

[Update notes](https://github.com/sakuexe/nixos_cloud/actions?query=event%3Aschedule+is%3Asuccess++)

## Installation

The installation uses [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
to make the process easy.

**Dependencies**

- Local system with `nix` installed
- SSH keys for the new system (set in common.nix)

**Command**

```bash
nix run github:nix-community/nixos-anywhere -- \
  --ssh-option IdentityFile=~/.ssh/<SSH_KEY> \
  --ssh-option IdentitiesOnly=yes \
  --flake .#<HOST_CONFIG_NAME> \
  --generate-hardware-config nixos-generate-config \
  ./hosts/<HOST_CONFIG_NAME>/hardware-configuration.nix \
  root@<REMOTE_IP>
```

## References

- [Install NixOS on Hetzner - NixOS Wiki](https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Cloud)
