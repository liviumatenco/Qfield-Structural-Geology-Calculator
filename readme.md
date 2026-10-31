# QField Structural Geology Calculator

**Author:** Liviu Matenco  
**Institution:** Utrecht University  
**Version:** 2.2  
**License:** MIT License  

This QField plugin provides structural geology calculations and real-time equal-area Schmidt stereonet plotting for fieldwork. It supports planes, lines, and shear senses, dynamically recognizing categories and structural types distributed on a Qfield map.

A testing dataset in QField/QGIS can be found in the files associated with the `Manual for building a digital field mapping system for structural geology using Qfield for QGIS`:  
https://github.com/liviumatenco/Qfield-digital-field-mapping-structural-geology/  
Download and unzip `UU_GEO_fieldwork.zip`

## Installation
Qfield -> Settings -> Manage plugins -> either use the link of the main github zip file, or use this QR-code:
<div align="center">
  <img src="qr-code.png" alt="QR Code" width="300">
</div>

## What's New in Version 2.2
* **New Tab B Domain Boundary Detection:** Domain Boundary Detection by grid size and threshold angle of 3D vectors. Measurements in the same area of the map have similar colors on the stereonet. Similar vector orientations have similar colors with threshold boundaries marked on the X-Y map.
  
## What's New in Version 2.1
* **Reorganized tabs and new tab:** Tabs are reorganized. Tabs 6 and 7 are now D and P. Tab 6 is a new calculation with lines.
* **Tab P:** Added transpression coefficients for shearzones. Note: the slip vector is compared with the pole of the plane vector, not with the strike. 
* **Adapted to dark modes and small corrections:** Adapted for visibility in dark modes.

## What's New in Version 2.0
* **Dynamic Categorization:** Automatically classifies measurements based on provided fields.
* **Kinematics Support:** Calculates shear sense from relative normal, reverse, sinistral, and dextral entries in a `Kinematics` field.
* **Dynamic Legend & Colors:** Automatically displays active types and assigns distinct, high-contrast colors to custom categories.
*  **Type of measurements:** An optional `Type` field in the layer is used to name the various categories. When absent, measurements in a layer will be plotted together.
*  **Separation in the same type:** An optional `Generation` field integer is used to define generations of the same Type. When absent, measurements in a type will be plotted together.
* **Fallback Types:** Uses the layer name as a type if no "Type" field exists.
* **SVG Button:** Stereonet and legend use svg vectors. The button exports the svg content to clipboard.
* **Axial planes:** Calculate bisector axial planes in Tab 1.
* **Re-folding:** Calculate re-folding Bingham axes and plane in Tab D.

## Qfield-derived limitations
**Changing Types** - Reset values before you change Types, residual values influence the Dynamic Categorization.
**Zero values** - Use 360 instead of 0 (zero) for azimuths and do not use 0 for inclinations. In Integer types Qfiled confuses 0 with with Unknown.
**90 dip/plunge values** - Never use values of 90 for inclinations, it disables kinematics.

## Calculation Tabs
*Note: Tabs S, D, and P automatically pull data from your active QField layer.*
| Tab | Name | Input Type | Description |
| :--- | :--- | :--- | :--- |
| **S** | Stereonet Plotting | Layer Data | Real-time Schmidt stereonet plotting with dynamic legends. |
| **D** | Structural Density | Layer Data | Contoured density plot for dominant orientations and refolding Bingham axes. |
| **P** | Paleostress or Strain| Layer Data | Calculates `σ1`, `σ2`, `σ3` for fault data or transpression values for shearzones. |
| **B** | Domain Boundary Detection | Layer Data | Calculate map boundaries based on grid size and threshold vectors angle. |
| **1** | 2P Intersection | Manual | Calculates intersection of two planes, Riedels and fold axes. |
| **2** | 1L, 1P Perpendicular | Manual | Line perpendicular to a given line within a plane. |
| **3** | Backtilting | Manual | Rotates data back to a horizontal reference. |
| **4** | Apparent Dip | Manual | Apparent dip in a vertical cross-section. |
| **5** | Best-Fit Plane | Manual | Pi-Diagram and kinematics for fold axes/best-fit planes and kinematics. |
| **6** | Best-Fit Lines | Manual | Best fit plane and pole for lines, angle between first two lines. |

## Toolbar & View Modes

