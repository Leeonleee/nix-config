{ config, lib, pkgs, ... }:

{
  options.programs.lsy.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    default = pkgs.callPackage ../../../packages/lsy { };
    description = "The lsy CLI, for modules that reference it by store path.";
  };

  config.home.packages = lib.optionals pkgs.stdenv.isLinux [ config.programs.lsy.package ];
}
