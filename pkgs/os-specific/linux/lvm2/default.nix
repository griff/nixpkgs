{ stdenv, fetchurl, pkgconfig, systemd, libudev, utillinux, coreutils, libuuid,
  enable_dmeventd ? false, enable_lvmetad ? false, enable_lvmpolld ? false }:

let
  version = "2.02.140";
in

stdenv.mkDerivation {
  inherit enable_dmeventd enable_lvmetad enable_lvmpolld;

  name = "lvm2-${version}";

  src = fetchurl {
    url = "ftp://sources.redhat.com/pub/lvm2/releases/LVM2.${version}.tgz";
    sha256 = "1jd46diyv7074fw8kxwq7imn4pl76g01d8y7z4scq0lkxf8jmpai";
  };

  configureFlags = [
    "--disable-readline"
    "--enable-udev_rules"
    "--enable-udev_sync"
    "--enable-pkgconfig"
    "--enable-applib"
    "--enable-cmdlib"
  ] ++ stdenv.lib.optional enable_dmeventd " --enable-dmeventd"
    ++ stdenv.lib.optional enable_lvmetad [
      "--enable-lvmetad"
      "--disable-udev-systemd-background-jobs"
    ]
    ++ stdenv.lib.optional enable_lvmpolld " --enable-lvmpolld";

  nativeBuildInputs = [ pkgconfig ];
  buildInputs = [ libudev libuuid ];

  preConfigure =
    ''
      substituteInPlace scripts/lvmdump.sh \
        --replace /usr/bin/tr ${coreutils}/bin/tr
      substituteInPlace scripts/lvm2_activation_generator_systemd_red_hat.c \
        --replace /usr/sbin/lvm $out/sbin/lvm \
        --replace /usr/bin/udevadm ${systemd.udev.bin}/bin/udevadm
      substituteInPlace udev/Makefile.in \
        --replace @bindir@/systemd-run ${systemd.out}/bin/systemd-run

      substituteInPlace make.tmpl.in \
        --replace @systemdsystemunitdir@ $out/etc/systemd/system
      substituteInPlace make.tmpl.in \
        --replace @systemdutildir@ $out/lib/systemd

      sed -i /DEFAULT_SYS_DIR/d Makefile.in
      sed -i /DEFAULT_PROFILE_DIR/d conf/Makefile.in

      configureFlags="$configureFlags --sbindir=$out/sbin"
    '';

  enableParallelBuilding = true;

  #patches = [ ./purity.patch ];
  patches = [ ./debug.patch ];

  # To prevent make install from failing.
  preInstall = "installFlags=\"OWNER= GROUP= confdir=$out/etc\"";

  # Install systemd stuff.
  installTargets = "install install_systemd_generators install_systemd_units install_tmpfiles_configuration";

  postInstall =
    ''
      substituteInPlace $out/lib/udev/rules.d/13-dm-disk.rules \
        --replace $out/sbin/blkid ${utillinux}/sbin/blkid
    '';

  meta = {
    homepage = http://sourceware.org/lvm2/;
    descriptions = "Tools to support Logical Volume Management (LVM) on Linux";
    platforms = stdenv.lib.platforms.linux;
    maintainers = with stdenv.lib.maintainers; [raskin];
    inherit version;
    downloadPage = "ftp://sources.redhat.com/pub/lvm2/";
  };
}
