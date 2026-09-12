import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string currentState: "stopped"
    readonly property string statusLabel: {
        switch (currentState) {
        case "idle": return "Ready";
        case "recording": return "Recording";
        case "transcribing": return "Transcribing…";
        default: return "Stopped";
        }
    }
    readonly property string statusIcon: currentState === "recording" ? "mic"
        : currentState === "transcribing" ? "hourglass_top"
        : currentState === "idle" ? "keyboard_voice" : "mic_off"
    readonly property color statusColor: currentState === "recording" ? Theme.error
        : currentState === "transcribing" ? Theme.primary : Theme.surfaceText

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
        command: ["@voxtype@", "status", "--format", "json"]
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
        Row {
            spacing: Theme.spacingS
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.statusIcon
                color: root.statusColor
                size: Theme.iconSize
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Vox: " + root.statusLabel
                color: root.statusColor
                font.pixelSize: Theme.fontSizeMedium
            }
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
