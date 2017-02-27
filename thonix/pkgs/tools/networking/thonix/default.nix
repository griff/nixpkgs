# This file was generated by go2nix.
{ stdenv, buildGo17StaticPackage, fetchFromGitHub, fetchgit, fetchhg, fetchbzr, fetchsvn }:

buildGo17StaticPackage rec {
  name = "thonix-${version}";
  version = "20161220-${stdenv.lib.strings.substring 0 7 rev}";
  rev = "cd7033d819ec7bedccab4c8ec81575541c9b4b0f";

  goPackagePath = "github.com/griff/thonix";

  src = fetchFromGitHub {
    inherit rev;
    owner = "griff";
    repo = "thonix-rescue";
    sha256 = "1f8ic4cmjyxrydj60jjhixvj9r93shh01s4z21sgfz946b5gamcq";
  };

  goDeps = ./deps.nix;

  buildFlags = [ "-tags" "netgo" "--ldflags=\"-s\"" ];

  # metadata https://nixos.org/nixpkgs/manual/#sec-standard-meta-attributes
  meta = {
    description = "ThoNix Rescue daemon";
    license = stdenv.lib.licenses.agpl3;
  };
}
