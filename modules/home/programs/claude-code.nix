{ pkgsUnstable, ... }:

{
  programs.claude-code = {
    enable = true;
    package = pkgsUnstable.claude-code;

    settings = {
      attribution = {
        commit = "";
        pr = "";
      };
    };
  };
}
