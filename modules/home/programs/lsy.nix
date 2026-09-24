{ pkgs, ... }:

{
  home.packages = pkgs.lib.optionals pkgs.stdenv.isLinux [
    (pkgs.callPackage ../../../packages/lsy { })
  ];
}
