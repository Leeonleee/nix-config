{ ... }:

{
  system.primaryUser = "leonlee";

  users.users.leonlee = {
    name = "leonlee";
    home = "/Users/leonlee";
  };

  nixpkgs.config.allowUnfree = true;

  homebrew.enable = true;

  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  system.stateVersion = 6;
}