{ pkgs, inputs, ... }:

{
  imports = [
    ../theme.nix
    ./home-manager-unstable.nix
    ./profiles/universal-apps.nix
    ./programs/zsh.nix
    ./programs/fastfetch.nix
    ./programs/neovim
    ./programs/kitty.nix
    ./programs/starship
    ./programs/eza.nix
    ./programs/herdr.nix
    ./programs/pi.nix
    ./programs/claude-code.nix
  ];
  stylix.targets = {
    starship.enable = false;
    gtk.enable = false;
  };

  home.packages = with pkgs; [
    lsof
    gh
    usbutils
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

  programs.home-manager.enable = true;
}
