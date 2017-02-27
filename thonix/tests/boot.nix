{ system ? builtins.currentSystem }:

with import ../lib/testing.nix { inherit system; };
with import <nixpkgs/nixos/lib/qemu-flags.nix>;
with pkgs.lib;

let

  iso =
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      inherit system;
      modules =
        [ ../modules/installer/installation-cd-minimal.nix
          <nixpkgs/nixos/modules/testing/test-instrumentation.nix>
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
