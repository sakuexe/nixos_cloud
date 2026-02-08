# NixOS configurations for the cloud

This repository contains the files for my NixOS virtual machines.

I mostly use Hetzner Cloud, so they are optimized for that.

## Installation

The installation uses [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
to make the process easy.

**Dependencies**

- Local system with `nix` installed
- SSH keys for the new system (set in common.nix)

**Command**

```bash
nix run github:nix-community/nixos-anywhere -- \                                                                                                                                                       4m 21.737s
  --flake .#<HOST_CONFIG_NAME> \
  --generate-hardware-config nixos-generate-config \
  ./hosts/<HOST_CONFIG_NAME>/hardware-configuration.nix \
  root@<REMOTE_IP>
```

## References

- [Install NixOS on Hetzner - NixOS Wiki](https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Cloud)
