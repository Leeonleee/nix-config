{ lib, pkgs, ... }:

let
  webApps = {
    chatgpt = {
      name = "ChatGPT";
      url = "https://chatgpt.com";
      icon = ./web-apps/icons/chatgpt.svg;
    };
    youtube = {
      name = "YouTube";
      url = "https://youtube.com";
      icon = ./web-apps/icons/youtube.svg;
    };
  };

  # Exec uses desktop-entry quoting, not shell quoting; literal % is %%.
  quoteExecArg = value:
    let
      quoted = builtins.replaceStrings
        [ "\\" "\"" "`" "$" "%" ]
        [ "\\\\" "\\\"" "\\`" "\\$" "%%" ]
        value;
      escaped = builtins.replaceStrings [ "\\" ] [ "\\\\" ] quoted;
    in ''"${escaped}"'';
in
{
  xdg.desktopEntries = lib.mapAttrs' (id: app:
    lib.nameValuePair "webapp-${id}" {
      name = app.name;
      type = "Application";
      terminal = false;
      categories = [ "Network" ];
      icon = "${app.icon}";
      exec = "${quoteExecArg "${pkgs.google-chrome}/bin/google-chrome"} ${quoteExecArg "--app=${app.url}"}";
    }
  ) webApps;
}
