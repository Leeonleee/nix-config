{ config, lib, pkgs, ... }:

let
  userName = config.lsy.vm.userName;
in
{
  options.lsy.vm.userName = lib.mkOption {
    type = lib.types.strMatching "[a-z_][a-z0-9_-]*[$]?";
    default = "guest";
    description = "Guest login name; lsy vm run supplies the invoking account's name.";
  };

  config = {
    assertions = [
      {
        assertion = !(builtins.elem userName [ "root" "nobody" "nixbld" ]);
        message = "lsy.vm.userName must be a non-system user name.";
      }
    ];
    networking.hostName = "lsy-vm";
    system.stateVersion = "26.05";

    microvm = {
      hypervisor = "qemu";
      vcpu = 2;
      # Avoid QEMU microvm's known hang at exactly 2048 MiB.
      mem = 1536;
      socket = "control.sock";
      # Embed the guest store instead of exposing the host's /nix/store.
      shares = [ ];
      writableStoreOverlay = "/nix/.rw-store";
      interfaces = [
        {
          type = "user";
          id = "eth0";
          mac = "02:00:00:00:00:01";
        }
      ];
    };

    networking.useNetworkd = true;
    systemd.network.networks."20-guest" = {
      matchConfig.MACAddress = "02:00:00:00:00:01";
      networkConfig.DHCP = "yes";
    };

    # Console-only convenience account; no host credentials, SSH, or forwarded ports.
    services.getty.autologinUser = userName;
    users.users.${userName} = {
      isNormalUser = true;
      createHome = true;
      home = "/home/${userName}";
      extraGroups = [ "wheel" ];
    };
    security.sudo.wheelNeedsPassword = false;
    environment.systemPackages = with pkgs; [
      git
      curl
      nano
    ];
    environment.variables.EDITOR = "nano";
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
