{
  imports = [
    ../programs/niri.nix
    ../programs/niri-keybinds.nix
    ../programs/capture.nix
    ../programs/dms.nix
    ../programs/noctalia.nix
    ../programs/noctalia-niri.nix
    ../programs/system-menu.nix
  ];

  # Shell started with Niri: "dms" or "noctalia". Both stay installed; only
  # the selected one runs and owns the shell keybindings.
  desktop.niri.shell = "noctalia";
}
