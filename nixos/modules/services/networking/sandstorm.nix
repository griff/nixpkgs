{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.sandstorm;

  sandstorm = pkgs.stdenv.mkDerivation {
      name = "sandstorm-${(builtins.parseDrvName cfg.package.name).version}";
      buildCommand = ''
          mkdir -p $out/bin
          ln -sfT "${cfg.installDir}/sandstorm" $out/bin/sandstorm
          ln -sfT "${cfg.installDir}/sandstorm" $out/bin/spk
        '';
    };

  #sandstorm = cfg.package;

  # The main Sandstorm configuration file.
  configFile = pkgs.writeText "sandstorm.conf"
    ''
    SERVER_USER=sandstorm
    PORT=${toString cfg.port}
    MONGO_PORT=${toString cfg.mongoPort}
    BIND_IP=${cfg.bindIp}
    BASE_URL=${cfg.baseUrl}
    WILDCARD_HOST=${cfg.wildcardHost}
    UPDATE_CHANNEL=${cfg.updateChannel}
    ALLOW_DEV_ACCOUNTS=${if cfg.allowDevAccounts then "true" else "false"}
    SMTP_LISTEN_PORT=${toString cfg.smtpPort}
    '' + optionalString (cfg.httpsPort != null) ''
    HTTPS_PORT=${toString cfg.httpsPort}
    '' + optionalString (cfg.sandcatsBaseDomain != null) ''
    SANDCATS_BASE_DOMAIN=${cfg.sandcatsBaseDomain}
    '';

in

{

  ###### interface

  options = {

    services.sandstorm = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run Sandstorm.
        '';
      };

      baseUrl = mkOption {
        type = types.str;
        example = literalExample "http://example.com";
        description = ''
          The base URL for Sandstorm 
        '';
      };

      wildcardHost = mkOption {
        type = types.str;
        example = literalExample "*.example.com";
        description = ''
          Sandstorm uses random generated hostnames for security and needs to known
          the wildcard hostname to use.
        '';
      };

      package = mkOption {
        type = types.package;
        example = literalExample "pkgs.sandstorm-dev";
        description = ''
          Sandstorm package to use.
        '';
      };

      bindIp = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = ''
          IP on which the server instance will listen for incoming connections. Defaults to any IP.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 80;
        description = ''
          The port on which Sandstorm listens.
        '';
      };

      mongoPort = mkOption {
        type = types.int;
        default = if cfg.port < 1024 then 6081 else cfg.port + 1;
        description = ''
          The port on which the MongoDB that Sandstorm uses listens on.
        '';
      };

      smtpPort = mkOption {
        type = types.int;
        default = 30025;
        description = ''
          The port on which Sandstorm listens for SMTP mails.
        '';
      };

      updateChannel = mkOption {
        type = types.enum [ "none" "dev"];
        default = "none";
        description = ''
          Which Sandstorm channel to use for updates. Defaults to any none.
          When set to anything other than none the Sandstorm version from
          nixpkgs is only used for the initial install and after that Sandstorm
          itself takes over the update process.
        '';
      };

      allowDevAccounts = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to allow accounts for developing sandstorm apps.
        '';
      };

      installDir = mkOption {
        type = types.path;
        default = "/opt/sandstorm";
        description = ''
          Installation directory for Sandstorm.
        '';
      };

      httpsPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Https port to use when using sandcats.io
        '';
      };

      sandcatsBaseDomain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Sandcats.io base domain name to use when using sandcats.io
        '';
      };
    };

  };


  ###### implementation

  config = mkIf config.services.sandstorm.enable {

    services.sandstorm.baseUrl = mkIf (lib.hasPrefix "*." cfg.wildcardHost) 
      (mkDefault "http://${lib.removePrefix "*." cfg.wildcardHost}/");
    services.sandstorm.package = mkDefault pkgs.sandstorm;

    users.extraUsers.sandstorm =
      { name = "sandstorm";
        uid = config.ids.uids.sandstorm;
        group = "sandstorm";
        description = "Sandstorm server user";
      };

    users.extraGroups.sandstorm.gid = config.ids.gids.sandstorm;

    environment.systemPackages = [ sandstorm ];

    systemd.services.sandstorm =
      { description = "Sandstorm Server";

        wantedBy = [ "multi-user.target" ];
        requires = [ "local-fs.target" "remote-fs.target" "network.target" ];
        after = [ "local-fs.target" "remote-fs.target" "network.target" ];

        path = [ sandstorm ];

        preStart =
          ''
            # Create data directory.
            if ! test -L ${cfg.installDir}/sandstorm; then
              mkdir -m 0700 -p ${cfg.installDir}
              cd ${cfg.installDir}

              mkdir -p var/{log,pid,mongo} var/sandstorm/{apps,grains,downloads}

              # Set ownership of files.  We want the dirs to be root:sandstorm but the contents to be
              # sandstorm:sandstorm.
              chown -R sandstorm:sandstorm var/{log,pid,mongo} var/sandstorm/{apps,grains,downloads}
              chown root:sandstorm . var/{log,pid,mongo,sandstorm} var/sandstorm/{apps,grains,downloads}
              chmod -R g=rwX,o= var/{log,pid,mongo,sandstorm} var/sandstorm/{apps,grains,downloads}

              ln -sfT latest/sandstorm sandstorm
            fi
            ln -sfn "${configFile}" "${cfg.installDir}/sandstorm.conf"
            if [[ "${cfg.updateChannel}" == "none" || ! -e "${cfg.installDir}/latest" ]]; then
              if ! test -d ${cfg.installDir}/${cfg.package.name}; then
                cp -a "${cfg.package.out}" "${cfg.installDir}/${cfg.package.name}"
              fi
              ln -sfTr "${cfg.installDir}/${sandstorm.name}" "${cfg.installDir}/latest"
            fi
          ''; # */
        serviceConfig.Type = "forking";
        serviceConfig.ExecStart = "${cfg.installDir}/sandstorm start";
        serviceConfig.ExecStop = "${cfg.installDir}/sandstorm stop";
        serviceConfig.PIDFile = "${cfg.installDir}/var/pid/sandstorm.pid";

        unitConfig.RequiresMountsFor = "${cfg.installDir}";
      };

  };

  #meta.doc = ./postgresql.xml;

}
