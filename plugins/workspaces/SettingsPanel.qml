import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Panel de ajustes del widget de workspaces: un campo por workspace para
// elegir su icono.
//
// El campo acepta las dos formas en que uno tiene un icono a mano: pegado
// como glifo, o escrito como codepoint (`f121`, `U+F121`, `0xF121`). Un
// glifo de Nerd Font no se puede teclear, y un codepoint no se puede leer,
// así que las dos hacen falta. La vista previa a la derecha resuelve la duda
// antes de guardar.
//
// Los valores se escriben en la entrada del widget en shell.json, así que
// sobreviven al reinicio y se pueden editar a mano igual que el resto de la
// configuración de la barra.
Panel {
  id: root
  // Lo inyecta el widget anfitrión con el id que le dio la barra, para que
  // persistSettings escriba en la entrada correcta de shell.json sea cual sea
  // el nombre del clon. El IPC lo publica el widget, no este panel.
  manageIpc: false

  property var anchorItem: null

  // La barra identifica el panel por el widget montado en su slot, no por
  // este Panel anidado.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Inyectados por el widget: los ids a listar y el mapa efectivo actual.
  property var ids: []
  property var icons: ({})

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Color.muted
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Escribe primero en local para que el panel y la barra se redibujen en el
  // mismo gesto; la vuelta por shell.json llega con el mismo valor.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Un codepoint suelto o un glifo pegado.
  //
  // El primer carácter se saca con codePointAt y no con Array.from: el motor
  // JS de Qt parte los pares sustitutos por unidad UTF-16, así que un icono
  // del plano suplementario (los Material Design, U+F0000+) se quedaba en su
  // mitad alta y se dibujaba como tofu.
  function parseIcon(raw) {
    var value = String(raw || "").trim()
    if (value === "") return ""

    var hex = value.match(/^(?:u\+|0x|\\u)?([0-9a-f]{4,6})$/i)
    if (hex) {
      var cp = parseInt(hex[1], 16)
      if (cp > 0 && cp <= 0x10FFFF) return String.fromCodePoint(cp)
    }

    return String.fromCodePoint(value.codePointAt(0))
  }

  function setIcon(id, raw) {
    var next = {}
    for (var key in root.icons) if (root.icons[key]) next[key] = root.icons[key]

    var icon = parseIcon(raw)
    if (icon === "") delete next[String(id)]
    else next[String(id)] = icon

    persistSettings({ icons: next })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(6)

      PanelSectionHeader {
        width: parent.width
        text: "WORKSPACE ICONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        id: rows
        model: root.ids

        Row {
          required property var modelData
          width: column.width
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(16)
            text: modelData === 10 ? "0" : String(modelData)
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }

          TextField {
            id: field
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(16) - Style.space(28) - Style.space(16)
            text: root.icons[String(modelData)] || ""
            placeholderText: "glyph or f121"
            foreground: root.foreground
            verticalPadding: Style.space(3)
            onAccepted: root.setIcon(modelData, text)
            // Guarda también al salir del campo, para que tabular entre
            // varias filas no pierda lo escrito en la anterior.
            onActiveFocusChanged: {
              if (activeFocus) return
              // Solo guarda si de verdad cambió: un campo que todavía no
              // recibió su valor no puede borrar el icono al perder el foco.
              if (root.parseIcon(text) !== (root.icons[String(modelData)] || "")) root.setIcon(modelData, text)
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            text: root.parseIcon(field.text)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      Text {
        width: parent.width
        text: "Enter saves · empty clears · paste a glyph or type its hex"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
