/*
 * ============================================================================
 * Structural Geology Calculator
 * ============================================================================
 * Author:      Liviu Matenco (Utrecht University)
 * Version:     1.0
 * License:     MIT License
 * 
 * Description:
 * This QField plugin provides structural geology calculations and real-time
 * equal-area Schmidt stereonet plotting for fieldwork. It supports planes, 
 * lines, and faults with shear sense.
 * 
 * Project Setup Requirements:
 * The active layer in QField must be named "measurements" and contain the 
 * following fields (case-insensitive, must be exact, otherwise modify the code below):
 *  - Dip azimuth & Dip (Integer): Required for planes (see also alternative names below)
 *  - Trend & Plunge (Integer): Required for lines
 *  - Top to (Integer): Required for senses of shear
 *  - Type (Text/String): Defines the structural feature (see below)
 * 
 * Supported "Type" Values (must be exact, otherwise modify the code below):
 *  - Planes: bedding, bedding overturned, foliation, foliation S1, 
 *    foliation S2, foliation S3, cleavage, normal fault, reverse fault, 
 *    fault gouge foliation, Riedel shear, Other measurements
 *  - Lines: fold, fold f1, fold f2, fold f3, fold f4, stretching lineation, 
 *    stretching lineation L1, stretching lineation L2, stretching lineation L3, 
 *    slickenlines, other lineation
 *  - Faults: fault, fault gen 1, fault gen 2, fault gen 3, fault gen 4
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
    // NAMES OF FIELDS FOR MEASUREMENTS OF PLANES, LINEATIONS AND SHEAR SENSES
    // ============================================================
	property var dipFieldNames: ["dip", "dip_angle", "P_dip", "Dip"]
	property var dipDirFieldNames: ["dip_dir", "dipdirection", "dd", "Dip azimuth"]
	property var azimuthFieldNames: ["azimuth", "trend", "L_plungeAzimuth", "Trend"]
	property var plungeFieldNames: ["plunge", "pl", "L_plunge", "Plunge"]
	property var topToFieldNames: ["Top to", "Top_to", "top_to"]
    property bool extentOnly: false  // false = all features, true = current view only
    // ============================================================
    // NAMES OF THE FIELD WHERE THE TYPE OF MEASUREMENT IS DEFINED
    // ============================================================
	property var typeFieldNames: ["Type", "type"]
    // TAB S (STEREONET) PROPERTIES
    property var selectedTypes: []
    property var activeLayer: null
    property string planeProjectionMode: "poles"
    property var planeTypes: [ "bedding", "bedding overturned", "fault", "fault gen 1", "fault gen 2", "fault gen 3", "fault gen 4", "foliation", "foliation S1", "foliation S2", "foliation S3", "cleavage", "normal fault", "reverse fault", "fault gouge foliation", "Riedel shear", "Other measurements", "Axial Plane", "shear plane", "Gouge P fol", "Flow Bands" ]
    property var lineTypes: [ "fault", "fault gen 1", "fault gen 2", "fault gen 3", "fault gen 4", "fold", "fold f1", "fold f2", "fold f3", "fold f4", "stretching lineation", "stretching lineation L1", "stretching lineation L2", "stretching lineation L3", "slickenlines", "other lineation" ]
    property var allTypes: planeTypes.concat(lineTypes).filter(function(item, pos, self) {
        return self.indexOf(item) === pos;
    })
    property var topToTypes: [ "fault", "fault gen 1", "fault gen 2", "fault gen 3", "fault gen 4", "stretching lineation", "stretching lineation L1", "stretching lineation L2", "stretching lineation L3", "slickenlines" ]
    property var typeColors: ({
        "bedding": "#000000", "bedding overturned": "#FF0000", "fault": "#000000",
        "fault gen 1": "#FF0000", "fault gen 2": "#00A000", "fault gen 3": "#4B0082",
        "fault gen 4": "#0000FF", "foliation": "#000000", "foliation S1": "#FF0000",
        "foliation S2": "#00A000", "foliation S3": "#4B0082", "Axial Plane": "#FF0000",
        "shear plane": "#000000", "Gouge P fol": "#FF0000", "Flow Bands": "#000000",
        "cleavage": "#0000FF", "normal fault": "#000000", "reverse fault": "#4B0082",
        "fault gouge foliation": "#FF0000", "Riedel shear": "#FF0000", "Other measurements": "#000000",
        "fold": "#000000", "fold f1": "#FF0000", "fold f2": "#00A000",
        "fold f3": "#4B0082", "fold f4": "#0000FF", "currents": "#FF0000",
        "stretching lineation": "#000000", "stretching lineation L1": "#FF0000", "stretching lineation L2": "#00A000",
        "stretching lineation L3": "#4B0082", "slickenlines": "#0000FF", "other lineation": "#000000"
    })
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
                delegate: Rectangle { width: typeList.width; height: 42
                    color: plugin.selectedTypes.indexOf(modelData) >= 0 ? "#E3F2FD" : (typeMouse.containsMouse ? "#F5F5F5" : "#FFFFFF")
                    border.color: plugin.selectedTypes.indexOf(modelData) >= 0 ? "#2196F3" : "#EEEEEE"; border.width: 1
                    Rectangle { width: 18; height: 18; radius: 9; anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; color: plugin.colorForType(modelData) }
                    Text { anchors.left: parent.left; anchors.leftMargin: 38; anchors.right: parent.right; anchors.rightMargin: 35; anchors.verticalCenter: parent.verticalCenter; text: modelData; font.pixelSize: 14; color: "#222222"; elide: Text.ElideRight }
                    Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: plugin.isFaultType(modelData) ? "P+L" : (plugin.isPlaneType(modelData) ? "P" : "L"); font.pixelSize: 11; font.bold: true; color: "#777777" }
                    MouseArea { id: typeMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var index = plugin.selectedTypes.indexOf(modelData)
                            if (index >= 0) {
                                plugin.selectedTypes.splice(index, 1)
                            } else {
                                plugin.selectedTypes.push(modelData)
                            }
                            plugin.selectedTypesChanged()
                            plugin.plotSelectedType()
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
                        Column { id: tabSColumn; width: parent.width; spacing: 7
                            // TITLE
                            Text { width: parent.width; height: 28; text: "Structural Geology Stereonet"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 17; font.bold: true; color: "#222222" }
                            // TYPE SELECTOR
                            Row { width: parent.width; height: 46; spacing: 8
                                Text { width: 45; text: "Type:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 14; font.bold: true; color: "#333333" }
                                Button { id: typeButton; width: parent.width - 53; height: 44; font.pixelSize: 14
                                    background: Rectangle { color: "#FFFFFF"; border.color: "#777777"; border.width: 1; radius: 4 }
                                    contentItem: Row { spacing: 10; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter
                                        Rectangle { width: 16; height: 16; radius: 8; visible: plugin.selectedTypes.length === 1; color: plugin.selectedTypes.length === 1 ? plugin.colorForType(plugin.selectedTypes[0]) : "transparent"; anchors.verticalCenter: parent.verticalCenter }
                                        Text { 
                                            text: plugin.selectedTypes.length === 0 ? "None selected" : (plugin.selectedTypes.length === 1 ? plugin.selectedTypes[0] : plugin.selectedTypes.length + " types selected"); 
                                            color: "#222222"; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: typeButton.width - 70 
                                        }
                                        Text { text: "▼"; color: "#555555"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    onClicked: { typeSelectorPopup.open() }
                                }
                            }
                            // PLANE PROJECTION SELECTOR
                            Row { width: parent.width; height: 42; spacing: 6; visible: plugin.selectedTypes.some(function(t) { return plugin.isPlaneType(t) && !plugin.isFaultType(t); })
                                Text { width: 65; text: "Plot:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 13; font.bold: true; color: "#333333" }
                                Button { width: 95; height: 36; text: "Poles"
                                    background: Rectangle { radius: 4; color: plugin.planeProjectionMode === "poles" ? "#2196F3" : "#EEEEEE"; border.color: "#777777"; border.width: 1 }
                                    contentItem: Text { text: parent.text; color: plugin.planeProjectionMode === "poles" ? "white" : "#333333"; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: { plugin.planeProjectionMode = "poles"; plugin.plotSelectedType() }
                                }
                                Button { width: 120; height: 36; text: "Great circles"
                                    background: Rectangle { radius: 4; color: plugin.planeProjectionMode === "greatCircles" ? "#2196F3" : "#EEEEEE"; border.color: "#777777"; border.width: 1 }
                                    contentItem: Text { text: parent.text; color: plugin.planeProjectionMode === "greatCircles" ? "white" : "#333333"; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: { plugin.planeProjectionMode = "greatCircles"; plugin.plotSelectedType() }
                                }
                            }
                            // EXPLANATORY BOX
                            Rectangle { width: parent.width; height: (plugin.selectedTypes.length === 1 && plugin.isFaultType(plugin.selectedTypes[0])) ? 62 : ((plugin.selectedTypes.length === 1 && plugin.hasTopToLine(plugin.selectedTypes[0])) ? 48 : 30); radius: 4; color: "#F5F5F5"; border.color: plugin.selectedTypes.length === 1 ? plugin.colorForType(plugin.selectedTypes[0]) : "#CCCCCC"; border.width: 1
                                Column { anchors.centerIn: parent; spacing: 2
                                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 7
                                        Rectangle { width: 13; height: 13; radius: 6.5; color: plugin.selectedTypes.length === 1 ? plugin.colorForType(plugin.selectedTypes[0]) : "transparent" }
                                        Text { text: plugin.selectedTypes.length === 0 ? "NO TYPES SELECTED" : (plugin.selectedTypes.length === 1 ? (plugin.isFaultType(plugin.selectedTypes[0]) ? "FAULT → GREAT CIRCLE + LINEATION" : (plugin.isPlaneType(plugin.selectedTypes[0]) ? (plugin.planeProjectionMode === "greatCircles" ? "PLANE → GREAT CIRCLE" : "PLANE → POLE") : "LINE → POINT")) : (plugin.selectedTypes.some(function(t) { return plugin.isPlaneType(t); }) ? "PLANES (" + plugin.planeProjectionMode.toUpperCase() + ") + OTHER TYPES" : "MULTIPLE TYPES SELECTED")); font.pixelSize: 12; font.bold: true; color: "#444444" }
                                    }
                                    Text { visible: plugin.selectedTypes.length === 1 && plugin.hasTopToLine(plugin.selectedTypes[0]); text: (plugin.selectedTypes.length === 1 && plugin.isFaultType(plugin.selectedTypes[0])) ? "Top to → sense-of-shear arrow" : "Top to → arrow"; font.pixelSize: 10; color: "#777777"; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }
                            // STEREONET CANVAS
                            Canvas { id: tabSCanvas; width: Math.min(parent.width, 440); height: width; anchors.horizontalCenter: parent.horizontalCenter
                                property var points: []; property bool isPoles: true
                                // Render the background stereonet grid
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2; var cy = height / 2; var R = Math.min(width, height) / 2 - 25
                                    drawStereonet(ctx, cx, cy, R); 
                                    // Pass 1: Clipped elements (Great circles only)
                                    ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.clip()
                                    for (var i = 0; i < points.length; i++) {
                                        var pt = points[i]
                                        if (plugin.isFaultType(pt.type)) {
                                            drawGlobalGreatCircle(ctx, cx, cy, R, pt.d, pt.dd, plugin.colorForType(pt.type))
                                        } else if (plugin.isPlaneType(pt.type) && plugin.planeProjectionMode === "greatCircles") {
                                            drawGlobalGreatCircle(ctx, cx, cy, R, pt.d, pt.dd, plugin.colorForType(pt.type))
                                        }
                                    }
                                    ctx.restore()
                                    // Pass 2: Unclipped elements (Points and Arrows)
                                    for (var i = 0; i < points.length; i++) {
                                        var pt = points[i]
                                        var px, py
                                        var isPlane = plugin.isPlaneType(pt.type) && !plugin.isFaultType(pt.type)
                                        
                                        if (plugin.isFaultType(pt.type)) {
                                            var faultProj = projectStereonetPoint(pt.pl, pt.az, R); px = cx + faultProj.x; py = cy - faultProj.y
                                        } else if (isPlane) {
                                            if (plugin.planeProjectionMode === "greatCircles") continue
                                            var poleAzimuth = (pt.dd + 180) % 360; var polePlunge = 90 - pt.d
                                            var poleProj = projectStereonetPoint(polePlunge, poleAzimuth, R); px = cx + poleProj.x; py = cy - poleProj.y
                                        } else {
                                            var proj = projectStereonetPoint(pt.pl, pt.az, R); px = cx + proj.x; py = cy - proj.y
                                        }
                                        // Draw Point
                                        ctx.fillStyle = plugin.colorForType(pt.type); ctx.beginPath(); ctx.arc(px, py, 4.5, 0, 2 * Math.PI); ctx.fill()
                                        // Draw Arrow
                                        if (plugin.isFaultType(pt.type) && pt.topTo !== null && pt.topTo !== undefined) {
                                            drawGlobalTopToArrow(ctx, px, py, pt.topTo, R, plugin.colorForType(pt.type))
                                        } else if (!isPlane && plugin.hasTopToLine(pt.type) && pt.topTo !== null && pt.topTo !== undefined) {
                                            drawGlobalTopToArrow(ctx, px, py, pt.topTo, R, plugin.colorForType(pt.type))
                                        }
                                    }
                                }
                            }
                            // FOOTER
                            Text { id: countText; width: parent.width; height: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; color: "#555555"; wrapMode: Text.WordWrap }
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
                            // TAB 1 STEREONET
                            Canvas {
                                id: canvas; width: Math.min(parent.width, 440); height: width; anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2; var cy = width / 2; var R = width / 2 - 28
                                    drawStereonet(ctx, cx, cy, R); ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                                    ctx.clip()
                                    drawGlobalGreatCircle(ctx, cx, cy, R, plugin.dip1, plugin.dipAzimuth1, "#1565C0")
                                    drawGlobalGreatCircle(ctx, cx, cy, R, plugin.dip2, plugin.dipAzimuth2, "#D32F2F")
                                    if (
                                        plugin.hasResult
                                    ) {
                                        var proj = projectStereonetPoint(plugin.resultPlunge, plugin.resultAzimuth, R)
                                        var ix = cx + proj.x; var iy = cy - proj.y
                                        ctx.fillStyle = "#000000"; ctx.strokeStyle = "#000000"; ctx.lineWidth = 1.5
                                        ctx.beginPath(); ctx.arc(ix, iy, 5, 0, 2 * Math.PI); ctx.fill()
                                        ctx.beginPath(); ctx.moveTo(ix - 8, iy); ctx.lineTo(ix + 8, iy)
                                        ctx.moveTo(ix, iy - 8); ctx.lineTo(ix, iy + 8); ctx.stroke()
                                        
                                        var fproj = projectStereonetPoint(plugin.faultPlusPlunge, plugin.faultPlusAzimuth, R)
                                        var fx = cx + fproj.x; var fy = cy - fproj.y
                                        ctx.fillStyle = "#FF9800"; ctx.strokeStyle = "#E65100"
                                        ctx.beginPath(); ctx.arc(fx, fy, 5, 0, 2 * Math.PI); ctx.fill(); ctx.stroke()
                                        ctx.beginPath(); ctx.moveTo(fx - 7, fy); ctx.lineTo(fx + 7, fy)
                                        ctx.moveTo(fx, fy - 7); ctx.lineTo(fx, fy + 7); ctx.stroke()
                                    }
                                    ctx.restore()
                                }
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
                            canvas.requestPaint()
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
                            canvas.requestPaint()
                            return
                        }
                        faultPerpendicular = normalizeVector(faultPerpendicular)
                        var faultAttitudeVector = { x: faultPerpendicular.x, y: faultPerpendicular.y, z: -faultPerpendicular.z }
                        var faultAttitude = vectorToAttitude(faultAttitudeVector)
                        plugin.faultPlusAzimuth = faultAttitude.azimuth
                        plugin.faultPlusPlunge = faultAttitude.plunge
                        plugin.hasResult = true
                        canvas.requestPaint()
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
                                                    tab2Canvas.requestPaint()
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
                                                    tab2Canvas.requestPaint()
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
                                                    tab2Canvas.requestPaint()
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
                                                    tab2Canvas.requestPaint()
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
                            // TAB 2 STEREONET
                            Canvas {
                                id: tab2Canvas; width: Math.min(parent.width, 440); height: width; anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2, cy = width / 2, R = width / 2 - 28
                                    // STEREONET GRID
                                    drawStereonet(ctx, cx, cy, R);
                                    // CLIP TO NET
                                    ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.clip()
                                    // INPUT PLANE
                                    drawGlobalGreatCircle(ctx, cx, cy, R, plugin.tab2PlaneDip, plugin.tab2PlaneDipAzimuth, "#2E7D32")
                                    // INPUT + PERPENDICULAR LINES
                                    if (plugin.tab2HasResult) {
                                        drawGlobalLinePoint(ctx, cx, cy, R, plugin.tab2LineTrend, plugin.tab2LinePlunge, "#1565C0")
                                        drawGlobalLinePoint(ctx, cx, cy, R, plugin.tab2PerpendicularTrend, plugin.tab2PerpendicularPlunge, "#D32F2F")
                                    }
                                    ctx.restore()
                                }
                            }
                            // TAB 2 FOOTER
                            Text { width: parent.width; height: 18; text: plugin.tab2HasResult ? "Green = Plane   Blue = Original line   Red = Perpendicular" : "Green = Plane — enter the line and calculate"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 9; color: "#666666" }
                        }
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
                            tab2Canvas.requestPaint()
                            return
                        }
                        var perpendicular = crossProduct(planeNDown, existingLine)
                        var pLength = vectorLength(perpendicular)
                        if (pLength < 0.000001) {
                            plugin.tab2HasResult = false
                            mainWindow.displayToast("Unable to calculate perpendicular line")
                            tab2Canvas.requestPaint()
                            return
                        }
                        perpendicular = normalizeVector(perpendicular)
                        var perpendicularAttitude = vectorToAttitude(perpendicular)
                        plugin.tab2PerpendicularTrend = perpendicularAttitude.azimuth
                        plugin.tab2PerpendicularPlunge = perpendicularAttitude.plunge
                        plugin.tab2HasResult = true
                        tab2Canvas.requestPaint()
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
                            // TAB 3 STEREONET
                            Canvas {
                                id: tab3Canvas; width: Math.min(parent.width, 440); height: width; anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2; var cy = width / 2; var R = width / 2 - 28
                                    drawStereonet(ctx, cx, cy, R); ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.clip()
                                    if (tab3RefAzimuth.text !== "" && tab3RefDip.text !== "") { drawGlobalGreatCircle(ctx, cx, cy, R, parseFloat(tab3RefDip.text), parseFloat(tab3RefAzimuth.text), "#757575") }
                                    if (tab3TargetPlaneAzimuth.text !== "" && tab3TargetPlaneDip.text !== "") { drawGlobalGreatCircle(ctx, cx, cy, R, parseFloat(tab3TargetPlaneDip.text), parseFloat(tab3TargetPlaneAzimuth.text), "#1565C0") }
                                    if (tab3TargetPointTrend.text !== "" && tab3TargetPointPlunge.text !== "") { 
                                        drawGlobalLinePoint(ctx, cx, cy, R, parseFloat(tab3TargetPointTrend.text), parseFloat(tab3TargetPointPlunge.text), "#1565C0") 
                                        }
                                        if (plugin.tab3HasResult) {
                                            drawGlobalGreatCircle(ctx, cx, cy, R, plugin.tab3ResultPlaneDip, plugin.tab3ResultPlaneAzimuth, "#D32F2F")
                                            drawGlobalLinePoint(ctx, cx, cy, R, plugin.tab3ResultPointTrend, plugin.tab3ResultPointPlunge, "#D32F2F")
                                        }
                                    ctx.restore()
                                }
                            }
                            // TAB 3 FOOTER
                            Text {
                                width: parent.width; height: 18
                                text: plugin.tab3HasResult ? "Gray = Reference | Blue = Original Inputs | Red = New Results" : "Enter values and calculate to see stereonet"
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 9; color: "#666666"
                            }
                        }
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
                        plugin.tab3HasResult = true; tab3Canvas.requestPaint()
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
                                            tab5Canvas.requestPaint();
                                        }
                                    }
                                }
                                Button { text: "Clear"; onClicked: { plugin.tab5Planes = []; tab5CountText.text = "Planes added: 0"; plugin.tab5HasResult = false; tab5Canvas.requestPaint(); } }
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
                                        Text { id: c5Res2; text: plugin.tab5HasResult ? "Best Plane: " + formatNumber(plugin.tab5BestPlaneAzimuth) + "° / " + formatNumber(plugin.tab5BestPlaneDip) + "°" : ""; visible: plugin.tab5HasResult; color: "#D32F2F"; font.bold: true }
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
                            // STEREONET
                            Canvas {
                                id: tab5Canvas; width: Math.min(parent.width, 440); height: width + 42; anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                    var cx = width / 2; var cy = width / 2 + 2; var R = width / 2 - 28;
                                    drawStereonet(ctx, cx, cy, R);
                                    ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.clip();
                                    for(var i=0; i<plugin.tab5Planes.length; i++) {
                                        drawGlobalGreatCircle(ctx, cx, cy, R, plugin.tab5Planes[i].dip, plugin.tab5Planes[i].az, "#9E9E9E");
                                        var n = planeNormal(plugin.tab5Planes[i].az, plugin.tab5Planes[i].dip);
                                        var att = vectorToAttitude({x:n.x, y:n.y, z:-n.z});
                                        drawGlobalLinePoint(ctx, cx, cy, R, att.azimuth, att.plunge, "#1565C0");
                                    }
                                    if(plugin.tab5HasResult) {
                                        drawGlobalGreatCircle(ctx, cx, cy, R, plugin.tab5BestPlaneDip, plugin.tab5BestPlaneAzimuth, "#D32F2F");
                                        drawGlobalLinePoint(ctx, cx, cy, R, plugin.tab5FoldAxisTrend, plugin.tab5FoldAxisPlunge, "#000000");
                                    }
                                    ctx.restore();
                                }
                            }
                        }
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
                        plugin.tab5HasResult = true; tab5Canvas.requestPaint();
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
                            Text { width: parent.width; text: "Plots poles to planes (bedding, foliation) and lines (fold)\nThe type must be \"bedding\", \"foliation\", or \"fold\""; font.pixelSize: 10; color: "#666666"; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
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
                            Canvas {
                                id: tab6Canvas
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width, 440); height: width
                                property var densityGrid: []
                                property real maxDensity: 0
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                    var cx = width / 2, cy = width / 2 + 2, R = width / 2 - 28;
                                    drawStereonet(ctx, cx, cy, R);
                                    ctx.save(); ctx.beginPath(); 
                                    ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.clip();
                                    if (densityGrid.length > 0 && maxDensity > 0) {
                                        var gridSize = 60;
                                        var levels = [0.2, 0.4, 0.6, 0.8];
                                        var colors = ["#D3D3D3", "#A9A9A9", "#696969", "#333333"];
                                        for (var l = 0; l < levels.length; l++) {
                                            var threshold = maxDensity * levels[l];
                                            ctx.strokeStyle = colors[l];
                                            ctx.lineWidth = 1.5;
                                            ctx.beginPath();
                                            for (var i = 0; i < gridSize - 1; i++) {
                                                for (var j = 0; j < gridSize - 1; j++) {
                                                    var x0 = cx - R + (i / gridSize) * (2 * R);
                                                    var y0 = cy - R + (j / gridSize) * (2 * R);
                                                    var x1 = cx - R + ((i+1) / gridSize) * (2 * R);
                                                    var y1 = cy - R + ((j+1) / gridSize) * (2 * R);
                                                    var v00 = densityGrid[i][j] - threshold;
                                                    var v10 = densityGrid[i+1][j] - threshold;
                                                    var v01 = densityGrid[i][j+1] - threshold;
                                                    var v11 = densityGrid[i+1][j+1] - threshold;
                                                    var caseIndex = (v00 > 0 ? 1 : 0) | (v10 > 0 ? 2 : 0) | (v11 > 0 ? 4 : 0) | (v01 > 0 ? 8 : 0);
                                                    if (caseIndex === 0 || caseIndex === 15) continue;
                                                    var p0 = {x: x0 + (x1-x0)*(0-v00)/(v10-v00), y: y0};
                                                    var p1 = {x: x1, y: y0 + (y1-y0)*(0-v10)/(v11-v10)};
                                                    var p2 = {x: x0 + (x1-x0)*(0-v01)/(v11-v01), y: y1};
                                                    var p3 = {x: x0, y: y0 + (y1-y0)*(0-v00)/(v01-v00)};
                                                    if (caseIndex === 1 || caseIndex === 14) { ctx.moveTo(p3.x, p3.y); ctx.lineTo(p0.x, p0.y); }
                                                    else if (caseIndex === 2 || caseIndex === 13) { ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); }
                                                    else if (caseIndex === 4 || caseIndex === 11) { ctx.moveTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); }
                                                    else if (caseIndex === 8 || caseIndex === 7) { ctx.moveTo(p2.x, p2.y); ctx.lineTo(p3.x, p3.y); }
                                                    else if (caseIndex === 3 || caseIndex === 12) { ctx.moveTo(p3.x, p3.y); ctx.lineTo(p1.x, p1.y); }
                                                    else if (caseIndex === 6 || caseIndex === 9) { ctx.moveTo(p0.x, p0.y); ctx.lineTo(p2.x, p2.y); }
                                                }
                                            }
                                            ctx.stroke();
                                        }
                                    }
                                    if (plugin.tab6Data) {
                                        for (var i = 0; i < plugin.tab6Data.length; i++) {
                                            var item = plugin.tab6Data[i];
                                            if (item.isPlane) {
                                                var n = planeNormal(item.dipAz, item.dip);
                                                var pole = vectorToAttitude({x: n.x, y: n.y, z: -n.z});
                                                var pProj = projectStereonetPoint(pole.plunge, pole.azimuth, R);
                                                ctx.fillStyle = item.type.toLowerCase().startsWith("bedding") ? "#D32F2F" : "#1565C0";
                                                ctx.beginPath(); ctx.arc(cx + pProj.x, cy - pProj.y, 3, 0, 2 * Math.PI); ctx.fill();
                                            } else {
                                                var lProj = projectStereonetPoint(item.plunge, item.trend, R);
                                                ctx.fillStyle = "#2E7D32"; ctx.beginPath();
                                                ctx.moveTo(cx + lProj.x, cy - lProj.y - 4);
                                                ctx.lineTo(cx + lProj.x - 4, cy - lProj.y + 3);
                                                ctx.lineTo(cx + lProj.x + 4, cy - lProj.y + 3);
                                                ctx.closePath(); ctx.fill();
                                            }
                                        }
                                    }
                                    if (plugin.tab6HasMax) {
                                        var maxProj = projectStereonetPoint(plugin.tab6MaxPlunge, plugin.tab6MaxTrend, R);
                                        ctx.strokeStyle = "#FF0000";
                                        ctx.lineWidth = 2.5;
                                        ctx.beginPath();
                                        ctx.arc(cx + maxProj.x, cy - maxProj.y, 8, 0, 2 * Math.PI);
                                        ctx.stroke();
                                    }
                                    ctx.restore();
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
                            Canvas {
                                id: tab7Canvas
                                width: Math.min(parent.width, 440); height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    var ctx = getContext("2d"); 
                                    ctx.clearRect(0, 0, width, height);
                                    var cx = width / 2; var cy = width / 2 + 2; var R = width / 2 - 28;
                                    drawStereonet(ctx, cx, cy, R);
                                    
                                    // PASS 1: CLIPPED (Great Circles only)
                                    ctx.save(); 
                                    ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.clip();
                                    ctx.lineWidth = 1;
                                    for(var i=0; i<plugin.tab7Faults.length; i++) {
                                        var fault = plugin.tab7Faults[i];
                                        drawGlobalGreatCircle(ctx, cx, cy, R, fault.dip, fault.dipAz, fault.color || "#E0E0E0");
                                    }
                                    ctx.restore();
                                    
                                    // PASS 2: UNCLIPPED (Symbols, Arrows, and Individual Stresses)
                                    for(var i=0; i<plugin.tab7Faults.length; i++) {
                                        var fault = plugin.tab7Faults[i];
                                        var sigmas = calculateConjugateSigmas(fault);
                                        var faultColor = fault.color || "#000000";
                                        
                                        // Original Plunge (Brown outline) - Increased to 6
                                        var origProj = projectStereonetPoint(fault.plunge, fault.trend, R);
                                        ctx.strokeStyle = "#795548"; ctx.lineWidth = 1.5;
                                        ctx.beginPath(); ctx.arc(cx + origProj.x, cy - origProj.y, 6, 0, 2 * Math.PI); ctx.stroke();
        
                                        // Corrected Plunge (Matches Fault Color) - Increased to 6
                                        var corrProj = projectStereonetPoint(fault.correctedPlunge, fault.correctedTrend, R);
                                        ctx.fillStyle = faultColor;
                                        ctx.beginPath(); ctx.arc(cx + corrProj.x, cy - corrProj.y, 6, 0, 2 * Math.PI); ctx.fill();
        
                                        // Shear Sense Arrow
                                        drawGlobalTopToArrow(ctx, cx + corrProj.x, cy - corrProj.y, fault.sense, R, faultColor);
        
                                        // Individual σ1 (Red Cross)
                                        var s1Proj = projectStereonetPoint(sigmas.s1.plunge, sigmas.s1.azimuth, R);
                                        ctx.strokeStyle = "#D32F2F"; ctx.lineWidth = 1.5; ctx.beginPath();
                                        ctx.moveTo(cx + s1Proj.x - 3, cy - s1Proj.y); ctx.lineTo(cx + s1Proj.x + 3, cy - s1Proj.y);
                                        ctx.moveTo(cx + s1Proj.x, cy - s1Proj.y - 3); ctx.lineTo(cx + s1Proj.x, cy - s1Proj.y + 3); ctx.stroke();
                                        
                                        // Individual σ2 (Blue Triangle)
                                        var s2Proj = projectStereonetPoint(sigmas.s2.plunge, sigmas.s2.azimuth, R);
                                        ctx.strokeStyle = "#1565C0"; ctx.beginPath();
                                        ctx.moveTo(cx + s2Proj.x, cy - s2Proj.y - 3); ctx.lineTo(cx + s2Proj.x - 3, cy - s2Proj.y + 2);
                                        ctx.lineTo(cx + s2Proj.x + 3, cy - s2Proj.y + 2); ctx.closePath(); ctx.stroke();
                                        
                                        // Individual σ3 (Black Square)
                                        var s3Proj = projectStereonetPoint(sigmas.s3.plunge, sigmas.s3.azimuth, R);
                                        ctx.strokeStyle = "#000000"; ctx.strokeRect(cx + s3Proj.x - 2, cy - s3Proj.y - 2, 4, 4);
                                    }
                                    
                                    // PASS 3: Inverted Paleostress Field (Large Symbols) - Scaled up ~30%
                                    if (plugin.tab7HasResult) {
                                        var avgS1 = projectStereonetPoint(plugin.tab7Sigma1Plunge, plugin.tab7Sigma1Trend, R);
                                        ctx.strokeStyle = "#D32F2F"; ctx.lineWidth = 3; ctx.beginPath(); 
                                        ctx.arc(cx + avgS1.x, cy - avgS1.y, 10.5, 0, 2 * Math.PI); ctx.stroke(); // Was 8
                                        
                                        var avgS3 = projectStereonetPoint(plugin.tab7Sigma3Plunge, plugin.tab7Sigma3Trend, R);
                                        ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; 
                                        ctx.strokeRect(cx + avgS3.x - 9, cy - avgS3.y - 9, 18, 18); // Was 14x14 (-7)
                                        
                                        var avgS2 = projectStereonetPoint(plugin.tab7Sigma2Plunge, plugin.tab7Sigma2Trend, R);
                                        ctx.strokeStyle = "#1565C0"; ctx.lineWidth = 3; ctx.beginPath();
                                        ctx.moveTo(cx + avgS2.x, cy - avgS2.y - 10.5); // Was -8
                                        ctx.lineTo(cx + avgS2.x - 10.5, cy - avgS2.y + 8); // Was -8, +6
                                        ctx.lineTo(cx + avgS2.x + 10.5, cy - avgS2.y + 8); // Was +8, +6
                                        ctx.closePath(); ctx.stroke();
                                    }
                                }
                            }
                            // TAB 7 FOOTER
                            Text { width: parent.width; height: 32; text: "NOTE: just averages, not paleostress inversion!"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11; color: "#2E7D32"; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
            // CLOSE BUTTON
            Button {
                Layout.alignment: Qt.AlignHCenter
                width: 80; height: 28; text: "Close"
                font.pixelSize: 11
                onClicked: intersectionPopup.close()
            }
        }
    }
    // ================================================================
    // FUNCTIONS SECTION
    // ================================================================
    // Draws the complete Schmidt stereonet grid including outer border and labels
    function drawStereonet(ctx, cx, cy, R) {
        ctx.save(); ctx.strokeStyle = "#CCCCCC"; ctx.lineWidth = 0.5;
        ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.stroke();
        for (var lat = -80; lat <= 80; lat += 10) { if (lat !== 0) drawSmallCircleLat(ctx, cx, cy, R, lat); }
        for (var lon = -80; lon <= 80; lon += 10) { if (lon !== 0) drawGreatCircleLon(ctx, cx, cy, R, lon); }
        ctx.strokeStyle = "#999999"; ctx.lineWidth = 0.7;
        ctx.beginPath(); ctx.moveTo(cx, cy - R); ctx.lineTo(cx, cy + R); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(cx - R, cy); ctx.lineTo(cx + R, cy); ctx.stroke(); ctx.restore();
        ctx.save(); ctx.strokeStyle = "#000000"; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.stroke(); ctx.restore();
        ctx.fillStyle = "#000000"; ctx.font = "bold 13px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
        ctx.fillText("N", cx, cy - R - 11); ctx.fillText("S", cx, cy + R + 11);
        ctx.fillText("E", cx + R + 11, cy); ctx.fillText("W", cx - R - 11, cy);
    }
    // Projects spherical coordinates onto a flat plane using equal-area Lambert projection
    function lambertProject(lon, lat, R) {
        var denom = 1 + Math.cos(lat) * Math.cos(lon); if (denom < 0.0001) return null;
        var k = Math.sqrt(2 / denom);
        return { x: R * k * Math.cos(lat) * Math.sin(lon) / Math.sqrt(2), y: R * k * Math.sin(lat) / Math.sqrt(2) };
    }
    // Draws latitude lines (small circles) across the stereonet
    function drawSmallCircleLat(ctx, cx, cy, R, latDeg) {
        ctx.beginPath(); var first = true; var lat = latDeg * Math.PI / 180;
        for (var lonDeg = -90; lonDeg <= 90; lonDeg += 2) {
            var pt = lambertProject(lonDeg * Math.PI / 180, lat, R); if (!pt) continue;
            if (first) { ctx.moveTo(cx + pt.x, cy - pt.y); first = false; } else { ctx.lineTo(cx + pt.x, cy - pt.y); }
        }
        ctx.stroke();
    }
    // Draws longitude lines (great circles) across the stereonet
    function drawGreatCircleLon(ctx, cx, cy, R, lonDeg) {
        ctx.beginPath(); var first = true; var lon = lonDeg * Math.PI / 180;
        for (var latDeg = -90; latDeg <= 90; latDeg += 2) {
            var pt = lambertProject(lon, latDeg * Math.PI / 180, R); if (!pt) continue;
            if (first) { ctx.moveTo(cx + pt.x, cy - pt.y); first = false; } else { ctx.lineTo(cx + pt.x, cy - pt.y); }
        }
        ctx.stroke();
    }
    // Projects a plunge and azimuth onto the stereonet using equal-area projection
    function projectStereonetPoint(plunge, azimuth, R) {
        var plungeRad = plunge * Math.PI / 180; var azRad = azimuth * Math.PI / 180;
        var r = R * Math.sqrt(2) * Math.sin((Math.PI / 2 - plungeRad) / 2);
        return { x: r * Math.sin(azRad), y: r * Math.cos(azRad) };
    }
    // Draws a great circle representing a geological plane
    function drawGlobalGreatCircle(ctx, cx, cy, R, dip, dipAzimuth, color) {
        var dipRad = dip * Math.PI / 180; var strikeRad = (dipAzimuth - 90 + 360) % 360 * Math.PI / 180;
        var sx = Math.sin(strikeRad); var sy = Math.cos(strikeRad);
        var dx = Math.cos(dipRad) * Math.sin(dipAzimuth * Math.PI / 180); var dy = Math.cos(dipRad) * Math.cos(dipAzimuth * Math.PI / 180); var dz = Math.sin(dipRad);
        ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath(); var first = true;
        for (var a = 0; a <= 180; a += 1) {
            var angle = a * Math.PI / 180; var vx = sx * Math.cos(angle) + dx * Math.sin(angle); var vy = sy * Math.cos(angle) + dy * Math.sin(angle); var vz = dz * Math.sin(angle);
            var len = Math.sqrt(vx*vx + vy*vy + vz*vz); if (len < 0.000001) continue; vx /= len; vy /= len; vz /= len;
            var azimuth = Math.atan2(vx, vy); if (azimuth < 0) azimuth += 2 * Math.PI;
            var plunge = Math.atan2(vz, Math.sqrt(vx*vx + vy*vy)); var proj = projectStereonetPoint(plunge * 180 / Math.PI, azimuth * 180 / Math.PI, R);
            if (first) { ctx.moveTo(cx + proj.x, cy - proj.y); first = false; } else { ctx.lineTo(cx + proj.x, cy - proj.y); }
        }
        ctx.stroke(); ctx.restore();
    }
    // Draws a shear sense arrow for fault data
    function drawGlobalTopToArrow(ctx, px, py, topTo, R, color) {
        if (topTo === null || topTo === undefined || isNaN(topTo)) return;
        var arrowLength = R / 8; var topToRad = topTo * Math.PI / 180;
        var endX = px + arrowLength * Math.sin(topToRad); var endY = py - arrowLength * Math.cos(topToRad);
        ctx.save(); ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 2; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(endX, endY); ctx.stroke();
        var arrowHeadLength = 7; var arrowHeadAngle = 25 * Math.PI / 180;
        var leftAngle = topToRad + Math.PI - arrowHeadAngle; var rightAngle = topToRad + Math.PI + arrowHeadAngle;
        ctx.beginPath(); ctx.moveTo(endX, endY); ctx.lineTo(endX + arrowHeadLength * Math.sin(leftAngle), endY - arrowHeadLength * Math.cos(leftAngle)); ctx.lineTo(endX + arrowHeadLength * Math.sin(rightAngle), endY - arrowHeadLength * Math.cos(rightAngle)); ctx.closePath(); ctx.fill(); ctx.restore();
    }
    // DRAW GLOBAL LINE POINT: Draws a lineation as a point on the stereonet
    function drawGlobalLinePoint(ctx, cx, cy, R, trend, plunge, color) {
        var p = projectStereonetPoint(plunge, trend, R)
        var x = cx + p.x, y = cy - p.y
        ctx.save()
        ctx.fillStyle = color
        ctx.strokeStyle = "#FFFFFF"
        ctx.lineWidth = 1 // White outline for better visibility
        ctx.beginPath()
        ctx.arc(x, y, 6, 0, 2 * Math.PI)
        ctx.fill()
        ctx.stroke()
        ctx.restore()
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
        if (typeColors[typeName] !== undefined) { return typeColors[typeName] }
        return "#000000"
    }
    // IS PLANE TYPE: Checks if the feature should be drawn as a great circle or pole
    function isPlaneType(typeName) { return (planeTypes.indexOf(typeName) >= 0) }
    // IS FAULT TYPE: Identifies faults which require both a plane and a lineation
    function isFaultType(typeName) { return (typeName === "fault" || typeName === "fault gen 1" || typeName === "fault gen 2" || typeName === "fault gen 3" || typeName === "fault gen 4") }
    // HAS TOP TO LINE: Checks if the structural type includes sense-of-shear (Top to) data
    function hasTopToLine(typeName) { return (topToTypes.indexOf(typeName) >= 0) }
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
    // PLOT SELECTED TYPE: Extracts valid measurements and sends them to the stereonet canvas
    function plotSelectedType() {
        var layer = plugin.activeLayer; if (!layer) return
        try {
            var allFeatures = getAllFeatures(layer)
            if (!allFeatures || allFeatures.length === 0) { tabSCanvas.points = []; tabSCanvas.requestPaint(); return }
            tabSCanvas.points = [];
            var fieldNames = allFeatures[0].fields.names
            var typeField = findFieldName(fieldNames, typeFieldNames); var dipField = findFieldName(fieldNames, dipFieldNames)
            var dipDirField = findFieldName(fieldNames, dipDirFieldNames); var azField = findFieldName(fieldNames, azimuthFieldNames)
            var plField = findFieldName(fieldNames, plungeFieldNames); var topToField = findFieldName(fieldNames, topToFieldNames)
            if (!typeField) { mainWindow.displayToast("Field 'Type' not found"); return }
            var dataPoints = []; var skipped = 0; var missingTopTo = 0
            for (var i = 0; i < allFeatures.length; i++) {
                var feat = allFeatures[i]
                var featureType = feat.attribute(typeField); if (featureType === null || featureType === undefined) { continue }
                var featureTypeString = String(featureType).trim()
                if (plugin.selectedTypes.indexOf(featureTypeString) === -1) { continue }
                var faultMode = isFaultType(featureTypeString)
                var planeMode = isPlaneType(featureTypeString) && !faultMode
                if (faultMode) {
                    if (!dipField || !dipDirField || !azField || !plField) { continue }
                    var faultDip = feat.attribute(dipField); var faultDipDir = feat.attribute(dipDirField)
                    var faultAz = feat.attribute(azField); var faultPlunge = feat.attribute(plField)
                    if (faultDip === null || faultDip === undefined || faultDipDir === null || faultDipDir === undefined || faultAz === null || faultAz === undefined || faultPlunge === null || faultPlunge === undefined) { skipped++; continue }
                    var fd = parseFloat(faultDip); var fdd = parseFloat(faultDipDir); var fa = parseFloat(faultAz); var fp = parseFloat(faultPlunge)
                    if (isNaN(fd) || isNaN(fdd) || isNaN(fa) || isNaN(fp)) { skipped++; continue }
                    var faultTopTo = null
                    if (topToField) { var faultTopToRaw = feat.attribute(topToField); if (faultTopToRaw !== null) { var faultTopToParsed = parseFloat(faultTopToRaw); if (!isNaN(faultTopToParsed)) { faultTopTo = faultTopToParsed } } }
                    if (faultTopTo === null) { missingTopTo++ }
                    dataPoints.push({ d: fd, dd: fdd, az: fa, pl: fp, topTo: faultTopTo, type: featureTypeString })
                } else if (planeMode) {
                    if (!dipField || !dipDirField) { continue }
                    var dip = feat.attribute(dipField); var dipDir = feat.attribute(dipDirField)
                    if (dip === null || dip === undefined) { skipped++; continue }
                    var d = parseFloat(dip); var dd = parseFloat(dipDir)
                    if (isNaN(d) || isNaN(dd)) { skipped++; continue }
                    dataPoints.push({ d: d, dd: dd, type: featureTypeString })
                } else {
                    if (!azField || !plField) { continue }
                    var az = feat.attribute(azField); var plunge = feat.attribute(plField)
                    if (az === null || az === undefined) { skipped++; continue }
                    var a = parseFloat(az); var p = parseFloat(plunge)
                    if (isNaN(a) || isNaN(p)) { skipped++; continue }
                    var topToValue = null
                    if (hasTopToLine(featureTypeString) && topToField) { var topToRaw = feat.attribute(topToField); if (topToRaw !== null) { var topToParsed = parseFloat(topToRaw); if (!isNaN(topToParsed)) { topToValue = topToParsed } } }
                    if (hasTopToLine(featureTypeString) && topToValue === null) { missingTopTo++ }
                    dataPoints.push({ az: a, pl: p, topTo: topToValue, type: featureTypeString })
                }
            }
            tabSCanvas.points = dataPoints; tabSCanvas.requestPaint()
            
            if (dataPoints.length === 0) { countText.text = "No valid measurements" } else {
                countText.text = dataPoints.length + " measurements plotted"
                if (skipped > 0) { countText.text += " | " + skipped + " invalid" }
                if (missingTopTo > 0) { countText.text += " | " + missingTopTo + " without Top to" }
            }
            countText.color = "#555555"
        } catch (error) { mainWindow.displayToast("Plot error: " + error.toString()) }
    }
    // PROCESS LAYER: Validates the active layer and checks for required attribute fields
    function processLayer() {
        try {
            var dashBoard = iface.findItemByObjectName("dashBoard")
            var layer = dashBoard ? dashBoard.activeLayer : null
            if (!layer) { countText.text = "Error: No layer selected"; countText.color = "#D32F2F"; return }
            if (layer.type !== 0) { countText.text = "Error: Not a vector layer"; countText.color = "#D32F2F"; return }
            plugin.activeLayer = layer
            var features = getAllFeatures(layer)
            if (!features || features.length === 0) { countText.text = "Error: No features in layer"; countText.color = "#D32F2F"; return }
            var fieldNames = features[0].fields.names
            var typeField = findFieldName(fieldNames, typeFieldNames)
            if (!typeField) { countText.text = "Error: Field 'Type' not found in the active layer"; countText.color = "#D32F2F"; return }
            countText.color = "#555555"; countText.text = ""
            plotSelectedType()
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
	    for (var i = 0; i < fieldNames.length; i++) {
	        var fn = String(fieldNames[i])
	        for (var j = 0; j < candidates.length; j++) {
	            if (fn.toLowerCase() === String(candidates[j]).toLowerCase()) return fieldNames[i]
	        }
	    }
	    return null
	}
    // LOAD FAULTS FROM LAYER: Extracts fault data with valid shear sense from the active QField layer
    function loadFaultsFromLayer() {
        var dashBoard = iface.findItemByObjectName("dashBoard"), layer = dashBoard ? dashBoard.activeLayer : null
        if (!layer || layer.type !== 0) { mainWindow.displayToast("No active vector layer found"); return }
        var features = getAllFeatures(layer)
        if (!features || features.length === 0) { mainWindow.displayToast("No features in layer"); return }
        var fields = features[0].fields.names
        var typeField = findFieldName(fields, typeFieldNames), dipField = findFieldName(fields, dipFieldNames)
        var dipDirField = findFieldName(fields, dipDirFieldNames), azField = findFieldName(fields, azimuthFieldNames)
        var plField = findFieldName(fields, plungeFieldNames), topToField = findFieldName(fields, topToFieldNames)
        plugin.allLoadedFaults = []; typeModel.clear(); var uniqueTypes = {}        
        var faultTypeRegex = /^(fault|fault\s+gen\s+\d+)$/i;
        for (var i = 0; i < features.length; i++) {
                var feat = features[i]
                var dip = dipField ? feat.attribute(dipField) : null, dipDir = dipDirField ? feat.attribute(dipDirField) : null
                var trend = azField ? feat.attribute(azField) : null, plunge = plField ? feat.attribute(plField) : null
                var topTo = topToField ? feat.attribute(topToField) : null
                if (isValidValue(dip) && isValidValue(dipDir) && isValidValue(trend) && isValidValue(topTo)) {
                        var featureType = typeField ? String(feat.attribute(typeField)) : "Unknown"
                        if (faultTypeRegex.test(featureType.trim())) {
                            if (!uniqueTypes[featureType]) { uniqueTypes[featureType] = 0 }
                            uniqueTypes[featureType]++;
                            var correctedPlunge = correctPlungeOnPlane(parseFloat(dipDir), parseFloat(dip), parseFloat(trend))
                            var color = plugin.colorForType(featureType.trim())
                            plugin.allLoadedFaults.push({ type: featureType, dipAz: parseFloat(dipDir), dip: parseFloat(dip), trend: parseFloat(trend), plunge: isValidValue(plunge) ? parseFloat(plunge) : correctedPlunge, correctedPlunge: correctedPlunge, sense: parseFloat(topTo), color: color })
                        }
                }
        }
        var sortedTypes = Object.keys(uniqueTypes).sort(function(a, b) { return uniqueTypes[b] - uniqueTypes[a]; });
        for (var j = 0; j < sortedTypes.length; j++) {
            typeModel.append({ text: sortedTypes[j] });
        }
        if (typeModel.count > 0) { typeComboBox.currentIndex = 0; filterFaultsByType() } 
        else { mainWindow.displayToast("No valid fault types found with required elements") }
    }
    // FILTER FAULTS BY TYPE
    function filterFaultsByType() {
        if (typeComboBox.currentIndex === -1) return;
        var selectedType = typeModel.get(typeComboBox.currentIndex).text;
        plugin.tab7Faults = [];
        for (var i = 0; i < plugin.allLoadedFaults.length; i++) {
            var fault = plugin.allLoadedFaults[i];
            if (fault.type === selectedType) plugin.tab7Faults.push(fault);
        }
        tab7CountText.text = "Faults loaded: " + plugin.tab7Faults.length;
        mainWindow.displayToast("Loaded " + plugin.tab7Faults.length + " " + selectedType + " features");
        if (plugin.tab7Faults.length > 0) {
            calculatePaleostress();
        } else {
            plugin.tab7HasResult = false;
            tab7ResultText.text = "Average σ1: ---\nAverage σ2: ---\nAverage σ3: ---";
            tab7Canvas.requestPaint();
        }
    }
    // LOAD STRUCTURAL DATA: Extracts bedding, foliation, and lineations for density plotting
    function loadStructuralData() {
        var dashBoard = iface.findItemByObjectName("dashBoard"), layer = dashBoard ? dashBoard.activeLayer : null;
        if (!layer || layer.type !== 0) { mainWindow.displayToast("No active vector layer found"); return; }
        var features = getAllFeatures(layer);
        if (!features || features.length === 0) { mainWindow.displayToast("No features in layer"); return; }
        var fields = features[0].fields.names;
        var typeField = findFieldName(fields, typeFieldNames), dipField = findFieldName(fields, dipFieldNames);
        var dipDirField = findFieldName(fields, dipDirFieldNames), azField = findFieldName(fields, azimuthFieldNames);
        var plField = findFieldName(fields, plungeFieldNames);
        plugin.allLoadedData = []; 
        tab6TypeModel.clear(); 
        var uniqueTypes = {};
        var typeRegex = /^(bedding|foliation|fold|cleavage|normal fault|reverse fault|fault gouge foliation|Riedel shear|other lineation)/i;
        for (var i = 0; i < features.length; i++) {
            var feat = features[i];
            var featureType = typeField ? String(feat.attribute(typeField)).trim() : "Unknown";
            if (typeRegex.test(featureType)) {
                var lowerType = featureType.toLowerCase();
                if (lowerType.startsWith("bedding") || lowerType.startsWith("foliation") || lowerType.startsWith("cleavage") || lowerType.startsWith("normal fault") || lowerType.startsWith("reverse fault") || lowerType.startsWith("fault gouge foliation") || lowerType.startsWith("riedel shear")) {
                    var dip = dipField ? feat.attribute(dipField) : null, dipDir = dipDirField ? feat.attribute(dipDirField) : null;
                    if (isValidValue(dip) && isValidValue(dipDir)) {
                        if (!uniqueTypes[featureType]) { uniqueTypes[featureType] = 0; }
                        uniqueTypes[featureType]++;
                        plugin.allLoadedData.push({ type: featureType, dipAz: parseFloat(dipDir), dip: parseFloat(dip), isPlane: true });
                    }
                } else if (lowerType.startsWith("fold") || lowerType.startsWith("other lineation")) {
                    var trend = azField ? feat.attribute(azField) : null, plunge = plField ? feat.attribute(plField) : null;
                    if (isValidValue(trend) && isValidValue(plunge)) {
                        if (!uniqueTypes[featureType]) { uniqueTypes[featureType] = 0; }
                        uniqueTypes[featureType]++;
                        plugin.allLoadedData.push({ type: featureType, trend: parseFloat(trend), plunge: parseFloat(plunge), isPlane: false });
                    }
                }
            }
        }
        var sortedTypes = Object.keys(uniqueTypes).sort(function(a, b) { return uniqueTypes[b] - uniqueTypes[a]; });
        for (var j = 0; j < sortedTypes.length; j++) {
            tab6TypeModel.append({ text: sortedTypes[j] });
        }
        if (tab6TypeModel.count > 0) { 
            tab6TypeComboBox.currentIndex = 0; 
            filterDataByType(); 
        } else { 
            mainWindow.displayToast("No valid structural types found"); 
        }
    }
    // FILTER DATA BY TYPE: Resets previous results completely before loading new structural data
    function filterDataByType() {
        if (tab6TypeComboBox.currentIndex === -1) return;
        var selectedType = tab6TypeModel.get(tab6TypeComboBox.currentIndex).text;
        // 1. Reset previous results completely
        plugin.tab6Data = [];
        plugin.tab6HasMax = false;
        tab6Canvas.densityGrid = [];
        tab6Canvas.maxDensity = 0;
        tab6DensityResultText.text = "Max Density: ---\nTotal Points: ---";
        // 2. Load new data
        for (var i = 0; i < plugin.allLoadedData.length; i++) {
            var item = plugin.allLoadedData[i];
            if (item.type === selectedType) plugin.tab6Data.push(item);
        }
        tab6CountText.text = "Loaded: " + plugin.tab6Data.length;
        mainWindow.displayToast("Loaded " + plugin.tab6Data.length + " " + selectedType + " features");
        // 3. Calculate and force UI update
        if (plugin.tab6Data.length > 0) {
            calculateDensityPlot();
        } else {
            tab6Canvas.requestPaint();
        }
    }
    // CALCULATE DENSITY PLOT
    function calculateDensityPlot() {
        var data = plugin.tab6Data;
        if (data.length === 0) return;
        
        var points = [];
        for (var i = 0; i < data.length; i++) {
            var item = data[i];
            if (item.isPlane) {
                var n = planeNormal(item.dipAz, item.dip);
                var pole = vectorToAttitude({x: n.x, y: n.y, z: -n.z});
                points.push(projectStereonetPoint(pole.plunge, pole.azimuth, 1.0));
            } else {
                points.push(projectStereonetPoint(item.plunge, item.trend, 1.0));
            }
        }
        var gridSize = 60, rawGrid = [], radius = 0.15; 
        for (var i = 0; i < gridSize; i++) {
            rawGrid[i] = [];
            for (var j = 0; j < gridSize; j++) {
                var x = (i / (gridSize - 1)) * 2 - 1, y = (j / (gridSize - 1)) * 2 - 1;
                if (x*x + y*y > 1.05) { rawGrid[i][j] = 0; continue; }
                var density = 0;
                for (var p = 0; p < points.length; p++) {
                    var dx = x - points[p].x, dy = y - (-points[p].y);
                    if (dx*dx + dy*dy < radius*radius) density += 1.0;
                }
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
                        if (ni >= 0 && ni < gridSize && nj >= 0 && nj < gridSize) {
                            var weight = (di === 0 && dj === 0) ? 4 : ((di === 0 || dj === 0) ? 2 : 1);
                            sum += rawGrid[ni][nj] * weight; count += weight;
                        }
                    }
                }
                grid[i][j] = sum / count;
                if (grid[i][j] > maxD) { maxD = grid[i][j]; maxI = i; maxJ = j; }
            }
        }
        plugin.tab6HasMax = false;
        if (maxD > 0 && maxI !== -1) {
            var px = (maxI / (gridSize - 1)) * 2 - 1, py = -((maxJ / (gridSize - 1)) * 2 - 1);
            var r = Math.sqrt(px*px + py*py);
            if (r <= 1.0) {
                var plungeRad = Math.PI / 2 - 2 * Math.asin(r / Math.sqrt(2));
                var trendRad = Math.atan2(px, py);
                plugin.tab6MaxPlunge = plungeRad * 180 / Math.PI;
                plugin.tab6MaxTrend = trendRad * 180 / Math.PI;
                if (plugin.tab6MaxTrend < 0) plugin.tab6MaxTrend += 360;
                
                plugin.tab6HasMax = true;
            }
        }
        tab6Canvas.densityGrid = grid;
        tab6Canvas.maxDensity = maxD;
        var resultString = "Max Density: " + formatNumber(maxD) + "  |  Total Points: " + data.length + "<br>";
        if (plugin.tab6HasMax) {
            resultString += "<font color='#D32F2F'>Peak: " + formatNumber(plugin.tab6MaxTrend) + "° / " + formatNumber(plugin.tab6MaxPlunge) + "°</font>";
        }
        tab6DensityResultText.text = resultString;
        tab6Canvas.requestPaint();
    }
    // RELOAD CURRENT TAB DATA: Refreshes the active tab's data whenever the popup is opened
    function reloadCurrentTabData() {
        if (!intersectionPopup.opened) return;
        switch (calculatorTabs.currentIndex) {
            case 0: // Tab S
                plotSelectedType();
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
        var sigmasData = [];
        for (var i = 0; i < faults.length; i++) {
            sigmasData.push(calculateConjugateSigmas(faults[i]));
        }
        var avgSigmas = calculateAverageSigmas(sigmasData);
        tab7ResultText.textFormat = Text.StyledText;
        tab7ResultText.text = "<font color='#D32F2F'><b>Average σ1: " + formatNumber(avgSigmas.sigma1.azimuth) + "° / " + formatNumber(avgSigmas.sigma1.plunge) + "°</b></font><br>" +
                              "<font color='#1565C0'><b>Average σ2: " + formatNumber(avgSigmas.sigma2.azimuth) + "° / " + formatNumber(avgSigmas.sigma2.plunge) + "°</b></font><br>" +
                              "<font color='#000000'><b>Average σ3: " + formatNumber(avgSigmas.sigma3.azimuth) + "° / " + formatNumber(avgSigmas.sigma3.plunge) + "°</b></font>";
        plugin.tab7Sigma1Trend = avgSigmas.sigma1.azimuth; plugin.tab7Sigma1Plunge = avgSigmas.sigma1.plunge;
        plugin.tab7Sigma2Trend = avgSigmas.sigma2.azimuth; plugin.tab7Sigma2Plunge = avgSigmas.sigma2.plunge;
        plugin.tab7Sigma3Trend = avgSigmas.sigma3.azimuth; plugin.tab7Sigma3Plunge = avgSigmas.sigma3.plunge;
        plugin.tab7HasResult = true; 
        tab7Canvas.requestPaint();
    }
}
