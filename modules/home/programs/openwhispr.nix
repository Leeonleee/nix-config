{ inputs, ... }:

{
  home.packages = [
    inputs.openwhispr.packages.x86_64-linux.default
  ];
}