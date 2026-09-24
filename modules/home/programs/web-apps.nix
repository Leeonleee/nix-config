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
    let
      appId = "webapp-${id}";
    in lib.nameValuePair appId {
      name = app.name;
      type = "Application";
      terminal = false;
      categories = [ "Network" ];
      icon = "${app.icon}";
      settings.StartupWMClass = appId;
      exec = "${quoteExecArg "${pkgs.google-chrome}/bin/google-chrome"} ${quoteExecArg "--app=${app.url}"} ${quoteExecArg "--class=${appId}"}";
    }
  ) webApps;
}
