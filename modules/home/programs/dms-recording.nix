{ config, lib, pkgs, ... }:

let
  capture = lib.getExe config.programs.capture.package;
  manifest = (pkgs.formats.json {}).generate "plugin.json" {
    id = "recordingStatus";
    name = "Recording Status";
    description = "Screen recording status; click to stop";
    version = "1.0.0";
    author = "leonl";
    type = "widget";
    capabilities = [ "dankbar-widget" ];
    component = "./Widget.qml";
    icon = "screen_record";
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

        property string currentState: "idle"
        property int elapsed: 0
        property string lastStatusError: ""
        readonly property bool active: currentState === "starting"
            || currentState === "recording" || currentState === "stopping"
        readonly property string duration: String(Math.floor(elapsed / 60)).padStart(2, "0")
            + ":" + String(elapsed % 60).padStart(2, "0")
        readonly property string statusLabel: stopProcess.running ? "Stopping…"
            : currentState === "recording" ? "Recording " + duration
            : currentState === "starting" ? "Starting…"
            : currentState === "stopping" ? "Stopping…"
            : currentState === "failed" ? "Recording failed"
            : currentState === "unavailable" ? "Recording status unavailable" : ""
        readonly property string statusIcon: currentState === "recording" && !stopProcess.running
            ? "fiber_manual_record"
            : (currentState === "failed" || currentState === "unavailable") ? "videocam_off" : "hourglass_top"
        readonly property color statusColor: currentState === "recording"
            ? "#ef4444" : Theme.surfaceVariantText

        // PluginComponent's public visibility override collapses both bar orientations.
        // Keep polling while hidden so a recording started by a keybinding appears.
        onCurrentStateChanged: setVisibilityOverride(currentState !== "idle")
        Component.onCompleted: setVisibilityOverride(currentState !== "idle")

        // PluginComponent runs a zero-argument pillClickAction on either bar orientation.
        // Never start recording from the widget, including after a failed status query.
        pillClickAction: () => {
            if ((root.active || root.currentState === "failed") && !stopProcess.running)
                stopProcess.running = true;
        }

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
            // Bound hung queries as well as guarding against overlapping polls.
            command: ["${lib.getExe' pkgs.coreutils "timeout"}", "--kill-after=1s", "3s",
                "${capture}", "record", "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const status = JSON.parse(text);
                        if (!["idle", "starting", "recording", "stopping", "failed", "unavailable"].includes(status.state)
                                || !Number.isInteger(status.elapsed) || status.elapsed < 0)
                            throw new Error("Invalid recording status");
                        root.elapsed = status.elapsed;
                        root.currentState = status.state;
                        if (status.state !== "unavailable")
                            root.lastStatusError = "";
                    } catch (error) {
                        root.elapsed = 0;
                        root.currentState = "unavailable";
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    const detail = text.trim();
                    // Retain the actual systemd error in DMS logs without
                    // spamming the same diagnostic on every 500 ms poll.
                    if (detail && detail !== root.lastStatusError) {
                        console.warn("Capture status: " + detail);
                        root.lastStatusError = detail;
                    }
                }
            }
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0 || exitStatus !== 0) {
                    root.elapsed = 0;
                    root.currentState = "unavailable";
                }
            }
        }

        Process {
            id: stopProcess
            command: ["${capture}", "record", "stop"]
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0 || exitStatus !== 0)
                    root.currentState = "failed";
                if (!statusProcess.running)
                    statusProcess.running = true;
            }
        }

        horizontalBarPill: Component {
            Row {
                spacing: Theme.spacingS
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.statusIcon
                    color: root.statusColor
                    size: root.iconSize
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusLabel
                    color: root.statusColor
                    font.pixelSize: root.textSize
                }
            }
        }

        verticalBarPill: Component {
            DankIcon {
                name: root.statusIcon
                color: root.statusColor
                size: root.iconSize
            }
        }
    }
  '';
in
{
  programs.dank-material-shell = {
    managePluginSettings = true;
    plugins.recordingStatus.src = pkgs.runCommand "dms-recording-status" {} ''
      mkdir -p "$out"
      cp ${manifest} "$out/plugin.json"
      cp ${widget} "$out/Widget.qml"
    '';
  };
}
