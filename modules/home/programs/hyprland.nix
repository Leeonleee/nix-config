{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.hyprland;
  capture = lib.getExe config.programs.capture.package;
  # A single source for Hyprland's described bindings and the searchable viewer.
  binding = kind: mods: key: description: dispatcher: argument: {
    inherit kind mods key description dispatcher argument;
  };
  bind = binding "bindd";
  repeat = binding "binded";
  locked = binding "bindld";
  lockedRepeat = binding "bindeld";
  exec = mods: key: description: command: bind mods key description "exec" command;

  screenshot = pkgs.writeShellApplication {
    name = "hyprland-screenshot";
    runtimeInputs = [ pkgs.coreutils pkgs.grimblast ];
    text = ''
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      # Match Niri's screenshot-path naming.
      file="$directory/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
      grimblast --notify copysave "$1" "$file"
    '';
  };

  # Niri's switch-focus-between-floating-and-tiling.
  focusFloatingOrTiling = pkgs.writeShellApplication {
    name = "hyprland-focus-floating-or-tiling";
    runtimeInputs = [ pkgs.jq config.wayland.windowManager.hyprland.finalPackage ];
    text = ''
      if hyprctl -j activewindow | jq -e '.floating == true' > /dev/null; then
        hyprctl dispatch cyclenext tiled
      else
        hyprctl dispatch cyclenext floating
      fi
    '';
  };

  bindings = [
    # viewer only consumes labels, so this self-reference does not recurse.
    (exec "SUPER SHIFT" "slash" "Show keybindings" (lib.getExe viewer))
    (exec "SUPER" "Return" "Open terminal" "kitty")
    (exec "SUPER" "space" "Open Vicinae" "vicinae toggle")
  ] ++ cfg.shellBindings ++ [
    (exec "SUPER SHIFT" "space" "Open system menu" (lib.getExe config.programs.system-menu.package))
    (exec "SUPER" "T" "Open Dolphin" "dolphin")
    (locked "SUPER ALT" "S" "Toggle screen reader" "exec" "${pkgs.procps}/bin/pkill orca || exec orca")
    (bind "SUPER" "Q" "Close window" "killactive" "")
    # r-/r+ stay on the current monitor and include empty workspaces, like
    # Niri's per-monitor workspace strip.
    (bind "SUPER" "U" "Focus workspace up" "workspace" "r-1")
    (bind "SUPER" "I" "Focus workspace down" "workspace" "r+1")
    (bind "SUPER CTRL" "U" "Move window to workspace up" "movetoworkspace" "r-1")
    (bind "SUPER CTRL" "I" "Move window to workspace down" "movetoworkspace" "r+1")
    (bind "SUPER SHIFT CTRL" "Left" "Move workspace to left monitor" "movecurrentworkspacetomonitor" "l")
    (bind "SUPER SHIFT CTRL" "Right" "Move workspace to right monitor" "movecurrentworkspacetomonitor" "r")
    # Column management.
    (bind "SUPER" "bracketleft" "Consume or expel window left" "layoutmsg" "consume_or_expel prev")
    (bind "SUPER" "bracketright" "Consume or expel window right" "layoutmsg" "consume_or_expel next")
    (bind "SUPER" "comma" "Consume window into column" "layoutmsg" "consume")
    (bind "SUPER" "period" "Expel window from column" "layoutmsg" "promote")
    (bind "SUPER" "R" "Next preset column width" "layoutmsg" "colresize +conf")
    (bind "SUPER SHIFT" "R" "Previous preset column width" "layoutmsg" "colresize -conf")
    (bind "SUPER" "F" "Maximize column" "layoutmsg" "colresize 1.0")
    (bind "SUPER SHIFT" "F" "Fullscreen window" "fullscreen" "0")
    # Scrolling maximize gives the window its own full-width column.
    (bind "SUPER" "M" "Maximize window" "fullscreen" "1")
    (bind "SUPER" "C" "Center column" "layoutmsg" "center")
    (repeat "SUPER" "minus" "Decrease column width" "layoutmsg" "colresize -0.1")
    (repeat "SUPER" "equal" "Increase column width" "layoutmsg" "colresize +0.1")
    (repeat "SUPER SHIFT" "minus" "Decrease window height" "resizeactive" "0 -10%")
    (repeat "SUPER SHIFT" "equal" "Increase window height" "resizeactive" "0 10%")
    (bind "SUPER" "V" "Toggle floating" "togglefloating" "")
    (exec "SUPER SHIFT" "V" "Switch focus between floating and tiling" (lib.getExe focusFloatingOrTiling))
    (bind "SUPER" "W" "Toggle tabbed window group" "togglegroup" "")
    (exec "" "Print" "Screenshot region" "${lib.getExe screenshot} area")
    (exec "CTRL" "Print" "Screenshot focused output" "${lib.getExe screenshot} output")
    (exec "ALT" "Print" "Screenshot active window" "${lib.getExe screenshot} active")
    # Shared capture's screenshots and colour picker use Niri IPC; do not call
    # those branches here. OCR uses grim/slurp; recording uses the portal.
    (exec "SHIFT" "Print" "Toggle screen recording" "${capture} record toggle")
    (exec "SUPER CTRL" "Print" "Copy text from region (OCR)" "${capture} ocr")
    (exec "SUPER" "Print" "Pick and copy a colour" "${lib.getExe pkgs.hyprpicker} --autocopy")
    (bind "SUPER SHIFT" "E" "Exit Hyprland" "exit" "")
    (bind "CTRL ALT" "Delete" "Exit Hyprland" "exit" "")
    (bind "SUPER SHIFT" "P" "Turn off monitors (input wakes them)" "dpms" "off")
    (lockedRepeat "" "XF86AudioRaiseVolume" "Increase volume" "exec" "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0")
    (lockedRepeat "" "XF86AudioLowerVolume" "Decrease volume" "exec" "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-")
    (locked "" "XF86AudioMute" "Toggle audio mute" "exec" "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    (locked "" "XF86AudioMicMute" "Toggle microphone mute" "exec" "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    (lockedRepeat "" "XF86MonBrightnessUp" "Increase brightness" "exec" "${lib.getExe pkgs.brightnessctl} --class=backlight set +10%")
    (lockedRepeat "" "XF86MonBrightnessDown" "Decrease brightness" "exec" "${lib.getExe pkgs.brightnessctl} --class=backlight set 10%-")
  ] ++ lib.concatMap (direction: [
    (repeat "SUPER" direction.key "Focus ${direction.name}" "layoutmsg" "focus ${direction.arg}")
    (repeat "SUPER SHIFT" direction.key "Move ${direction.move}" direction.moveDispatcher direction.moveArg)
    (bind "SUPER CTRL" direction.key "Focus monitor ${direction.name}" "focusmonitor" direction.arg)
    (bind "SUPER SHIFT CTRL" direction.key "Move window to monitor ${direction.name}" "movewindow" "mon:${direction.arg}")
  ]) [
    # Horizontal moves swap whole columns, as Niri's move-column-left/right.
    { key = "H"; name = "left"; arg = "l"; move = "column left"; moveDispatcher = "layoutmsg"; moveArg = "swapcol l"; }
    { key = "J"; name = "down"; arg = "d"; move = "window down"; moveDispatcher = "movewindow"; moveArg = "d"; }
    { key = "K"; name = "up"; arg = "u"; move = "window up"; moveDispatcher = "movewindow"; moveArg = "u"; }
    { key = "L"; name = "right"; arg = "r"; move = "column right"; moveDispatcher = "layoutmsg"; moveArg = "swapcol r"; }
  ] ++ lib.concatMap (number: let n = toString number; in [
    (bind "SUPER" n "Go to workspace ${n}" "workspace" n)
    (bind "SUPER SHIFT" n "Move window to workspace ${n}" "movetoworkspace" n)
  ]) (lib.range 1 9) ++ map (media:
    locked "" media.key media.description "exec" "${lib.getExe pkgs.playerctl} ${media.command}"
  ) [
    { key = "XF86AudioPlay"; description = "Play or pause"; command = "play-pause"; }
    { key = "XF86AudioStop"; description = "Stop playback"; command = "stop"; }
    { key = "XF86AudioPrev"; description = "Previous track"; command = "previous"; }
    { key = "XF86AudioNext"; description = "Next track"; command = "next"; }
  ];

  labels = pkgs.writeText "hyprland-keybindings.txt" (lib.concatMapStringsSep "\n" (b:
    "${lib.optionalString (b.mods != "") "${b.mods} + "}${b.key}    ${b.description}"
  ) bindings + "\n");
  viewer = pkgs.writeShellApplication {
    name = "hyprland-keybindings";
    text = ''
      # Read-only: choosing a row never executes its associated command.
      ${lib.getExe pkgs.fuzzel} --dmenu --prompt='Keybindings: ' < ${labels} > /dev/null || true
    '';
  };
  bindingSettings = lib.genAttrs (lib.unique (map (b: b.kind) bindings)) (kind:
    map (b: "${b.mods}, ${b.key}, ${b.description}, ${b.dispatcher}, ${b.argument}")
      (builtins.filter (b: b.kind == kind) bindings)
  );
in
{
  options.desktop.hyprland = {
    shell = lib.mkOption {
      type = lib.types.enum [ "caelestia" "noctalia" ];
      description = ''
        Desktop shell started with Hyprland. Only the selected shell's service,
        keybindings and system-menu entries are enabled; both remain installed.
      '';
    };
    shellBindings = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      internal = true;
      description = "Bindings contributed by the selected shell module.";
    };
  };

  config = {
    home.packages = with pkgs; [ brightnessctl playerctl wl-clipboard fuzzel hyprpicker ];

    # Hyprland equivalent of the Niri system menu's capture section. The
    # selected shell module appends its own sections.
    programs.system-menu.sections.Hyprland = [
      {
        label = "Capture";
        children = [
          {
            label = "Screenshot";
            children = [
              { label = "Region"; action = "${lib.getExe screenshot} area"; }
              { label = "Window"; action = "${lib.getExe screenshot} active"; }
              { label = "Screen"; action = "${lib.getExe screenshot} output"; }
            ];
          }
          { label = "Screen recording (toggle)"; action = "${capture} record toggle"; }
          { label = "OCR region"; action = "${capture} ocr"; }
          { label = "Colour picker"; action = "${lib.getExe pkgs.hyprpicker} --autocopy"; }
        ];
      }
    ];

    systemd.user.services.hyprland-polkit-agent = {
      Unit = {
        Description = "PolicyKit authentication agent for Hyprland";
        Requisite = [ "hyprland-session.target" ];
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      # Keep described Hyprlang bindings even on HM versions defaulting to Lua.
      configType = "hyprlang";
      xwayland.enable = true;
      systemd = {
        enable = true;
        enableXdgAutostart = false;
      };
      # HM starts/stops hyprland-session.target. The selected Hyprland shell
      # must be attached to that target; DMS must be attached ONLY to
      # niri.service in its own module, not graphical-session.target (which
      # both compositors legitimately use).
      settings = {
        env = [ "NIXOS_OZONE_WL,1" ];
        # HM only restarts the session targets at login. Stop them on exit so
        # Restart= services such as Vicinae and EasyEffects do not crash-loop
        # without a display until the next login, each crash spawning DrKonqi.
        exec-shutdown = [
          "systemctl --user stop hyprland-session.target graphical-session.target"
        ];
        monitor = [ ",preferred,auto,1" ];
        input = {
          numlock_by_default = true;
          follow_mouse = 1;
          accel_profile = "flat";
          sensitivity = 0;
          touchpad = {
            tap-to-click = true;
            natural_scroll = true;
            scroll_factor = 0.3;
          };
        };
        general = {
          layout = "scrolling";
          # gaps_in applies to each window edge, so adjacent windows are 16px
          # apart, matching Niri's gaps = 16.
          gaps_in = 8;
          gaps_out = 16;
          border_size = 4;
          "col.active_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base0D}cc)";
          "col.inactive_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base03})";
          # Niri does not wrap or jump to another window at a layout edge.
          no_focus_fallback = true;
        };
        binds.window_direction_monitor_fallback = false;
        scrolling = {
          column_width = 0.5;
          explicit_column_widths = "0.333, 0.5, 0.667";
          # Niri's center-focused-column = "never": scroll just enough to fit.
          focus_fit_method = 1; # fit
          fullscreen_on_one_column = false;
          # Approximates Niri's focus-follows-mouse max-scroll-amount = "50%".
          follow_min_visible = 0.5;
          wrap_focus = false;
          wrap_swapcol = false;
        };
        decoration = {
          rounding = 0;
          shadow.enabled = false;
        };
        # Niri's named workspaces. Workspaces stack vertically, as in Niri.
        workspace = [
          "1, defaultName:browser, persistent:true"
          "2, defaultName:terminal, persistent:true"
          "3, defaultName:code, persistent:true"
          "4, defaultName:agents, persistent:true"
          "5, defaultName:social, persistent:true"
        ];
        windowrule = [
          "float on, match:class firefox$, match:title ^Picture-in-Picture$"
        ];
        # Niri-like touchpad: swipe horizontally along columns, vertically
        # between workspaces.
        gesture = [
          "3, horizontal, scrollMove"
          "3, vertical, workspace"
        ];
        # Roughly Niri's default durations (150-250ms) and ease-out curve.
        bezier = [ "easeOutExpo, 0.16, 1, 0.3, 1" ];
        animation = [
          "global, 1, 3, easeOutExpo"
          "windows, 1, 2.5, easeOutExpo"
          "windowsIn, 1, 1.5, easeOutExpo, popin 90%"
          "windowsOut, 1, 1.5, easeOutExpo, popin 90%"
          "border, 1, 2.5, easeOutExpo"
          "fade, 1, 1.5, easeOutExpo"
          "layers, 1, 2, easeOutExpo, fade"
          "workspaces, 1, 2.5, easeOutExpo, slidevert"
        ];
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
        };
        # Niri actions without a Hyprland equivalent are left unbound rather
        # than substituted: overview (Super+O), first/last column, move column
        # to first/last, window height presets, expand column to available
        # width, center visible columns, workspace reordering and the shortcut
        # inhibitor toggle. Directional monitor/workspace moves take ONE window,
        # not a whole column, and Super+F sets full width rather than toggling.
        # Super+P is supplied by the selected shell module.
      } // bindingSettings;
    };
  };
}
