{ pkgs, lib, config, ... }:

let
  capture = lib.getExe config.programs.capture.package;
in
{
  # The shell (DMS or Noctalia) is selected with desktop.niri.shell; its
  # service, shell keybindings and system-menu entries live in its module.
  imports = [ ./niri-shell.nix ];

  # Niri-specific applications/utilities.
  home.packages = with pkgs; [
    brightnessctl
    playerctl
    wl-clipboard
    fuzzel
  ];

  stylix.targets.fuzzel.enable = true;

  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        font = lib.mkForce "${config.stylix.fonts.sansSerif.name}:size=14";

        layer = "overlay";
      };
    };
  };

  programs.niri.settings = {
    # Electron apps such as VS Code use native Wayland.
    environment."NIXOS_OZONE_WL" = "1";

    # Support applications that require XWayland.
    # Use an absolute path because xwayland-satellite is not otherwise on PATH.
    xwayland-satellite = {
      enable = true;
      path = lib.getExe pkgs.xwayland-satellite-unstable;
    };

    # -------------------------------------------------------------------------
    # Workspaces
    # -------------------------------------------------------------------------

    # niri-flake creates workspaces sorted by key, so numbered keys keep the
    # order; it matches the Hyprland workspace order in hyprland.nix. Names
    # start with a Nerd Font glyph (web, terminal, code braces, robot, chat)
    # that Noctalia's one-character workspace labels show as an icon.
    workspaces = {
      "1-browser".name = "󰖟 browser";
      "2-terminal".name = " terminal";
      "3-code".name = "󰅩 code";
      "4-agents".name = "󰚩 agents";
      "5-social".name = "󰭹 social";
    };

    # -------------------------------------------------------------------------
    # Input
    # -------------------------------------------------------------------------

    input = {
      keyboard = {
        numlock = true;
      };

      touchpad = {
        tap = true;
        natural-scroll = true;
        scroll-factor = 0.3;
      };

      mouse = {
        accel-speed = 0;
        accel-profile = "flat";
      };

      focus-follows-mouse = {
        enable = true;
        max-scroll-amount = "50%";
      };
    };

    # -------------------------------------------------------------------------
    # Layout
    # -------------------------------------------------------------------------

    layout = {
      gaps = 16;

      center-focused-column = "never";

      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];

      default-column-width = {
        proportion = 0.5;
      };

      focus-ring = {
        enable = true;
        width = 4;

        active.color = "${config.lib.stylix.colors.withHashtag.base0D}CC";
        inactive.color = config.lib.stylix.colors.withHashtag.base03;
      };

      border = {
        enable = false;
        width = 4;

        active.color = config.lib.stylix.colors.withHashtag.base0D;
        inactive.color = config.lib.stylix.colors.withHashtag.base03;
        urgent.color = config.lib.stylix.colors.withHashtag.base08;
      };

      shadow = {
        enable = false;

        softness = 30;
        spread = 5;

        offset = {
          x = 0;
          y = 5;
        };

        color = "#0007";
      };
    };

    # -------------------------------------------------------------------------
    # General
    # -------------------------------------------------------------------------

    prefer-no-csd = true;

    screenshot-path =
      "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    # -------------------------------------------------------------------------
    # Gestures
    # -------------------------------------------------------------------------

    gestures.hot-corners.enable = false;

    # -------------------------------------------------------------------------
    # Window rules
    # -------------------------------------------------------------------------

    window-rules = [
      # WezTerm initial configure workaround.
      {
        matches = [
          {
            app-id = "^org\\.wezfurlong\\.wezterm$";
          }
        ];

        default-column-width = {};
      }

      # Firefox picture-in-picture.
      {
        matches = [
          {
            app-id = "firefox$";
            title = "^Picture-in-Picture$";
          }
        ];

        open-floating = true;
      }

      # Rounded corners and blur for all windows.
      {
        geometry-corner-radius = {
          top-left = 0.0;
          top-right = 0.0;
          bottom-left = 0.0;
          bottom-right = 0.0;
        };

        clip-to-geometry = true;

      }
    ];

    # -------------------------------------------------------------------------
    # Keybindings
    # -------------------------------------------------------------------------

    binds = {
      "Mod+Return" = {
        hotkey-overlay.title = "Open a Terminal: kitty";
        action.spawn = "kitty";
      };

      "Mod+Space" = {
        hotkey-overlay.title = "Open Vicinae";
        action.spawn = [ "vicinae" "toggle" ];
      };

      "Mod+T" = {
        hotkey-overlay.title = "Open file manager: Dolphin";
        action.spawn = "dolphin";
      };

      "Super+Alt+S" = {
        allow-when-locked = true;
        hotkey-overlay.hidden = true;
        action.spawn-sh = "pkill orca || exec orca";
      };

      # Volume.
      "XF86AudioRaiseVolume" = {
        allow-when-locked = true;
        action.spawn-sh =
          "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0";
      };

      "XF86AudioLowerVolume" = {
        allow-when-locked = true;
        action.spawn-sh =
          "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
      };

      "XF86AudioMute" = {
        allow-when-locked = true;
        action.spawn-sh =
          "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      "XF86AudioMicMute" = {
        allow-when-locked = true;
        action.spawn-sh =
          "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      };

      # Media.
      "XF86AudioPlay" = {
        allow-when-locked = true;
        action.spawn-sh = "playerctl play-pause";
      };

      "XF86AudioStop" = {
        allow-when-locked = true;
        action.spawn-sh = "playerctl stop";
      };

      "XF86AudioPrev" = {
        allow-when-locked = true;
        action.spawn-sh = "playerctl previous";
      };

      "XF86AudioNext" = {
        allow-when-locked = true;
        action.spawn-sh = "playerctl next";
      };

      # Brightness.
      "XF86MonBrightnessUp" = {
        allow-when-locked = true;
        action.spawn = [
          "brightnessctl"
          "--class=backlight"
          "set"
          "+10%"
        ];
      };

      "XF86MonBrightnessDown" = {
        allow-when-locked = true;
        action.spawn = [
          "brightnessctl"
          "--class=backlight"
          "set"
          "10%-"
        ];
      };

      "Mod+O" = {
        repeat = false;
        action.toggle-overview = [];
      };

      "Mod+Q" = {
        repeat = false;
        action.close-window = [];
      };

      # Focus.
      "Mod+H".action.focus-column-left = [];
      "Mod+J".action.focus-window-down = [];
      "Mod+K".action.focus-window-up = [];
      "Mod+L".action.focus-column-right = [];

      # Move windows/columns.
      "Mod+Shift+H".action.move-column-left = [];
      "Mod+Shift+J".action.move-window-down = [];
      "Mod+Shift+K".action.move-window-up = [];
      "Mod+Shift+L".action.move-column-right = [];

      "Mod+Home".action.focus-column-first = [];
      "Mod+End".action.focus-column-last = [];

      "Mod+Ctrl+Home".action.move-column-to-first = [];
      "Mod+Ctrl+End".action.move-column-to-last = [];

      # Monitor focus.
      "Mod+Ctrl+H".action.focus-monitor-left = [];
      "Mod+Ctrl+J".action.focus-monitor-down = [];
      "Mod+Ctrl+K".action.focus-monitor-up = [];
      "Mod+Ctrl+L".action.focus-monitor-right = [];

      # Move columns between monitors.
      "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [];
      "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = [];
      "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = [];
      "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [];

      # Move whole workspaces between monitors.
      "Mod+Shift+Ctrl+Left".action.move-workspace-to-monitor-left = [];
      "Mod+Shift+Ctrl+Right".action.move-workspace-to-monitor-right = [];

      # Workspace navigation.
      "Mod+U".action.focus-workspace-up = [];
      "Mod+I".action.focus-workspace-down = [];

      "Mod+Ctrl+U".action.move-column-to-workspace-up = [];
      "Mod+Ctrl+I".action.move-column-to-workspace-down = [];

      "Mod+Shift+U".action.move-workspace-up = [];
      "Mod+Shift+I".action.move-workspace-down = [];

      # Direct workspace access.
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;
      "Mod+Shift+6".action.move-column-to-workspace = 6;
      "Mod+Shift+7".action.move-column-to-workspace = 7;
      "Mod+Shift+8".action.move-column-to-workspace = 8;
      "Mod+Shift+9".action.move-column-to-workspace = 9;

      # Column management.
      "Mod+BracketLeft".action.consume-or-expel-window-left = [];
      "Mod+BracketRight".action.consume-or-expel-window-right = [];

      "Mod+Comma".action.consume-window-into-column = [];
      "Mod+Period".action.expel-window-from-column = [];

      "Mod+R".action.switch-preset-column-width = [];
      "Mod+Shift+R".action.switch-preset-column-width-back = [];

      "Mod+Ctrl+Shift+R".action.switch-preset-window-height = [];
      "Mod+Ctrl+R".action.reset-window-height = [];

      "Mod+F".action.maximize-column = [];
      "Mod+Shift+F".action.fullscreen-window = [];
      "Mod+M".action.maximize-window-to-edges = [];

      "Mod+Ctrl+F".action.expand-column-to-available-width = [];

      "Mod+C".action.center-column = [];
      "Mod+Ctrl+C".action.center-visible-columns = [];

      # Fine sizing.
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";

      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";

      # Floating/tabbed.
      "Mod+V".action.toggle-window-floating = [];
      "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = [];

      "Mod+W".action.toggle-column-tabbed-display = [];

      # Capture: shared commands with the system menu.
      "Print" = {
        hotkey-overlay.title = "Screenshot region";
        action.spawn = [ capture "screenshot" "region" ];
      };
      "Ctrl+Print" = {
        hotkey-overlay.title = "Screenshot screen";
        action.spawn = [ capture "screenshot" "screen" ];
      };
      "Alt+Print" = {
        hotkey-overlay.title = "Screenshot window";
        action.spawn = [ capture "screenshot" "window" ];
      };
      "Shift+Print" = {
        repeat = false;
        hotkey-overlay.title = "Toggle screen recording";
        action.spawn = [ capture "record" "toggle" ];
      };
      "Mod+Print" = {
        hotkey-overlay.title = "Pick a colour";
        action.spawn = [ capture "colour" ];
      };
      "Mod+Ctrl+Print" = {
        hotkey-overlay.title = "Copy text from region (OCR)";
        action.spawn = [ capture "ocr" ];
      };

      # Shortcut inhibitor escape hatch.
      "Mod+Escape" = {
        allow-inhibiting = false;
        action.toggle-keyboard-shortcuts-inhibit = [];
      };

      # Session.
      "Mod+Shift+E".action.quit = [];
      "Ctrl+Alt+Delete".action.quit = [];

      # "Mod+Shift+P".action.power-off-monitors = [];
    };
  };
}
