{ configuration ? import ../nixos/lib/from-env.nix "NIXOS_CONFIG" <nixos-config>
, system ? builtins.currentSystem
}:

let

  eval = import ../nixos/lib/eval-config.nix {
    inherit system;
    modules = [ configuration ];
  };

  inherit (eval) pkgs;

  # This is for `nixos-rebuild build-vm'.
  vmConfig = (import ../nixos/lib/eval-config.nix {
    inherit system;
    modules = [ configuration ../nixos/modules/virtualisation/qemu-vm.nix ];
  }).config;

  # This is for `nixos-rebuild build-vm-with-bootloader'.
  vmWithBootLoaderConfig = (import ../nixos/lib/eval-config.nix {
    inherit system;
    modules =
      [ configuration
        ../nixos/modules/virtualisation/qemu-vm.nix
        { virtualisation.useBootLoader = true; }
      ];
  }).config;

in

{
  inherit (eval) config options;

  system = eval.config.system.build.toplevel;

  vm = vmConfig.system.build.vm;

  vmWithBootLoader = vmWithBootLoaderConfig.system.build.vm;

  # The following are used by nixos-rebuild.
  nixFallback = pkgs.nixUnstable.out;
}
