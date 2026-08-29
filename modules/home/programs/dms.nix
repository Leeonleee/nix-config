{ pkgs, inputs, ... }:

 {
   imports = [
     inputs.dms.homeModules.dank-material-shell
     inputs.dms.homeModules.niri
   ];

   # Preserve the old DMS theme and font defaults instead of overriding them
   # with the global Stylix theme.
   stylix.targets.dank-material-shell.enable = false;

   programs.dank-material-shell = {
     enable = true;

     systemd.enable = true;

     # Migrated from the old DMS configVersion 13 settings file to the current
     # configVersion 16 format. Values matching DMS defaults and obsolete or
     # machine-specific keys have been omitted.
     settings = {
       cornerRadius = 12;
       barElevationEnabled = false;
       controlCenterShowMicPercent = true;
       showWorkspaceName = true;
       appIdSubstitutions = [ ];
       appDrawerSectionViewModes.apps = "grid";
       networkPreference = "wifi";

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
           position = 0;
           screenPreferences = [ "all" ];
           showOnLastDisplay = true;

           leftWidgets = [
             {
               id = "launcherButton";
               enabled = true;
             }
             {
               id = "workspaceSwitcher";
               enabled = true;
             }
             {
               id = "music";
               enabled = true;
             }
           ];

           centerWidgets = [
             {
               id = "weather";
               enabled = true;
             }
             {
               id = "clock";
               enabled = true;
             }
             {
               id = "focusedWindow";
               enabled = true;
             }
           ];

           rightWidgets = [
             "systemTray"
             "clipboard"
             "cpuUsage"
             "memUsage"
             "notificationButton"
             "battery"
             "controlCenterButton"
           ];

           spacing = 4;
           innerPadding = 4;
           bottomGap = 0;
           transparency = 1;
           widgetTransparency = 1;
           squareCorners = false;
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

   # Home Manager replaces settings.json with a new symlink. DMS's file watcher
   # does not reliably notice that replacement, so restart it after changes.
   xdg.configFile."DankMaterialShell/settings.json".onChange = ''
     XDG_RUNTIME_DIR="/run/user/$UID" \
       ${pkgs.systemd}/bin/systemctl --user restart dms.service || true
   '';
 }
