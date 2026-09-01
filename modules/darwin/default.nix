{ ... }:

{
  nixpkgs.config.allowUnfree = true;

  homebrew.enable = true;

  
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
}
