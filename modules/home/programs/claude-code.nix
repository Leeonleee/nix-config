{ config, pkgsUnstable, ... }:

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
  home.file."${config.programs.claude-code.configDir}/settings.json".force = true;
}
