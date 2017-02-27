# This module contains the basic configuration for building a NixOS
# installation CD.

{ config, lib, pkgs, ... }:

with lib;

{
  imports =
    [ ./base.nix

      # Profiles of this basic installation CD.
      <nixpkgs/nixos/modules/profiles/all-hardware.nix>
      <nixpkgs/nixos/modules/profiles/base.nix>
      <nixpkgs/nixos/modules/profiles/minimal.nix>

      # Enable devices which are usually scanned, because we don't know the
      # target system.
      <nixpkgs/nixos/modules/installer/scan/detected.nix>
      <nixpkgs/nixos/modules/installer/scan/not-detected.nix>

      # Allow "nixos-rebuild" to work properly by providing
      # /etc/nixos/configuration.nix.
      <nixpkgs/nixos/modules/profiles/clone-config.nix>

      # Include a copy of Nixpkgs so that nixos-install works out of
      # the box.
      <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    ];

  # ISO naming.
  isoImage.isoName = "${config.isoImage.isoBaseName}-${config.system.nixosLabel}-${pkgs.stdenv.system}.iso";

  isoImage.volumeID = substring 0 11 "THONIX_ISO";

  # EFI booting
  isoImage.makeEfiBootable = true;

  # USB booting
  isoImage.makeUsbBootable = true;

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

  # Allow the user to log in as root without a password.
  users.extraUsers.root.initialHashedPassword = "";
}
