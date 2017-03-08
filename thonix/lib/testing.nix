{ system, minimal ? false, config ? {} }:

import <nixpkgs/nixos/lib/testing.nix> { inherit system minimal config; }