The plugin adds a dedicated button to your QField toolbar. You can use this button to control which measurements are included in your stereonet plots and calculations:
* **Single Tap:** Opens the main calculation popup.
* **Press and Hold:** Toggles between two spatial filter modes:
  * **All Features (Default):** Processes every measurement in the active layer, regardless of your current map view.
  * **Current View Only:** Processes only the measurements visible within your current map extent (indicated by a yellow button background). *Note: For this mode to work correctly, your active layer and the QField project must be defined with the same Coordinate Reference System (CRS).*

## Project Setup Requirements

The active layer in QField should contain the following fields (case-insensitive). Any valid definitions of planes and lines will be processed, as well as Faults and Shear Zones with absolute `Senses of Shear` or relative `Kinematics` (case-sensitive).

| Field name | Supported Field Names | Data Type | Description |
| :--- | :--- | :--- | :--- |
| **Type** | `Type`, `type` | Text | Defines the structural feature (Fallback: Layer name) |
| **Dip Direction** | `Dip azimuth`, `dip_dir`, `dd`, `DipDir_ref`, `Dip_Dir` | Integer | Required for planes |
| **Dip** | `Dip`, `dip_angle`, `P_dip`, `Dip_ref` | Integer | Required for planes |
| **Azimuth/Trend** | `Trend`, `azimuth`, `L_plungeAzimuth`, `Azimuth` | Integer | Required for lines |
| **Plunge** | `Plunge`, `plunge`, `pl`, `L_plunge` | Integer | Required for lines |
| **Senses of Shear** | `Top to`, `Top_to`, `top_to` | Integer | Used for defining senses of shear |
| **Kinematics** | `Kinematics` | Text | Relative shear senses (normal, reverse, dextral, sinistral) |

## Feature Categorization

The plugin automatically classifies your measurements based on the fields provided:
| Feature Class | Classification Logic |
| :--- | :--- |
| **plane** | Requires Dip & Dip Azimuth (Line and Shear Sense must be empty/null). |
| **line** | Requires Trend & Plunge (Plane and Shear Sense must be empty/null). |
| **plane-line** | Requires Plane and Line data (Shear Sense must be empty/null). |
| **line-sense** | Requires Line and Shear Sense (Plane must be empty/null). |
| **plane-line-sense** | Requires Plane, Line, and Shear Sense.

## "Type" values
### Any layer
Any valid definitions as above in the active layer will be processed in one type. `Senses of Shear` have priority over `Kinematics`. Different colors are assigned by a random generator.
### Any layer with existing `Type` string field
As above and supplementary categorization on the type.
### Optimal: any layer with existing `Type` string field and `Generation` integer field
As above and supplementary sub-division inside the same type (e.g., superposition of deformation types). `Generation` values 1-9 have predefined colors.
### Recommended minimum content
One single layer containing "measurements" in its name, a `Type` string field and a `Generation` integer field. Reccommended `Type` values: plane, bedding, foliation, fault plane, fault gouge foliation, Riedel shear, line, fold, lineation, plane-line, line-sense, stretching lineation, slickenlines, plane-line-sene, fault, shearzone. 

## Troubleshooting

| Issue | Possible Cause | Solution |
| :--- | :--- | :--- |
| **No valid measurements** | Data is present, but fields are empty or incorrectly formatted. | Check that numerical fields are formatted as Integers and do not contain NULL values for required fields. |
| **CRS Mismatch** | Project and layer coordinate systems do not match. | Ensure your QField project and active layer share the same Coordinate Reference System (CRS) to use "Current View Only" mode. |
| **Missing Shear Sense Arrows** | Kinematics field is present but "Top to" is empty. | Ensure the `Kinematics` field is properly populated with normal, reverse, sinistral, or dextral values. |

## Changelog & Updates
* **Version 2.2:** New Tab B Domain Boundary Detection.
* **Version 2.1:** Tabs renamed, re-organized, new Tab 6, transpression coefficients in tab P, adapted to dark mode and small corrections.
* **Version 2.0:** Added dynamic recognition of categories, `Generation` superposition sub-types, `Kinematics` field support, dynamic legends, and dynamic color generation for types, SVG content export to clipboard.
* **Version 1.0:** Initial release. Includes real-time stereonet plotting, 7 calculation tabs, and spatial filtering for current view/all features.