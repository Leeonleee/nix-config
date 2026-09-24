{ config, lib, options, pkgs, ... }:

let
  cfg = config.programs.windows-vm;
  lsy = lib.getExe config.programs.lsy.package;
  windows = args: lib.escapeShellArgs ([ lsy "windows" "vm" ] ++ args);
  # Commands with output or prompts stay visible in Kitty after they finish.
  inKitty = args: lib.escapeShellArgs ([
    (lib.getExe config.programs.kitty.package)
    "--hold"
    "--title"
    "Windows VM"
    lsy
    "windows"
    "vm"
  ] ++ args);

  windowsSection = {
    label = "Windows";
    children = [
      # lsy reports launch progress and errors through notifications itself.
      { label = "Launch"; action = "${windows [ "launch" ]} || true"; }
      { label = "Launch (keep alive)"; action = "${windows [ "launch" "--keep-alive" ]} || true"; }
      { label = "Console"; action = windows [ "console" ]; }
      { label = "Status"; action = inKitty [ "status" ]; }
      { label = "Stop"; action = "${windows [ "stop" ]} && notify-send 'Windows 11' 'Windows VM stopped'"; }
      { label = "Remove"; action = inKitty [ "remove" ]; }
    ];
  };
in
{
  # Persistent Dockur Windows 11 VM managed by `lsy windows vm`; run
  # `lsy windows vm install` once in a terminal. Docker and KVM come from the
  # NixOS baseline. FreeRDP's X11 client runs through Xwayland.
  options.programs.windows-vm.scale = lib.mkOption {
    type = lib.types.nullOr (lib.types.ints.between 100 500);
    default = null;
    example = 175;
    description = ''
      Windows display scale in percent, sent by FreeRDP when connecting.
      Null follows the focused Hyprland or Niri output.
    '';
  };

  config = lib.mkMerge [
    {
      # Read by lsy windows vm launch; kept by lsy windows vm remove.
      xdg.configFile."lsy/windows.json" = lib.mkIf (cfg.scale != null) {
        text = builtins.toJSON { inherit (cfg) scale; };
      };

      home.packages = [
        pkgs.freerdp
        pkgs.libnotify
      ];

      # Discoverable by Vicinae and other application launchers.
      xdg.desktopEntries.windows-11 = {
        name = "Windows 11";
        genericName = "Virtual machine";
        comment = "Start the Windows 11 VM and connect with FreeRDP";
        exec = "${lsy} windows vm launch";
        icon = "computer";
        terminal = false;
        categories = [ "System" "Emulator" ];
        settings.StartupWMClass = "lsy-windows";
      };
    }
    # The system menu exists only when a session profile imports it.
    (lib.optionalAttrs (options.programs ? system-menu) {
      programs.system-menu.commonSections = [ windowsSection ];
    })
  ];
}
