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
  property var labels: ({})

  // Rejilla de iconos comunes, para que el caso normal sea un click y no un
  // viaje al cheat sheet de Nerd Fonts. Van como codepoint y no como glifo
  // literal: los caracteres de la Private Use Area no sobreviven a todas las
  // tuberías de texto y una lista de ellos se lee como una columna de vacíos.
  // Todos verificados contra la fuente que trae Omarchy.
  readonly property var presetIcons: [
    0xF120, 0xF121, 0xE73C, 0xE74E, 0xE7BA, 0xF1D3, 0xF09B, 0xF296,
    0xF268, 0xF269, 0xF086, 0xF198, 0xF066F, 0xF099, 0xF0E0, 0xF292,
    0xF001, 0xF1BC, 0xF03D, 0xF11B, 0xF1B6, 0xF030, 0xF03E, 0xF1FC,
    0xF07B, 0xF02D, 0xF040, 0xF073, 0xF017, 0xF002, 0xF188, 0xF080,
    0xF1C0, 0xF233, 0xF0C2, 0xE7B0, 0xF17C, 0xF179, 0xF17A, 0xF17B,
    0xF015, 0xF013, 0xF023, 0xF0C3, 0xF135, 0xF0F4, 0xF005, 0xF04B
  ]

  // Con nueve campos en pantalla, una rejilla por campo no cabe: hay una sola
  // abajo y escribe en la fila que tenga el foco. `fields` guarda la
  // referencia de cada campo, que es la única forma de alcanzarlo desde
  // fuera del delegado del Repeater.
  property var fields: ({})
  property int activeRow: -1

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

  function setLabel(id, raw) {
    var next = {}
    for (var key in root.labels) if (root.labels[key]) next[key] = root.labels[key]

    var text = String(raw || "").trim()
    if (text === "") delete next[String(id)]
    else next[String(id)] = text

    persistSettings({ labels: next })
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
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(6)

      PanelSectionHeader {
        width: parent.width
        text: "WORKSPACE LABELS"
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
            // Estrecho a propósito: aquí solo cabe un glifo, y darle más
            // ancho invitaría a escribir un nombre en el campo equivocado.
            width: Style.space(86)
            text: root.icons[String(modelData)] || ""
            placeholderText: "icon"
            foreground: root.foreground
            verticalPadding: Style.space(3)
            Component.onCompleted: root.fields[String(modelData)] = field
            onAccepted: root.setIcon(modelData, text)
            onActiveFocusChanged: {
              // Al ganar el foco, esta fila pasa a ser el destino de la
              // rejilla de abajo.
              if (activeFocus) {
                root.activeRow = modelData
                return
              }
              // Al perderlo, guarda lo escrito — así tabular entre filas no
              // pierde lo de la anterior. Solo si de verdad cambió: un campo
              // que todavía no recibió su valor no puede borrar el icono.
              if (root.parseIcon(text) !== (root.icons[String(modelData)] || "")) root.setIcon(modelData, text)
            }
          }

          TextField {
            id: labelField
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(16) - Style.space(86) - Style.space(28) - Style.space(24)
            text: root.labels[String(modelData)] || ""
            placeholderText: "label"
            foreground: root.foreground
            verticalPadding: Style.space(3)
            onAccepted: root.setLabel(modelData, text)
            onActiveFocusChanged: {
              if (activeFocus) return
              if (text.trim() !== (root.labels[String(modelData)] || "")) root.setLabel(modelData, text)
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

      Grid {
        id: presets
        width: parent.width
        columns: 8
        spacing: Style.space(2)

        readonly property real cell: Math.floor((width - spacing * (columns - 1)) / columns)

        Repeater {
          model: root.presetIcons

          Rectangle {
            required property var modelData
            readonly property string glyph: String.fromCodePoint(modelData)
            readonly property bool current: root.activeRow > 0
              && (root.icons[String(root.activeRow)] || "") === glyph

            width: presets.cell
            height: presets.cell
            radius: Style.cornerRadius
            color: current
              ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              : (hover.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: parent.glyph
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
            }

            HoverHandler { id: hover }
            TapHandler {
              // Escribe y guarda en el mismo gesto: aquí no hay un Enter que
              // cierre el panel como en un formulario de un solo campo, y un
              // click que solo rellenara obligaría a volver al teclado.
              onTapped: {
                if (root.activeRow <= 0) return
                var f = root.fields[String(root.activeRow)]
                if (f) f.text = parent.glyph
                root.setIcon(root.activeRow, parent.glyph)
              }
            }
          }
        }
      }

      Text {
        width: parent.width
        text: "Icon: pick below, or type a glyph / hex · Label: free text · Enter saves"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
