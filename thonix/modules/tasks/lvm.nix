{ config, lib, pkgs, ... }:

with lib;

{
  nixpkgs.config = {
    packageOverrides = pkgs: {
      lvm2 = pkgs.lvm2.override {
        enable_dmeventd = true;
        enable_lvmetad = true;
        enable_lvmpolld = true;
      };
    };
  };
}
