{ config, lib, pkgs, ... }:

let
  cfg = config.services.dolphin-taildrop;
  nicknames = pkgs.writeText "taildrop-nicknames.json" (builtins.toJSON cfg.nicknames);
  sender = pkgs.writeShellApplication {
    name = "dolphin-taildrop";
    runtimeInputs = [ pkgs.python3 pkgs.tailscale pkgs.kdePackages.kdialog ];
    text = ''
      exec python3 ${./taildrop/send.py} ${nicknames} "$@"
    '';
  };
in
{
  options.services.dolphin-taildrop.nicknames = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = { "phone" = "My phone"; "ipad" = "My iPad"; };
    description = ''
      Taildrop display names keyed by Tailscale IP, full MagicDNS name, short
      MagicDNS name, or hostname (in that precedence order). Named devices
      appear first in the picker. Only online Taildrop targets are shown.
    '';
  };

  config = {
    home.packages = [ sender ];
    xdg.dataFile."kio/servicemenus/taildrop.desktop" = {
      executable = true;
      text = ''
        [Desktop Entry]
        Type=Service
        MimeType=application/octet-stream;
        X-KDE-Protocols=file
        Actions=taildrop;

        [Desktop Action taildrop]
        Name=Send with Taildrop…
        Icon=network-transmit
        Exec=${sender}/bin/dolphin-taildrop %F
      '';
    };
  };
}
