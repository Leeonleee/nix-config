{
  imports = [
    ./packages.nix
    ../home-manager-unstable.nix
    ../../home/leonl/programs/zsh/zsh.nix
    ../../home/leonl/programs/fastfetch/fastfetch.nix
    ../../home/leonl/programs/neovim/neovim.nix
    ../../home/leonl/programs/kitty/kitty.nix
    ../../home/leonl/programs/starship/starship.nix
    ../../home/leonl/programs/eza/eza.nix
    ../../home/leonl/programs/herdr/herdr.nix
    ../../home/leonl/programs/pi/pi.nix
  ];

  home.username = "leonl";
  home.homeDirectory = "/home/leonl";

  home.stateVersion = "26.05";

  stylix.targets = {
    starship.enable = false;
    gtk.enable = false;
  };

  stylix.opacity = {
    terminal = 0.9;
  };

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
