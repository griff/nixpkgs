{ nixpkgs ? { outPath = ./..; revCount = 56789; shortRev = "gfedcba"; }
, stableBranch ? false
, supportedSystems ? [ "x86_64-linux" "i686-linux" ]
}:

with import ../lib;

let
  version = fileContents ./.version;
  versionSuffix =
    (if stableBranch then "." else "beta") + "${toString (nixpkgs.revCount - 90538)}.${nixpkgs.shortRev}";

  forAllSystems = genAttrs supportedSystems;

  importTest = fn: args: system: import fn ({
    inherit system;
  } // args);

  callTest = fn: args: forAllSystems (system: hydraJob (importTest fn args system));

  callSubTests = fn: args: let
    discover = attrs: let
      subTests = filterAttrs (const (hasAttr "test")) attrs;
    in mapAttrs (const (t: hydraJob t.test)) subTests;

    discoverForSystem = system: mapAttrs (_: test: {
      ${system} = test;
    }) (discover (importTest fn args system));

  # If the test is only for a particular system, use only the specified
  # system instead of generating attributes for all available systems.
  in if args ? system then discover (import fn args)
     else foldAttrs mergeAttrs {} (map discoverForSystem supportedSystems);

  pkgs = import nixpkgs { system = "x86_64-linux"; };


  versionModule =
    { system.nixosVersionSuffix = versionSuffix;
      system.nixosRevision = nixpkgs.rev or nixpkgs.shortRev;
    };


  makeIso =
    { module, type, maintainers ? ["griff"], system }:

    with import nixpkgs { inherit system; };

    hydraJob ((import ../nixos/lib/eval-config.nix {
      inherit system;
      modules = [ module versionModule { isoImage.isoBaseName = "thonix-${type}"; } ];
    }).config.system.build.isoImage);


  makeSystemTarball =
    { module, maintainers ? ["griff"], system }:

    with import nixpkgs { inherit system; };

    let

      config = (import ../nixos/lib/eval-config.nix {
        inherit system;
        modules = [ module versionModule ];
      }).config;

      tarball = config.system.build.tarball;

    in
      tarball //
        { meta = {
            description = "ThoNix system tarball for ${system} - ${stdenv.platform.name}";
            maintainers = map (x: lib.maintainers.${x}) maintainers;
          };
          inherit config;
        };


  makeClosure = module: buildFromConfig module (config: config.system.build.toplevel);


  buildFromConfig = module: sel: forAllSystems (system: hydraJob (sel (import ../nixos/lib/eval-config.nix {
    inherit system;
    modules = [ module versionModule ] ++ singleton
      ({ config, lib, ... }:
      { fileSystems."/".device  = mkDefault "/dev/sda1";
        boot.loader.grub.device = mkDefault "/dev/sda";
      });
  }).config));


in rec {

  channel = import lib/make-channel.nix { inherit pkgs nixpkgs version versionSuffix; };

  manual = buildFromConfig ({ pkgs, ... }: { }) (config: config.system.build.manual.manual);
  manualEpub = (buildFromConfig ({ pkgs, ... }: { }) (config: config.system.build.manual.manualEpub));
  manpages = buildFromConfig ({ pkgs, ... }: { }) (config: config.system.build.manual.manpages);
  options = (buildFromConfig ({ pkgs, ... }: { }) (config: config.system.build.manual.optionsJSON)).x86_64-linux;


  # Build the initial ramdisk so Hydra can keep track of its size over time.
  initialRamdisk = buildFromConfig ({ pkgs, ... }: { }) (config: config.system.build.initialRamdisk);

  netboot.x86_64-linux = let build = (import ../nixos/lib/eval-config.nix {
      system = "x86_64-linux";
      modules = [
        ./modules/installer/netboot/netboot-minimal.nix
        versionModule
      ];
    }).config.system.build;
  in
    pkgs.symlinkJoin {
      name="netboot";
      paths=[
        build.netbootRamdisk
        build.kernel
        build.netbootIpxeScript
      ];
      postBuild = ''
        mkdir -p $out/nix-support
        echo "file bzImage $out/bzImage" >> $out/nix-support/hydra-build-products
        echo "file initrd $out/initrd" >> $out/nix-support/hydra-build-products
        echo "file ipxe $out/netboot.ipxe" >> $out/nix-support/hydra-build-products
      '';
    };

  iso_minimal = forAllSystems (system: makeIso {
    module = ./modules/installer/cd-dvd/installation-cd-minimal.nix;
    type = "minimal";
    inherit system;
  });

  # A variant with a more recent (but possibly less stable) kernel
  # that might support more hardware.
  iso_minimal_new_kernel = genAttrs [ "x86_64-linux" ] (system: makeIso {
    module = ./modules/installer/cd-dvd/installation-cd-minimal-new-kernel.nix;
    type = "minimal-new-kernel";
    inherit system;
  });


  # A bootable VirtualBox virtual appliance as an OVA file (i.e. packaged OVF).
  ova = genAttrs [ "x86_64-linux" ] (system:

    with import nixpkgs { inherit system; };

    hydraJob ((import ../nixos/lib/eval-config.nix {
      inherit system;
      modules =
        [ versionModule
          ./modules/installer/virtualbox-demo.nix
        ];
    }).config.system.build.virtualBoxOVA)

  );


  # Ensure that all packages used by the minimal NixOS config end up in the channel.
  dummy = forAllSystems (system: pkgs.runCommand "dummy"
    { toplevel = (import ../nixos/lib/eval-config.nix {
        inherit system;
        modules = singleton ({ config, pkgs, ... }:
          { fileSystems."/".device  = mkDefault "/dev/sda1";
            boot.loader.grub.device = mkDefault "/dev/sda";
          });
      }).config.system.build.toplevel;
      preferLocalBuild = true;
    }
    "mkdir $out; ln -s $toplevel $out/dummy");


  # Provide a tarball that can be unpacked into an SD card, and easily
  # boot that system from uboot (like for the sheevaplug).
  # The pc variant helps preparing the expression for the system tarball
  # in a machine faster than the sheevpalug
  /*
  system_tarball_pc = forAllSystems (system: makeSystemTarball {
    module = ./modules/installer/cd-dvd/system-tarball-pc.nix;
    inherit system;
  });
  */

  # Provide container tarball for lxc, libvirt-lxc, docker-lxc, ...
  containerTarball = forAllSystems (system: makeSystemTarball {
    module = ./modules/virtualisation/lxc-container.nix;
    inherit system;
  });

  /*
  system_tarball_fuloong2f =
    assert builtins.currentSystem == "mips64-linux";
    makeSystemTarball {
      module = ./modules/installer/cd-dvd/system-tarball-fuloong2f.nix;
      system = "mips64-linux";
    };

  system_tarball_sheevaplug =
    assert builtins.currentSystem == "armv5tel-linux";
    makeSystemTarball {
      module = ./modules/installer/cd-dvd/system-tarball-sheevaplug.nix;
      system = "armv5tel-linux";
    };
  */


  # Run the tests for each platform.  You can run a test by doing
  # e.g. ‘nix-build -A tests.login.x86_64-linux’, or equivalently,
  # ‘nix-build tests/login.nix -A result’.
  tests.boot = callSubTests tests/boot.nix {};
  tests.rescue = callSubTests tests/rescue.nix {};
  #tests.boot-stage1 = callTest tests/boot-stage1.nix {};

  /* Build a bunch of typical closures so that Hydra can keep track of
     the evolution of closure sizes. */

  closures = {

    smallContainer = makeClosure ({ pkgs, ... }:
      { boot.isContainer = true;
        services.openssh.enable = true;
      });

    tinyContainer = makeClosure ({ pkgs, ... }:
      { boot.isContainer = true;
        imports = [ modules/profiles/minimal.nix ];
      });

    ec2 = makeClosure ({ pkgs, ... }:
      { imports = [ modules/virtualisation/amazon-image.nix ];
      });

    # Linux/Apache/PostgreSQL/PHP stack.
    lapp = makeClosure ({ pkgs, ... }:
      { services.httpd.enable = true;
        services.httpd.adminAddr = "foo@example.org";
        services.postgresql.enable = true;
        services.postgresql.package = pkgs.postgresql93;
        environment.systemPackages = [ pkgs.php ];
      });
  };
}
