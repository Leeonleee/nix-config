{ lib, ... }:

{
  options.desktop.niri.shell = lib.mkOption {
    type = lib.types.enum [ "dms" "noctalia" ];
    description = ''
      Desktop shell started with Niri. Only the selected shell's service,
      keybindings and system-menu entries are enabled; both remain installed.
    '';
  };
}
