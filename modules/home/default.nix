{ pkgs, ... }:

{
  imports = [
    ../theme.nix
    ./home-manager-unstable.nix
    ./programs/zsh.nix
    ./programs/fastfetch.nix
    ./programs/neovim
    ./programs/kitty.nix
    ./programs/starship
    ./programs/eza.nix
    ./programs/herdr
    ./programs/pi.nix
  ];
  stylix.targets = {
    starship.enable = false;
    gtk.enable = false;
  };

  home.packages = with pkgs; [
    bitwarden-desktop
    google-chrome
    vscode
    lsof
  ];

  home.stateVersion = "26.05";

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Leon Lee";
        email = "leonlee20031219@gmail.com";
      };

      init.defaultBranch = "main";
    };
  };

  programs.vesktop.enable = true;
  programs.home-manager.enable = true;
}
