# System-menu sections for Noctalia, shared by the Hyprland and Niri sessions.
# `msg` builds a `noctalia msg` command line.
msg: [
  {
    label = "Noctalia";
    children = [
      { label = "Control center"; action = msg "panel-toggle control-center"; }
      { label = "Settings"; action = msg "settings-open"; }
      { label = "App launcher"; action = msg "panel-toggle launcher"; }
      { label = "Clipboard history"; action = msg "panel-toggle clipboard"; }
      { label = "Notifications"; action = msg "panel-toggle control-center notifications"; }
      { label = "Do Not Disturb (toggle)"; action = msg "notification-dnd-toggle"; }
    ];
  }
  {
    label = "Appearance / wallpaper";
    children = [
      { label = "Browse wallpapers"; action = msg "panel-toggle wallpaper"; }
    ];
  }
  {
    label = "Network / Bluetooth";
    children = [
      { label = "Network"; action = msg "panel-toggle control-center network"; }
      { label = "Bluetooth"; action = msg "panel-toggle control-center bluetooth"; }
    ];
  }
  {
    label = "Power";
    children = [
      { label = "Lock screen"; action = msg "session lock"; }
      # Noctalia's session panel owns log out, suspend, restart and shut down.
      { label = "Suspend / restart / shut down / log out"; action = msg "panel-toggle session"; }
    ];
  }
]
