import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "com.github.eliashaugsbakk.omarchy-gaming"

  property bool isGaming: false

  function toggle() {
    toggleProc.running = true
  }

  function checkState() {
    checkProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "com.github.eliashaugsbakk.omarchy-gaming"

    function toggle(): void {
      root.toggle()
    }

    function check(): void {
      root.checkState()
    }
  }

  Process {
    id: checkProc
    command: ["sh", "-c", "test -f \"$HOME/.local/state/omarchy/toggles/gaming\""]
    onExited: function(exitCode) {
      root.isGaming = (exitCode === 0)
    }
  }

  Process {
    id: toggleProc
    // Keep all state changes and safety checks in the project's toggle script.
    // The AUR package installs that script alongside this plugin.
    command: ["sh", "-c", "command -v omarchy-gaming-toggle >/dev/null 2>&1 && exec omarchy-gaming-toggle || { printf '%s\\n' 'omarchy-gaming-toggle is not installed' >&2; exit 127; }"]
    onExited: function(exitCode) {
      root.checkState()
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.checkState()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊴"
    active: root.isGaming
    useActiveColor: true
    activeColor: Color.urgent
    tooltipText: root.isGaming ? "Gaming Mode: Active (Click to disable)" : "Gaming Mode: Inactive (Click to enable)"
    slotSize: Style.bar.statusSlot

    onPressed: function(buttonCode) {
      root.toggle()
    }
  }
}
