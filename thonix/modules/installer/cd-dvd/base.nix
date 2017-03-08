# This module contains the basic configuration for building a NixOS
# installation CD.

{ config, lib, pkgs, ... }:

with lib;

{
  imports =
    [ <nixpkgs/nixos/modules/installer/cd-dvd/iso-image.nix>];

  config = {
    boot.initrd.network.enable = true;
    boot.initrd.network.rescue.enable = true;
    boot.initrd.network.rescue.port = 80;
    boot.initrd.network.rescue.package = pkgs.thonix-head;

    # Note that /dev/root is a symlink to the actual root device
    # specified on the kernel command line, created in the stage 1
    # init script.
    fileSystems."/iso" = mkOverride 10
      { device = "/dev/root";
        neededForBoot = true;
        noCheck = true;
        postMountCommands = ''
          echo cp -v "$mountPoint/nix-store.squashfs" "$mountPoint/../nix-store.squashfs"
          cp -v "$mountPoint/nix-store.squashfs" "$mountPoint/../nix-store.squashfs"
        '';
      };

    # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
    # image) to make this a live CD.
    fileSystems."/nix/.ro-store" = mkOverride 10
      { fsType = "squashfs";
        device = "/nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };
  };
}
