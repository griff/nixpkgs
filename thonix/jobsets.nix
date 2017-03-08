{ nixpkgs, declInput }: let pkgs = import nixpkgs {}; in {
  jobsets = pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toXML declInput}
    EOF
    cat > $out <<EOF
    {
        "stable": {
            "enabled": 1,
            "hidden": false,
            "description": "ThoNix release channel",
            "nixexprinput": "thonix",
            "nixexprpath": "release-combined.nix",
            "checkinterval": 300,
            "schedulingshares": 100,
            "enableemail": false,
            "emailoverride": "",
            "keepnr": 3,
            "inputs": {
                "nixpkgs": { "type": "git", "value": "https://github.com/NixOS/nixpkgs-channels.git nixos-16.09", "emailresponsible": false },
                "thonix": { "type": "path", "value": "/vagrant/thonix", "emailresponsible": false }
                "stableBranch": { "type": "boolean", "value": "true" }
            }
        }
    }
    EOF
  '';
}