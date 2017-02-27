{ system ? builtins.currentSystem, networkd ? false }:

with import ../lib/testing.nix { inherit system; };
with pkgs.lib;

let
  router = { config, pkgs, ... }:
    with pkgs.lib;
    let
      vlanIfs = range 1 (length config.virtualisation.vlans);
    in {
      virtualisation.vlans = [ 1 ];
      networking = {
        useDHCP = false;
        useNetworkd = networkd;
        firewall.allowPing = true;
        interfaces = mkOverride 0 (listToAttrs ((flip map vlanIfs (n:
          nameValuePair "eth${toString n}" {
            ipAddress = "192.168.${toString n}.1";
            prefixLength = 24;
          })) ++ [(nameValuePair "eth0" { useDHCP = true;})]) );
      };
      services.dhcpd = {
        enable = true;
        interfaces = map (n: "eth${toString n}") vlanIfs;
        extraConfig = ''
          option subnet-mask 255.255.255.0;
        '' + flip concatMapStrings vlanIfs (n: ''
          subnet 192.168.${toString n}.0 netmask 255.255.255.0 {
            option broadcast-address 192.168.${toString n}.255;
            option routers 192.168.${toString n}.1;
            range 192.168.${toString n}.2 192.168.${toString n}.254;
          }
        '');
      };
    };

  testCases = {
    dhcpSimple = {
      name = "SimpleDHCP";
      nodes.router = router;
      nodes.client = { config, pkgs, ... }: with pkgs.lib; {
        virtualisation.vlans = [ 1 ];
        boot.kernelParams = mkOverride 0 [ "console=ttyS0" "ip=:::::eth1:dhcp" ];

        boot.initrd.network.enable = true;
        boot.initrd.network.rescue.enable = true;
        boot.initrd.network.rescue.port = 80;
        boot.initrd.network.rescue.package = pkgs.thonix-head;

        networking = {
          useNetworkd = networkd;
          firewall.allowPing = true;
          useDHCP = true;
          interfaces.eth1.ip4 = mkOverride 0 [ ];
        };
      };
      testScript = { nodes, ... }:
        ''
          $router->start;
          $router->waitForUnit("network-interfaces.target");
          $router->waitForUnit("network.target");

          $client->start;
          $router->waitUntilSucceeds("curl --fail http://192.168.1.2/index.html");
          $router->succeeds("curl http://192.168.1.2/state | grep Booting");
        '';
    };
    failure = {
      name = "failure";
      nodes.router = router;
      nodes.client = { config, pkgs, ... }: with pkgs.lib; {
        virtualisation.vlans = [ 1 ];
        boot.kernelParams = mkOverride 0 [ "console=ttyS0" "ip=:::::eth1:dhcp" ];

        boot.initrd.network.enable = true;
        boot.initrd.network.rescue.enable = true;
        boot.initrd.network.rescue.port = 80;
        boot.initrd.network.rescue.package = pkgs.thonix-head;
        boot.initrd.postDeviceCommands = ''
          fail
        '';

        networking = {
          useNetworkd = networkd;
          firewall.allowPing = true;
          useDHCP = true;
          interfaces.eth1.ip4 = mkOverride 0 [ ];
        };
      };
      testScript = { nodes, ... }:
        ''
          $router->start;
          $router->waitForUnit("network-interfaces.target");
          $router->waitForUnit("network.target");

          $client->start;

          $router->waitUntilSucceeds("curl --fail http://192.168.1.2/state | grep BootFailed");
        '';
    };
  };

in mapAttrs (const (attrs: makeTest (attrs // {
  name = "${attrs.name}-Rescue-${if networkd then "Networkd" else "Scripted"}";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ griff ];
  };
}))) testCases
