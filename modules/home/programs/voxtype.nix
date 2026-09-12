{ pkgs, lib, config, ... }:

let
  settings = {
    state_file = "auto";
    hotkey = {
      key = "RIGHTALT";
      modifiers = [];
      mode = "push_to_talk";
    };
    audio = {
      device = "default";
      sample_rate = 16000;
      max_duration_secs = 60;
    };
    whisper = {
      model = "base.en";
      language = "en";
      translate = false;
    };
    output = {
      mode = "type";
      driver_order = [ "wtype" "ydotool" "clipboard" ];
      fallback_to_clipboard = true;
      wait_for_modifier_release = true;
      auto_submit = false;
      type_delay_ms = 0;
      notification = {
        on_recording_start = false;
        on_recording_stop = false;
        on_transcription = false;
      };
    };
  };
  configFile = (pkgs.formats.toml {}).generate "voxtype-config.toml" settings;
in
{
  home.packages = with pkgs; [
    voxtype
    wtype
    wl-clipboard
  ];

  # Models remain writable user data; download base.en once on each machine.
  xdg.configFile."voxtype/config.toml".source = configFile;

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype push-to-talk voice-to-text daemon";
      Documentation = [ "https://voxtype.io" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      X-Restart-Triggers = [ "${configFile}" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.voxtype} --config ${config.xdg.configHome}/voxtype/config.toml daemon";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "XDG_RUNTIME_DIR=%t"
        "PATH=${lib.makeBinPath [ pkgs.wtype pkgs.ydotool pkgs.wl-clipboard ]}:/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
