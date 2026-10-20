# QField Structural Geology Calculator

**Author:** Liviu Matenco  
**Institution:** Utrecht University  
**Version:** 1.0  

This plugin has been created for Structural Geology students at Utrecht University to assist with field measurements and calculations within QField.  
A testing dataset in QField/QGIS can be found in the files associated with the `Manual for building a digital field mapping system for structural geology using Qfield for QGIS` that can be found here:  
https://github.com/liviumatenco/Qfield-digital-field-mapping-structural-geology/
Download and unzip `UU_GEO_fieldwork.zip`

## Installation
Qfield -> Settings -> Manage plugins -> either use the link of the main github zip file, or use this QR-code:
<div align="center">
  <img src="qr-code.png" alt="QR Code" width="300">
</div>

## Toolbar & View Modes

The plugin adds a dedicated button to your QField toolbar. You can use this button to control which measurements are included in your stereonet plots and calculations:

* **Single Tap:** Opens the main calculation popup.
* **Press and Hold:** Toggles between two spatial filter modes:
  * **All Features (Default):** Processes every measurement in the active layer, regardless of your current map view.
  * **Current View Only:** Processes only the measurements visible within your current map extent (indicated by a yellow button background). *Note: For this mode to work correctly, your active layer and the QField project must be defined with the same Coordinate Reference System (CRS).*

## Setup Requirements

To use this plugin, the active layer in QField must be named **"measurements"**. The plugin is flexible and will automatically recognize any of the following field name variations (case-insensitive):

| Field name | Supported Field Names | Data Type | Description |
| :--- | :--- | :--- | :--- |
| **Type** | `Type`, `type` | Text (String) | Defines the structural feature |
| **Dip Direction** | `Dip azimuth`, `dip_dir`, `dip_direction`, `dipdir`, `dd`, `dipdir_ref` | Integer (32 bit) | Used for defining planes |
| **Dip** | `Dip`, `dip`, `dip_angle`, `dip_ref` | Integer (32 bit) | Used for defining planes |
| **Azimuth/Trend** | `Trend`, `azimuth`, `az`, `bearing`, `trend` | Integer (32 bit) | Used for defining lines |
| **Plunge** | `Plunge`, `plunge`, `pl` | Integer (32 bit) | Used for defining lines |
| **Senses of Shear** | `Top to`, `Top_to`, `top_to` | Integer (32 bit) | Used for defining senses of shear |

## Measurement Definitions

Depending on the type of structural feature you are recording, different fields are used:

* **Planes:** Defined by *Dip azimuth* and *Dip*.
* **Lines:** Defined by *Trend* and *Plunge*.
* **Senses of Shear:** Defined by *Top to*.
* **Faults (with senses of shear):** Defined by all 5 elements (*Dip azimuth*, *Dip*, *Trend*, *Plunge*, and *Top to*). This applies to "fault" and "fault gen 1" through "fault gen 4".

## Supported "Type" Values

When setting up your Value Map for the **Type** field, the following values are supported:

* **Planes:** bedding, bedding overturned, foliation, foliation S1, foliation S2, foliation S3, cleavage, normal fault, reverse fault, fault gouge foliation, Riedel shear, Other measurements.
* **Lines:** fold, fold f1, fold f2, fold f3, fold f4, stretching lineation, stretching lineation L1, stretching lineation L2, stretching lineation L3, slickenlines, other lineation.
* **Faults:** fault, fault gen 1, fault gen 2, fault gen 3, fault gen 4.

## Calculation Tabs

*Note: Tabs S, 6, and 7 automatically pull data from your active QField layer. Tabs 1 through 5 require manual input of measurements.*

| Tab | Name | Input Type | Detailed Description |
| :--- | :--- | :--- | :--- |
| **S** | Stereonet Plotting Tool | Layer Data | Provides real-time equal-area Schmidt stereonet plotting. Filter by structural type and toggle between plotting poles or great circles for planes. |
| **1** | 2P Intersection | Manual | Calculates the exact intersection line (Trend/Plunge) of two planes, such as a main fault and a Riedel shear. |
| **2** | 1L, 1P Perpendicular | Manual | Determines the line perpendicular to a given line within a specific plane (e.g., slip direction from a drag fold axis). |
| **3** | Backtilting | Manual | Rotates structural data (planes or lines) back to a horizontal reference plane. |
| **4** | Apparent Dip | Manual | Calculates the apparent dip of a geological plane as it would appear in a vertical cross-section. |
| **5** | Best-Fit Plane | Manual | Uses a Pi-Diagram method to calculate the best-fit plane and fold axis from multiple measurements. |
| **6** | Structural Density | Layer Data | Generates a contoured density plot for structural data to identify dominant orientations. |
| **7** | Paleostress | Layer Data | Calculates individual conjugate stresses and the Eigenvector Average ($\sigma_1$, $\sigma_2$, $\sigma_3$) for fault data. |

## Troubleshooting

| Issue | Possible Cause | Solution |
| :--- | :--- | :--- |
| **"Field 'Type' not found"** | The active layer is missing the required "Type" column. | Ensure your layer has a text field named "Type" containing the supported structural types. |
| **"No valid measurements"** | Data is present, but fields are empty or incorrectly formatted. | Check that your numerical fields are formatted as Integers and do not contain NULL values for the required fields. |
| **"CRS Mismatch"** | Project and layer coordinate systems do not match. | Ensure your QField project and active layer share the same Coordinate Reference System (CRS) to use the "Current View Only" mode. |
| **"Line not contained in plane"** | The input line in Tab 2 deviates from the plane by >6 degrees. | Verify your field measurements; the plugin strictly enforces geometric reality. |

## Changelog & Updates

* **Version 1.0:** Initial release. Includes real-time stereonet plotting, 7 calculation tabs, and spatial filtering for current view/all features.
