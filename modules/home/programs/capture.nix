{ config, lib, pkgs, ... }:

let
  tools = {
    niri = lib.getExe config.programs.niri.package;
    recorder = lib.getExe pkgs.gpu-screen-recorder;
    rofi = lib.getExe config.programs.rofi.finalPackage;
    pactl = "${pkgs.pulseaudio}/bin/pactl";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    notify = "${pkgs.libnotify}/bin/notify-send";
    slurp = lib.getExe pkgs.slurp;
    grim = lib.getExe pkgs.grim;
    tesseract = lib.getExe pkgs.tesseract;
    zbar = "${pkgs.zbar}/bin/zbarimg";
    clipboard = "${pkgs.wl-clipboard}/bin/wl-copy";
    videos = "${pkgs.xdg-user-dirs}/bin/xdg-user-dir";
  };
  source = pkgs.writeText "capture.py" (
    "TOOLS = ${builtins.toJSON tools}\n" + builtins.readFile ./capture/capture.py
  );
  capture = pkgs.writeShellApplication {
    name = "capture";
    text = ''
      exec ${lib.getExe pkgs.python3} ${source} "$@"
    '';
  };
in
{
  options.programs.capture.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Niri capture command used by keybindings and session menus.";
  };

  config = {
    programs.capture.package = capture;
    home.packages = [ capture ];

    # Deliberately not enabled at login: the CLI starts this on demand.
    systemd.user.services.capture-record = {
      Unit = {
        Description = "Portal-selected GPU screen recording";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${lib.getExe capture} _record-worker";
        # Only the supervisor gets SIGINT; it forwards it once to its child.
        KillMode = "mixed";
        KillSignal = "SIGINT";
        TimeoutStopSec = 30;
        Restart = "no";
        UMask = "0077";
      };
    };
  };
}
