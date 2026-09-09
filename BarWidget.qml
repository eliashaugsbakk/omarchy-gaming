import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.elias.gaming"

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
    target: "io.github.elias.gaming"

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
    command: ["sh", "-c", "if command -v omarchy-gaming-toggle >/dev/null 2>&1; then omarchy-gaming-toggle; else if [ -f \"$HOME/.local/state/omarchy/toggles/gaming\" ]; then omarchy-toggle gaming off && hyprctl reload || true; omarchy-shell notifications setDnd off || true; omarchy toggle idle allow-idle || true; omarchy-powerprofiles-set autodetect power-saver || true; else omarchy-toggle gaming on && hyprctl reload || true; omarchy-shell notifications setDnd on || true; omarchy toggle idle stay-awake || true; omarchy-powerprofiles-set autodetect performance || true; fi; fi"]
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
