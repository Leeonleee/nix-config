{ pkgs, inputs, ... }:

 {
   imports = [
     inputs.dms.homeModules.dank-material-shell
     inputs.dms.homeModules.niri
   ];

   programs.dank-material-shell = {
     enable = true;

     systemd.enable = true;

     settings = {
       # clockFormat = "24h";
       enableFprint = true;
       loginctlLockIntegration = true;
       lockBeforeSuspend = true;

       acLockTimeout = 600;
       batteryLockTimeout = 300;

       acPostLockMonitorTimeout = 60;
       batteryPostLockMonitorTimeout = 30;

       lockScreenShowPasswordField = true;
       lockScreenShowPowerActions = true;
       lockScreenPowerOffMonitorsOnLock = false;
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
