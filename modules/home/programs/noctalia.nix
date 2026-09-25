{ config, pkgs, pkgsUnstable, ... }:

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
in
{
  # Compositor-independent shell configuration. Session wiring, such as
  # keybindings, lives in noctalia-hyprland.nix and noctalia-niri.nix.
  imports = [
    ../home-manager-unstable.nix
    ./noctalia-service.nix
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
          # Open panels beside the clicked bar widget instead of at the
          # bar's centre.
          open_near_click_control_center = true;
          open_near_click_launcher = true;
          open_near_click_clipboard = true;
          open_near_click_wallpaper = true;
          open_near_click_session = true;
        };
        # DMS app drawer grid view.
        launcher.app_grid = true;
        # Power menu. Noctalia replaces this list as a whole, so every entry is
        # listed; the last one mirrors DMS's restart-shell button.
        session.actions =
          let
            action = name: shortcut: {
              action = name;
              inherit shortcut;
              countdown_seconds = 0.0;
              enabled = true;
              variant = "default";
            };
          in
          [
            (action "lock" "1")
            (action "logout" "2")
            (action "lock_and_suspend" "3")
            (action "reboot" "4")
            (action "shutdown" "5" // { variant = "destructive"; })
            {
              action = "command";
              command = "${pkgs.systemd}/bin/systemctl --user restart noctalia";
              label = "Restart Noctalia";
              shortcut = "6";
              countdown_seconds = 0.0;
              enabled = true;
              variant = "default";
            }
          ];
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

      # Weather for the control center, located from the connection like DMS.
      weather.enabled = true;
      location.auto_locate = true;

      bar.main = {
        position = "left";
        # Floats clear of the screen edge; square, opaque and without elevation.
        background_opacity = opacity.desktop;
        radius = 0;
        # Gap between the bar and the left screen edge.
        margin_edge = 8;
        # Gap at the top and bottom ends of the vertical bar.
        margin_ends = 8;
        shadow = false;
        thickness = 38;
        padding = 8;
        widget_spacing = 6;
        # A square capsule behind each widget; spacers stay bare.
        capsule = true;
        # Matches the occupied workspace boxes (widget.workspaces.occupied_color).
        capsule_fill = "outline";
        capsule_radius = 0.0;
        capsule_padding = 8.0;

        # Spacers separate the top widgets.
        start = [ "control-center" "gap" "workspaces" "gap" "media" ];
        center = [ "clock" ];
        # Voxtype, recording, microphone and media appear only while active.
        end = [
          "tray"
          "voxtype"
          "recording"
          "gap"
          "volume"
          "microphone"
          "battery"
        ];
      };

      widget = {
        gap = {
          type = "spacer";
          length = 12;
        };
        # DMS showWorkspaceName; names come from Hyprland's defaultName.
        workspaces = {
          # One square box per workspace instead of a widget capsule around
          # them all.
          capsule = false;
          style = "regular";
          capsule_radius = 0.0;
          # Match the control center's capsule: 29px across (0.76 of the 38px
          # bar) and 32px long (16px glyph plus 8px padding each end). Pills
          # are 16px * scale across and pill_size times that long; pill_scale
          # tops out at 1.0, so the widget scale does the enlarging.
          scale = 1.8125;
          pill_scale = 1.0;
          active_pill_size = 1.1;
          inactive_pill_size = 1.1;
          # The first character of each name is its Nerd Font icon (see the
          # Niri and Hyprland workspace names). The 11px label also grows with
          # scale, so shrink it back to ~16px.
          label_source = "name";
          max_label_chars = 1;
          font_scale = 0.8;
          # Quieter than the default secondary accent: highlight only the
          # focused workspace.
          focused_color = "primary";
          occupied_color = "outline";
          empty_color = "surface_variant";
        };
        clock = {
          format = "{:%a %d %b  %H:%M}";
          vertical_format = "{:%H\n%M}";
          tooltip_format = "{:%A, %d %B %Y}";
        };
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
