{ pkgs, ... }:

{
  programs.starship = {
    enable = true;

    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  xdg.configFile."starship.toml".source = ./starship.toml;
}
