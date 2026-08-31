{ ... }:

{
  imports = [
    ../../modules/darwin
  ];

  system.primaryUser = "leonlee";

  users.users.leonlee = {
    name = "leonlee";
    home = "/Users/leonlee";
  };

  system.stateVersion = 6;
}
