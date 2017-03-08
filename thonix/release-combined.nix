# This jobset defines the main ThoNix channels (such as thonix-unstable
# and thonix-1.0). The channel is updated every time the ‘tested’ job
# succeeds, and all other jobs have finished (they may fail).

{ nixpkgs ? { outPath = ../nixpkgs; revCount = 56789; shortRev = "gfedcba"; }
, thonix ? { outPath = ./.; revCount = 56789; shortRev = "gfedcba"; }
, stableBranch ? false
, supportedSystems ? [ "x86_64-linux" "i686-linux" ]
}:

let

  nixpkgsSrc = nixpkgs; # urgh
  thonixSrc = thonix; # urgh

  pkgs = import <nixpkgs> {};

  removeMaintainers = set: if builtins.isAttrs set
    then if (set.type or "") == "derivation"
      then set // { meta = builtins.removeAttrs (set.meta or {}) [ "maintainers" ]; }
      else pkgs.lib.mapAttrs (n: v: removeMaintainers v) set
    else set;

in rec {

  thonix = (import ./release.nix {
    inherit stableBranch supportedSystems;
    nixpkgs = nixpkgsSrc;
    thonix = thonixSrc;
  });

  /*
  nixpkgs = builtins.removeAttrs (removeMaintainers (import ../pkgs/top-level/release.nix {
    inherit supportedSystems;
    nixpkgs = nixpkgsSrc;
  })) [ "unstable" ];
  */

  tested = pkgs.lib.hydraJob (pkgs.releaseTools.aggregate {
    name = "thonix-${nixos.channel.version}";
    meta = {
      description = "Release-critical builds for the ThoNix channel";
      maintainers = [ "Brian Olsen <brian@maven-group.org>" ];
    };
    constituents =
      let all = x: map (system: x.${system}) supportedSystems; in
      [ thonix.channel
        (all thonix.dummy)

        (all thonix.iso_minimal)
        #thonix.ova.x86_64-linux

        (all thonix.tests.boot.biosCdrom)
        (all thonix.tests.boot.biosUsb) # disabled due to issue #15690
        (all thonix.tests.boot.uefiCdrom)
        (all thonix.tests.boot.uefiUsb)

        #nixpkgs.tarball
      ];
  });

}
