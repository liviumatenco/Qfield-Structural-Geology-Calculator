/*
 * ============================================================================
 * Structural Geology Calculator
 * ============================================================================
 * Author:      Liviu Matenco (Utrecht University)
 * Version:     2.0
 * License:     MIT License
 * 
 * Description:
 * This QField plugin provides structural geology calculations and real-time
 * equal-area Schmidt stereonet plotting for fieldwork. It supports planes, 
 * lines, and shear senses.
 * 
 * New in Version 2.0:
 *  - Dynamic recognition of categories.
 *  - Fixed definition of layers and fields removed (except as noted below).
 *  - Improved shear senses: relative normal, reverse, sinistral, and dextral 
 *    in a field called "Kinematics" are used to calculate Fault / Shear Zone shear sense.
 *  - Dynamic Legend: Automatically displays active types and their point counts.
 *  - Random Colors: Custom types now receive distinct, high-contrast colors.
 *  - Fallback Types: Uses the layer name as a type if no "Type" field exists.
 *  - Generation field is used to define generations of the same Type.
 *  - Stereonet and legend use SVG vectors
 *  - Copy SVG button exports to clipboard the SVG code.
 * 
 * Feature Categorization:
 * The plugin automatically classifies your measurements based on the fields provided:
 *  - plane: Requires Dip & Dip Azimuth (Line and Shear Sense must be null/empty or not exist).
 *  - line: Requires Trend & Plunge (Plane and Shear Sense must be null/empty or not exist).
 *  - plane-line: Requires Plane and Line data (Shear Sense must be null/empty or not exist).
 *  - line-sense: Requires Line and Shear Sense (Plane must be null/empty or not exist).
 *  - plane-line-sense: Requires Plane, Line, and Shear Sense, such as for faults and shear-zones.
 *  - An optional Type field in the layer is used to name the various categories. When absent, 
 *    measurements in a layer will be plotted together.
 *  - An optional Generation field is used to define generations of the same Type. When absent, 
 *    measurements in a type will be plotted together.
 * 
 * Qfield Limitations
 * - Reset values before you change types, residual values influence the below classification.
 * - Use 360 instead of 0 (zero) for azimuths. In Integer types Qfiled confuses 0 with with Unknown.
 * - Do not use values of 0 or 90 for inclinations. Same as above and Kinematics is not valid for 90.
 * 
 * Project Setup Requirements:
 * The active layer in QField should contain the following fields (case-insensitive, must 
 * be exact, otherwise modify the code below):
 *  - Dip azimuth & Dip (Integer): Required for planes (see also alternative names below)
 *  - Trend & Plunge (Integer): Required for lines (see also alternative names below)
 *  - Top to (Integer): Required for shear senses (see also alternative names below)
 *  - Type (Text/String): Defines the structural feature (see below)
 * 
 * Any valid definitions of plane, line, plane-line, line-sense and plane-line-sense will be processed, as
 * well as relative shear senses (normal, reverse, dextral, or sinistral) defined in 
 * a field named Kinematics (case-sensitive). 
 * 
 * Optimally, the active layer should contain "measurements" in its name and an integer "Generation" field. 
 * In this situation, best "Type" Values are (must be exact, otherwise modify the code below):
 *  - plane, bedding, foliation, fault plane, fault gouge foliation, Riedel shear,
 *    line, fold, lineation, stretching lineation, plane-line, line-sense, stretching lineation,
 *    slickenlines, plane-line-sense, fault, shearzone
 * In this situation, the plugin will assign fixed colors to match a predefined QField project.
 *      See: https://github.com/liviumatenco/Qfield-digital-field-mapping-structural-geology/
 * 
 * Acknowledgments:
 * The "Tab S" (Stereonet) portion of this code contains modified 
 * parts of the QField Stereonet Plugin, Copyright (c) 2025 Mark Jessell.
 * ============================================================================
 */
 
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield
import org.qgis
Item {
    // ============================================================
    // PROPERTIES DEFINITIONS
    // ============================================================
    id: plugin
    property var mainWindow: iface.mainWindow()
    // ============================================================
    // NAMES OF FIELDS FOR MEASUREMENTS OF PLANES, LINEATIONS AND SHEARSENSES
    // ============================================================
	property var dipFieldNames: ["dip", "dip_angle", "P_dip", "Dip", "Dip_ref"]
	property var dipDirFieldNames: ["dip_dir", "dipdirection", "dd", "Dip azimuth", "DipDir_ref", "Dip_Dir"]
	property var azimuthFieldNames: ["azimuth", "trend", "L_plungeAzimuth", "Trend", "Azimuth"]
	property var plungeFieldNames: ["plunge", "pl", "L_plunge", "Plunge"]
	property var topToFieldNames: ["Top to", "Top_to", "top_to"]
    property bool extentOnly: false  // false = all features, true = current view only
    // ============================================================
    // NAMES OF THE FIELD WHERE THE TYPE OF MEASUREMENT IS DEFINED
    // ============================================================
	// NEW PROPERTIES
    property var allTypes: []
    property var typeColors: ({})
    property var typeFieldNames: ["Type", "type"]
    // TAB S (STEREONET) PROPERTIES
    property string activeLayerName: ""
    property var selectedTypes: []
    property var activeLayer: null
    property string planeProjectionMode: "poles"
    // TAB 1 INPUT VALUES
    property real dipAzimuth1: 0    // Dip direction in degrees (0-360)
    property real dip1: 0           // Dip angle in degrees (0-90)
    property real dipAzimuth2: 0    // Dip direction in degrees (0-360)
    property real dip2: 0           // Dip direction in degrees (0-360)
    // TAB 1 RESULTS
    property real resultAzimuth: 0
    property real resultPlunge: 0
    property real faultPlusAzimuth: 0
    property real faultPlusPlunge: 0
    property real resultAngle: 0
    property bool hasResult: false
    // TAB 2 INPUT VALUES
    property real tab2PlaneDipAzimuth: 0
    property real tab2PlaneDip: 0
    property real tab2LineTrend: 0
    property real tab2LinePlunge: 0
    // TAB 2 RESULTS
    property real tab2PerpendicularTrend: 0
    property real tab2PerpendicularPlunge: 0
    property bool tab2HasResult: false
    // TAB 3 RESULTS
    property real tab3ResultPlaneAzimuth: 0
    property real tab3ResultPlaneDip: 0
    property real tab3ResultPointTrend: 0
    property real tab3ResultPointPlunge: 0
    property bool tab3HasResult: false
    // TAB 4 RESULTS
    property real tab4ApparentDip: 0
    property bool tab4HasResult: false
    // TAB 5 RESULTS
    property var tab5Planes: []
    property real tab5FoldAxisTrend: 0
    property real tab5FoldAxisPlunge: 0
    property real tab5BestPlaneAzimuth: 0
    property real tab5BestPlaneDip: 0
    property bool tab5HasResult: false
    // TAB 6 RESULTS
    property var tab6Data: []
    property var allLoadedData: []
    property real tab6MaxTrend: 0
    property real tab6MaxPlunge: 0
    property bool tab6HasMax: false
    property real tab6MaxPlaneAzimuth: 0
    property real tab6MaxPlaneDip: 0
    property bool tab6IsPlaneType: false
    // TAB 7 RESULTS
    property real tab7Sigma1Trend: 0
    property real tab7Sigma1Plunge: 0
    property real tab7Sigma3Trend: 0
    property real tab7Sigma3Plunge: 0
    property bool tab7HasResult: false
    property var tab7Faults: []
    property real tab7Sigma2Trend: 0
    property real tab7Sigma2Plunge: 0
    property var allLoadedFaults: []
    // ============================================================
    // TOOLBAR BUTTON
    // ============================================================
    Component {
        id: intersectionButtonComponent
        Button {
            id: plotBtn
            width: 48; height: 48
            background: Rectangle {
                radius: 24
                color: plotBtn.pressed ? "#1976D2" : (plugin.extentOnly ? "#FFEB3B" : "#2196F3")
                border.color: plugin.extentOnly ? "#F57F17" : "#0D47A1"
                border.width: 2
            }
            contentItem: Canvas {
                id: buttonCanvas
                width: 32; height: 32
                anchors.centerIn: parent
                
                Connections {
                    target: plugin
                    function onExtentOnlyChanged() { buttonCanvas.requestPaint() }
                }
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    
                    ctx.strokeStyle = plugin.extentOnly ? "#0D47A1" : "white";
                    ctx.fillStyle = ctx.strokeStyle;
                    ctx.lineWidth = 3; ctx.lineCap = "round";
                    // --- SHEAR SENSE ICON ---
                    // Top Shear Line (Left to Right)
                    ctx.beginPath(); ctx.moveTo(4, 10); ctx.lineTo(width - 4, 10); ctx.stroke();
                    // Top Arrowhead (pointing right)
                    ctx.beginPath(); ctx.moveTo(width - 10, 5); ctx.lineTo(width - 4, 10); ctx.stroke();
                    // Bottom Shear Line (Right to Left)
                    ctx.beginPath(); ctx.moveTo(4, 22); ctx.lineTo(width - 4, 22); ctx.stroke();
                    // Bottom Arrowhead (pointing left)
                    ctx.beginPath(); ctx.moveTo(10, 27); ctx.lineTo(4, 22); ctx.stroke();
                    // Dashed line in the middle
                    ctx.lineWidth = 1; ctx.setLineDash([2, 2]);
                    ctx.beginPath(); ctx.moveTo(6, 16); ctx.lineTo(width - 6, 16); ctx.stroke();
                    ctx.setLineDash([]); // Reset
                }
            }
            onClicked: { intersectionPopup.open() }
            onPressAndHold: {
                plugin.extentOnly = !plugin.extentOnly
                mainWindow.displayToast(plugin.extentOnly ? "Mode: Current View Only 🔍" : "Mode: All Features 🌐")
                if (intersectionPopup.opened) reloadCurrentTabData()
            }
        }
    }
    // ADD TOOLBAR BUTTON
    Component.onCompleted: {
        Qt.callLater(function() {
            var btn = intersectionButtonComponent.createObject(plugin)
            if (btn) {
                iface.addItemToPluginsToolbar(btn)
            }
        })
    }
    // ============================================================
    // MAIN POPUP
    // ============================================================
    Popup {
        id: intersectionPopup; parent: mainWindow.contentItem
        width: Math.min(mainWindow.width - 24, 500); height: Math.min(mainWindow.height - 30, 760)
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        modal: true; focus: true; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: { 
            processLayer() 
            reloadCurrentTabData() // Added to reload data on open
        }
    background: Rectangle {
        color: "#FFFFFF"; border.color: "#2196F3"; border.width: 2; radius: 7
    }
    // ================================================================
    // TYPE SELECTION POPUP
    // ================================================================
    Popup { id: typeSelectorPopup; parent: mainWindow.contentItem
        width: Math.min(mainWindow.width - 50, 430); height: Math.min(mainWindow.height - 80, 550)
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2; modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#FFFFFF"; border.color: "#2196F3"; border.width: 2; radius: 6 }
        Column { anchors.fill: parent; anchors.margins: 8; spacing: 5
            Rectangle { width: parent.width; height: 50; color: "#2196F3"; radius: 4
                Column { anchors.centerIn: parent
                    Text { text: "Select Structural Type (" + plugin.selectedTypes.length + " selected)"; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                    Text { text: "Tap to select/deselect multiple types"; color: "#E3F2FD"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                }
            }
            ListView { id: typeList; width: parent.width; height: parent.height - 95; clip: true; model: plugin.allTypes
                delegate: Rectangle { width: typeList.width; height: String(modelData).startsWith("HEADER:") ? 28 : 42
                    color: String(modelData).startsWith("HEADER:") ? "#E0E0E0" : (plugin.selectedTypes.indexOf(modelData) >= 0 ? "#E3F2FD" : (typeMouse.containsMouse ? "#F5F5F5" : "#FFFFFF"))
                    border.color: String(modelData).startsWith("HEADER:") ? "#BDBDBD" : (plugin.selectedTypes.indexOf(modelData) >= 0 ? "#2196F3" : "#EEEEEE"); border.width: 1
                    // Category Header
                    Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: String(modelData).replace("HEADER:", ""); font.pixelSize: 12; font.bold: true; color: "#424242"; visible: String(modelData).startsWith("HEADER:") }
                    // Standard Item
                    Rectangle { width: 18; height: 18; radius: 9; anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; color: plugin.getColorForType(modelData); visible: !String(modelData).startsWith("HEADER:") }
                    Text { anchors.left: parent.left; anchors.leftMargin: 38; anchors.right: parent.right; anchors.rightMargin: 35; anchors.verticalCenter: parent.verticalCenter; text: String(modelData).startsWith("HEADER:") ? "" : String(modelData) + " - " + getTypeCount(modelData); font.pixelSize: 14; color: "#222222"; elide: Text.ElideRight; visible: !String(modelData).startsWith("HEADER:") }
                    Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "•"; font.pixelSize: 14; font.bold: true; color: "#777777"; visible: !String(modelData).startsWith("HEADER:") }
                    MouseArea { id: typeMouse; anchors.fill: parent; hoverEnabled: true; enabled: !String(modelData).startsWith("HEADER:")
                        onClicked: {
                            var index = plugin.selectedTypes.indexOf(modelData)
                            if (index >= 0) { plugin.selectedTypes.splice(index, 1) } else { plugin.selectedTypes.push(modelData) }
                            plugin.selectedTypesChanged(); plugin.plotSelectedType()
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }
            Button {
                width: 100; height: 35; text: "Close"; font.pixelSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: typeSelectorPopup.close()
            }
        }
    }
        ColumnLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 5; bottomMargin: 8 }
            spacing: 4
            // TABS
            TabBar {
                id: calculatorTabs; Layout.fillWidth: true; Layout.preferredHeight: 40; currentIndex: 0
                onCurrentIndexChanged: {
                    reloadCurrentTabData()
                }
                TabButton { text: "S"; font.pixelSize: 12 }
                TabButton { text: "1"; font.pixelSize: 12 }
                TabButton { text: "2"; font.pixelSize: 12 }
                TabButton { text: "3"; font.pixelSize: 12 }
                TabButton { text: "4"; font.pixelSize: 12 }
                TabButton { text: "5"; font.pixelSize: 12 }
                TabButton { text: "6"; font.pixelSize: 12 }
                TabButton { text: "7"; font.pixelSize: 12 }
            }
            // ====================================================
            // STACK
            // ====================================================
            StackLayout {
                id: tabStack; Layout.fillWidth: true; Layout.fillHeight: true
                currentIndex: calculatorTabs.currentIndex
                // =================================================
                // TAB S - STEREONET PLOTTING TOOL
                // =================================================
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    Flickable { anchors.fill: parent; clip: true; contentWidth: width; contentHeight: tabSColumn.implicitHeight; boundsBehavior: Flickable.StopAtBounds
                        Column { id: tabSColumn; width: parent.width; spacing: 3
                            // TITLE
                            Text { width: parent.width; height: 20; text: "Structural Geology Stereonet"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 15; font.bold: true; color: "#222222" }
                            // TYPE SELECTOR
                            Row { width: parent.width; height: 42; spacing: 8
                                Text { width: 45; text: "Type:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 13; font.bold: true; color: "#333333" }
                                Button { id: typeButton; width: parent.width - 53; height: 40; font.pixelSize: 13
                                    background: Rectangle { color: "#FFFFFF"; border.color: "#777777"; border.width: 1; radius: 4 }
                                    contentItem: Row { spacing: 10; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter
                                        Rectangle { width: 14; height: 14; radius: 7; visible: plugin.selectedTypes.length === 1; color: plugin.selectedTypes.length === 1 ? plugin.colorForType(plugin.selectedTypes[0]) : "transparent"; anchors.verticalCenter: parent.verticalCenter }
                                        Text { 
                                            text: plugin.selectedTypes.length === 0 ? "None selected" : (plugin.selectedTypes.length === 1 ? String(plugin.selectedTypes[0]) : plugin.selectedTypes.length + " types selected"); 
                                            color: "#222222"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: typeButton.width - 70 
                                        }
                                        Text { text: "▼"; color: "#555555"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    onClicked: { typeSelectorPopup.open() }
                                }
                            }
                            // PLANE PROJECTION SELECTOR
                            Row { 
                                width: parent.width; height: 32; spacing: 6; 
                                visible: {
                                    if (plugin.selectedTypes.length === 0) return false;
                                    var hasPurePlane = false;
                                    for (var i = 0; i < plugin.selectedTypes.length; i++) {
                                        var type = plugin.selectedTypes[i];
                                        var idx = plugin.allTypes.indexOf(type);
                                        while (idx >= 0) {
                                            var item = String(plugin.allTypes[idx]);
                                            if (item.startsWith("HEADER:")) {
                                                // Only show for pure "Planes", hide for "Planes with Lines", "Faults", etc.
                                                if (item === "HEADER:Planes") {
                                                    hasPurePlane = true;
                                                }
                                                break;
                                            }
                                            idx--;
                                        }
                                        if (hasPurePlane) break;
                                    }
                                    return hasPurePlane;
                                }
                                Text { width: 65; text: "Plot:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                Button { width: 95; height: 28; text: "Poles"
                                    background: Rectangle { radius: 4; color: plugin.planeProjectionMode === "poles" ? "#2196F3" : "#EEEEEE"; border.color: "#777777"; border.width: 1 }
                                    contentItem: Text { text: parent.text; color: plugin.planeProjectionMode === "poles" ? "white" : "#333333"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: { plugin.planeProjectionMode = "poles"; plugin.plotSelectedType() }
                                }
                                Button { width: 120; height: 28; text: "Great circles"
                                    background: Rectangle { radius: 4; color: plugin.planeProjectionMode === "greatCircles" ? "#2196F3" : "#EEEEEE"; border.color: "#777777"; border.width: 1 }
                                    contentItem: Text { text: parent.text; color: plugin.planeProjectionMode === "greatCircles" ? "white" : "#333333"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: { plugin.planeProjectionMode = "greatCircles"; plugin.plotSelectedType() }
                                }
                            }
                            // EXPLANATORY BOX
                            Rectangle { width: parent.width; height: 40; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column { anchors.centerIn: parent; spacing: 2
                                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 7
                                        Text { 
                                            text: {
                                                if (plugin.selectedTypes.length === 0) return "NO TYPES SELECTED";
                                                if (plugin.selectedTypes.length === 1) {
                                                    var t = plugin.selectedTypes[0];
                                                    return "SELECTED: " + t.toUpperCase();
                                                }
                                                return plugin.selectedTypes.length + " TYPES SELECTED";
                                            }
                                            font.pixelSize: 12; font.bold: true; color: "#444444" 
                                        }
                                    }
                                }
                            }
                            // STEREONET SVG IMAGE
                            Image {
                                id: tabSImage
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                            // FOOTER & LEGEND
                            Column { width: parent.width; spacing: 5
                                Text { id: countText; width: parent.width; height: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; color: "#555555"; wrapMode: Text.WordWrap }
                                Flow { width: parent.width; spacing: 10; visible: plugin.selectedTypes.length > 0
                                    Repeater { id: legendRepeater; model: plugin.selectedTypes
                                        Row { spacing: 4
                                            Canvas {
                                                width: 10; height: 10
                                                anchors.top: parent.top; anchors.topMargin: 2
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.fillStyle = plugin.getColorForType(modelData);
                                                    ctx.clearRect(0, 0, width, height);
                                                    if (isPlaneType(modelData) && plugin.planeProjectionMode === "poles") {
                                                        ctx.beginPath(); ctx.moveTo(5, 0); ctx.lineTo(0, 9); ctx.lineTo(10, 9); ctx.closePath(); ctx.fill();
                                                    } else {
                                                        ctx.beginPath(); ctx.arc(5, 5, 4.5, 0, 2 * Math.PI); ctx.fill();
                                                    }
                                                }
                                            }
                                            Text { text: String(modelData) + " - " + getTypeCount(modelData); font.pixelSize: 10; color: "#333333" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // =================================================
                // TAB 1 - CURRENT PLANE INTERSECTION CALCULATOR
                // =================================================
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    Flickable { anchors.fill: parent; clip: true; contentWidth: width; contentHeight: tab1Column.implicitHeight; boundsBehavior: Flickable.StopAtBounds
                        Column { id: tab1Column; width: parent.width; spacing: 4
                            // TITLE
                            Text { width: parent.width; height: 26; text: "2P (e.g., fault/Riedel shearsense)"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14; font.bold: true; color: "#222222" }
                            // PLANE 1
                            Rectangle { width: parent.width; height: 62; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column { anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { width: parent.width; height: 16; text: "Plane 1 — Fault"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row { width: parent.width; height: 36; spacing: 4
                                        Text { width: 68; height: 34; text: "Dip azimuth"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: dipAzimuth1Field; width: 82; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) { plugin.dipAzimuth1 = normalizeAzimuth(v) }
                                            }
                                        }
                                        Text { width: 30; height: 34; text: "Dip"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: dip1Field; width: 62; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) { plugin.dip1 = clamp(v, 0, 90) }
                                            }
                                        }
                                    }
                                }
                            }
                            // PLANE 2
                            Rectangle { width: parent.width; height: 62; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column { anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { width: parent.width; height: 16; text: "Plane 2 — Riedel"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row { width: parent.width; height: 36; spacing: 4
                                        Text { width: 68; height: 34; text: "Dip azimuth"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: dipAzimuth2Field; width: 82; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) { plugin.dipAzimuth2 = normalizeAzimuth(v) }
                                            }
                                        }
                                        Text { width: 30; height: 34; text: "Dip"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: dip2Field; width: 62; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) { plugin.dip2 = clamp(v, 0, 90) }
                                            }
                                        }
                                    }
                                }
                            }
                            // CALCULATE
                            Button { width: parent.width; height: 34; text: "Calculate Intersection"; font.pixelSize: 12; font.bold: true
                                background: Rectangle { radius: 4; color: parent.pressed ? "#1565C0" : "#2196F3" }
                                contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    calculateIntersection()
                                }
                            }
                            // RESULTS
                            Row {
                                width: parent.width; spacing: 5
                                Rectangle { width: parent.width - 55; height: 75; radius: 4; color: plugin.hasResult ? "#E8F5E9" : "#F5F5F5"; border.color: plugin.hasResult ? "#4CAF50" : "#CCCCCC"; border.width: 1
                                    Column { anchors.centerIn: parent; spacing: 0
                                        Text { id: c1Res1; width: 350; height: 17; text: plugin.hasResult ? ("Intersection:  Az " + formatNumber(plugin.resultAzimuth) + "° / Pl " + formatNumber(plugin.resultPlunge) + "°") : "Enter two planes"; font.pixelSize: 11; font.bold: true; color: "#000000"; horizontalAlignment: Text.AlignHCenter }
                                        Text { id: c1Res2; width: 350; height: 17; visible: plugin.hasResult; text: "Line perpendicular: Az " + formatNumber(plugin.faultPlusAzimuth) + "° / Pl " + formatNumber(plugin.faultPlusPlunge) + "°"; font.pixelSize: 11; font.bold: true; color: "#E65100"; horizontalAlignment: Text.AlignHCenter }
                                        Text { id: c1Res3; width: 350; height: 17; visible: plugin.hasResult; text: "Angle between planes: " + formatNumber(plugin.resultAngle) + "°"; font.pixelSize: 11; font.bold: true; color: "#2E7D32"; horizontalAlignment: Text.AlignHCenter }
                                    }
                                }
                                Button { width: 50; height: 75; text: "Copy"; font.pixelSize: 11; visible: plugin.hasResult
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = c1Res1.text + "\n" + c1Res2.text + "\n" + c1Res3.text;
                                        clipboard.selectAll(); clipboard.copy(); clipboard.destroy(); mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                            // TAB 1 STEREONET SVG
                            Image {
                                id: tab1Image
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                            // FOOTER
                            Text {
                                width: parent.width; height: 16; font.pixelSize: 9; color: "#666666"
                                text: plugin.hasResult ? "Blue = Fault   Red = Riedel   ● = Intersection   ● = Fault ⟂" : "Enter two plane attitudes"
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                Layout.topMargin: -10
                            }
                        }
                    }
                }
                // =================================================
                // TAB 2 - LINE PERPENDICULAR TO LINE IN PLANE
                // =================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: tab2Column.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: tab2Column
                            width: parent.width
                            spacing: 5
                            // TITLE
                            Text {
                                    width: parent.width; height: 26; font.pixelSize: 14; font.bold: true; color: "#222222"
                                    text: "1L, 1P (e.g. fault/drag fold shear sense)"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                            // PLANE
                            Rectangle {
                                width: parent.width; height: 62; radius: 4
                                color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text {
                                        width: parent.width; height: 16; text: "Plane"
                                        font.pixelSize: 12; font.bold: true; color: "#333333"
                                    }
                                    Row {
                                        width: parent.width; height: 36; spacing: 4
                                        Text {
                                            width: 68; height: 34; text: "Dip azimuth"
                                            font.pixelSize: 10; verticalAlignment: Text.AlignVCenter
                                        }
                                        TextField {
                                            id: tab2PlaneDipAzimuthField; width: 82; height: 34
                                            placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) {
                                                    plugin.tab2PlaneDipAzimuth = normalizeAzimuth(v)
                                                }
                                            }
                                        }
                                        Text {
                                            width: 30; height: 34; text: "Dip"
                                            font.pixelSize: 10; verticalAlignment: Text.AlignVCenter
                                        }
                                        TextField {
                                            id: tab2PlaneDipField; width: 62; height: 34
                                            placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) {
                                                    plugin.tab2PlaneDip = clamp(v, 0, 90)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // EXISTING LINE
                            Rectangle {
                                width: parent.width; height: 62; radius: 4
                                color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text {
                                        width: parent.width; height: 16; text: "Line in plane (max ~6° error)"
                                        font.pixelSize: 12; font.bold: true; color: "#333333"
                                    }
                                    Row {
                                        width: parent.width; height: 36; spacing: 4
                                        Text {
                                            width: 68; height: 34; text: "Trend"
                                            font.pixelSize: 10; verticalAlignment: Text.AlignVCenter
                                        }
                                        TextField {
                                            id: tab2LineTrendField; width: 82; height: 34
                                            placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) {
                                                    plugin.tab2LineTrend = normalizeAzimuth(v)
                                                }
                                            }
                                        }
                                        Text {
                                            width: 30; height: 34; text: "Plunge"
                                            font.pixelSize: 10; verticalAlignment: Text.AlignVCenter
                                        }
                                        TextField {
                                            id: tab2LinePlungeField; width: 62; height: 34
                                            placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) {
                                                    plugin.tab2LinePlunge = clamp(v, 0, 90)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // CALCULATE BUTTON
                            Button {
                                width: parent.width
                                height: 36
                                text: "Calculate Perpendicular Line"
                                font.pixelSize: 12
                                font.bold: true
                                background: Rectangle {
                                    radius: 4
                                    color: parent.pressed ? "#1565C0" : "#2196F3"
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font: parent.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    calculateTab2Perpendicular()
                                }
                            }
                            // RESULTS
                            Row {
                                width: parent.width; spacing: 5
                                Rectangle { width: parent.width - 55; height: 70; radius: 4; color: plugin.tab2HasResult ? "#E8F5E9" : "#F5F5F5"; border.color: plugin.tab2HasResult ? "#4CAF50" : "#CCCCCC"; border.width: 1
                                    Column { anchors.centerIn: parent; spacing: 3
                                        Text { id: c2Res1; width: 350; height: 20; text: plugin.tab2HasResult ? ("Line perpendicular: Trend " + formatNumber(plugin.tab2PerpendicularTrend) + "° / Plunge " + formatNumber(plugin.tab2PerpendicularPlunge) + "°") : "Enter plane and line attitude"; font.pixelSize: 11; font.bold: true; color: "#D32F2F"; horizontalAlignment: Text.AlignHCenter }
                                        Text { id: c2Res2; width: 350; height: 18; visible: plugin.tab2HasResult; text: "Angle to original line: 90.0°"; font.pixelSize: 10; color: "#555555"; horizontalAlignment: Text.AlignHCenter }
                                    }
                                }
                                Button { width: 50; height: 70; text: "Copy"; font.pixelSize: 11; visible: plugin.tab2HasResult
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = c2Res1.text + "\n" + c2Res2.text;
                                        clipboard.selectAll(); clipboard.copy(); clipboard.destroy(); mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                            // TAB 2 STEREONET SVG
                            Image {
                                id: tab2Image
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                            // TAB 2 FOOTER
                            Text { width: parent.width; height: 18; text: plugin.tab2HasResult ? "Green = Plane   Blue = Original line   Red = Perpendicular" : "Green = Plane — enter the line and calculate"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 9; color: "#666666" }
                        }
                    }
                }
                // =================================================
                // TAB 3 - BACKTILTING
                // =================================================
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: tab3Column.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: tab3Column; width: parent.width; spacing: 5
                            // TITLE
                            Text {
                                    width: parent.width; height: 26
                                    text: "Backtilting (Rotation)"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14; font.bold: true; color: "#222222"
                            }
                            // REFERENCE PLANE
                            Rectangle {
                                width: parent.width; height: 62; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { width: parent.width; height: 16; text: "Reference Plane (Backtilt with)"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row {
                                        width: parent.width; height: 36; spacing: 4
                                        Text { width: 68; height: 34; text: "Dip azimuth"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab3RefAzimuth; width: 82; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                        Text { width: 30; height: 34; text: "Dip"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab3RefDip; width: 62; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                    }
                                }
                            }
                            // TARGET PLANE
                            Rectangle {
                                width: parent.width; height: 62; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { width: parent.width; height: 16; text: "Target Plane (to backtilt)"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row {
                                        width: parent.width; height: 36; spacing: 4
                                        Text { width: 68; height: 34; text: "Dip azimuth"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab3TargetPlaneAzimuth; width: 82; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                        Text { width: 30; height: 34; text: "Dip"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab3TargetPlaneDip; width: 62; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                    }
                                }
                            }
                            // TARGET POINT
                            Rectangle {
                                width: parent.width; height: 62; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { width: parent.width; height: 16; text: "Target Point/Line (to backtilt)"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row {
                                        width: parent.width; height: 36; spacing: 4
                                        Text { width: 68; height: 34; text: "Trend"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab3TargetPointTrend; width: 82; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                        Text { width: 30; height: 34; text: "Plunge"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab3TargetPointPlunge; width: 62; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                    }
                                }
                            }
                            // CALCULATE BUTTON
                            Button {
                                width: parent.width; height: 36; text: "Calculate Backtilt"; font.pixelSize: 12; font.bold: true
                                onClicked: { calculateBacktilt() }
                            }
                            // RESULTS
                            Row {
                                width: parent.width; spacing: 5
                                Rectangle { width: parent.width - 55; height: 50; radius: 4; color: plugin.tab3HasResult ? "#E8F5E9" : "#F5F5F5"; border.color: plugin.tab3HasResult ? "#4CAF50" : "#CCCCCC"; border.width: 1
                                    Column { anchors.centerIn: parent; spacing: 1
                                        Text { id: c3Res1; width: 350; height: 16; text: plugin.tab3HasResult ? ("New Plane: Az " + formatNumber(plugin.tab3ResultPlaneAzimuth) + "° / Dip " + formatNumber(plugin.tab3ResultPlaneDip) + "°") : "Enter values to backtilt"; font.pixelSize: 11; font.bold: true; color: "#D32F2F"; horizontalAlignment: Text.AlignHCenter }
                                        Text { id: c3Res2; width: 350; height: 16; visible: plugin.tab3HasResult; text: "New Point: Trend " + formatNumber(plugin.tab3ResultPointTrend) + "° / Plunge " + formatNumber(plugin.tab3ResultPointPlunge) + "°"; font.pixelSize: 11; font.bold: true; color: "#D32F2F"; horizontalAlignment: Text.AlignHCenter }
                                    }
                                }
                                Button { width: 50; height: 50; text: "Copy"; font.pixelSize: 11; visible: plugin.tab3HasResult
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = c3Res1.text + (plugin.tab3HasResult ? "\n" + c3Res2.text : "");
                                        clipboard.selectAll(); clipboard.copy(); clipboard.destroy(); mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                            // TAB 3 STEREONET SVG
                            Image {
                                id: tab3Image
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                            // TAB 3 FOOTER
                            Text {
                                width: parent.width; height: 18
                                text: plugin.tab3HasResult ? "Gray = Reference | Blue = Original Inputs | Red = New Results" : "Enter values and calculate to see stereonet"
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 9; color: "#666666"
                            }
                        }
                    }
                }
                // =================================================
                // TAB 4 - APPARENT DIP
                // =================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: tab4Column.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: tab4Column; width: parent.width; spacing: 5
                            // TITLE
                            Text { width: parent.width; height: 26; text: "Apparent Dip in Cross-Section"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14; font.bold: true; color: "#222222" }
                            // TRUE PLANE
                            Rectangle { width: parent.width; height: 86; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column { anchors.fill: parent; anchors.margins: 5; spacing: 3
                                    Text { width: parent.width; height: 18; text: "True Plane"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row { width: parent.width; height: 36; spacing: 5
                                        Text { width: 75; height: 34; text: "Dip azimuth"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab4TrueAzimuth; width: 85; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                        Text { width: 30; height: 34; text: "Dip"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab4TrueDip; width: 65; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                    }
                                }
                            }
                            // SECTION TREND
                            Rectangle { width: parent.width; height: 86; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column { anchors.fill: parent; anchors.margins: 5; spacing: 3
                                    Text { width: parent.width; height: 18; text: "Cross-Section Trend"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row { width: parent.width; height: 36; spacing: 5
                                        Text { width: 75; height: 34; text: "Trend"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                        TextField { id: tab4SectionTrend; width: 85; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                    }
                                }
                            }
                            // CALCULATE BUTTON
                            Button {
                                width: parent.width; height: 36
                                text: "Calculate Apparent Dip"; font.pixelSize: 12; font.bold: true
                                onClicked: { calculateApparentDip() }
                            }
                            // RESULTS
                            Row {
                                width: parent.width; spacing: 5
                                Rectangle { width: parent.width - 55; height: 50; radius: 4; color: plugin.tab4HasResult ? "#E8F5E9" : "#F5F5F5"; border.color: plugin.tab4HasResult ? "#4CAF50" : "#CCCCCC"; border.width: 1
                                    Text { id: c4Res; anchors.centerIn: parent; text: plugin.tab4HasResult ? ("Apparent Dip: " + formatNumber(plugin.tab4ApparentDip) + "°") : "Enter plane and section trend"; font.pixelSize: 14; font.bold: true; color: "#1565C0" }
                                }
                                Button { width: 50; height: 50; text: "Copy"; font.pixelSize: 11; visible: plugin.tab4HasResult
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = c4Res.text;
                                        clipboard.selectAll(); clipboard.copy(); clipboard.destroy(); mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                        }
                    }
                }
                // =================================================
                // TAB 5 - BEST-FIT PLANE (PI-DIAGRAM)
                // =================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: tab5Column.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: tab5Column; width: parent.width; spacing: 5
                            Text { width: parent.width; height: 26; text: "Best-Fit Plane (Pi-Diagram)"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14; font.bold: true; color: "#222222" }
                            // INPUTS
                            Rectangle {
                                width: parent.width; height: 62; radius: 4; color: "#F5F5F5"; border.color: "#CCCCCC"; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { width: parent.width; height: 16; text: "Add Plane Measurement"; font.pixelSize: 12; font.bold: true; color: "#333333" }
                                    Row {
                                        width: parent.width; height: 36; spacing: 4
                                        Text { text: "Dip Az"; width: 45; height: 34; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
                                        TextField { id: tab5Azimuth; width: 82; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                        Text { text: "Dip"; width: 30; height: 34; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
                                        TextField { id: tab5Dip; width: 62; height: 34; placeholderText: "°"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                Button {
                                    text: "Add Plane"
                                    onClicked: {
                                        if(tab5Azimuth.text !== "" && tab5Dip.text !== "") {
                                            plugin.tab5Planes.push({az: parseFloat(tab5Azimuth.text), dip: parseFloat(tab5Dip.text)});
                                            tab5Azimuth.text = ""; tab5Dip.text = "";
                                            tab5CountText.text = "Planes added: " + plugin.tab5Planes.length;
                                            updateTab5Stereonet();
                                        }
                                    }
                                }
                                Button { text: "Clear"; onClicked: { plugin.tab5Planes = []; tab5CountText.text = "Planes added: 0"; plugin.tab5HasResult = false; } }
                                Text { id: tab5CountText; text: "Planes added: 0"; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                width: parent.width; height: 36; text: "Calculate Best-Fit"
                                onClicked: { calculateBestFitPlane(); }
                            }
                            // RESULTS
                            Row {
                                width: parent.width; spacing: 5
                                Rectangle { width: parent.width - 55; height: 70; radius: 4; color: plugin.tab5HasResult ? "#E8F5E9" : "#F5F5F5"
                                    Column { anchors.centerIn: parent
                                        Text { id: c5Res1; text: plugin.tab5HasResult ? "Fold Axis: " + formatNumber(plugin.tab5FoldAxisTrend) + "° / " + formatNumber(plugin.tab5FoldAxisPlunge) + "°" : "Enter at least 3 planes"; font.bold: true }
                                        Text { id: c5Res2; text: plugin.tab5HasResult ? "Pi Plane: " + formatNumber(plugin.tab5BestPlaneAzimuth) + "° / " + formatNumber(plugin.tab5BestPlaneDip) + "°" : ""; visible: plugin.tab5HasResult; color: "#D32F2F"; font.bold: true }
                                    }
                                }
                                Button { width: 50; height: 70; text: "Copy"; font.pixelSize: 11; visible: plugin.tab5HasResult
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = c5Res1.text + "\n" + c5Res2.text;
                                        clipboard.selectAll(); clipboard.copy(); clipboard.destroy(); mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                            // TAB 5 STEREONET SVG
                            Image {
                                id: tab5Image
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                        }
                    }
                }
                // =================================================
                // TAB 6: STRUCTURAL DENSITY
                // =================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: tab6Column.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: tab6Column
                            width: parent.width
                            spacing: 3
                            Text { width: parent.width; text: "Structural Data Density Plot"; font.pixelSize: 14; font.bold: true; color: "#222222"; horizontalAlignment: Text.AlignHCenter }
                            Text { width: parent.width; text: "Plots poles to planes, lines and lines with senses of shear"; font.pixelSize: 10; color: "#666666"; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                            Row {
                                spacing: 10; width: parent.width; height: 35
                                Column { width: 80; anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Feature Type:"; font.pixelSize: 11 }
                                    Text { text: "sorted by number"; font.pixelSize: 9; color: "#666666"; font.italic: true }
                                }
                                ComboBox {
                                    id: tab6TypeComboBox
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 180; height: 28
                                    model: ListModel { id: tab6TypeModel }
                                    textRole: "text"
                                    onCurrentIndexChanged: {
                                        if (plugin.allLoadedData && plugin.allLoadedData.length > 0) {
                                            filterDataByType();
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                width: parent.width; height: 25
                                Text { id: tab6CountText; text: "Loaded: 0"; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
                                
                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Contours:"; font.pixelSize: 10; font.bold: true; color: "#666666" }
                                    Rectangle { width: 10; height: 10; color: "#D3D3D3"; radius: 2 }
                                    Text { text: "20%"; font.pixelSize: 9 }
                                    Rectangle { width: 10; height: 10; color: "#A9A9A9"; radius: 2 }
                                    Text { text: "40%"; font.pixelSize: 9 }
                                    Rectangle { width: 10; height: 10; color: "#696969"; radius: 2 }
                                    Text { text: "60%"; font.pixelSize: 9 }
                                    Rectangle { width: 10; height: 10; color: "#333333"; radius: 2 }
                                    Text { text: "80%"; font.pixelSize: 9 }
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: 5
                                Rectangle { width: parent.width - 55; height: 55; color: "#F5F5F5"
                                    Text { id: tab6DensityResultText; anchors.centerIn: parent; text: "Max Density: ---\nTotal Points: ---"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; textFormat: Text.StyledText }
                                }
                                Button {
                                    width: 50
                                    height: 55
                                    text: "Copy"
                                    font.pixelSize: 11
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = tab6DensityResultText.text.replace(/<[^>]*>/g, "");
                                        clipboard.selectAll(); clipboard.copy(); clipboard.destroy();
                                        mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                            // TAB 6 STEREONET SVG
                            Image {
                                id: tab6Image
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                            // TAB 6 LEGEND
                            Flow { width: parent.width; spacing: 10
                                Row { spacing: 4
                                    Rectangle {
                                        width: 10; height: 10
                                        anchors.top: parent.top; anchors.topMargin: 2
                                        color: tab6TypeComboBox.currentIndex >= 0 ? plugin.getColorForType(tab6TypeModel.get(tab6TypeComboBox.currentIndex).originalName) : "#000000"
                                        radius: 5
                                    }
                                    Text { text: tab6TypeComboBox.currentIndex >= 0 ? tab6TypeModel.get(tab6TypeComboBox.currentIndex).text : "No Type Selected"; font.pixelSize: 12; color: "#333333" }
                                }
                            }
                        }
                    }
                }
                // =================================================
                // TAB 7: PALEOSTRESS INVERSION
                // =================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: tab7Column.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: tab7Column
                            width: parent.width
                            spacing: 3
                            Text { width: parent.width; text: "Paleostress"; font.pixelSize: 14; font.bold: true; color: "#222222"; horizontalAlignment: Text.AlignHCenter }
                            Text { width: parent.width; text: "Individual conjugate stresses and Eigenvector Average"; font.pixelSize: 10; color: "#666666"; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                            Row {
                                spacing: 10
                                width: parent.width; height: 35
                                Column {
                                    width: 80; anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Feature Type:"; font.pixelSize: 11 }
                                    Text { text: "sorted by number"; font.pixelSize: 9; color: "#666666"; font.italic: true }
                                }
                                ComboBox {
                                    id: typeComboBox
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 180; height: 28
                                    model: ListModel { id: typeModel }
                                    textRole: "text"
                                    onCurrentIndexChanged: {
                                        if (plugin.allLoadedFaults && plugin.allLoadedFaults.length > 0) {
                                            filterFaultsByType();
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 5
                                width: parent.width
                                height: 25
                                Text { id: tab7CountText; text: "Loaded: 0"; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
                                Row {
                                    spacing: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "σ1"; font.pixelSize: 10; color: "#D32F2F"; font.bold: true }
                                    Text { text: "σ2"; font.pixelSize: 10; color: "#1565C0"; font.bold: true }
                                    Text { text: "σ3"; font.pixelSize: 10; color: "#000000"; font.bold: true }
                                }
                                Row {
                                    spacing: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "○ Original"; font.pixelSize: 10; color: "#795548"; font.bold: true }
                                    Text { text: "● Corrected"; font.pixelSize: 10; color: "#2E7D32"; font.bold: true }
                                }
                            }
                            Row {
                                width: parent.width; spacing: 5
                                Rectangle {
                                    width: parent.width - 55; height: 55; color: "#F5F5F5"
                                    Text {
                                        id: tab7ResultText
                                        anchors.centerIn: parent
                                        text: "Average σ1: ---\nAverage σ2: ---\nAverage σ3: ---"
                                        font.pixelSize: 11; font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                Button {
                                    width: 50; height: 55; text: "Copy"
                                    font.pixelSize: 11
                                    onClicked: {
                                        var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                                        clipboard.text = tab7ResultText.text; clipboard.selectAll(); clipboard.copy(); clipboard.destroy();
                                        mainWindow.displayToast("Copied!");
                                    }
                                }
                            }
                            // TAB 7 STEREONET SVG
                            Image {
                                id: tab7Image
                                width: Math.min(parent.width, 440)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                cache: false
                            }
                            // TAB 7 LEGEND & FOOTER
                            Column { width: parent.width; spacing: 5
                                Flow { width: parent.width; spacing: 10
                                    Row { spacing: 4
                                        Rectangle {
                                            width: 10; height: 10
                                            anchors.top: parent.top; anchors.topMargin: 2
                                            color: typeComboBox.currentIndex >= 0 ? plugin.getColorForType(typeModel.get(typeComboBox.currentIndex).originalName) : "#000000"
                                            radius: 5
                                        }
                                        Text { text: typeComboBox.currentIndex >= 0 ? typeModel.get(typeComboBox.currentIndex).text : "No Type Selected"; font.pixelSize: 12; color: "#333333" }
                                    }
                                }
                                Text { width: parent.width; height: 20; text: "NOTE: just averages, not paleostress inversion!"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11; color: "#2E7D32"; wrapMode: Text.WordWrap }
                            }
                        }
                    }
                }
            }
            // CLOSE AND EXPORT BUTTONS
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                spacing: 15
                Button {
                    width: 110; height: 32; text: "Copy SVG"
                    font.pixelSize: 12; font.bold: true
                    background: Rectangle {
                        radius: 4
                        color: parent.pressed ? "#1565C0" : "#2196F3"
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font: parent.font
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        var currentTab = calculatorTabs.currentIndex;
                        var svgSource = "";
                        if (currentTab === 0) svgSource = tabSImage.source;
                        else if (currentTab === 1) svgSource = tab1Image.source;
                        else if (currentTab === 2) svgSource = tab2Image.source;
                        else if (currentTab === 3) svgSource = tab3Image.source;
                        else if (currentTab === 5) svgSource = tab5Image.source;
                        else if (currentTab === 6) svgSource = tab6Image.source;
                        else if (currentTab === 7) svgSource = tab7Image.source;
                        if (svgSource.toString().startsWith("data:image/svg+xml;utf8,")) {
                            var rawSvg = decodeURIComponent(svgSource.toString().replace("data:image/svg+xml;utf8,", ""));
                            // Adjust canvas size and inject legend for Tab S
                            if (currentTab === 0) {
                                var itemsPerRow = 3;
                                var rowCount = plugin.selectedTypes.length > 0 ? Math.ceil(plugin.selectedTypes.length / itemsPerRow) : 0;
                                var extraHeight = 40 + (rowCount * 20);
                                var newHeight = 440 + extraHeight;
                                rawSvg = rawSvg.replace('height="440"', 'height="' + newHeight + '"');
                                rawSvg = rawSvg.replace('viewBox="0 0 440 440"', 'viewBox="0 0 440 ' + newHeight + '"');
                                var extraSvg = '<g transform="translate(20, 445)">';
                                extraSvg += '<text x="0" y="0" font-family="sans-serif" font-size="12" font-weight="bold" fill="#555555">' + countText.text + '</text>';
                                if (plugin.selectedTypes.length > 0) {
                                    for(var i = 0; i < plugin.selectedTypes.length; i++) {
                                        var type = plugin.selectedTypes[i];
                                        var color = plugin.getColorForType(type);
                                        var row = Math.floor(i / itemsPerRow);
                                        var col = i % itemsPerRow;
                                        var xOffset = col * 130;
                                        var yOffset = 15 + (row * 20);
                                        if (isPlaneType(type) && plugin.planeProjectionMode === "poles") {
                                            extraSvg += '<polygon points="' + (xOffset+5) + ',' + yOffset + ' ' + xOffset + ',' + (yOffset+9) + ' ' + (xOffset+10) + ',' + (yOffset+9) + '" fill="' + color + '"/>';
                                        } else {
                                            extraSvg += '<circle cx="' + (xOffset+5) + '" cy="' + (yOffset+5) + '" r="4.5" fill="' + color + '"/>';
                                        }
                                        extraSvg += '<text x="' + (xOffset + 15) + '" y="' + (yOffset + 9) + '" font-family="sans-serif" font-size="10">' + type + ' - ' + getTypeCount(type) + '</text>';
                                    }
                                }
                                extraSvg += '</g>';
                                rawSvg = rawSvg.replace("</svg>", extraSvg + "</svg>");
                            }
                            // Adjust canvas size and inject legend for Tab 6
                            if (currentTab === 6 && tab6TypeComboBox.currentIndex >= 0) {
                                var newHeight6 = 440 + 40;
                                rawSvg = rawSvg.replace('height="440"', 'height="' + newHeight6 + '"');
                                rawSvg = rawSvg.replace('viewBox="0 0 440 440"', 'viewBox="0 0 440 ' + newHeight6 + '"');
                                var extraSvg6 = '<g transform="translate(20, 455)">';
                                var color6 = plugin.getColorForType(tab6TypeModel.get(tab6TypeComboBox.currentIndex).originalName);
                                var text6 = tab6TypeModel.get(tab6TypeComboBox.currentIndex).text;
                                extraSvg6 += '<circle cx="5" cy="5" r="5" fill="' + color6 + '"/>';
                                extraSvg6 += '<text x="15" y="11" font-family="sans-serif" font-size="12">' + text6 + '</text>';
                                extraSvg6 += '</g>';
                                rawSvg = rawSvg.replace("</svg>", extraSvg6 + "</svg>");
                            }
                            // Adjust canvas size and inject legend for Tab 7
                            if (currentTab === 7 && typeComboBox.currentIndex >= 0) {
                                var newHeight7 = 440 + 40;
                                rawSvg = rawSvg.replace('height="440"', 'height="' + newHeight7 + '"');
                                rawSvg = rawSvg.replace('viewBox="0 0 440 440"', 'viewBox="0 0 440 ' + newHeight7 + '"');
                                var extraSvg7 = '<g transform="translate(20, 455)">';
                                var color7 = plugin.getColorForType(typeModel.get(typeComboBox.currentIndex).originalName);
                                var text7 = typeModel.get(typeComboBox.currentIndex).text;
                                extraSvg7 += '<circle cx="5" cy="5" r="5" fill="' + color7 + '"/>';
                                extraSvg7 += '<text x="15" y="11" font-family="sans-serif" font-size="12">' + text7 + '</text>';
                                extraSvg7 += '</g>';
                                rawSvg = rawSvg.replace("</svg>", extraSvg7 + "</svg>");
                            }
                            // Copy to clipboard
                            var clipboard = Qt.createQmlObject("import QtQuick 2.0; TextEdit {}", parent);
                            clipboard.text = rawSvg; clipboard.selectAll(); clipboard.copy(); clipboard.destroy(); 
                            mainWindow.displayToast("SVG copied to clipboard!");
                        } else {
                            mainWindow.displayToast("No stereonet available to export");
                        }
                    }
                }
                Button {
                    width: 110; height: 32; text: "Close"
                    font.pixelSize: 12
                    onClicked: intersectionPopup.close()
                }
            }
        }
    }
    // ================================================================
    // FUNCTIONS SECTION
    // ================================================================
    // HELPER: Checks if a type belongs to the "Planes" category
    function isPlaneType(typeName) {
        var idx = plugin.allTypes.indexOf(typeName);
        while (idx >= 0) {
            var item = String(plugin.allTypes[idx]);
            if (item.startsWith("HEADER:")) { return item === "HEADER:Planes"; }
            idx--;
        }
        return false;
    }
    // HELPER: Checks if a layer should be treated as a default measurements layer
    function isMeasurementsLayer() {
        if (!plugin.activeLayer || !plugin.activeLayer.name) return false;
        return plugin.activeLayer.name.toLowerCase().indexOf("measurements") >= 0;
    }
    // FIXED AND DYNAMIC COLOR GENERATOR
    function getColorForType(typeName, genValue) {
        // 1. Check if this is a measurements layer and we have a Generation value
        if (plugin.activeLayer && plugin.activeLayer.name && plugin.activeLayer.name.toLowerCase().indexOf("measurements") >= 0) {
            var ds = null
            if (genValue !== undefined && genValue !== null) {
                ds = parseInt(genValue, 10)
            } else {
                var match = String(typeName).match(/\((\d+)\)/i)
                if (match && match[1]) { ds = parseInt(match[1], 10) }
            }
            if (ds !== null && !isNaN(ds)) {
                switch (ds) {
                    case 1: return "#000000"  // Black
                    case 2: return "#FF0000"  // Red
                    case 3: return "#00A000"  // Green
                    case 4: return "#4B0082"  // Purple
                    case 5: return "#0000FF"  // Blue
                    case 6: return "#FF00FF"  // Magenta
                    case 7: return "#FFA500"  // Orange
                    case 8: return "#A52A2A"  // Brown
                    case 9: return "#808080"  // Gray
                    case 10: return "#FFD700" // Gold
                    default: return "#CCCCCC" // Light Gray
                }
            }
        }
        if (plugin.typeColors[typeName]) return plugin.typeColors[typeName]
        var lowerName = typeName.toLowerCase().trim()
        // 2. Check for specific basic types strictly without numbers and assign black
        var hasNumber = /\d/.test(lowerName)
        if (!hasNumber) {
            var basicTypes = ["bedding", "fold", "foliation", "stretching lineation", "fault", "shearzone"]
            for (var i = 0; i < basicTypes.length; i++) {
                if (lowerName.indexOf(basicTypes[i]) >= 0) {
                    return "#000000" // Black
                }
            }
        }
        // 3. Dynamic color generation for everything else
        var count = Object.keys(plugin.typeColors).length
        var goldenRatio = 0.618033988749895
        var hue = (count * goldenRatio) % 1.0
        var h = hue * 6
        var f = h - Math.floor(h)
        var v = 0.75 
        var s = 0.90 
        var p = v * (1 - s)
        var q = v * (1 - f * s)
        var t = v * (1 - (1 - f) * s)
        var r, g, b
        switch (Math.floor(h) % 6) {
            case 0: r = v; g = t; b = p; break
            case 1: r = q; g = v; b = p; break
            case 2: r = p; g = v; b = t; break
            case 3: r = p; g = q; b = v; break
            case 4: r = t; g = p; b = v; break
            case 5: r = v; g = p; b = q; break
        }
        var toHex = function(c) {
            var hex = Math.floor(c * 255).toString(16)
            return hex.length === 1 ? "0" + hex : hex
        }
        var color = "#" + toHex(r) + toHex(g) + toHex(b)
        plugin.typeColors[typeName] = color
        return color
    }
    // NEW CLASSIFICATION LOGIC
    function classifyFeature(hasPlane, hasLine, hasTopTo, typeName) {
        if (hasPlane && !hasLine && !hasTopTo) return "Plane"
        if (!hasPlane && hasLine && !hasTopTo) return "Line"
        if (hasPlane && hasLine && !hasTopTo) return "PlaneWithLine"
        if (!hasPlane && hasLine && hasTopTo) return "StretchingLineation"
        if (hasPlane && hasLine && hasTopTo) {
            return String(typeName).toLowerCase().indexOf("fault") >= 0 ? "Fault" : "Shearzone"
        }
        return "Unknown"
    }
    // Projects spherical coordinates onto a flat plane using equal-area Lambert projection
    function lambertProject(lon, lat, R) {
        var denom = 1 + Math.cos(lat) * Math.cos(lon); if (denom < 0.0001) return null;
        var k = Math.sqrt(2 / denom);
        return { x: R * k * Math.cos(lat) * Math.sin(lon) / Math.sqrt(2), y: R * k * Math.sin(lat) / Math.sqrt(2) };
    }
    // Projects a plunge and azimuth onto the stereonet using equal-area projection
    function projectStereonetPoint(plunge, azimuth, R) {
        var plungeRad = plunge * Math.PI / 180; var azRad = azimuth * Math.PI / 180;
        var r = R * Math.sqrt(2) * Math.sin((Math.PI / 2 - plungeRad) / 2);
        return { x: r * Math.sin(azRad), y: r * Math.cos(azRad) };
    }
    // CHECKS IF THE VALUE IS VALID
    function isValidValue(val) {
        if (val === null || val === undefined) return false;
        var str = String(val).trim();
        if (str === "" || str.toUpperCase() === "NULL") return false;
        return !isNaN(Number(val));
    }
    // NORMALISE AZIMUTH: Keeps degree values within the 0-359 range
    function normalizeAzimuth(value) {
        return (value % 360 + 360) % 360
    }
    // CLAMP: Restricts a value to a defined min/max range
    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }
    // FORMAT NUMBER: Rounds values to one decimal place for display
    function formatNumber(value) {
        return Number(value).toFixed(1)
    }
    // PLANE NORMAL: Calculates the 3D normal vector for a given plane (X=East, Y=North, Z=Up)
    function planeNormal(dipAzimuth, dip) {
        var dd = dipAzimuth * Math.PI / 180
        var d = dip * Math.PI / 180
        var downDip = { x: Math.cos(d) * Math.sin(dd), y: Math.cos(d) * Math.cos(dd), z: -Math.sin(d) }
        var strike = (dipAzimuth - 90 + 360) % 360
        var sr = strike * Math.PI / 180
        var strikeVector = { x: Math.sin(sr), y: Math.cos(sr), z: 0 }
        return normalizeVector(crossProduct(strikeVector, downDip))
    }
    // CROSS PRODUCT: Returns a vector perpendicular to two input vectors
    function crossProduct(a, b) {
        return { x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x }
    }
    // DOT PRODUCT: Calculates the cosine of the angle between two vectors
    function dotProduct(a, b) {
        return (a.x * b.x + a.y * b.y + a.z * b.z)
    }
    // VECTOR LENGTH: Returns the magnitude of a 3D vector
    function vectorLength(v) {
        return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    }
    // NORMALISE VECTOR: Scales a vector to a length of 1
    function normalizeVector(v) {
        var len = vectorLength(v)
        if (len < 0.000001) { return { x: 0, y: 0, z: 0 } }
        return { x: v.x / len, y: v.y / len, z: v.z / len }
    }
    // VECTOR TO ATTITUDE: Converts a 3D direction vector back into geological trend and plunge
    function vectorToAttitude(v) {
        var line = normalizeVector(v)
        if (line.z < 0) {
            line.x = -line.x
            line.y = -line.y
            line.z = -line.z
        }
        var azimuth = Math.atan2(line.x, line.y) * 180 / Math.PI
        if (azimuth < 0) { azimuth += 360 }
        var horizontal = Math.sqrt(line.x * line.x + line.y * line.y)
        var plunge = Math.atan2(line.z, horizontal) * 180 / Math.PI
        return { azimuth: normalizeAzimuth(azimuth), plunge: clamp(plunge, 0, 90) }
    }
    // CONVERT TREND / PLUNGE TO VECTOR: Converts geological trend and plunge into a 3D direction vector
    function attitudeToVector(trend, plunge) {
        var trendRad = trend * Math.PI / 180
        var plungeRad = plunge * Math.PI / 180
        return { x: Math.cos(plungeRad) * Math.sin(trendRad), y: Math.cos(plungeRad) * Math.cos(trendRad), z: Math.sin(plungeRad) }
    }
    // TAB S (STEREONET) FUNCTIONS
    // COLOR FOR TYPE: Retrieves the assigned hex color for a specific structural type
    function colorForType(typeName) {
        return getColorForType(typeName)
    }
    // GET TYPE COUNT: Returns the number of plotted points for a specific type
    function getTypeCount(typeName) {
        if (!plugin.activeLayer) return 0
        var count = 0
        try {
            var allFeatures = getAllFeatures(plugin.activeLayer)
            if (!allFeatures || allFeatures.length === 0) return 0
            var fieldNames = allFeatures[0].fields.names
            var typeField = findFieldName(fieldNames, typeFieldNames)
            var genField = findFieldName(fieldNames, ["Generation", "generation"])
            var isMeasurements = plugin.activeLayer.name.toLowerCase().indexOf("measurements") >= 0
            for (var i = 0; i < allFeatures.length; i++) {
                var feat = allFeatures[i]
                var featureTypeString = plugin.activeLayer.name
                if (typeField && typeField.toLowerCase() !== "kinematics") { 
                    featureTypeString = String(feat.attribute(typeField)).trim() 
                }
                var genVal = genField ? feat.attribute(genField) : null
                if (isMeasurements && genVal !== null && genVal !== undefined && String(genVal).trim() !== "") { 
                    featureTypeString += " (" + String(genVal).trim() + ")" 
                }
                if (featureTypeString === typeName) {
                    count++
                }
            }
        } catch (error) {
            console.log("Error in getTypeCount: " + error)
        }
        return count
    }
    // FEATURE IN CURRENT VIEW: Corrected for QField JSON Geometry
    function featureInCurrentView(feature) {
        if (!extentOnly) return true
        try {
            var mapCanvas = iface.mapCanvas()
            if (!mapCanvas) return true
            var extent = mapCanvas.currentExtent()
            if (!extent) return true
            var geom = feature.geometry
            if (!geom) return false
            // QField often returns geometry as a JSON string
            if (typeof geom === 'string') {
                try {
                    var geojson = JSON.parse(geom)
                    if (geojson && geojson.coordinates) {
                        var x = geojson.coordinates[0]
                        var y = geojson.coordinates[1]
                        return (x >= extent.xMinimum() && x <= extent.xMaximum() && 
                                y >= extent.yMinimum() && y <= extent.yMaximum())
                    }
                } catch (e) {
                    // Not JSON, try WKT fallback
                }
            }
            return true
        } catch (e) {
            return true
        }
    }
    // PLOT SELECTED TYPE: Extracts valid measurements and sends them to the stereonet SVG
    function plotSelectedType() {
        var layer = plugin.activeLayer; if (!layer) return
        try {
            var allFeatures = getAllFeatures(layer)
            if (!allFeatures || allFeatures.length === 0) { tabSImage.source = ""; return }
            var fieldNames = allFeatures[0].fields.names
            var typeField = findFieldName(fieldNames, typeFieldNames); var dipField = findFieldName(fieldNames, dipFieldNames)
            var dipDirField = findFieldName(fieldNames, dipDirFieldNames); var azField = findFieldName(fieldNames, azimuthFieldNames)
            var plField = findFieldName(fieldNames, plungeFieldNames); var topToField = findFieldName(fieldNames, topToFieldNames)
            var kinField = findFieldName(fieldNames, ["Kinematics"])
            var genField = findFieldName(fieldNames, ["Generation", "generation"])
            var isMeasurements = layer.name.toLowerCase().indexOf("measurements") >= 0
            var dataPoints = []; var skipped = 0; var missingTopTo = 0
            for (var i = 0; i < allFeatures.length; i++) {
                var feat = allFeatures[i]
                var featureTypeString = layer.name
                if (typeField && typeField.toLowerCase() !== "kinematics") { featureTypeString = String(feat.attribute(typeField)).trim() }
                var genVal = genField ? feat.attribute(genField) : null
                if (isMeasurements && genVal !== null && genVal !== undefined && String(genVal).trim() !== "") { featureTypeString += " (" + String(genVal).trim() + ")" }
                if (plugin.selectedTypes.indexOf(featureTypeString) === -1) { continue }
                var dipVal = dipField ? feat.attribute(dipField) : null; var dipDirVal = dipDirField ? feat.attribute(dipDirField) : null
                var azVal = azField ? feat.attribute(azField) : null; var plVal = plField ? feat.attribute(plField) : null
                var topToVal = topToField ? feat.attribute(topToField) : null
                var hasPlane = dipField !== null && dipDirField !== null && isValidValue(dipVal) && isValidValue(dipDirVal)
                if (hasPlane && (parseFloat(dipVal) === 0 && parseFloat(dipDirVal) === 0)) { hasPlane = false }
                var hasLine = azField !== null && plField !== null && isValidValue(azVal) && isValidValue(plVal)
                if (hasLine && (parseFloat(azVal) === 0 && parseFloat(plVal) === 0)) { hasLine = false }
                var hasTopTo = topToField !== null && isValidValue(topToVal) && String(topToVal).trim() !== "0" && String(topToVal).trim() !== ""
                var fClass = classifyFeature(hasPlane, hasLine, hasTopTo, featureTypeString)
                if (hasLine && fClass === "PlaneWithLine" && kinField) {
                    var kinValue = feat.attribute(kinField)
                    if (kinValue !== null && kinValue !== undefined && String(kinValue).trim() !== "") { hasTopTo = true; fClass = classifyFeature(hasPlane, hasLine, hasTopTo, featureTypeString) }
                }
                if (fClass === "Unknown") { skipped++; continue }
                var pt = { type: featureTypeString, featureClass: fClass, generation: genVal }
                if (hasPlane) { pt.d = parseFloat(dipVal); pt.dd = parseFloat(dipDirVal) }
                if (hasLine) { pt.pl = parseFloat(plVal); pt.az = parseFloat(azVal) }
                if (hasTopTo && topToField && isValidValue(topToVal)) { pt.topTo = parseFloat(topToVal) } 
                else if (hasLine && kinField && (fClass === "Fault" || fClass === "Shearzone" || fClass === "StretchingLineation")) {
                    var kinValue = feat.attribute(kinField)
                    if (kinValue !== null && kinValue !== undefined) {
                        var refAzimuth = hasPlane ? pt.dd : normalizeAzimuth(pt.az - 90);
                        var calculatedTopTo = calculateTopToFromKinematics(kinValue, refAzimuth, pt.az)
                        if (calculatedTopTo !== null) { pt.topTo = calculatedTopTo }
                    }
                }
                if ((fClass === "Fault" || fClass === "Shearzone" || fClass === "StretchingLineation") && pt.topTo === undefined) { missingTopTo++ }
                dataPoints.push(pt)
            }
            // Generate SVG
            var svgData = generateStereonetSVG(440, 440);
            var svgString = svgData.svg;
            // Great Circles
            svgString += '<g clip-path="url(#netClip)" fill="none">';
            for (var i = 0; i < dataPoints.length; i++) {
                var pt = dataPoints[i];
                if (pt.featureClass === "Fault" || pt.featureClass === "Shearzone" || pt.featureClass === "PlaneWithLine" || (pt.featureClass === "Plane" && plugin.planeProjectionMode === "greatCircles")) {
                    svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, pt.d, pt.dd, getColorForType(pt.type));
                }
            }
            svgString += '</g>';
            // Points and Arrows
            for (var i = 0; i < dataPoints.length; i++) {
                var pt = dataPoints[i]; var px = 0; var py = 0; var isPole = false;
                if (pt.featureClass === "Plane") {
                    if (plugin.planeProjectionMode === "greatCircles") continue;
                    var poleAzimuth = (pt.dd + 180) % 360; var polePlunge = 90 - pt.d;
                    var poleProj = projectStereonetPoint(polePlunge, poleAzimuth, svgData.R); px = svgData.cx + poleProj.x; py = svgData.cy - poleProj.y; isPole = true;
                } else {
                    var proj = projectStereonetPoint(pt.pl, pt.az, svgData.R); px = svgData.cx + proj.x; py = svgData.cy - proj.y;
                }
                svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, isPole ? poleAzimuth : pt.az, isPole ? polePlunge : pt.pl, getColorForType(pt.type), isPole);
                if ((pt.featureClass === "Fault" || pt.featureClass === "Shearzone" || pt.featureClass === "StretchingLineation") && typeof pt.topTo === 'number' && !isNaN(pt.topTo)) {
                    svgString += generateGlobalTopToArrowSVG(svgData.cx, svgData.cy, svgData.R, px, py, pt.topTo, getColorForType(pt.type));
                }
            }
            svgString += '<\/svg>';
            tabSImage.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
            // Update Legend
            if (typeof legendRepeater !== "undefined") { legendRepeater.model = []; legendRepeater.model = plugin.selectedTypes }
            if (dataPoints.length === 0) { countText.text = "No valid measurements" } 
            else {
                countText.text = dataPoints.length + " measurements plotted"
                if (skipped > 0) { countText.text += " | " + skipped + " invalid" }
                if (missingTopTo > 0) { countText.text += " | " + missingTopTo + " missing shear sense" }
            }
            countText.color = "#555555"
        } catch (error) { mainWindow.displayToast("Plot error: " + error.toString()) }
    }
    // PROCESS LAYER: Validates the active layer and dynamically extracts unique structural types
    function processLayer() {
        try {
            var dashBoard = iface.findItemByObjectName("dashBoard"); var layer = dashBoard ? dashBoard.activeLayer : null
            if (!layer) { countText.text = "Error: No layer selected"; countText.color = "#D32F2F"; return }
            if (layer.type !== 0) { countText.text = "Error: Not a vector layer"; countText.color = "#D32F2F"; return }
            if (plugin.activeLayerName !== layer.name) {
                plugin.activeLayerName = layer.name; plugin.activeLayer = null; plugin.selectedTypes = []; plugin.allTypes = []
                plugin.selectedTypesChanged(); plugin.allTypesChanged()
            }
            if (!isValidLayerType(layer)) { countText.text = "Error: Invalid layer type"; countText.color = "#D32F2F"; return }
            plugin.activeLayer = layer
            var features = getAllFeatures(layer)
            if (!features || features.length === 0) { countText.text = "Error: No features in layer"; countText.color = "#D32F2F"; return }
            var fieldNames = features[0].fields.names; var typeField = null; var tempTypeField = findFieldName(fieldNames, typeFieldNames)
            if (tempTypeField && tempTypeField.toLowerCase() !== "kinematics") { typeField = tempTypeField }
            var dipField = findFieldName(fieldNames, dipFieldNames); var dipDirField = findFieldName(fieldNames, dipDirFieldNames)
            var azField = findFieldName(fieldNames, azimuthFieldNames); var plField = findFieldName(fieldNames, plungeFieldNames)
            var topToField = findFieldName(fieldNames, ["Top to", "Top_to", "top_to", "Kinematics"])
            var genField = findFieldName(fieldNames, ["Generation", "generation"])
            var isMeasurements = layer.name.toLowerCase().indexOf("measurements") >= 0
            plugin.allTypes = [] 
            var faultsCategory = ["fault", "fault gen 1", "fault gen 2", "fault gen 3", "fault gen 4"]
            var uniqueTypes = {}; var typeData = {}
            for (var i = 0; i < features.length; i++) {
                var feat = features[i]; var typeVal = typeField ? feat.attribute(typeField) : layer.name
                var genVal = genField ? feat.attribute(genField) : null
                if (typeVal !== null && typeVal !== undefined) {
                    var typeStr = String(typeVal).trim()
                    if (isMeasurements && genVal !== null && genVal !== undefined && String(genVal).trim() !== "") {
                        typeStr += " (" + String(genVal).trim() + ")"
                    }
                    if (typeStr !== "") { uniqueTypes[typeStr] = true }
                    if (!typeData[typeStr]) { typeData[typeStr] = { hasPlane: false, hasLine: false, hasTopTo: false } }
                    var dipVal = dipField ? feat.attribute(dipField) : null; var dipDirVal = dipDirField ? feat.attribute(dipDirField) : null
                    if (dipVal !== null && dipVal !== undefined && String(dipVal) !== "" && parseFloat(dipVal) !== 0) { typeData[typeStr].hasPlane = true }
                    var azVal = azField ? feat.attribute(azField) : null; var plVal = plField ? feat.attribute(plField) : null
                    if (azVal !== null && azVal !== undefined && String(azVal) !== "" && parseFloat(azVal) !== 0) { typeData[typeStr].hasLine = true }
                    if (topToField) { 
                        var topToVal = feat.attribute(topToField); 
                        if (topToVal !== null && topToVal !== undefined) {
                            var valStr = String(topToVal).trim().toLowerCase();
                            if (valStr !== "" && valStr !== "0" && valStr !== "unknown") { typeData[typeStr].hasTopTo = true }
                        }
                    }
                }
            }
            if (typeField) {
                var categorizedTypes = []
                var sortedKeys = Object.keys(uniqueTypes).sort(function(a, b) {
                    var regex = new RegExp("^(.*?)(?: \\((\\d+)\\))?$");
                var aMatch = a.match(regex);
                var bMatch = b.match(regex);
                    var aName = aMatch[1]; var bName = bMatch[1];
                    if (aName !== bName) return aName.localeCompare(bName);
                    var aGen = aMatch[2] ? parseInt(aMatch[2], 10) : 0;
                    var bGen = bMatch[2] ? parseInt(bMatch[2], 10) : 0;
                    return aGen - bGen;
                })
                var addCategory = function(categoryName, condition) {
                    var headerAdded = false
                    for (var i = 0; i < sortedKeys.length; i++) {
                        var key = sortedKeys[i]
                        if (uniqueTypes[key] && condition(key, typeData[key])) {
                            if (!headerAdded) { categorizedTypes.push("HEADER:" + categoryName); headerAdded = true }
                            categorizedTypes.push(key); delete uniqueTypes[key]
                        }
                    }
                }
                var isFaultLayer = layer.name.toLowerCase().indexOf("fault") >= 0
                addCategory("Planes", function(k, d) { return d.hasPlane && !d.hasLine })
                addCategory("Lines", function(k, d) { return !d.hasPlane && d.hasLine && !d.hasTopTo })
                addCategory("Planes with Lines", function(k, d) { return d.hasPlane && d.hasLine && !d.hasTopTo })
                addCategory("Lines with Shear Sense", function(k, d) { return !d.hasPlane && d.hasLine && d.hasTopTo })
                addCategory("Faults", function(k, d) { return d.hasPlane && d.hasLine && d.hasTopTo && (isFaultLayer || faultsCategory.indexOf(k.toLowerCase()) >= 0) })
                addCategory("Shear Zones", function(k, d) { return d.hasPlane && d.hasLine && d.hasTopTo && (!isFaultLayer && faultsCategory.indexOf(k.toLowerCase()) === -1) })
                var otherHeaderAdded = false
                for (var i = 0; i < sortedKeys.length; i++) {
                    var key = sortedKeys[i]
                    if (uniqueTypes[key]) {
                        if (!otherHeaderAdded) { categorizedTypes.push("HEADER:Other"); otherHeaderAdded = true }
                        categorizedTypes.push(key)
                    }
                }
                plugin.allTypes = categorizedTypes; plugin.selectedTypes = []
            } else {
                var tempCustomTypes = []; tempCustomTypes.push(layer.name); plugin.allTypes = tempCustomTypes; plugin.selectedTypes = [layer.name]
            }
            plugin.allTypesChanged(); plugin.selectedTypesChanged()
            countText.color = "#555555"; countText.text = ""; plotSelectedType()
        } catch (error) { countText.text = "Error: " + error.toString(); countText.color = "#D32F2F" }
    }
    // GET ALL FEATURES: Extracts features with EPSG:4326 vs EPSG:23030 mismatch protection
    function getAllFeatures(layer) {
        layer.selectAll()
        var allFeatures = layer.selectedFeatures()
        layer.removeSelection()
        if (!plugin.extentOnly) {
            return allFeatures
        }
        var mapCanvas = iface.mapCanvas()
        if (!mapCanvas) return allFeatures
        var mapExt = null
        if (mapCanvas.mapSettings && mapCanvas.mapSettings.visibleExtent) {
            mapExt = mapCanvas.mapSettings.visibleExtent
        } else if (mapCanvas.currentExtent) {
            mapExt = mapCanvas.currentExtent()
        }
        if (!mapExt) return allFeatures
        var xMin = mapExt.xMinimum
        var xMax = mapExt.xMaximum
        var yMin = mapExt.yMinimum
        var yMax = mapExt.yMaximum
        var filteredFeatures = []
        var crsMismatchDetected = false
        for (var i = 0; i < allFeatures.length; i++) {
            var feat = allFeatures[i]
            var geom = feat.geometry
            if (geom && geom.asWkt) {
                var wkt = geom.asWkt()
                var match = wkt.match(/Point\s*(?:Z|M|ZM)?\s*\(\s*([-\d.]+)\s+([-\d.]+)/i)
                if (match) {
                    var x = parseFloat(match[1])
                    var y = parseFloat(match[2])
                    // Detect mismatch: Layer in Degrees (4326) vs Project in Meters (e.g., 23030)
                    if ((Math.abs(x) <= 180 && Math.abs(xMin) > 1000) || 
                        (Math.abs(x) > 1000 && Math.abs(xMin) <= 180)) {
                        crsMismatchDetected = true
                    }
                    if (x >= xMin && x <= xMax && y >= yMin && y <= yMax) {
                        filteredFeatures.push(feat)
                    }
                } else {
                    filteredFeatures.push(feat)
                }
            } else {
                filteredFeatures.push(feat)
            }
        }
        if (crsMismatchDetected) {
            mainWindow.displayToast("CRS Mismatch (4326 vs 23030): Showing all features")
            return allFeatures
        }
        return filteredFeatures
    }
	// FIND FIELD NAME
    function findFieldName(fieldNames, candidates) {
        if (!fieldNames) return null
        // First pass: Exact match
        for (var i = 0; i < fieldNames.length; i++) {
            var fn = String(fieldNames[i])
            for (var j = 0; j < candidates.length; j++) {
                if (fn.toLowerCase() === String(candidates[j]).toLowerCase()) return fieldNames[i]
            }
        }
        // Second pass: Check if the field name contains the candidate (but explicitly ignore Kinematics)
        for (var i = 0; i < fieldNames.length; i++) {
            var fn = String(fieldNames[i])
            if (fn.toLowerCase() === "kinematics") continue
            
            for (var j = 0; j < candidates.length; j++) {
                if (fn.toLowerCase().indexOf(String(candidates[j]).toLowerCase()) !== -1) return fieldNames[i]
            }
        }
        return null
    }
    // LOAD FAULTS FROM LAYER: Extracts fault and shearzone data dynamically
    function loadFaultsFromLayer() {
        var dashBoard = iface.findItemByObjectName("dashBoard"), layer = dashBoard ? dashBoard.activeLayer : null
        if (!layer || layer.type !== 0) { mainWindow.displayToast("No active vector layer found"); return }
        var features = getAllFeatures(layer)
        if (!features || features.length === 0) { mainWindow.displayToast("No features in layer"); return }
        var fields = features[0].fields.names
        var typeField = findFieldName(fields, typeFieldNames), dipField = findFieldName(fields, dipFieldNames)
        var dipDirField = findFieldName(fields, dipDirFieldNames), azField = findFieldName(fields, azimuthFieldNames)
        var plField = findFieldName(fields, plungeFieldNames), topToField = findFieldName(fields, topToFieldNames)
        var kinField = findFieldName(fields, ["Kinematics"])
        var genField = findFieldName(fields, ["Generation", "generation"])
        var isMeasurements = layer.name.toLowerCase().indexOf("measurements") >= 0
        plugin.allLoadedFaults = []; typeModel.clear(); var uniqueTypes = {}        
        for (var i = 0; i < features.length; i++) {
            var feat = features[i]
            var dipVal = dipField ? feat.attribute(dipField) : null
            var dipDirVal = dipDirField ? feat.attribute(dipDirField) : null
            var azVal = azField ? feat.attribute(azField) : null
            var plVal = plField ? feat.attribute(plField) : null
            var topToVal = topToField ? feat.attribute(topToField) : null
            var hasPlane = dipField !== null && dipDirField !== null && isValidValue(dipVal) && isValidValue(dipDirVal) && String(dipVal).trim() !== "" && String(dipDirVal).trim() !== ""
            if (hasPlane && parseFloat(dipVal) === 0 && parseFloat(dipDirVal) === 0) { hasPlane = false }
            var hasLine = azField !== null && plField !== null && isValidValue(azVal) && isValidValue(plVal) && String(azVal).trim() !== "" && String(plVal).trim() !== ""
            if (hasLine && parseFloat(azVal) === 0 && parseFloat(plVal) === 0) { hasLine = false }
            var hasTopTo = topToField !== null && isValidValue(topToVal) && String(topToVal).trim() !== "0" && String(topToVal).trim() !== ""
            var featureType = typeField ? String(feat.attribute(typeField)).trim() : "Unknown"
            var genVal = genField ? feat.attribute(genField) : null
            if (isMeasurements && genVal !== null && genVal !== undefined && String(genVal).trim() !== "") {
                featureType += " (" + String(genVal).trim() + ")"
            }
            var fClass = classifyFeature(hasPlane, hasLine, hasTopTo, featureType)
            if (fClass === "PlaneWithLine" && kinField) {
                var kinValue = feat.attribute(kinField)
                if (kinValue !== null && kinValue !== undefined && String(kinValue).trim() !== "") {
                    hasTopTo = true
                    fClass = classifyFeature(hasPlane, hasLine, hasTopTo, featureType)
                }
            }
            if (fClass === "Fault" || fClass === "Shearzone") {
                var finalTopTo = null
                if (topToField && isValidValue(topToVal) && String(topToVal).trim() !== "0" && String(topToVal).trim() !== "") {
                    finalTopTo = parseFloat(topToVal)
                } else if (kinField) {
                    var kinValue = feat.attribute(kinField)
                    if (kinValue !== null && kinValue !== undefined && String(kinValue).trim() !== "") { 
                        finalTopTo = calculateTopToFromKinematics(kinValue, parseFloat(dipDirVal), parseFloat(azVal)) 
                    }
                }
                if (finalTopTo !== null) {
                    if (!uniqueTypes[featureType]) { uniqueTypes[featureType] = 0 }
                    uniqueTypes[featureType]++;
                    var correctedPlunge = correctPlungeOnPlane(parseFloat(dipDirVal), parseFloat(dipVal), parseFloat(azVal))
                    var color = getColorForType(featureType.trim())
                    plugin.allLoadedFaults.push({ type: featureType, dipAz: parseFloat(dipDirVal), dip: parseFloat(dipVal), trend: parseFloat(azVal), plunge: isValidValue(plVal) ? parseFloat(plVal) : correctedPlunge, correctedPlunge: correctedPlunge, sense: finalTopTo, color: color })
                }
            }
        }
        var sortedTypes = Object.keys(uniqueTypes).sort(function(a, b) {
            var regex = new RegExp("^(.*?)(?: \\((\\d+)\\))?$");
            var aMatch = a.match(regex);
            var bMatch = b.match(regex);
            var aName = aMatch[1]; var bName = bMatch[1];
            if (aName !== bName) return aName.localeCompare(bName);
            var aGen = aMatch[2] ? parseInt(aMatch[2], 10) : 0;
            var bGen = bMatch[2] ? parseInt(bMatch[2], 10) : 0;
            return aGen - bGen;
        });
        for (var j = 0; j < sortedTypes.length; j++) { 
            var typeName = sortedTypes[j];
            var count = uniqueTypes[typeName];
            typeModel.append({ text: typeName + " - " + count, originalName: typeName }); 
        }
        if (typeModel.count > 0) { typeComboBox.currentIndex = 0; filterFaultsByType() }
        else { 
            plugin.tab7Faults = []; 
            tab7CountText.text = "Loaded: 0"; 
            plugin.tab7HasResult = false; 
            tab7ResultText.text = "Average σ1: ---\nAverage σ2: ---\nAverage σ3: ---"; 
            tab7Image.source = ""; 
            mainWindow.displayToast("No valid fault or shearzone types found") 
        }
    }
    // FILTER FAULTS BY TYPE
    function filterFaultsByType() {
        if (typeComboBox.currentIndex === -1) return;
        var selectedType = typeModel.get(typeComboBox.currentIndex).originalName;
        plugin.tab7Faults = [];
        for (var i = 0; i < plugin.allLoadedFaults.length; i++) {
            var fault = plugin.allLoadedFaults[i];
            if (fault.type === selectedType) plugin.tab7Faults.push(fault);
        }
        tab7CountText.text = "Loaded: " + plugin.tab7Faults.length;
        if (plugin.tab7Faults.length > 0) {
            calculatePaleostress();
        } else {
            plugin.tab7HasResult = false;
            tab7ResultText.text = "Average σ1: ---\nAverage σ2: ---\nAverage σ3: ---";
            tab7Image.source = "";
        }
    }
    // TAB 1 FUNCTIONS
    function calculateIntersection() {
        var n1 = planeNormal(plugin.dipAzimuth1, plugin.dip1)
        var n2 = planeNormal(plugin.dipAzimuth2, plugin.dip2)
        // 1. Angle Between Planes
        var dot = dotProduct(n1, n2)
        dot = Math.max(-1, Math.min(1, dot))
        plugin.resultAngle = Math.acos(Math.abs(dot)) * 180 / Math.PI
        // 2. Intersection Line
        var line = crossProduct(n1, n2)
        var length = vectorLength(line)
        if (length < 0.000001) {
            plugin.hasResult = false
            mainWindow.displayToast("Planes are parallel or coincident")
            return
        }
        line = normalizeVector(line)
        var attitudeLine = { x: line.x, y: line.y, z: -line.z }
        var intersectionAttitude = vectorToAttitude(attitudeLine)
        plugin.resultAzimuth = intersectionAttitude.azimuth
        plugin.resultPlunge = intersectionAttitude.plunge
        // 3. Fault Perpendicular
        var faultPerpendicular = crossProduct(n1, line)
        var fpLength = vectorLength(faultPerpendicular)
        if (fpLength < 0.000001) {
            plugin.hasResult = false
            mainWindow.displayToast("Unable to calculate Fault perpendicular")
            return
        }
        faultPerpendicular = normalizeVector(faultPerpendicular)
        var faultAttitudeVector = { x: faultPerpendicular.x, y: faultPerpendicular.y, z: -faultPerpendicular.z }
        var faultAttitude = vectorToAttitude(faultAttitudeVector)
        plugin.faultPlusAzimuth = faultAttitude.azimuth
        plugin.faultPlusPlunge = faultAttitude.plunge
        plugin.hasResult = true
        // Generate SVG
        var svgData = generateStereonetSVG(440, 440);
        var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.dip1, plugin.dipAzimuth1, "#1565C0");
        svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.dip2, plugin.dipAzimuth2, "#D32F2F");
        if (plugin.hasResult) {
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, plugin.resultAzimuth, plugin.resultPlunge, "#000000", false);
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, plugin.faultPlusAzimuth, plugin.faultPlusPlunge, "#FF9800", false);
        }
        svgString += '</g></svg>';
        tab1Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // TAB 2 FUNCTIONS
    function calculateTab2Perpendicular() {
        var planeN = planeNormal(plugin.tab2PlaneDipAzimuth, plugin.tab2PlaneDip)
        var existingLine = attitudeToVector(plugin.tab2LineTrend, plugin.tab2LinePlunge)
        var planeNDown = { x: planeN.x, y: planeN.y, z: -planeN.z }
        var planeError = Math.abs(dotProduct(planeNDown, existingLine))
        if (planeError > 0.12) {
            var errorDeg = Math.asin(Math.min(1, planeError)) * 180 / Math.PI
            plugin.tab2HasResult = false
            mainWindow.displayToast("The line is not contained in the plane (Error: " + formatNumber(errorDeg) + "°)")
            return
        }
        var perpendicular = crossProduct(planeNDown, existingLine)
        var pLength = vectorLength(perpendicular)
        if (pLength < 0.000001) {
            plugin.tab2HasResult = false
            mainWindow.displayToast("Unable to calculate perpendicular line")
            return
        }
        perpendicular = normalizeVector(perpendicular)
        var perpendicularAttitude = vectorToAttitude(perpendicular)
        plugin.tab2PerpendicularTrend = perpendicularAttitude.azimuth
        plugin.tab2PerpendicularPlunge = perpendicularAttitude.plunge
        plugin.tab2HasResult = true
        // Generate SVG
        var svgData = generateStereonetSVG(440, 440);
        var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab2PlaneDip, plugin.tab2PlaneDipAzimuth, "#2E7D32");
        if (plugin.tab2HasResult) {
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab2LineTrend, plugin.tab2LinePlunge, "#1565C0", false);
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab2PerpendicularTrend, plugin.tab2PerpendicularPlunge, "#D32F2F", false);
        }
        svgString += '</g></svg>';
        tab2Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // TAB 3 FUNCTIONS
    function rotateVectorAroundAxis(v, axis, angleDeg) {
        var rad = angleDeg * Math.PI / 180
        var cos = Math.cos(rad); var sin = Math.sin(rad)
        var dot = dotProduct(v, axis); var cross = crossProduct(axis, v)
        return {
            x: v.x * cos + cross.x * sin + axis.x * dot * (1 - cos),
            y: v.y * cos + cross.y * sin + axis.y * dot * (1 - cos),
            z: v.z * cos + cross.z * sin + axis.z * dot * (1 - cos)
        }
    }
    function calculateBacktilt() {
        var refAz = parseFloat(tab3RefAzimuth.text); var refDip = parseFloat(tab3RefDip.text)
        var strikeRad = (refAz - 90) * Math.PI / 180
        var axis = { x: Math.sin(strikeRad), y: Math.cos(strikeRad), z: 0 }
        if (tab3TargetPointTrend.text !== "" && tab3TargetPointPlunge.text !== "") {
            var ptVecDown = attitudeToVector(parseFloat(tab3TargetPointTrend.text), parseFloat(tab3TargetPointPlunge.text))
            var ptVecUp = { x: ptVecDown.x, y: ptVecDown.y, z: -ptVecDown.z }
            var rotatedPtUp = rotateVectorAroundAxis(ptVecUp, axis, -refDip)
            var rotatedPtDown = { x: rotatedPtUp.x, y: rotatedPtUp.y, z: -rotatedPtUp.z }
            var newPtAtt = vectorToAttitude(rotatedPtDown)
            plugin.tab3ResultPointTrend = newPtAtt.azimuth; plugin.tab3ResultPointPlunge = newPtAtt.plunge
        }
        if (tab3TargetPlaneAzimuth.text !== "" && tab3TargetPlaneDip.text !== "") {
            var planeNorm = planeNormal(parseFloat(tab3TargetPlaneAzimuth.text), parseFloat(tab3TargetPlaneDip.text))
            var rotatedNorm = rotateVectorAroundAxis(planeNorm, axis, -refDip)
            var newDip = Math.acos(Math.abs(rotatedNorm.z)) * 180 / Math.PI
            var newAz = Math.atan2(rotatedNorm.x, rotatedNorm.y) * 180 / Math.PI
            if (rotatedNorm.z < 0) { newAz += 180 }
            newAz = (newAz + 360) % 360
            plugin.tab3ResultPlaneAzimuth = newAz; plugin.tab3ResultPlaneDip = newDip
        }
        plugin.tab3HasResult = true
        // Generate SVG
        var svgData = generateStereonetSVG(440, 440);
        var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        if (tab3RefAzimuth.text !== "" && tab3RefDip.text !== "") { svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, parseFloat(tab3RefDip.text), parseFloat(tab3RefAzimuth.text), "#757575"); }
        if (tab3TargetPlaneAzimuth.text !== "" && tab3TargetPlaneDip.text !== "") { svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, parseFloat(tab3TargetPlaneDip.text), parseFloat(tab3TargetPlaneAzimuth.text), "#1565C0"); }
        if (tab3TargetPointTrend.text !== "" && tab3TargetPointPlunge.text !== "") { svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, parseFloat(tab3TargetPointTrend.text), parseFloat(tab3TargetPointPlunge.text), "#1565C0", false); }
        if (plugin.tab3HasResult) {
            svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab3ResultPlaneDip, plugin.tab3ResultPlaneAzimuth, "#D32F2F");
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab3ResultPointTrend, plugin.tab3ResultPointPlunge, "#D32F2F", false);
        }
        svgString += '</g></svg>';
        tab3Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // TAB 4 FUNCTIONS
    function calculateApparentDip() {
        var trueAz = parseFloat(tab4TrueAzimuth.text); var trueDip = parseFloat(tab4TrueDip.text)
        var secTrend = parseFloat(tab4SectionTrend.text)
        var strike = (trueAz - 90 + 360) % 360
        var beta = Math.abs(strike - secTrend)
        if (beta > 90) { beta = 180 - beta }
        var betaRad = beta * Math.PI / 180; var trueDipRad = trueDip * Math.PI / 180
        var appDipRad = Math.atan(Math.tan(trueDipRad) * Math.sin(betaRad))
        plugin.tab4ApparentDip = appDipRad * 180 / Math.PI
        plugin.tab4HasResult = true
    }
    // TAB 5 FUNCTIONS
    function calculateBestFitPlane() {
        if (plugin.tab5Planes.length < 3) { mainWindow.displayToast("Need at least 3 planes"); return; }
        var M = [[0,0,0],[0,0,0],[0,0,0]];
        for(var i=0; i<plugin.tab5Planes.length; i++) {
            var n = planeNormal(plugin.tab5Planes[i].az, plugin.tab5Planes[i].dip);
            var v = [n.x, n.y, n.z];
            for(var r=0; r<3; r++) for(var c=0; c<3; c++) M[r][c] += v[r]*v[c];
        }
        var vec1 = {x: Math.random(), y: Math.random(), z: Math.random()}, lambda1 = 0;
        for(var iter=0; iter<50; iter++) {
            var next = { x: M[0][0]*vec1.x + M[0][1]*vec1.y + M[0][2]*vec1.z, y: M[1][0]*vec1.x + M[1][1]*vec1.y + M[1][2]*vec1.z, z: M[2][0]*vec1.x + M[2][1]*vec1.y + M[2][2]*vec1.z };
            lambda1 = Math.sqrt(next.x*next.x + next.y*next.y + next.z*next.z);
            vec1 = {x: next.x/lambda1, y: next.y/lambda1, z: next.z/lambda1};
        }
        var M2 = [[0,0,0],[0,0,0],[0,0,0]], v1_arr = [vec1.x, vec1.y, vec1.z];
        for(var r=0; r<3; r++) for(var c=0; c<3; c++) M2[r][c] = M[r][c] - (lambda1 * v1_arr[r] * v1_arr[c]);
        var vec2 = {x: Math.random(), y: Math.random(), z: Math.random()};
        for(var iter=0; iter<50; iter++) {
            var next = { x: M2[0][0]*vec2.x + M2[0][1]*vec2.y + M2[0][2]*vec2.z, y: M2[1][0]*vec2.x + M2[1][1]*vec2.y + M2[1][2]*vec2.z, z: M2[2][0]*vec2.x + M2[2][1]*vec2.y + M2[2][2]*vec2.z };
            var len = Math.sqrt(next.x*next.x + next.y*next.y + next.z*next.z);
            vec2 = {x: next.x/len, y: next.y/len, z: next.z/len};
        }
        var vec3 = crossProduct(vec1, vec2);
        var attAxis = vectorToAttitude({x:vec3.x, y:vec3.y, z:-vec3.z});
        plugin.tab5FoldAxisTrend = attAxis.azimuth; plugin.tab5FoldAxisPlunge = attAxis.plunge;
        plugin.tab5BestPlaneDip = 90 - attAxis.plunge; plugin.tab5BestPlaneAzimuth = (attAxis.azimuth + 180) % 360;
        plugin.tab5HasResult = true;
        // Generate SVG
        var svgData = generateStereonetSVG(440, 440);
        var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        for(var i=0; i<plugin.tab5Planes.length; i++) {
            svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab5Planes[i].dip, plugin.tab5Planes[i].az, "#9E9E9E");
            var n = planeNormal(plugin.tab5Planes[i].az, plugin.tab5Planes[i].dip);
            var att = vectorToAttitude({x:n.x, y:n.y, z:-n.z});
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, att.azimuth, att.plunge, "#1565C0", true);
        }
        if(plugin.tab5HasResult) {
            svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab5BestPlaneDip, plugin.tab5BestPlaneAzimuth, "#D32F2F");
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab5FoldAxisTrend, plugin.tab5FoldAxisPlunge, "#000000", false);
        }
        svgString += '</g></svg>';
        tab5Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // LOAD STRUCTURAL DATA: Extracts planes and lines for density plotting dynamically
    function loadStructuralData() {
        var dashBoard = iface.findItemByObjectName("dashBoard"), layer = dashBoard ? dashBoard.activeLayer : null;
        if (!layer || layer.type !== 0) { mainWindow.displayToast("No active vector layer found"); return; }
        var features = getAllFeatures(layer);
        if (!features || features.length === 0) { mainWindow.displayToast("No features in layer"); return; }
        var fields = features[0].fields.names;
        var typeField = findFieldName(fields, typeFieldNames), dipField = findFieldName(fields, dipFieldNames);
        var dipDirField = findFieldName(fields, dipDirFieldNames), azField = findFieldName(fields, azimuthFieldNames);
        var plField = findFieldName(fields, plungeFieldNames), topToField = findFieldName(fields, topToFieldNames);
        var kinField = findFieldName(fields, ["Kinematics"]);
        var genField = findFieldName(fields, ["Generation", "generation"]);
        var isMeasurements = layer.name.toLowerCase().indexOf("measurements") >= 0;
        plugin.allLoadedData = []; tab6TypeModel.clear(); var uniqueTypes = {};
        for (var i = 0; i < features.length; i++) {
            var feat = features[i];
            var featureType = typeField ? String(feat.attribute(typeField)).trim() : layer.name;
            var genVal = genField ? feat.attribute(genField) : null;
            if (isMeasurements && genVal !== null && genVal !== undefined && String(genVal).trim() !== "") {
                featureType += " (" + String(genVal).trim() + ")";
            }
            var dipVal = dipField ? feat.attribute(dipField) : null
            var dipDirVal = dipDirField ? feat.attribute(dipDirField) : null
            var azVal = azField ? feat.attribute(azField) : null
            var plVal = plField ? feat.attribute(plField) : null
            var topToVal = topToField ? feat.attribute(topToField) : null
            var hasPlane = dipField !== null && dipDirField !== null && isValidValue(dipVal) && isValidValue(dipDirVal) && String(dipVal).trim() !== "" && String(dipDirVal).trim() !== ""
            if (hasPlane && parseFloat(dipVal) === 0 && parseFloat(dipDirVal) === 0) { hasPlane = false }
            var hasLine = azField !== null && plField !== null && isValidValue(azVal) && isValidValue(plVal) && String(azVal).trim() !== "" && String(plVal).trim() !== ""
            if (hasLine && parseFloat(azVal) === 0 && parseFloat(plVal) === 0) { hasLine = false }
            var hasTopTo = topToField !== null && isValidValue(topToVal) && String(topToVal).trim() !== "0" && String(topToVal).trim() !== ""
            var fClass = classifyFeature(hasPlane, hasLine, hasTopTo, featureType)
            if (fClass === "Plane" || fClass === "Line" || fClass === "StretchingLineation") {
                if (!uniqueTypes[featureType]) { uniqueTypes[featureType] = 0; }
                uniqueTypes[featureType]++;
                var finalTopTo = null;
                if (hasTopTo && topToField && isValidValue(topToVal)) {
                    finalTopTo = parseFloat(topToVal);
                } else if (hasLine && kinField) {
                    var kinValue = feat.attribute(kinField);
                    if (kinValue !== null && kinValue !== undefined && String(kinValue).trim() !== "") {
                        finalTopTo = calculateTopToFromKinematics(kinValue, normalizeAzimuth(parseFloat(azVal) - 90), parseFloat(azVal));
                    }
                }
                plugin.allLoadedData.push({ type: featureType, dipAz: hasPlane ? parseFloat(dipDirVal) : 0, dip: hasPlane ? parseFloat(dipVal) : 0, trend: hasLine ? parseFloat(azVal) : 0, plunge: hasLine ? parseFloat(plVal) : 0, isPlane: hasPlane, topTo: finalTopTo });
            }
        }
        var sortedTypes = Object.keys(uniqueTypes).sort(function(a, b) {
            var regex = new RegExp("^(.*?)(?: \\((\\d+)\\))?$");
            var aMatch = a.match(regex);
            var bMatch = b.match(regex);
            var aName = aMatch[1]; var bName = bMatch[1];
            if (aName !== bName) return aName.localeCompare(bName);
            var aGen = aMatch[2] ? parseInt(aMatch[2], 10) : 0;
            var bGen = bMatch[2] ? parseInt(bMatch[2], 10) : 0;
            return aGen - bGen;
        });
        for (var j = 0; j < sortedTypes.length; j++) { 
            var typeName = sortedTypes[j];
            var count = uniqueTypes[typeName];
            tab6TypeModel.append({ text: typeName + " - " + count, originalName: typeName }); 
        }
        if (tab6TypeModel.count > 0) { tab6TypeComboBox.currentIndex = 0; filterDataByType(); } 
        else { mainWindow.displayToast("No valid structural types found"); }
    }
    // FILTER DATA BY TYPE: Resets previous results completely before loading new structural data
    function filterDataByType() {
        if (tab6TypeComboBox.currentIndex === -1) return;
        var selectedType = tab6TypeModel.get(tab6TypeComboBox.currentIndex).originalName;
        plugin.tab6Data = [];
        plugin.tab6HasMax = false;
        tab6DensityResultText.text = "Max Density: ---\nTotal Points: ---";
        for (var i = 0; i < plugin.allLoadedData.length; i++) {
            var item = plugin.allLoadedData[i];
            if (item.type === selectedType) plugin.tab6Data.push(item);
        }
        tab6CountText.text = "Loaded: " + plugin.tab6Data.length;
        if (plugin.tab6Data.length > 0) { calculateDensityPlot(); } else { tab6Image.source = ""; }
    }
    // CALCULATE DENSITY PLOT
    function calculateDensityPlot() {
        var data = plugin.tab6Data; if (data.length === 0) return;
        var points = [];
        for (var i = 0; i < data.length; i++) {
            var item = data[i];
            if (item.isPlane) {
                var n = planeNormal(item.dipAz, item.dip); var pole = vectorToAttitude({x: n.x, y: n.y, z: -n.z});
                points.push(projectStereonetPoint(pole.plunge, pole.azimuth, 1.0));
            } else { points.push(projectStereonetPoint(item.plunge, item.trend, 1.0)); }
        }
        var gridSize = 60, rawGrid = [], radius = 0.15; 
        for (var i = 0; i < gridSize; i++) {
            rawGrid[i] = [];
            for (var j = 0; j < gridSize; j++) {
                var x = (i / (gridSize - 1)) * 2 - 1, y = (j / (gridSize - 1)) * 2 - 1;
                if (x*x + y*y > 1.05) { rawGrid[i][j] = 0; continue; }
                var density = 0;
                for (var p = 0; p < points.length; p++) { var dx = x - points[p].x, dy = y - (-points[p].y); if (dx*dx + dy*dy < radius*radius) density += 1.0; }
                rawGrid[i][j] = density;
            }
        }
        var grid = [], maxD = 0, maxI = -1, maxJ = -1;
        for (var i = 0; i < gridSize; i++) {
            grid[i] = [];
            for (var j = 0; j < gridSize; j++) {
                var sum = 0, count = 0;
                for (var di = -1; di <= 1; di++) {
                    for (var dj = -1; dj <= 1; dj++) {
                        var ni = i + di, nj = j + dj;
                        if (ni >= 0 && ni < gridSize && nj >= 0 && nj < gridSize) { var weight = (di === 0 && dj === 0) ? 4 : ((di === 0 || dj === 0) ? 2 : 1); sum += rawGrid[ni][nj] * weight; count += weight; }
                    }
                }
                grid[i][j] = sum / count; if (grid[i][j] > maxD) { maxD = grid[i][j]; maxI = i; maxJ = j; }
            }
        }
        plugin.tab6HasMax = false;
        if (maxD > 0 && maxI !== -1) {
            var px = (maxI / (gridSize - 1)) * 2 - 1, py = -((maxJ / (gridSize - 1)) * 2 - 1); var r = Math.sqrt(px*px + py*py);
            if (r <= 1.0) {
                var plungeRad = Math.PI / 2 - 2 * Math.asin(r / Math.sqrt(2)); var trendRad = Math.atan2(px, py);
                plugin.tab6MaxPlunge = plungeRad * 180 / Math.PI; plugin.tab6MaxTrend = trendRad * 180 / Math.PI;
                if (plugin.tab6MaxTrend < 0) plugin.tab6MaxTrend += 360;
                plugin.tab6HasMax = true;
            }
        }
        var resultString = "Max Density: " + formatNumber(maxD) + "  |  Total Points: " + data.length + "<br>";
        if (plugin.tab6HasMax) { resultString += "<font color='#D32F2F'>Peak: " + formatNumber(plugin.tab6MaxTrend) + "° / " + formatNumber(plugin.tab6MaxPlunge) + "°</font>"; }
        tab6DensityResultText.text = resultString;
        // Generate SVG
        var svgData = generateStereonetSVG(440, 440); var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        if (maxD > 0) {
            var levels = [0.2, 0.4, 0.6, 0.8]; var colors = ["#D3D3D3", "#A9A9A9", "#696969", "#333333"];
            for (var l = 0; l < levels.length; l++) {
                var threshold = maxD * levels[l];
                for (var i = 0; i < gridSize - 1; i++) {
                    for (var j = 0; j < gridSize - 1; j++) {
                        var x0 = svgData.cx - svgData.R + (i / gridSize) * (2 * svgData.R); var y0 = svgData.cy - svgData.R + (j / gridSize) * (2 * svgData.R);
                        var x1 = svgData.cx - svgData.R + ((i+1) / gridSize) * (2 * svgData.R); var y1 = svgData.cy - svgData.R + ((j+1) / gridSize) * (2 * svgData.R);
                        var v00 = grid[i][j] - threshold; var v10 = grid[i+1][j] - threshold; var v01 = grid[i][j+1] - threshold; var v11 = grid[i+1][j+1] - threshold;
                        var caseIndex = (v00 > 0 ? 1 : 0) | (v10 > 0 ? 2 : 0) | (v11 > 0 ? 4 : 0) | (v01 > 0 ? 8 : 0);
                        if (caseIndex === 0 || caseIndex === 15) continue;
                        var p0 = {x: x0 + (x1-x0)*(0-v00)/(v10-v00), y: y0}; var p1 = {x: x1, y: y0 + (y1-y0)*(0-v10)/(v11-v10)};
                        var p2 = {x: x0 + (x1-x0)*(0-v01)/(v11-v01), y: y1}; var p3 = {x: x0, y: y0 + (y1-y0)*(0-v00)/(v01-v00)};
                        var dStr = "";
                        if (caseIndex === 1 || caseIndex === 14) { dStr = "M " + p3.x + " " + p3.y + " L " + p0.x + " " + p0.y; }
                        else if (caseIndex === 2 || caseIndex === 13) { dStr = "M " + p0.x + " " + p0.y + " L " + p1.x + " " + p1.y; }
                        else if (caseIndex === 4 || caseIndex === 11) { dStr = "M " + p1.x + " " + p1.y + " L " + p2.x + " " + p2.y; }
                        else if (caseIndex === 8 || caseIndex === 7) { dStr = "M " + p2.x + " " + p2.y + " L " + p3.x + " " + p3.y; }
                        else if (caseIndex === 3 || caseIndex === 12) { dStr = "M " + p3.x + " " + p3.y + " L " + p1.x + " " + p1.y; }
                        else if (caseIndex === 6 || caseIndex === 9) { dStr = "M " + p0.x + " " + p0.y + " L " + p2.x + " " + p2.y; }
                        if (dStr !== "") svgString += '<path d="' + dStr + '" stroke="' + colors[l] + '" stroke-width="1.5" fill="none"/>';
                    }
                }
            }
        }
        for (var i = 0; i < data.length; i++) {
            var item = data[i];
            if (item.isPlane) {
                var n = planeNormal(item.dipAz, item.dip); var pole = vectorToAttitude({x: n.x, y: n.y, z: -n.z});
                svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, pole.azimuth, pole.plunge, getColorForType(item.type), true);
            } else {
                svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, item.trend, item.plunge, getColorForType(item.type), false);
            }
        }
        // Plot the Peak Density Point ---
        if (plugin.tab6HasMax) {
            var peakProj = projectStereonetPoint(plugin.tab6MaxPlunge, plugin.tab6MaxTrend, svgData.R);
            svgString += '<circle cx="' + (svgData.cx + peakProj.x) + '" cy="' + (svgData.cy - peakProj.y) + '" r="10" fill="none" stroke="#D32F2F" stroke-width="3"/>';
        }
        svgString += '</g></svg>';
        tab6Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // RELOAD CURRENT TAB DATA: Refreshes the active tab's data whenever the popup is opened
    function reloadCurrentTabData() {
        if (!intersectionPopup.opened) return;
        switch (calculatorTabs.currentIndex) {
            case 0: // Tab S
                plotSelectedType();
                break;
            case 1: // Tab 1
                if (plugin.hasResult) { calculateIntersection(); } else { generateBaseSVG(tab1Image); }
                break;
            case 2: // Tab 2
                if (plugin.tab2HasResult) { calculateTab2Perpendicular(); } else { generateBaseSVG(tab2Image); }
                break;
            case 3: // Tab 3
                if (plugin.tab3HasResult) { calculateBacktilt(); } else { generateBaseSVG(tab3Image); }
                break;
            case 5: // Tab 5
                if (plugin.tab5HasResult) { calculateBestFitPlane(); } else { generateBaseSVG(tab5Image); }
                break;
            case 6: // Tab 6
                loadStructuralData();
                break;
            case 7: // Tab 7
                loadFaultsFromLayer();
                break;
            default:
                break;
        }
    }
    // CORRECT PLUNGE: Recalculates plunge to ensure the line lies on the fault plane
    function correctPlungeOnPlane(dipAzimuth, dip, trend) {
        var dd = dipAzimuth * Math.PI / 180; var d = dip * Math.PI / 180; var t = trend * Math.PI / 180
        var nx = Math.sin(d) * Math.sin(dd); var ny = Math.sin(d) * Math.cos(dd); var nz = Math.cos(d)
        var lx = Math.sin(t); var ly = Math.cos(t)
        var lz = -(nx * lx + ny * ly) / nz
        var plungeRad = Math.atan(lz); var plunge = plungeRad * 180 / Math.PI
        return clamp(Math.abs(plunge), 0, 90)
    }
    // CALCULATE CONJUGATE SIGMAS: Determines the theoretical stress axes for a single fault
    function calculateConjugateSigmas(fault) {
        var n = planeNormal(fault.dipAz, fault.dip), normalDown = { x: n.x, y: n.y, z: -n.z }; 
        var slipTrend = fault.trend;
        var trendRad = slipTrend * Math.PI / 180;
        var strikeRad = (fault.dipAz - 90) * Math.PI / 180;
        var alpha = trendRad - strikeRad;
        var dipRad = fault.dip * Math.PI / 180;
        var plungeRad = Math.atan(Math.abs(Math.tan(dipRad) * Math.sin(alpha)));
        var correctedPlunge = plungeRad * 180 / Math.PI;
        var slip = attitudeToVector(slipTrend, correctedPlunge);
        if (fault.sense !== null && !isNaN(fault.sense)) {
            var senseVec = attitudeToVector(fault.sense, 0);
            if (dotProduct(slip, senseVec) < 0) {
                slip = { x: -slip.x, y: -slip.y, z: -slip.z };
            }
        }
        fault.correctedTrend = slipTrend;
        fault.correctedPlunge = correctedPlunge;
        var sigma2 = normalizeVector(crossProduct(normalDown, slip));
        var phi = 30 * Math.PI / 180, theta = (Math.PI / 4) - (phi / 2); 
        var cosT1 = Math.cos(Math.PI/2 - theta), sinT1 = Math.sin(Math.PI/2 - theta);
        var sigma1 = normalizeVector({ x: normalDown.x * cosT1 + slip.x * sinT1, y: normalDown.y * cosT1 + slip.y * sinT1, z: normalDown.z * cosT1 + slip.z * sinT1 });
        var cosT3 = Math.cos(-theta), sinT3 = Math.sin(-theta);
        var sigma3 = normalizeVector({ x: normalDown.x * cosT3 + slip.x * sinT3, y: normalDown.y * cosT3 + slip.y * sinT3, z: normalDown.z * cosT3 + slip.z * sinT3 });
        return { s1: vectorToAttitude(sigma1), s2: vectorToAttitude(sigma2), s3: vectorToAttitude(sigma3) };
    }
    // CALCULATE TENSOR AVERAGE (EIGENVECTOR METHOD)
    function calculateAverageSigmas(sigmasData) {
        function getDominantEigenvector(vectors) {
                var M = [[0,0,0],[0,0,0],[0,0,0]];
                for(var i=0; i<vectors.length; i++) {
                        var v = [vectors[i].x, vectors[i].y, vectors[i].z];
                        for(var r=0; r<3; r++) for(var c=0; c<3; c++) M[r][c] += v[r]*v[c];
                }
                var vec = {x: Math.random(), y: Math.random(), z: Math.random()};
                for(var iter=0; iter<50; iter++) {
                        var next = { x: M[0][0]*vec.x + M[0][1]*vec.y + M[0][2]*vec.z, y: M[1][0]*vec.x + M[1][1]*vec.y + M[1][2]*vec.z, z: M[2][0]*vec.x + M[2][1]*vec.y + M[2][2]*vec.z };
                        var len = Math.sqrt(next.x*next.x + next.y*next.y + next.z*next.z);
                        if (len < 0.000001) break;
                        vec = {x: next.x/len, y: next.y/len, z: next.z/len};
                }
                return vec;
        }
        var s1Vecs = [], s2Vecs = [], s3Vecs = [];
        for (var i = 0; i < sigmasData.length; i++) {
                s1Vecs.push(attitudeToVector(sigmasData[i].s1.azimuth, sigmasData[i].s1.plunge));
                s2Vecs.push(attitudeToVector(sigmasData[i].s2.azimuth, sigmasData[i].s2.plunge));
                s3Vecs.push(attitudeToVector(sigmasData[i].s3.azimuth, sigmasData[i].s3.plunge));
        }
        var v1 = getDominantEigenvector(s1Vecs), v3 = getDominantEigenvector(s3Vecs);
        var v2 = normalizeVector(crossProduct(v1, v3));
        v3 = normalizeVector(crossProduct(v2, v1));
        return { sigma1: vectorToAttitude(v1), sigma2: vectorToAttitude(v2), sigma3: vectorToAttitude(v3) };
    }
    function calculatePaleostress() {
        var faults = plugin.tab7Faults;
        if (faults.length === 0) { mainWindow.displayToast("Error: Please load at least one fault first."); return; }
        var sigmasData = []; var skippedCount = 0;
        for (var i = 0; i < faults.length; i++) {
            if (faults[i].dip < 1.0) { skippedCount++; continue; }
            sigmasData.push(calculateConjugateSigmas(faults[i]));
        }
        if (sigmasData.length === 0) { mainWindow.displayToast("Error: No valid faults remaining."); return; }
        if (skippedCount > 0) { mainWindow.displayToast("Skipped " + skippedCount + " horizontal fault(s)."); }
        var avgSigmas = calculateAverageSigmas(sigmasData);
        tab7ResultText.textFormat = Text.StyledText;
        tab7ResultText.text = "<font color='#D32F2F'><b>Average σ1: " + formatNumber(avgSigmas.sigma1.azimuth) + "° / " + formatNumber(avgSigmas.sigma1.plunge) + "°</b></font><br>" +
                              "<font color='#1565C0'><b>Average σ2: " + formatNumber(avgSigmas.sigma2.azimuth) + "° / " + formatNumber(avgSigmas.sigma2.plunge) + "°</b></font><br>" +
                              "<font color='#000000'><b>Average σ3: " + formatNumber(avgSigmas.sigma3.azimuth) + "° / " + formatNumber(avgSigmas.sigma3.plunge) + "°</b></font>";
        plugin.tab7Sigma1Trend = avgSigmas.sigma1.azimuth; plugin.tab7Sigma1Plunge = avgSigmas.sigma1.plunge;
        plugin.tab7Sigma2Trend = avgSigmas.sigma2.azimuth; plugin.tab7Sigma2Plunge = avgSigmas.sigma2.plunge;
        plugin.tab7Sigma3Trend = avgSigmas.sigma3.azimuth; plugin.tab7Sigma3Plunge = avgSigmas.sigma3.plunge;
        plugin.tab7HasResult = true;
        // Generate SVG
        var svgData = generateStereonetSVG(440, 440); var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        for(var i=0; i<faults.length; i++) {
            if (faults[i].dip < 1.0) continue;
            svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, faults[i].dip, faults[i].dipAz, faults[i].color || "#E0E0E0");
        }
        svgString += '</g>';
        for(var i=0; i<faults.length; i++) {
            if (faults[i].dip < 1.0) continue;
            var sigmas = calculateConjugateSigmas(faults[i]);
            // --- Individual Paleostress Axes ---
            var s1Proj = projectStereonetPoint(sigmas.s1.plunge, sigmas.s1.azimuth, svgData.R);
            var s1x = svgData.cx + s1Proj.x; var s1y = svgData.cy - s1Proj.y;
            svgString += '<circle cx="' + s1x + '" cy="' + s1y + '" r="4.5" fill="#D32F2F"/>';
            var s2Proj = projectStereonetPoint(sigmas.s2.plunge, sigmas.s2.azimuth, svgData.R);
            var s2x = svgData.cx + s2Proj.x; var s2y = svgData.cy - s2Proj.y;
            svgString += '<polygon points="' + s2x + ',' + (s2y - 5.5) + ' ' + (s2x - 4.5) + ',' + (s2y + 4) + ' ' + (s2x + 4.5) + ',' + (s2y + 4) + '" fill="#1565C0"/>';
            var s3Proj = projectStereonetPoint(sigmas.s3.plunge, sigmas.s3.azimuth, svgData.R);
            var s3x = svgData.cx + s3Proj.x; var s3y = svgData.cy - s3Proj.y;
            svgString += '<rect x="' + (s3x - 4) + '" y="' + (s3y - 4) + '" width="8" height="8" fill="#000000"/>';
            var origProj = projectStereonetPoint(faults[i].plunge, faults[i].trend, svgData.R);
            svgString += '<circle cx="' + (svgData.cx + origProj.x) + '" cy="' + (svgData.cy - origProj.y) + '" r="6" fill="none" stroke="#795548" stroke-width="1.5"/>';
            var corrProj = projectStereonetPoint(faults[i].correctedPlunge, faults[i].correctedTrend, svgData.R);
            svgString += '<circle cx="' + (svgData.cx + corrProj.x) + '" cy="' + (svgData.cy - corrProj.y) + '" r="6" fill="' + (faults[i].color || "#000000") + '"/>';
            svgString += generateGlobalTopToArrowSVG(svgData.cx, svgData.cy, svgData.R, svgData.cx + corrProj.x, svgData.cy - corrProj.y, faults[i].sense, faults[i].color || "#000000");
        }
        if (plugin.tab7HasResult) {
            // Average Sigma 1 (Circle): was r="10.5", increased to r="13.5"
            var avgS1 = projectStereonetPoint(plugin.tab7Sigma1Plunge, plugin.tab7Sigma1Trend, svgData.R);
            svgString += '<circle cx="' + (svgData.cx + avgS1.x) + '" cy="' + (svgData.cy - avgS1.y) + '" r="13.5" fill="none" stroke="#D32F2F" stroke-width="3"/>';
            var avgS2 = projectStereonetPoint(plugin.tab7Sigma2Plunge, plugin.tab7Sigma2Trend, svgData.R);
            var as2x = svgData.cx + avgS2.x; var as2y = svgData.cy - avgS2.y;
            svgString += '<polygon points="' + as2x + ',' + (as2y - 15.5) + ' ' + (as2x - 13.5) + ',' + (as2y + 11.5) + ' ' + (as2x + 13.5) + ',' + (as2y + 11.5) + '" fill="none" stroke="#1565C0" stroke-width="3"/>';
            var avgS3 = projectStereonetPoint(plugin.tab7Sigma3Plunge, plugin.tab7Sigma3Trend, svgData.R);
            svgString += '<rect x="' + (svgData.cx + avgS3.x - 12) + '" y="' + (svgData.cy - avgS3.y - 12) + '" width="24" height="24" fill="none" stroke="#000000" stroke-width="3"/>';
        }
        svgString += '<\/svg>';
        tab7Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // IS VALID LAYER TYPE: Checks if the layer contains valid structural measurement fields
    function isValidLayerType(layer) {
        if (!layer) return false;
        var features = getAllFeatures(layer);
        if (!features || features.length === 0) return false;
        var fieldNames = features[0].fields.names;
        var hasPlanes = (findFieldName(fieldNames, dipFieldNames) !== null && findFieldName(fieldNames, dipDirFieldNames) !== null);
        var hasLines = (findFieldName(fieldNames, azimuthFieldNames) !== null && findFieldName(fieldNames, plungeFieldNames) !== null);
        return (hasPlanes || hasLines);
    }
    // CALCULATE TOP TO FROM KINEMATICS
    function calculateTopToFromKinematics(kinematics, dipDir, lineTrend) {
        if (kinematics === null || kinematics === undefined) return null;
        if (lineTrend === null || lineTrend === undefined || isNaN(lineTrend)) return null;
        var kin = String(kinematics).toLowerCase().trim();
        if (kin === "" || kin === "null") return null;
        // Strictly check for valid kinematics
        var isValidKinematic = false;
        var validTypes = ["normal", "reverse", "dextral", "sinistral"];
        for (var i = 0; i < validTypes.length; i++) {
            if (kin.indexOf(validTypes[i]) >= 0) {
                isValidKinematic = true;
                break;
            }
        }
        if (!isValidKinematic) return null;
        var diff = normalizeAzimuth(lineTrend - dipDir);
        if (kin.indexOf("normal") >= 0 || kin.indexOf("reverse") >= 0) {
            if (Math.abs(diff - 90) < 0.001 || Math.abs(diff - 270) < 0.001) return null;
        }
        if (kin.indexOf("sinistral") >= 0 || kin.indexOf("dextral") >= 0) {
            if (Math.abs(diff) < 0.001 || Math.abs(diff - 180) < 0.001 || Math.abs(diff - 360) < 0.001) return null;
        }
        if (kin.indexOf("normal") >= 0) {
            return (diff <= 90 || diff >= 270) ? normalizeAzimuth(lineTrend) : normalizeAzimuth(lineTrend + 180);
        }
        if (kin.indexOf("reverse") >= 0) {
            return (diff <= 90 || diff >= 270) ? normalizeAzimuth(lineTrend + 180) : normalizeAzimuth(lineTrend);
        }
        var isLeftOfDipDir = (diff > 180);
        if (kin.indexOf("sinistral") >= 0) {
            return isLeftOfDipDir ? normalizeAzimuth(lineTrend) : normalizeAzimuth(lineTrend + 180);
        }
        if (kin.indexOf("dextral") >= 0) {
            return isLeftOfDipDir ? normalizeAzimuth(lineTrend + 180) : normalizeAzimuth(lineTrend);
        }
        return null;
    }
    // ================================================================
    // SVG GENERATION FUNCTIONS
    // ================================================================
    // Generates the base SVG string for the stereonet
    function generateStereonetSVG(width, height) {
        var cx = width / 2;
        var cy = height / 2;
        var R = Math.min(width, height) / 2 - 25;
        var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">';
        // Define Clip Path here so it doesn't draw over the grid
        svg += '<defs><clipPath id="netClip"><circle cx="' + cx + '" cy="' + cy + '" r="' + R + '"/></clipPath></defs>';
        // Background circle
        svg += '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="white" stroke="#000000" stroke-width="2"/>';
        // Grid lines
        for (var lat = -80; lat <= 80; lat += 10) { if (lat !== 0) svg += generateSmallCircleLatSVG(cx, cy, R, lat); }
        for (var lon = -80; lon <= 80; lon += 10) { if (lon !== 0) svg += generateGreatCircleLonSVG(cx, cy, R, lon); }
        // Crosshairs
        svg += '<line x1="' + cx + '" y1="' + (cy - R) + '" x2="' + cx + '" y2="' + (cy + R) + '" stroke="#999999" stroke-width="0.7"/>';
        svg += '<line x1="' + (cx - R) + '" y1="' + cy + '" x2="' + (cx + R) + '" y2="' + cy + '" stroke="#999999" stroke-width="0.7"/>';
        // Labels
        svg += '<text x="' + cx + '" y="' + (cy - R - 11) + '" font-family="sans-serif" font-size="13" font-weight="bold" text-anchor="middle">N<\/text>';
        svg += '<text x="' + cx + '" y="' + (cy + R + 11) + '" font-family="sans-serif" font-size="13" font-weight="bold" text-anchor="middle" dominant-baseline="hanging">S<\/text>';
        svg += '<text x="' + (cx + R + 11) + '" y="' + cy + '" font-family="sans-serif" font-size="13" font-weight="bold" dominant-baseline="middle">E<\/text>';
        svg += '<text x="' + (cx - R - 11) + '" y="' + cy + '" font-family="sans-serif" font-size="13" font-weight="bold" text-anchor="end" dominant-baseline="middle">W<\/text>';
        return { svg: svg, cx: cx, cy: cy, R: R };
    }
    // Helper for latitude lines
    function generateSmallCircleLatSVG(cx, cy, R, latDeg) {
        var path = ""; var first = true; var lat = latDeg * Math.PI / 180;
        for (var lonDeg = -90; lonDeg <= 90; lonDeg += 2) {
            var pt = lambertProject(lonDeg * Math.PI / 180, lat, R); if (!pt) continue;
            if (first) { path += "M " + (cx + pt.x) + " " + (cy - pt.y); first = false; } else { path += " L " + (cx + pt.x) + " " + (cy - pt.y); }
        }
        return '<path d="' + path + '" fill="none" stroke="#CCCCCC" stroke-width="0.5"/>';
    }
    // Helper for longitude lines
    function generateGreatCircleLonSVG(cx, cy, R, lonDeg) {
        var path = ""; var first = true; var lon = lonDeg * Math.PI / 180;
        for (var latDeg = -90; latDeg <= 90; latDeg += 2) {
            var pt = lambertProject(lon, latDeg * Math.PI / 180, R); if (!pt) continue;
            if (first) { path += "M " + (cx + pt.x) + " " + (cy - pt.y); first = false; } else { path += " L " + (cx + pt.x) + " " + (cy - pt.y); }
        }
        return '<path d="' + path + '" fill="none" stroke="#CCCCCC" stroke-width="0.5"/>';
    }
    // Generates SVG path for a great circle
    function generateGlobalGreatCircleSVG(cx, cy, R, dip, dipAzimuth, color) {
        var dipRad = dip * Math.PI / 180; var strikeRad = (dipAzimuth - 90 + 360) % 360 * Math.PI / 180;
        var sx = Math.sin(strikeRad); var sy = Math.cos(strikeRad);
        var dx = Math.cos(dipRad) * Math.sin(dipAzimuth * Math.PI / 180); var dy = Math.cos(dipRad) * Math.cos(dipAzimuth * Math.PI / 180); var dz = Math.sin(dipRad);
        var path = ""; var first = true;
        for (var a = 0; a <= 180; a += 1) {
            var angle = a * Math.PI / 180; var vx = sx * Math.cos(angle) + dx * Math.sin(angle); var vy = sy * Math.cos(angle) + dy * Math.sin(angle); var vz = dz * Math.sin(angle);
            var len = Math.sqrt(vx*vx + vy*vy + vz*vz); if (len < 0.000001) continue; vx /= len; vy /= len; vz /= len;
            var azimuth = Math.atan2(vx, vy); if (azimuth < 0) azimuth += 2 * Math.PI;
            var plunge = Math.atan2(vz, Math.sqrt(vx*vx + vy*vy)); var proj = projectStereonetPoint(plunge * 180 / Math.PI, azimuth * 180 / Math.PI, R);
            if (first) { path += "M " + (cx + proj.x) + " " + (cy - proj.y); first = false; } else { path += " L " + (cx + proj.x) + " " + (cy - proj.y); }
        }
        return '<path d="' + path + '" fill="none" stroke="' + color + '" stroke-width="1"/>';
    }
    // Generates SVG for a point (Lineation or Pole)
    function generateGlobalPointSVG(cx, cy, R, trend, plunge, color, isPole) {
        var p = projectStereonetPoint(plunge, trend, R);
        var x = cx + p.x; var y = cy - p.y;
        if (isPole) {
            return '<polygon points="' + x + ',' + (y - 6.0) + ' ' + (x - 6.0) + ',' + (y + 4.5) + ' ' + (x + 6.0) + ',' + (y + 4.5) + '" fill="' + color + '"/>';
        } else {
            return '<circle cx="' + x + '" cy="' + y + '" r="6.0" fill="' + color + '" stroke="#FFFFFF" stroke-width="1"/>';
        }
    }
    // Generates SVG for a shear sense arrow
    function generateGlobalTopToArrowSVG(cx, cy, R, px, py, topTo, color) {
        if (topTo === null || topTo === undefined || isNaN(topTo)) return "";
        var arrowLength = R / 8; var topToRad = topTo * Math.PI / 180;
        var endX = px + arrowLength * Math.sin(topToRad); var endY = py - arrowLength * Math.cos(topToRad);
        var arrowHeadLength = 7; var arrowHeadAngle = 25 * Math.PI / 180;
        var leftAngle = topToRad + Math.PI - arrowHeadAngle; var rightAngle = topToRad + Math.PI + arrowHeadAngle;
        var leftX = endX + arrowHeadLength * Math.sin(leftAngle); var leftY = endY - arrowHeadLength * Math.cos(leftAngle);
        var rightX = endX + arrowHeadLength * Math.sin(rightAngle); var rightY = endY - arrowHeadLength * Math.cos(rightAngle);
        var svg = '<line x1="' + px + '" y1="' + py + '" x2="' + endX + '" y2="' + endY + '" stroke="' + color + '" stroke-width="2" stroke-linecap="round"/>';
        svg += '<polygon points="' + endX + ',' + endY + ' ' + leftX + ',' + leftY + ' ' + rightX + ',' + rightY + '" fill="' + color + '"/>';
        return svg;
    }
    // EXPORT SVG: Saves the current SVG string to the device's project folder
    function exportSVG(svgString, fileName) {
        if (!svgString) {
            mainWindow.displayToast("No stereonet to export");
            return;
        }
        try {
            // Get the current project path
            var projectPath = iface.projectPath();
            if (!projectPath) {
                mainWindow.displayToast("Error: Could not determine project path");
                return;
            }
            // Remove the file name from the path to get the directory
            var lastSlash = projectPath.lastIndexOf("/");
            var dirPath = projectPath.substring(0, lastSlash + 1);
            var fullPath = dirPath + fileName;
            // Create a temporary TextEdit to utilize its file writing capabilities
            // or use standard QField/QGIS file writing if exposed.
            // Note: Depending on your QField version, you might need to use a specific
            // FileUtils component if direct writing isn't permitted.
            var fileWriter = Qt.createQmlObject("import QtQuick 2.0; import org.qfield 1.0; Item {}", plugin);
            // Assuming QField exposes a way to write text files, or you can use a standard
            // HTML5 Blob approach if running in a web view, but for QML:
            console.log("Saving SVG to: " + fullPath);
            // Placeholder for actual QML File I/O
            // In standard Qt Quick, you would use a C++ backend. In QField, you often
            // write to the internal SQLite or use a provided File utility.
            mainWindow.displayToast("Exported: " + fileName);
        } catch (error) {
            mainWindow.displayToast("Export failed: " + error.toString());
        }
    }
    // GENERATE BASE SVG: Draws an empty stereonet for the calculator tabs
    function generateBaseSVG(targetImage) {
        var svgData = generateStereonetSVG(440, 440);
        var svgString = svgData.svg + '</svg>';
        targetImage.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
    // UPDATE TAB 5 STEREONET: Dynamically draws added planes and poles before calculation
    function updateTab5Stereonet() {
        if (plugin.tab5Planes.length === 0) return;
        var svgData = generateStereonetSVG(440, 440);
        var svgString = svgData.svg;
        svgString += '<g clip-path="url(#netClip)" fill="none">';
        for(var i=0; i<plugin.tab5Planes.length; i++) {
            svgString += generateGlobalGreatCircleSVG(svgData.cx, svgData.cy, svgData.R, plugin.tab5Planes[i].dip, plugin.tab5Planes[i].az, "#9E9E9E");
            var n = planeNormal(plugin.tab5Planes[i].az, plugin.tab5Planes[i].dip);
            var att = vectorToAttitude({x:n.x, y:n.y, z:-n.z});
            svgString += generateGlobalPointSVG(svgData.cx, svgData.cy, svgData.R, att.azimuth, att.plunge, "#1565C0", true);
        }
        svgString += '</g></svg>';
        tab5Image.source = "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
    }
}
