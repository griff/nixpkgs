{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.boot.initrd.network.rescue;

in

{

  options = {

    boot.initrd.network.rescue.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Start ThoNix Rescue service during initrd boot. It can be used to debug
        failing boot on a remote server, enter pasphrase for an encrypted
        partition etc. Service is killed when stage-1 boot is finished.
      '';
    };

    boot.initrd.network.rescue.package = mkOption {
      type = types.package;
      default = pkgs.thonix;
      description = ''
        Version of ThoNix Rescue package to install. 
      '';
    };

    boot.initrd.network.rescue.port = mkOption {
      type = types.int;
      default = 443;
      description = ''
        Port on which ThoNix Rescue initrd service should listen.
      '';
    };

    boot.initrd.network.rescue.shell = mkOption {
      type = types.str;
      default = "/bin/ash";
      description = ''
        Login shell of the remote user. Can be used to limit actions user can do.
      '';
    };

    boot.initrd.network.rescue.sslPrivateKey = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        SSL private key file in PEM format.

        WARNING: This key is contained insecurely in the global Nix store. Do NOT
        use your regular SSL private keys for this purpose or you'll expose
        them to regular users!
      '';
    };

    boot.initrd.network.rescue.sslCertificate = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        SSL certificate file in PEM format.
      '';
    };
  };

  config = mkIf (config.boot.initrd.network.enable && cfg.enable) {
    assertions = [ {
      assertion = (cfg.sslPrivateKey == null && cfg.sslCertificate == null) || (cfg.sslPrivateKey != null && cfg.sslCertificate != null);
      message = "You should specify both private key and certificate for ThoNix Rescue to use SSL";
    } ];

    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${cfg.package}/bin/thonix

      ${optionalString (cfg.sslPrivateKey != null) "install -D ${cfg.sslPrivateKey} $out/etc/thonix/rescue/private_key.pem"}
      ${optionalString (cfg.sslCertificate != null) "install -D ${cfg.sslCertificate} $out/etc/thonix/rescue/certificate.pem"}
    '';

    boot.initrd.extraUtilsCommandsTest = ''
      $out/bin/thonix -v
    '';

    boot.initrd.preDeviceCommands = ''
      thonix report preDevice
    '';

    boot.initrd.preLVMCommands = ''
      thonix report preLVM
    '';

    boot.initrd.network.postCommands = ''
      echo '${cfg.shell}' > /etc/shells

      mkdir -p /etc/thonix/rescue
      ${optionalString (cfg.sslPrivateKey != null) "ln -s $extraUtils/etc/thonix/rescue/private_key.pem /etc/thonix/rescue/private_key.pem"}
      ${optionalString (cfg.sslCertificate != null) "ln -s $extraUtils/etc/thonix/rescue/certificate.pem /etc/thonix/rescue/certificate.pem"}

      thonix daemon -c 6 -s '${cfg.shell}' --state Booting -e $extraUtils/etc/thonix/rescue -p ${toString cfg.port} &
      thonix report networkPost
    '';

    boot.initrd.postDeviceCommands = ''
      thonix report postDevice
    '';

    boot.initrd.postMountCommands = ''
      thonix report postMount
    '';

    boot.initrd.preFailCommands = ''
      thonix failed
    '';
  };

}
