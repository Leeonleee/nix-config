
{ pkgs, ... }:

{
  programs.claude-code = {
    enable = true;

    settings = {
      attribution = {
        commit = "";
        pr = "";
      };
    };
  };
}
