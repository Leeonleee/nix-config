{ ... }:

{
  nixpkgs.config.allowUnfree = true;

  homebrew.enable = true;

  
  nix.settings = {
    experimental-features = [
        "nix-command"
        "flakes"
      ];

      extra-substituters = [
         "https://cache.numtide.com"
       ];

       extra-trusted-public-keys = [
         "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
       ];
  };
  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
}
