{ config, lib, pkgs, inputs, ... }:

let
  selected = config.desktop.niri.shell == "dms";
  dms = args: lib.escapeShellArgs ([ (lib.getExe config.programs.dank-material-shell.package) "ipc" "call" ] ++ args);
  colours = config.lib.stylix.colors.withHashtag;
  spacer = {
    id = "spacer";
    enabled = true;
    size = 4;
  };
  # The control center button with every status icon off shows a single
  # settings icon; enable individual icons through `icons`.
  controlCenterIconOnly = icons: {
    id = "controlCenterButton";
    enabled = true;
    showNetworkIcon = false;
    showVpnIcon = false;
    showBluetoothIcon = false;
    showAudioIcon = false;
    showScreenSharingIcon = false;
  } // icons;
in
{
  imports = [
    ./dms-voxtype.nix
    ./dms-recording.nix
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  config = lib.mkIf selected {
    # Follow the shared palette and fonts while retaining the session wallpaper.
    stylix.targets.dank-material-shell.enable = true;

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
      systemd.target = "niri.service";
      session.wallpaperPath = "${../../../assets/wallpapers/solar-system-minimal.png}";
      # DMS uses Id::ToolTip title when the title differs from the ID.
      # Hidden items remain accessible through the tray's expansion chevron.
      session.hiddenTrayIds = [
        "Claude_status_icon_1::Claude"
        "vesktop_status_icon_1::Vesktop"
        "Easy Effects"
        "dev.deedles.Trayscale"
      ];

      # Migrated from the old DMS configVersion 13 settings file to the current
      # configVersion 16 format. Values matching DMS defaults and obsolete or
      # machine-specific keys have been omitted.
      settings = {
        wallpaperFillMode = "Fill";
        # Square bar, widget pills and workspace boxes everywhere.
        radiusMode = "fixed";
        fixedRadius = 0;
        # Widget pills use the card surface; match Noctalia's surface_variant.
        cardSurfaceColor = "surfaceVariant";
        barElevationEnabled = false;
        controlCenterShowMicPercent = true;
        appIdSubstitutions = [ ];
        appDrawerSectionViewModes.apps = "grid";
        networkPreference = "wifi";
        systemTrayIconTintMode = "monochrome";

        cursorSettings = {
          theme = "System Default";
          size = 24;

          niri = {
            hideWhenTyping = false;
            hideAfterInactiveMs = 0;
          };

          hyprland = {
            hideOnKeyPress = false;
            hideOnTouch = false;
            inactiveTimeout = 0;
          };

          dwl.cursorHideTimeout = 0;
        };

        osdPowerProfileEnabled = true;
        closeNiriOverviewOnWindowFocus = true;

        barConfigs = [
          {
            id = "default";
            name = "Main Bar";
            enabled = true;
            # Left edge (0 top, 1 bottom, 2 left, 3 right).
            position = 2;
            screenPreferences = [ "all" ];
            showOnLastDisplay = true;

            # Mirrors the Noctalia bar in noctalia.nix. On a vertical bar the
            # left, center and right lists are the top, middle and bottom.
            # Spacers add to the 4px pill gap on each side, so size 4 is a
            # ~12px gap.
            leftWidgets = [
              (controlCenterIconOnly { })
              spacer
              {
                id = "workspaceSwitcher";
                enabled = true;
                # Name initials; DMS truncates names on a vertical bar.
                showWorkspaceName = true;
                # Highlight only the focused workspace; occupied boxes use the
                # outline colour, empty ones stay faint.
                workspaceOccupiedColorMode = "custom";
                workspaceOccupiedCustomColor = colours.base03;
              }
              spacer
              # Hidden while no media player exists.
              {
                id = "music";
                enabled = true;
              }
            ];

            centerWidgets = [
              {
                id = "clock";
                enabled = true;
                clockCompactMode = true;
              }
            ];

            rightWidgets = [
              {
                id = "systemTray";
                enabled = true;
                trayUseInlineExpansion = true;
              }
              # Shown only while active.
              {
                id = "voxtypeStatus";
                enabled = true;
              }
              {
                id = "recordingStatus";
                enabled = true;
              }
              spacer
              # DMS has no standalone volume widget: a second control center
              # button showing only the audio icon scrolls the volume.
              (controlCenterIconOnly { showAudioIcon = true; })
              # Microphone (or camera/screen share) in use; hidden otherwise.
              {
                id = "privacyIndicator";
                enabled = true;
              }
              {
                id = "battery";
                enabled = true;
              }
            ];

            # Floats 8px from the left edge and the top and bottom ends;
            # innerPadding 2 gives the 38px Noctalia bar thickness.
            spacing = 8;
            innerPadding = 2;
            bottomGap = 0;
            transparency = 1;
            widgetTransparency = 1;
            squareCorners = true;
            noBackground = false;
            maximizeWidgetIcons = false;
            maximizeWidgetText = false;
            removeWidgetPadding = false;
            widgetPadding = 8;
            gothCornersEnabled = false;
            gothCornerRadiusOverride = false;
            gothCornerRadiusValue = 12;
            borderEnabled = false;
            borderColor = "surfaceText";
            borderOpacity = 1;
            borderThickness = 1;
            widgetOutlineEnabled = false;
            widgetOutlineColor = "primary";
            widgetOutlineOpacity = 1;
            widgetOutlineThickness = 1;
            fontScale = 1;
            iconScale = 1;
            autoHide = false;
            autoHideDelay = 250;
            showOnWindowsOpen = false;
            openOnOverview = false;
            visible = true;
            popupGapsAuto = true;
            popupGapsManual = 4;
            maximizeDetection = true;
            scrollEnabled = true;
            scrollXBehavior = "column";
            scrollYBehavior = "workspace";
            shadowIntensity = 0;
            shadowOpacity = 60;
            shadowColorMode = "text";
            shadowCustomColor = "#000000";
            clickThrough = false;

          }
        ];

        builtInPluginSettings.dms_settings_search.trigger = "?";

        enableFprint = true;
        loginctlLockIntegration = true;
        lockBeforeSuspend = true;

        acLockTimeout = 0;
        batteryLockTimeout = 0;

        acPostLockMonitorTimeout = 60;
        batteryPostLockMonitorTimeout = 30;

        lockScreenShowPasswordField = true;
        lockScreenShowPowerActions = true;
        lockScreenPowerOffMonitorsOnLock = false;

        configVersion = 16;
      };

      niri = {
        enableSpawn = false;
        enableKeybinds = false;
        includes.enable = false;
      };
    };

    # Do not allow activation/manual service starts to launch DMS outside Niri.
    systemd.user.services.dms.Unit.Requisite = [ "niri.service" ];

    # Home Manager replaces settings.json with a new symlink. DMS's file watcher
    # does not reliably notice that replacement, so restart it after changes.
    xdg.configFile."DankMaterialShell/settings.json".onChange = ''
      XDG_RUNTIME_DIR="/run/user/$UID" \
        ${pkgs.systemd}/bin/systemctl --user try-restart dms.service || true
    '';

    programs.niri.settings.binds = {
      "Mod+Shift+Slash".action.spawn = [ "dms" "ipc" "call" "keybinds" "toggle" "niri" ];
      "Super+Alt+L" = {
        hotkey-overlay.title = "Lock the Screen: DMS";
        action.spawn = [ "dms" "ipc" "call" "lock" "lock" ];
      };
      "Mod+P".action.spawn = [ "dms" "ipc" "call" "control-center" "toggle" ];
    };

    programs.system-menu.sections.niri = lib.mkAfter [
      {
        label = "DMS settings";
        children = [
          { label = "All settings"; action = dms [ "settings" "open" ]; }
          { label = "Control center"; action = dms [ "control-center" "open" ]; }
          { label = "Bar appearance"; action = dms [ "settings" "openWith" "dankbar_appearance" ]; }
        ];
      }
      {
        label = "Appearance / wallpaper";
        children = [
          { label = "Browse wallpapers"; action = dms [ "dash" "open" "wallpaper" ]; }
          { label = "Wallpaper settings"; action = dms [ "settings" "openWith" "personalization" ]; }
          { label = "Theme and colors"; action = dms [ "settings" "openWith" "theme" ]; }
          { label = "Interface appearance"; action = dms [ "settings" "openWith" "theme_surfaces" ]; }
        ];
      }
      {
        label = "Network / Bluetooth";
        children = [
          { label = "Network"; action = dms [ "control-center" "openWith" "network" ]; }
          { label = "Bluetooth"; action = dms [ "control-center" "openWith" "bluetooth" ]; }
          { label = "Network settings"; action = dms [ "settings" "openWith" "network" ]; }
        ];
      }
      {
        label = "Power";
        children = [
          { label = "Lock screen"; action = dms [ "lock" "lock" ]; }
          # DMS owns power actions, confirmation, and lock-before-suspend.
          { label = "Suspend / restart / shut down / log out"; action = dms [ "powermenu" "open" ]; }
        ];
      }
    ];
  };
}
