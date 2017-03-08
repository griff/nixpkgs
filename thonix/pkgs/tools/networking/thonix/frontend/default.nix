{stdenv, fetchurl, fetchgit, buildMaven, unzip, writeText, boot}:
let 

  bootHome = args@
  { # Example: "2.7.1"
  version
  # The `url` and `urls` parameters, if specified should point to the JAR
  # file and will take precedence over the `repos` parameter. Only one of `url`
  # and `urls` can be specified, not both.
, url ? ""
, baseUrl ? "https://github.com/boot-clj/boot/releases/download"
, # The rest of the arguments are just forwarded to `fetchurl`.
  ...
}:
let
  name_ = "boot-${version}";
  url_ = if url != "" then url
  else "${baseUrl}/${version}/boot.jar";

  bootjar = fetchurl (
      builtins.removeAttrs args ["groupId" "artifactId" "version" "repos" "baseUrl" ]
        // { url = url_; name = "${name_}.jar"; }
    );
  properties = writeText "boot.properties" ''
    #http://boot-clj.com
    #Thu Feb 16 16:24:00 UTC 2017
    BOOT_CLOJURE_NAME=org.clojure/clojure
    BOOT_CLOJURE_VERSION=1.8.0
    BOOT_VERSION=${version}
  '';
in 
  stdenv.mkDerivation rec {
    name = "boot-${version}";
    buildInputs = [unzip];
    phases = "installPhase fixupPhase";
    installPhase = ''
      mkdir -p $out/cache/bin/${version}
      cp -r ${bootjar} $out/cache/bin/${version}/boot.jar
      mkdir -p $out/cache/lib/${version}
      cd $out/cache/lib/${version}
      unzip ${bootjar} aether.uber.jar
      cp ${properties} $out/boot.properties
    '';
  };

  boot27 = bootHome {
    version = "2.7.1";
    sha256 = "1w05ly2y1yj5myx2jpw9zhpvs28v7dhi4b3a2b9avdwrasj64ka6";
  };

  source = fetchgit {
    url = "https://github.com/griff/thonix-frontend";
    rev = "70bc52b9716d29a967a5aabb300f23e2909f2867";
    sha256 = "0gp1377frz5j4fpwrxcsqb1brwsvn0h5hryv40zwwa41qa1a14jb";
  };

  repo = (buildMaven "${source.out}/project-info.json");
in
stdenv.mkDerivation rec {
  version = "20161221-${stdenv.lib.strings.substring 0 7 rev}";
  rev = source.rev;
  name = "thonix-frontend-${version}";

  src = source;

  buildInputs = [boot boot27];

   buildPhase = ''
    runHook preBuild

    cp -r ${boot27.out} "$NIX_BUILD_TOP/.boot"
    chmod -R a+rw "$NIX_BUILD_TOP/.boot"
    export BOOT_HOME="$NIX_BUILD_TOP/.boot"
    export BOOT_LOCAL_REPO="${repo.repo}"
    ls -la "$BOOT_HOME/boot.properties"
    boot release

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r release/* $out

    runHook postInstall
  '';
}