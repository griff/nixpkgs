{ config, lib, pkgs, ... }:

with lib;

{

  ###### implementation

  config = mkIf (!config.boot.isContainer) {

    environment.systemPackages = [ pkgs.lvm2 ];

    services.udev.packages = [ pkgs.lvm2 ];
    systemd.packages = [ pkgs.lvm2 ];
    systemd.generator-packages = [ pkgs.lvm2 ];
    systemd.sockets.lvm2-lvmetad = mkIf pkgs.lvm2.enable_lvmetad {
      wantedBy = ["sockets.target"];
    };
    systemd.sockets.lvm2-lvmpolld = mkIf pkgs.lvm2.enable_lvmpolld {
      wantedBy = ["sockets.target"];
    };
  };

}
