{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ../../../packages/lsy { })
  ];
}
