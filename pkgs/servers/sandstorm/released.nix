{stdenv, fetchurl, channel ? "dev"}:
let
  channels = (import ./channels.nix) {inherit fetchurl;};
  source = builtins.getAttr channel channels;
in 
stdenv.mkDerivation rec {
  name = stdenv.lib.removeSuffix ".tar.xz" source.name;
  src = source;
  phases = "unpackPhase installPhase fixupPhase";
  installPhase = ''
    mkdir -p $out/
    cp -a . "$out/"
    mkdir -p $out/bin
    cd $out/bin
    ln -sTr $out/sandstorm $out/bin/sandstorm
  '';
}