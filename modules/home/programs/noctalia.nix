{ config, pkgsUnstable, ... }:

let
  colours = config.lib.stylix.colors.withHashtag;
  inherit (config.stylix) opacity;
  # Stylix's noctalia-shell target only supports Noctalia v4. Use its Base16
  # role mapping for a v5 custom palette until Stylix supports v5.
  palette = with colours; {
    mPrimary = base0D;
    mOnPrimary = base00;
    mSecondary = base0E;
    mOnSecondary = base00;
    mTertiary = base0C;
    mOnTertiary = base00;
    mError = base08;
    mOnError = base00;
    mSurface = base00;
    mOnSurface = base05;
    mSurfaceVariant = base01;
    mOnSurfaceVariant = base04;
    mOutline = base03;
    mShadow = base00;
    mHover = base0C;
    mOnHover = base00;
    # Required by the palette format; templates that use it are disabled below.
    terminal = {
      background = base00;
      foreground = base05;
      cursor = base05;
      cursorText = base00;
      selectionBg = base02;
      selectionFg = base05;
      normal = {
        black = base00;
        red = base08;
        green = base0B;
        yellow = base0A;
        blue = base0D;
        magenta = base0E;
        cyan = base0C;
        white = base05;
      };
      bright = {
        black = base03;
        red = base08;
        green = base0B;
        yellow = base0A;
        blue = base0D;
        magenta = base0E;
        cyan = base0C;
        white = base07;
      };
    };
  };
  wallpapers = ../../../assets/wallpapers;
  # Restrained rounding for the bar's widget capsules.
  capsuleGroup = id: members: {
    inherit id members;
    fill = "surface_variant";
    radius = 6.0;
    padding = 8.0;
  };
in
{
  # Compositor-independent shell configuration. Session wiring, such as the
  # Hyprland service and keybindings, lives in noctalia-hyprland.nix.
  imports = [
    ../home-manager-unstable.nix
    ./noctalia-status.nix
  ];

  programs.noctalia = {
    enable = true;
    # Matches the v5 module and documentation from Home Manager unstable.
    package = pkgsUnstable.noctalia;

    # Without a light variant, Noctalia uses this palette in both modes.
    customPalettes.stylix.dark = palette;

    # GUI changes are written to ~/.local/state/noctalia/settings.toml and
    # override these values; delete that file to return to this config.
    # The layout follows programs/dms.nix.
    settings = {
      theme = {
        mode = if config.stylix.polarity == "light" then "light" else "dark";
        source = "custom";
        custom_palette = "stylix";
        # Stylix owns application themes.
        templates = {
          enable_builtin_templates = false;
          enable_community_templates = false;
        };
      };

      shell = {
        font_family = config.stylix.fonts.sansSerif.name;
        # DMS cornerRadius = 0 and Hyprland's square windows.
        corner_radius_scale = 0.0;
        # Apps launched from the shell must survive a service restart after a
        # rebuild. Ignored if Noctalia is not running as a user unit.
        launch_apps_as_systemd_services = true;
        panel = {
          transparency_mode = "solid";
          shadow = false;
        };
        # DMS app drawer grid view.
        launcher.app_grid = true;
      };

      wallpaper = {
        enabled = true;
        # DMS wallpaperFillMode = "Fill".
        fill_mode = "crop";
        # The wallpaper picker browses the repository wallpapers.
        directory = "${wallpapers}";
        default.path = "${wallpapers}/solar-system-minimal.png";
      };

      # DMS enableFprint and lockBeforeSuspend. Noctalia authenticates with the
      # existing "login" PAM stack.
      lockscreen = {
        fingerprint = true;
        lock_before_suspend = true;
      };

      notification.background_opacity = opacity.popups;
      osd.background_opacity = opacity.popups;

      # DMS weather widget, located from the connection like DMS.
      weather.enabled = true;
      location.auto_locate = true;

      bar.main = {
        position = "left";
        # DMS: full-length, square, opaque and without elevation.
        background_opacity = opacity.desktop;
        radius = 0;
        margin_ends = 0;
        margin_edge = 0;
        shadow = false;
        thickness = 38;
        padding = 8;
        widget_spacing = 6;
        capsule = true;
        capsule_fill = "surface_variant";
        capsule_radius = 6.0;
        capsule_padding = 8.0;

        start = [ "launcher" "workspaces" "media" ];
        center = [ "group:time" "active_window" ];
        end = [ "group:tray" "group:status" "control-center" "notifications" ];

        # Related widgets share one capsule; DMS's control center button
        # likewise groups network, Bluetooth and audio.
        capsule_group = [
          (capsuleGroup "time" [ "weather" "clock" ])
          (capsuleGroup "tray" [ "tray" "voxtype" "recording" "clipboard" ])
          (capsuleGroup "status" [ "network" "bluetooth" "volume" "microphone" "battery" ]
            // { widget_spacing = 15; })
        ];
      };

      widget = {
        # DMS showWorkspaceName; names come from Hyprland's defaultName.
        workspaces = {
          capsule = false;
          # Workspace initials; full names do not fit a vertical bar.
          label_source = "name";
          max_label_chars = 1;
          # Quieter than the default secondary accent: highlight only the
          # focused workspace.
          focused_color = "primary";
          occupied_color = "outline";
          empty_color = "surface_variant";
        };
        active_window = {
          capsule = false;
          max_length = 320;
        };
        clock = {
          format = "{:%a %d %b  %H:%M}";
          vertical_format = "{:%H\n%M}";
          tooltip_format = "{:%A, %d %B %Y}";
        };
        weather.show_condition = false;
        network.show_label = false;
        # DMS keeps hidden tray items behind an expansion chevron; Noctalia's
        # drawer holds every item that is not pinned.
        tray.drawer = true;
        media.hide_when_no_media = true;
        # Microphone state, shown only while an application is recording.
        microphone = {
          type = "volume";
          device = "input";
          hide_when_inactive = true;
        };
      };
    };
  };
}
