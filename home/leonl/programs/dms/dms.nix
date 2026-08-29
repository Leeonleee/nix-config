{ inputs, ... }:

{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  programs.dank-material-shell = {
    enable = true;

    niri = {
      enableSpawn = true;
      enableKeybinds = false;

      includes.enable = false;
    };
  };
}
