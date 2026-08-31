{ ... }:

{
  system.primaryUser = "leonlee";

  users.users.leonlee = {
    name = "leonlee";
    home = "/Users/leonlee";
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = 6;
}