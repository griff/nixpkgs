{ system ? builtins.currentSystem }:

with import ../lib/testing.nix { inherit system; };
with import ../../nixos/lib/qemu-flags.nix;
with pkgs.lib;

let

  iso =
    (import ../../nixos/lib/eval-config.nix {
      inherit system;
      modules =
        [ ../modules/installer/cd-dvd/installation-cd-minimal.nix
          ../../nixos/modules/testing/test-instrumentation.nix
        ];
    }).config.system.build.isoImage;

  makeBootTest = name: machineConfig:
    makeTest {
      inherit iso;
      name = "boot-" + name;
      nodes = { };
      testScript =
        ''
          my $machine = createMachine({ ${machineConfig}, qemuFlags => '-m 1024' });
          $machine->start;
          $machine->waitForUnit("multi-user.target");
          $machine->shutdown;
        '';
    };
in {

    biosCdrom = makeBootTest "bios-cdrom" ''
        cdrom => glob("${iso}/iso/*.iso")
      '';

    biosUsb = makeBootTest "bios-usb" ''
        usb => glob("${iso}/iso/*.iso")
      '';

    uefiCdrom = makeBootTest "uefi-cdrom" ''
        cdrom => glob("${iso}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';

    uefiUsb = makeBootTest "uefi-usb" ''
        usb => glob("${iso}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
}
