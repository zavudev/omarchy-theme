import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  // `moduleName` se deja sin valor a propósito: la barra inyecta el id real de
  // la entrada de shell.json al montar el widget. Fijarlo aquí ataría el
  // fichero a un nombre de usuario concreto — `omarchy plugin clone` crea el
  // plugin como `<usuario>.workspaces` — y el panel guardaría los ajustes en
  // la entrada equivocada al copiarlo a otra máquina.

  // Iconos por defecto, uno por workspace, en el orden en que los uso.
  //
  // Se guardan como codepoint y no como glifo literal: los caracteres de la
  // Private Use Area no sobreviven a todas las tuberías de texto, y un fichero
  // que se ve vacío en un editor es imposible de revisar. Aquí el número dice
  // exactamente qué glifo es y se puede buscar en el catálogo de Nerd Fonts.
  //
  // Cualquier entrada `icons` en shell.json — la que escribe el panel de
  // ajustes — pisa estos valores, así que esto es solo el punto de partida.
  readonly property var defaultIcons: ({
    1: 0xF121,      // Coding    · nf-fa-code </>
    2: 0xF268,      // Chrome    · nf-fa-chrome
    3: 0xF120,      // Terminals · nf-fa-terminal >_
    4: 0xF066F,     // Discord   · nf-md-discord
    5: 0xF099,      // X/Twitter · nf-fa-twitter
    6: 0xF0E0,      // Email     · nf-fa-envelope
    7: 0xF1BC,      // Spotify   · nf-fa-spotify
    8: 0xF1B6,      // Steam     · nf-fa-steam
    9: 0xF292       // IRC       · nf-fa-hashtag (el # de los canales)
  })

  // Los defectos llegan como número, lo guardado por el panel como cadena.
  function glyphOf(value) {
    if (typeof value === "number") return value > 0 ? String.fromCodePoint(value) : ""
    return String(value || "")
  }

  readonly property var workspaceIcons: {
    var merged = {}
    for (var id in root.defaultIcons) merged[String(id)] = root.glyphOf(root.defaultIcons[id])

    var stored = root.settings ? root.settings.icons : null
    if (stored) {
      for (var key in stored) {
        // Una cadena vacía guardada es "sin icono", no "usa el defecto":
        // si no, borrar uno desde el panel no tendría efecto.
        merged[String(key)] = root.glyphOf(stored[key])
      }
    }
    return merged
  }

  // Un workspace sin icono asignado — el 10, o cualquiera que aparezca de
  // más — se queda solo con su número.
  function iconFor(id) {
    return root.workspaceIcons[String(id)] || ""
  }

  // El número es la tecla que hay que pulsar, así que va delante del icono:
  // el icono dice para qué es el workspace, el número dice cómo llegar.
  function numberFor(id) {
    return id === 10 ? "0" : String(id)
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    // El original fijaba [1..5] y sumaba del 6 al 10 solo si ya existían, así
    // que los workspaces vacíos no aparecían en la barra. Acá quedan fijos del
    // 1 al 9: se ven siempre, ocupados o no. El 10 (tecla 0) se sigue sumando
    // solo si existe, igual que antes.
    var ids = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---- Panel de ajustes. La barra enruta shell.summon/hide/toggle mirando
  //      open/close/opened en la raíz del widget, así que van aquí y no en el
  //      Panel anidado.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = root
    if ("hostWidget" in target) target.hostWidget = root
    if ("moduleName" in target) target.moduleName = root.moduleName
    // El orden importa: asignar `ids` construye los delegados del Repeater en
    // el acto, así que `icons` tiene que llegar antes o los campos nacen
    // vacíos y el primer foco perdido los guardaría así.
    if ("icons" in target) target.icons = root.workspaceIcons
    if ("ids" in target) target.ids = root.workspaceIds()
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("SettingsPanel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    // El id llega inyectado por la barra, después de crearse este handler:
    // sin la guarda se registraría con target vacío y quedaría inoperante.
    enabled: root.moduleName !== ""
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: button
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property color contentColor: active && useActiveColor ? activeColor : foreground

        bar: root.bar
        // El contenido lo pinta la fila de abajo, no la etiqueta del botón:
        // hacen falta dos tamaños de letra distintos en la misma celda.
        labelVisible: false
        hasVisualContent: true
        // El foco ya no cambia de glifo — antes se convertía en un cuadrado y
        // se perdía el icono justo en el workspace que estás mirando. Ahora lo
        // marca el color de acento, igual que el resto del tema marca el foco.
        active: focused
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        // La celda se mide sola: los iconos son más anchos que los dígitos y
        // el 10 ocupa más que el resto, así que fijar un ancho los apretaba.
        // En barra vertical no cabe la pareja, así que ahí queda solo el icono.
        fixedWidth: root.vertical ? root.barSize : content.implicitWidth + Style.spaceReal(13)
        fixedHeight: root.barSize
        onPressed: function(b) {
          // Izquierdo enfoca, derecho configura. Es el mismo reparto que usan
          // el reloj y el resto de widgets de la barra.
          if (b === Qt.RightButton) root.togglePanel()
          else root.focusWorkspace(modelData)
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical
            text: root.numberFor(button.modelData)
            font.family: button.fontFamily
            // Más pequeño y más apagado que el icono: acompaña, no compite.
            font.pixelSize: Math.round(button.fontSize * 0.85)
            color: button.contentColor
            opacity: 0.6
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.iconFor(button.modelData)
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            color: button.contentColor
          }
        }
      }
    }
  }
}
