{ pkgs, ... }:

let
  manifest = (pkgs.formats.json {}).generate "plugin.json" {
    id = "voxtypeStatus";
    name = "Voxtype Status";
    description = "Live push-to-talk recording and transcription status";
    version = "1.0.0";
    author = "leonl";
    type = "widget";
    capabilities = [ "dankbar-widget" ];
    component = "./Widget.qml";
    icon = "mic";
    permissions = [];
  };
  widget = pkgs.writeText "Widget.qml" ''
    import QtQuick
    import Quickshell.Io
    import qs.Common
    import qs.Widgets
    import qs.Modules.Plugins

    PluginComponent {
        id: root

        property string currentState: "stopped"
        readonly property string statusIcon: currentState === "recording" ? "mic"
            : currentState === "transcribing" ? "hourglass_top"
            : currentState === "idle" ? "keyboard_voice" : "mic_off"
        readonly property color statusColor: currentState === "recording" ? Theme.error
            : currentState === "transcribing" ? Theme.primary : Theme.surfaceText
        readonly property bool active: currentState === "recording" || currentState === "transcribing"

        // Only shown while listening or transcribing.
        onActiveChanged: setVisibilityOverride(active)
        Component.onCompleted: setVisibilityOverride(active)

        // Poll the daemon-aware status command rather than trusting a stale state file.
        Timer {
            interval: 500
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!statusProcess.running)
                    statusProcess.running = true;
            }
        }

        Process {
            id: statusProcess
            command: ["${pkgs.voxtype}/bin/voxtype", "status", "--format", "json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.currentState = JSON.parse(text).class || "stopped";
                    } catch (error) {
                        root.currentState = "stopped";
                    }
                }
            }
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0)
                    root.currentState = "stopped";
            }
        }

        horizontalBarPill: Component {
            DankIcon {
                name: root.statusIcon
                color: root.statusColor
                size: Theme.iconSize
            }
        }

        verticalBarPill: Component {
            DankIcon {
                name: root.statusIcon
                color: root.statusColor
                size: Theme.iconSize
            }
        }
    }
  '';
in
{
  programs.dank-material-shell = {
    # Generate plugin enablement even when the plugin has no custom settings.
    managePluginSettings = true;
    plugins.voxtypeStatus.src = pkgs.runCommand "dms-voxtype-status" {} ''
      mkdir -p "$out"
      cp ${manifest} "$out/plugin.json"
      cp ${widget} "$out/Widget.qml"
    '';
  };
}
