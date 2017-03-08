#!/usr/bin/env bash

# Allow the environment to override curl's User-Agent parameter. We
# use this to distinguish probably-actual-users installing Sandstorm
# from the automated test suite, which invokes the install script with
# this environment variable set.
CURL_USER_AGENT="${CURL_USER_AGENT:-thonix-sandstorm-update-script}"

# Define I/O helper functions.
fail() {
  local error_code="$1"
  shift

  if [ $# != 0 ]; then
    echo -en '\e[0;31m' >&2
    echo "$@" | (fold -s || cat) >&2
    echo -en '\e[0m' >&2
  fi
  echo "" >&2
  exit 1
}


retryable_curl() {
  # This function calls curl to download a file. If the file download fails, it asks the user if it
  # is OK to retry.
  local CURL_FAILED="no"
  curl -A "${CURL_USER_AGENT}" -f "$1" > "$2" || CURL_FAILED="yes"
  if [ "yes" = "${CURL_FAILED}" ] ; then
      echo "" >&2
      echo "Download failed. Waiting one second before retrying..." >&2
      sleep 1
      retryable_curl "$1" "$2"
  fi
}

download_latest_bundle_and_extract_if_needed() {
  local channel="$1"

  echo "Finding latest build for $channel channel..." >&2
  # NOTE: The type is install_v2. We use the "type" value when calculating how many people attempted
  # to do a Sandstorm install. We had to stop using "install" because vagrant-spk happens to use
  # &type=install during situations that we do not want to categorize as an attempt by a human to
  # install Sandstorm.
  BUILD="$(curl -A "$CURL_USER_AGENT" -fs "https://install.sandstorm.io/$channel?from=0&type=install")"
  BUILD_DIR="sandstorm-${BUILD}"

  if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
    fail "E_INVALID_BUILD_NUM" "Server returned invalid build number: $BUILD"
  fi

  do-download() {
    rm -rf "${BUILD_DIR}"
    WORK_DIR="$(mktemp -d ./sandstorm-installer.XXXXXXXXXX)"
    local URL="https://dl.sandstorm.io/sandstorm-$BUILD.tar.xz"
    echo "Downloading: $URL" >&2
    retryable_curl "$URL" "$WORK_DIR/sandstorm-$BUILD.tar.xz"
    retryable_curl "$URL.sig" "$WORK_DIR/sandstorm-$BUILD.tar.xz.sig"

    if which gpg2 > /dev/null; then
      export GNUPGHOME="$WORK_DIR/.gnupg"
      mkdir -m 0700 -p "$GNUPGHOME"

      # Regenerate with: gpg --armor --export 160D2D577518B58D94C9800B63F227499DA8CCBD
      gpg2 --dearmor > "$WORK_DIR/sandstorm-keyring.gpg" << __EOF__
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

mQENBFX8ypkBCAC8sjX5yZqKdW8nY7aE/GpVeS+qSCbpYSJwixYNFXbz3MQihR3S
suvg5uw1KyuQb23c0LwirfxazVf7txKhQNaNU3ek62LG3wcGeBrvQGsIUMbkatay
/163CLeVWfSK1Z4pFc4dhdjXYSOz0oZxd7Mp78crBbGKmyn7PtzdAqt+XfEXNuee
cDbx++P57n5s5xc5fQWznt333IMgmgTREGUROfh4kL376rFAS208XIywJlUVkoKM
kIzgcjevFGwYKdsLigHXCDp9toQHl8oPjFV+RE8Br8ciJlMp9CqCfHGwj0Orxasc
e9moLqqUc+iKdg9bQfuAbJ/jFNhGmV/CVv9tABEBAAG0LlNhbmRzdG9ybS5pbyAo
cmVsZWFzZXMpIDxzdXBwb3J0QHNhbmRzdG9ybS5pbz6JATgEEwECACIFAlX8ypkC
GwMGCwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEGPyJ0mdqMy91bYH/iTg9qbw
G3th57Yf70NtyMJE3UBFDYDNAgT45UBEHoHhQM5cdFu/EIHggOKl/A2zL19Nh555
5F5o3jiJChQ0cvpoVnDdA5lRKD9iK6hzAba9fCVAx/od1PULQP7KV+uHTQuclSFO
DBvpgT8bMY9LmlpTl+l2lvYd+c50w3jZMFwh8JrJYAc3X0kBfVEywVZkjH8Nw5nD
v/j5Of3XXfEg84tNyWSYUMrYVORJyfHtA9e3JXNv5BMxH73AVLnyCJhCaodQsC6Z
hFkHUvvRb58ZqKXMtLYTd/8XLIvpkgRNX6EHWDslJh3BaBwHSuqDNssh1TW5xPjA
9vkPDzeZfLkuxpy5AQ0EVfzKmQEIANyi22M/3KhkghsPA6Rpha1lx6JJCb4p7E21
y82OGFUwcMpZkSgh1lARgp/Mvc2CHhAXi6NkGbgYc1q5rgARSvim2EMZNQOEqRb9
teEeI3w7Nz8Q/WoWck9WaXg8EdELtBOXYgVEirVddUl6ftUvCeBh3hE2Y/CLQSXL
CYXdQ2/MN6xV8tepuWOu0aPxxPUNea9ceDNZ8/CXEL32pzv9SUX/3KgSnFTzmxNP
thzXGuaAQGMZRu3cdTSeK9UUX4L3lxv7p0nE/2K18MU3FayTJqspfUCc4BgHZRMN
sh+2/YNfJgi0uWex1WnU94ZIp4A0uic54bU1ZECSwxg81KHaEEkAEQEAAYkBHwQY
AQIACQUCVfzKmQIbDAAKCRBj8idJnajMvZgPB/0THpTPnfsYNkwQrBsrTq413ZTF
JmVyeZ9xnGDImOdyHhGLlnLC1YEnaNUVEyMKifya4TF2utrLrsMT9TC/dWvFsYlJ
oMcUpaSlrFoAoPp3pdOGCIRYNhWGHoxy0Ti1WAa/6A+GoHJpUEz85/jD4vjgYlCX
ZFW1Pji9PbdIZFZQR4FyYBkkZOUq6yyTNR0syQPVy3EsPVvXzszm2zV/1YjGymgj
MKeYR9+VU+PlFAY9wwLWLTFeSzxTyVjbPwF5bWHV32GM8g0/NgA6a1JLL40v7pqf
uYvFk2KJpo3gZNGJ72gLkSzie7Eu1/V67JIG9TwfrJUEj8Uwd5zPv1MOqfWl
=OiS5
-----END PGP PUBLIC KEY BLOCK-----
__EOF__

      if gpg2 --no-default-keyring --keyring $WORK_DIR/sandstorm-keyring.gpg --status-fd 1 \
             --verify $WORK_DIR/sandstorm-$BUILD.tar.xz{.sig,} 2>/dev/null | \
          grep -q '^\[GNUPG:\] VALIDSIG 160D2D577518B58D94C9800B63F227499DA8CCBD '; then
        echo "GPG signature is valid." >&2
      else
        rm -rf sandstorm-$BUILD
        fail "E_INVALID_GPG_SIG" "GPG signature is NOT valid! Please report to security@sandstorm.io immediately!"
      fi

      unset GNUPGHOME
    else
      echo "WARNING: gpg not installed; not verifying signatures (but it's HTTPS so you're probably fine)" >&2
    fi

    CHECKSUM="$(sha256sum -b "$WORK_DIR/sandstorm-$BUILD.tar.xz" | awk '{print $1}')"

    tar Jxof "$WORK_DIR/sandstorm-$BUILD.tar.xz"
    rm -rf "$WORK_DIR"

    if [ ! -e "$BUILD_DIR" ]; then
      fail "E_BAD_PACKAGE" "Bad package -- did not contain $BUILD_DIR directory."
    fi

    if [ ! -e "$BUILD_DIR/buildstamp" ] || \
       [ $(stat -c %Y "$BUILD_DIR/buildstamp") -lt $(( $(date +%s) - 30*24*60*60 )) ]; then
      rm -rf "$BUILD_DIR"
      fail "E_PKG_STALE" "The downloaded package seems to be more than a month old. Please verify that your" \
           "computer's clock is correct and try again. It could also be that an attacker is" \
           "trying to trick you into installing an old version. Please contact" \
           "security@sandstorm.io if the problem persists."
    fi

    echo -e "  $channel = fetchurl {\n    url = \"$URL\";\n    sha256 = \"$CHECKSUM\";\n  };"
  }

  do-download
  rm -rf "${BUILD_DIR}"
}

echo "{fetchurl}:" > channels.nix
echo "{" >> channels.nix
download_latest_bundle_and_extract_if_needed dev >> channels.nix
# download_latest_bundle_and_extract_if_needed canary >> channels.nix
# download_latest_bundle_and_extract_if_needed beta  >> channels.nix
# download_latest_bundle_and_extract_if_needed stable  >> channels.nix
echo "}" >> channels.nix