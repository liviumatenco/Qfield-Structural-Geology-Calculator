# Qfield Structural Geology Calculator: Plugin Explained
  
## General Setup & Data Categorization

Before performing any calculations, the plugin automatically classifies your structural measurements in the Qfield map based on the fields present in your active layer. 

### Required Fields
The plugin searches for field names defined in the following internal arrays:
*   **Planes:** Requires a field definition from `dipFieldNames` and `dipDirFieldNames`.
*   **Lines:** Requires a field definition from `azimuthFieldNames` and `plungeFieldNames`.
*   **Top to:** Requires a field definition from `topToFieldNames` or a `Kinematics` text field.

### Automatic Classification
Depending on which combination of these fields is filled, the plugin dynamically categorizes the feature:
*   **Plane:** Only plane data is present.
*   **Line:** Only line data is present.
*   **Plane-Line:** Both are present (e.g., a plane with a lineation).
*   **Line-Sense:** Line data and Top to/Kinematics are present (e.g., a stretching lineation)
*   **Plane-Line-Sense:** All three are present (e.g., a fault or shearzone with a known full kinematics).

If an optional `Type` field is present, the plugin will use it to group and color-code your measurements on the stereonet.
  
## Tab C: Geological compass

### The Smartphone Coordinate System
To understand the math, we must first define how the smartphone "sees" the world. The device uses a standard 3D coordinate system:

```text           +X (Top Edge)
    +-------------------------+
    |            ^            |
    |            |            |
    |            |            |
    |            |            |
    |            |            |
    |            |            |
    |            |            |
    |    +Y      |            |
    | <-(Long-O--|            |
    |    Edge)   |Z (+Z is UP,|
    |         out of screen)  |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    |                         |
    +-------------------------+
```
*   **The Z-Axis (Screen):** Used to measure **Planes** (like bedding or fault planes). The back of the phone is placed flat against the rock.
*   **The Y-Axis (Long Edge):** Used to measure **Lineations** (like slickenlines or fold axes). The long edge of the phone is aligned parallel to the linear feature.

---

### The Math and Implementation
The code inside `geoData.getOrientation()` takes the raw gravity vector $(g_x, g_y, g_z)$ and the compass heading $(hd)$ to calculate the geological features.

#### 1. Sensor Normalization
Before any trigonometry is applied, the gravity vector is normalized to a length of 1. This isolates the direction of gravity regardless of how the device is being held.
$$\text{Normalized Vector} = \frac{(g_x, g_y, g_z)}{\sqrt{g_x^2 + g_y^2 + g_z^2}}$$

```javascript
var hdRad = hd * Math.PI / 180;
var g_mag = Math.sqrt(gx*gx + gy*gy + gz*gz);
gx /= g_mag; gy /= g_mag; gz /= g_mag;
```  
#### 2. Hardware Metrics & Freezing
The plugin displays three key metrics to help you evaluate the quality of your measurement:
*   **Gravity:** The magnitude of the gravity vector (should be close to 1.0 g).
*   **Mag Var:** The live variance in the compass heading.
*   **Acc Stab:** The stability of the accelerometer.
These metrics are tied directly to the compass state. When you tap the compass to freeze your measurement, the sensors stop updating, locking the displayed values so you can evaluate them accurately.
```javascript
// Hardware metrics combined into a single row
Row { spacing: 15; anchors.horizontalCenter: parent.horizontalCenter
    Text { text: 'Gravity: ' + Math.round(plugin.gravityMagnitude * 100) / 100 + ' g'; font.pixelSize: 10; color: "#666666" }
    Text { text: 'Mag Var: ' + Math.round(plugin.magVariance * 10) / 10 + '°'; font.pixelSize: 10; color: "#666666" }
    Text { text: 'Acc Stab: ' + Math.round((10 - Math.min(10, plugin.accVariance)) * 10) + '%'; font.pixelSize: 10; color: "#666666" }
}
```
#### 3. Plane Calculations (Dip and Dip Direction)
When measuring a plane, we are interested in the angle of the Z-axis relative to gravity.
*   **Dip:** The angle between the screen and the horizontal plane.
    $$\text{Dip} = \arccos(|g_z|)$$
*   **Dip Direction:** The compass direction of the maximum slope, calculated by rotating the local gravity components by the compass heading.
    $$g_{north} = g_y \cos(hd) - g_x \sin(hd)$$
    $$g_{east} = g_y \sin(hd) + g_x \cos(hd)$$

```javascript
plugin.currentDip = Math.acos(Math.abs(gz)) * 180 / Math.PI;
var g_north = gy * Math.cos(hdRad) - gx * Math.sin(hdRad);
var g_east = gy * Math.sin(hdRad) + gx * Math.cos(hdRad);
plugin.currentDipDirection = Math.atan2(g_east, g_north) * 180 / Math.PI + 180;
```  
#### 4. Line Calculations (Trend and Plunge)
When measuring a lineation, we are interested in the orientation of the long edge (Y-axis).
*   **Plunge:** The vertical angle of the long edge relative to the horizontal plane.
    $$\text{Plunge} = \arcsin(|g_y|)$$
*   **Trend:** The compass bearing of the long edge, projected into geographical space.
    $$\text{pitch} = \arcsin(g_y) \quad\quad \text{roll} = \arctan2(-g_x, g_z)$$
    $$y_{east} = \sin(hd)\cos(\text{pitch}) + \cos(hd)\sin(\text{roll})\sin(\text{pitch})$$
    $$y_{north} = \cos(hd)\cos(\text{pitch}) - \sin(hd)\sin(\text{roll})\sin(\text{pitch})$$

```javascript
plugin.currentPlunge = Math.asin(Math.abs(gy)) * 180 / Math.PI;
var pitch = Math.asin(gy);
var roll = Math.atan2(-gx, gz);
var y_east = Math.sin(hdRad) * Math.cos(pitch) + Math.cos(hdRad) * Math.sin(roll) * Math.sin(pitch);
var y_north = Math.cos(hdRad) * Math.cos(pitch) - Math.sin(hdRad) * Math.sin(roll) * Math.sin(pitch);
plugin.currentTrend = Math.atan2(y_east, y_north) * 180 / Math.PI;
```
// Ensure the trend points in the downward direction of the plunge
if (gy > 0) { plugin.currentTrend += 180; }
  
#### 5. Error Calculation (Line vs. Plane)
The error is calculated as the true 3D spatial angle between the lineation vector and the plane itself. If the line lies perfectly within the plane, the error is 0 degrees.
$$\text{Error} = \arcsin(|\vec{L} \cdot \vec{N}|)$$

```javascript
// Final Corrected Error Calculation between Line and Plane
var ddRad = plugin.currentDipDirection * Math.PI / 180;
var dRad = plugin.currentDip * Math.PI / 180;
var nX = Math.sin(dRad) * Math.sin(ddRad);
var nY = Math.sin(dRad) * Math.cos(ddRad);
var nZ = -Math.cos(dRad); // Flipped to point downwards
var tRad = plugin.currentTrend * Math.PI / 180;
var pRad = plugin.currentPlunge * Math.PI / 180;
var lX = Math.cos(pRad) * Math.sin(tRad);
var lY = Math.cos(pRad) * Math.cos(tRad);
var lZ = Math.sin(pRad);
var dotProduct = (nX * lX) + (nY * lY) + (nZ * lZ);
dotProduct = Math.max(-1.0, Math.min(1.0, Math.abs(dotProduct)));
plugin.currentError = Math.asin(dotProduct) * 180 / Math.PI;
```  
  
## Tab S: Stereonet Plotting

### 1. Equal-Area Projection (Lambert)
The plugin uses a lower-hemisphere, equal-area (Schmidt) projection. This ensures that structural data density is preserved across the stereonet.

The projection of a point with a given plunge ($\phi$) and trend/azimuth ($\theta$) onto the flat circular net of radius $R$ is calculated as:
$$r = R \sqrt{2} \sin\left(\frac{\frac{\pi}{2} - \phi}{2}\right)$$

The Cartesian coordinates $(x, y)$ on the SVG canvas are then derived as:
$$x = r \sin(\theta) \quad\quad y = r \cos(\theta)$$

```javascript
function projectStereonetPoint(plunge, azimuth, R) {
    var plungeRad = plunge * Math.PI / 180; 
    var azRad = azimuth * Math.PI / 180;
    var r = R * Math.sqrt(2) * Math.sin((Math.PI / 2 - plungeRad) / 2);
    return { 
        x: r * Math.sin(azRad), 
        y: r * Math.cos(azRad) 
    };
}
```
  
### 2. Plane Normal (Pole) Calculation
To plot a pole to a plane, the plugin first converts the geological dip and dip direction into a 3D Cartesian normal vector. 

Given a dip direction ($dd$) and dip ($d$), the normal vector $\vec{N} = (n_x, n_y, n_z)$ is calculated by taking the cross product of the strike vector and the down-dip vector:
$$n_x = \sin(d) \sin(dd)$$
$$n_y = \sin(d) \cos(dd)$$
$$n_z = \cos(d)$$

```javascript
function planeNormal(dipAzimuth, dip) {
    var dd = dipAzimuth * Math.PI / 180;
    var d = dip * Math.PI / 180;
    // Normal vector pointing upwards
    return { 
        x: Math.sin(d) * Math.sin(dd), 
        y: Math.sin(d) * Math.cos(dd), 
        z: Math.cos(d) 
    };
}
```
  
### 3. Vector to Attitude Conversion
When performing calculations (like finding the intersection of two planes), the plugin works in 3D Cartesian space. It then converts the resulting vector back into a geological trend and plunge.

Given a normalized vector $\vec{V} = (x, y, z)$ pointing into the lower hemisphere ($z < 0$):
$$\text{Trend} = \arctan2(x, y)$$
$$\text{Plunge} = \arctan2\left(|z|, \sqrt{x^2 + y^2}\right)$$
  
```javascript
function vectorToAttitude(v) {
    var line = normalizeVector(v);
    // Ensure the vector points into the lower hemisphere
    if (line.z < 0) {
        line.x = -line.x;
        line.y = -line.y;
        line.z = -line.z;
    }
    var azimuth = Math.atan2(line.x, line.y) * 180 / Math.PI;
    if (azimuth < 0) { azimuth += 360; }
    var horizontal = Math.sqrt(line.x * line.x + line.y * line.y);
    var plunge = Math.atan2(line.z, horizontal) * 180 / Math.PI;
    return { 
        azimuth: normalizeAzimuth(azimuth), 
        plunge: clamp(plunge, 0, 90) 
    };
}
```
  
### 4. Great Circle Generation
To draw a plane as a great circle on the stereonet, the plugin calculates a series of points along the strike of the plane, rotating them by the dip angle.

The points are generated by iterating an angle $\alpha$ from $0^\circ$ to $180^\circ$ and projecting the resulting 3D vector onto the 2D net:
$$V_x = \sin(\text{strike}) \cos(\alpha) + \cos(\text{dip}) \sin(\text{strike}) \sin(\alpha)$$
$$V_y = \cos(\text{strike}) \cos(\alpha) + \cos(\text{dip}) \cos(\text{strike}) \sin(\alpha)$$
$$V_z = \sin(\text{dip}) \sin(\alpha)$$

```javascript
function generateGlobalGreatCircleSVG(cx, cy, R, dip, dipAzimuth, color) {
    var dipRad = dip * Math.PI / 180; 
    var strikeRad = (dipAzimuth - 90 + 360) % 360 * Math.PI / 180;
    var sx = Math.sin(strikeRad); 
    var sy = Math.cos(strikeRad);
    var dx = Math.cos(dipRad) * Math.sin(dipAzimuth * Math.PI / 180); 
    var dy = Math.cos(dipRad) * Math.cos(dipAzimuth * Math.PI / 180); 
    var dz = Math.sin(dipRad);
    var path = ""; 
    var first = true;
    for (var a = 0; a <= 180; a += 1) {
        var angle = a * Math.PI / 180; 
        var vx = sx * Math.cos(angle) + dx * Math.sin(angle); 
        var vy = sy * Math.cos(angle) + dy * Math.sin(angle); 
        var vz = dz * Math.sin(angle);
        var len = Math.sqrt(vx*vx + vy*vy + vz*vz); 
        if (len < 0.000001) continue; 
        vx /= len; vy /= len; vz /= len;
        var azimuth = Math.atan2(vx, vy); 
        if (azimuth < 0) azimuth += 2 * Math.PI;
        var plunge = Math.atan2(vz, Math.sqrt(vx*vx + vy*vy)); 
        var proj = projectStereonetPoint(plunge * 180 / Math.PI, azimuth * 180 / Math.PI, R);
        if (first) { 
            path += "M " + (cx + proj.x) + " " + (cy - proj.y); 
            first = false; 
        } else { 
            path += " L " + (cx + proj.x) + " " + (cy - proj.y); 
        }
    }
    return '<path d="' + path + '" fill="none" stroke="' + color + '" stroke-width="1"/>';
}
```
  
### 5. Shear Sense (Top To) Arrows
For faults and shear zones, the plugin plots the direction of movement using an arrow centered on the lineation. 

The arrow's orientation is determined by the **Top To** azimuth. The plugin dynamically calculates the correct geographic angle on the 2D stereonet and draws the arrow pointing in the direction of the hanging wall movement.

```javascript
// Calculate the end point of the arrow based on the Top To azimuth
var arrowLength = R / 8; 
var topToRad = topTo * Math.PI / 180;
var endX = px + arrowLength * Math.sin(topToRad); 
var endY = py - arrowLength * Math.cos(topToRad);
```

// Draw the arrow shaft and head
```javascript
svg += '<line x1="' + px + '" y1="' + py + '" x2="' + endX + '" y2="' + endY + '" stroke="' + color + '" stroke-width="2"/>';
```
  
## Tab D: Structural Density

### 1. Density Grid Calculation
To visualize the concentration of structural measurements (like poles to bedding or lineations), the plugin maps the data onto a 2D equal-area grid. It then calculates the density by counting how many points fall within a specific search radius around each grid node.

The plugin offers two contouring methods:
*   **Standard:** Uses a fixed search radius ($r = 0.15$) representing 15% of the stereonet.
*   **Kamb Contouring:** Dynamically scales the radius based on the total number of points ($N$). This ensures that the contours remain statistically significant, regardless of whether you have 10 or 1,000 measurements.
$$A = \frac{1}{N + 1} \quad\quad r = \sqrt{2A}$$

```javascript
// Dynamically calculate the search radius for Kamb contouring
var radius = 0.15;
if (plugin.tabdKambMode && points.length > 0) {
    var areaFraction = 1.0 / (points.length + 1.0);
    radius = Math.sqrt(areaFraction * 2.0); 
    if (radius > 0.4) { radius = 0.4; } // Cap the radius for small datasets
}
// Count points within the radius for each grid node
for (var p = 0; p < points.length; p++) { 
    var dx = x - points[p].x, dy = y - (-points[p].y); 
    if (dx*dx + dy*dy < radius*radius) density += 1.0; 
}
```
  
### 2. Contour Generation
Once the density grid is calculated, the plugin uses a basic marching squares algorithm to draw the contour lines. It evaluates the density values at the corners of each grid cell to determine where the contour lines should intersect the cell edges. It also calculates a peak density point. 

The plugin then overlays the peak density point over the poles or lines and the contours.

```javascript
// Example of drawing the peak density point on the SVG
if (plugin.tabdHasMax) {
    var peakProj = projectStereonetPoint(plugin.tabdMaxPlunge, plugin.tabdMaxTrend, svgData.R);
    svgString += '<circle cx="' + (svgData.cx + peakProj.x) + '" cy="' + (svgData.cy - peakProj.y) + '" r="10" fill="none" stroke="#D32F2F" stroke-width="3"/>';
}
```
  
### 3. Geometric Filtering for non-refolded datasets
The geometric filter isolates measurements clustering around a specific orientation (e.g., peak density) by suppressing background noise. It calculates the true 3D angular distance between a reference vector and each measurement.

1. **Vector Conversion:** Converts peaks and data points into 3D Cartesian vectors.
2. **Visual Filtering:** Grays out points falling outside the user-defined angular threshold that starts from a mean value of the displayed dataset.
3. **User input** Users can change the 3D peak vector and the angular threshold to adapt for their field observations.

```javascript
if (item.isPlane) {
    var n = planeNormal(item.dipAz, item.dip);
    itemVec = {x: n.x, y: n.y, z: Math.abs(n.z)};
} else { itemVec = attitudeToVector(item.trend, item.plunge); }
var angle = calculateAngularDistance(refVec, itemVec);
if (angle > threshold) { ptColor = "#CCCCCC"; }
```

### 4. Bingham Axes (Eigenvector Analysis) for refolded datasets
When analyzing folded terrain, we look for the fold axis (the line of maximum data spread) and the axial plane. The plugin automates this by treating the 3D orientation vectors as a mathematical tensor matrix.

By finding the **eigenvectors** of this matrix, the plugin extracts three perpendicular axes:
*   **$E_1$ (Maximum):** The direction where the data is most concentrated.
*   **$E_3$ (Minimum):** The pole to the best-fit plane (the plane that best describes the data).

```javascript
// Construct the orientation tensor matrix from the 3D vectors
var M = [[0,0,0],[0,0,0],[0,0,0]];
for(var i=0; i<vectors.length; i++) {
    var v = [vectors[i].x, vectors[i].y, vectors[i].z];
    for(var r=0; r<3; r++) for(var c=0; c<3; c++) M[r][c] += v[r]*v[c];
}
// Power iteration method to find the dominant eigenvector (E1)
for(var iter=0; iter<50; iter++) {
    var next = { x: M[0][0]*vec1.x + M[0][1]*vec1.y + M[0][2]*vec1.z, /* ... */ };
    lambda1 = Math.sqrt(next.x*next.x + next.y*next.y + next.z*next.z);
    vec1 = {x: next.x/lambda1, y: next.y/lambda1, z: next.z/lambda1};
}
```
  
### 5. Matrix Deflation for Secondary Axes
Once the primary axis ($E_1$) is identified, the plugin mathematically removes its influence from the data, i.e. **matrix deflation**. This allows the algorithm to find the remaining two axes ($E_2$ and $E_3$) while ensuring all three remain perfectly perpendicular (orthogonal) to each other.

```javascript
// Deflate the matrix by removing the influence of the first eigenvector
var M2 = [[0,0,0],[0,0,0],[0,0,0]], v1_arr = [vec1.x, vec1.y, vec1.z];
for(var r=0; r<3; r++) for(var c=0; c<3; c++) M2[r][c] = M[r][c] - (lambda1 * v1_arr[r] * v1_arr[c]);

// Find the third eigenvector (E3) and use the cross product to find E2
var vec2 = normalizeVector(crossProduct(vec1, vec3));
vec3 = normalizeVector(crossProduct(vec2, vec1));
```
  
## Tab P: Paleostress Inversion

### 1. Paleostress Calculation
When quickly analyzing faults in the field, we want to determine the orientation of the principal stress axes ($\sigma_1, \sigma_2, \sigma_3$) that caused the movement. 

**Important note:** The plugin takes a very simple approach to derive individual axes and an average. There is no point of having a full paleostress inversion on a smartphone, which should be done on a normal computer. We recommend WinTensor: https://damiendelvaux.be/Tensor/WinTensor/win-tensor.html

The plugin calculates these for each individual fault by assuming a standard angle of internal friction ($\phi = 30^\circ$). Before calculating the stress axes, the plugin mathematically forces the lineation to lie perfectly on the fault plane. It does this by taking the measured trend and calculating the exact plunge required for that vector to intersect the fault plane.
```javascript
// Calculate the normal vector of the fault plane
var nx = Math.sin(d) * Math.sin(dd); 
var ny = Math.sin(d) * Math.cos(dd); 
var nz = Math.cos(d);
// Calculate the horizontal components of the lineation
var lx = Math.sin(t); 
var ly = Math.cos(t);
// Solve for the vertical component (lz) that places the line on the plane
var lz = -(nx * lx + ny * ly) / nz;
var plungeRad = Math.atan(lz); 
var correctedPlunge = plungeRad * 180 / Math.PI;
```
  
The algorithm uses the fault plane's normal vector and the slip direction (lineation) to find:
*   **$\sigma_1$ (Maximum Stress):** Oriented at an angle of $\theta = 30^\circ$ to the fault plane.
*   **$\sigma_2$ (Intermediate Stress):** Parallel to the intersection of the fault plane and the slip normal.
*   **$\sigma_3$ (Minimum Stress):** Perpendicular to $\sigma_1$ and $\sigma_2$.

```javascript
// Calculate the normal vector and slip vector for the fault
var n = planeNormal(fault.dipAz, fault.dip);
var slip = attitudeToVector(slipTrend, correctedPlunge);
// Define the angle of internal friction and the failure angle
var phi = 30 * Math.PI / 180, theta = (Math.PI / 4) - (phi / 2); 
// Calculate Sigma 1 (Maximum Stress)
var cosT1 = Math.cos(Math.PI/2 - theta), sinT1 = Math.sin(Math.PI/2 - theta);
var sigma1 = normalizeVector({ 
    x: normalDown.x * cosT1 + slip.x * sinT1, 
    y: normalDown.y * cosT1 + slip.y * sinT1, 
    z: normalDown.z * cosT1 + slip.z * sinT1 
});
```

### 2. Tensor Averaging (Eigenvector Method)
The plugin averages the individual stress tensors using an eigenvector method to find the overall regional stress orientation. This method constructs a matrix from all the individual $\sigma_1$ vectors and finds the dominant direction, ensuring that the final averaged $\sigma_1, \sigma_2,$ and $\sigma_3$ axes are perfectly perpendicular to each other.

```javascript
// Construct the orientation matrix for all Sigma 1 vectors
var M = [[0,0,0],[0,0,0],[0,0,0]];
for(var i=0; i<vectors.length; i++) {
    var v = [vectors[i].x, vectors[i].y, vectors[i].z];
    for(var r=0; r<3; r++) for(var c=0; c<3; c++) M[r][c] += v[r]*v[c];
}
// Find the dominant eigenvector (Average Sigma 1)
var vec = {x: Math.random(), y: Math.random(), z: Math.random()};
for(var iter=0; iter<50; iter++) {
    var next = { x: M[0][0]*vec.x + M[0][1]*vec.y + M[0][2]*vec.z, /* ... */ };
    var len = Math.sqrt(next.x*next.x + next.y*next.y + next.z*next.z);
    vec = {x: next.x/len, y: next.y/len, z: next.z/len};
}
```
  
### 3. Transpression and Kinematic Vorticity
For shear zones, the plugin calculates the angle of convergence ($\alpha$) and the Kinematic Vorticity number ($W_k$). This helps determine whether the deformation was purely coaxial (flattening) or non-coaxial (simple shear).

*   **$W_k = 0$:** Pure shear (coaxial).
*   **$W_k = 1$:** Simple shear (non-coaxial).

**Methodological Note:** The plugin calculates the angle of convergence ($\alpha$) using the **full 3D orientation vectors** of the fault plane and the slip lineation. This is achieved by taking the dot product of the 3D normal vector ($n$) and the 3D slip vector ($slip$):
 
```javascript
// Calculate the true 3D convergence angle (alpha) using full vectors
var dot = Math.abs(dotProduct(n, slip));
var alphaRad = Math.asin(dot); 
```
 
```javascript
// Calculate Kinematic Vorticity (Wk)
var finalRad = plugin.tabpAlpha * Math.PI / 180;
plugin.tabpWk = Math.cos(finalRad) / (1 + Math.sin(finalRad));
```
  
### 4. Shear Sense (Top To) Integration
The direction of movement (shear sense) is vital for orienting the stress axes correctly. The plugin checks the recorded "Top To" azimuth against the calculated slip vector. If the vectors oppose each other, the plugin mathematically flips the slip vector to ensure the resulting $\sigma_1$ and $\sigma_3$ axes are placed in the correct quadrants.

```javascript
// Adjust the slip vector based on the shear sense (Top To)
if (fault.sense !== null && !isNaN(fault.sense)) {
    var senseVec = attitudeToVector(fault.sense, 0);
    if (dotProduct(slip, senseVec) < 0) {
        slip = { x: -slip.x, y: -slip.y, z: -slip.z };
    }
}
```
  
## Tab B: Domain Boundary Detection

### 1. Spatial Grid and Vector Averaging
To detect boundaries between different structural domains, the plugin divides the map into a grid. For each grid cell, it calculates the average 3D orientation vector of the measurements inside it. This allows the plugin to compare the structural "attitude" of neighboring areas rather than individual points.

```javascript
// Assign measurements to a spatial grid
var gX = Math.floor((pt.x - minX) / gridSize); 
var gY = Math.floor((pt.y - minY) / gridSize); 
var key = gX + "," + gY;
// Calculate the average normal vector for a grid cell
function calculateAverageNormal(points) {
    var sumX = 0, sumY = 0, sumZ = 0;
    for (var i = 0; i < points.length; i++) {
        var n = points[i].isPlane ? planeNormal(points[i].dipDir, points[i].dip) : attitudeToVector(points[i].trend, points[i].plunge);
        sumX += n.x; sumY += n.y; sumZ += n.z;
    }
    return normalizeVector({ x: sumX / points.length, y: sumY / points.length, z: sumZ / points.length });
}
```
  
### 2. Boundary Detection
Once the average orientation for each grid cell is calculated, the plugin compares each cell with its immediate neighbors (top, bottom, left, and right). It calculates the 3D angular distance between the average vectors of the two cells. If the angle exceeds a user-defined threshold (e.g., 20°), the plugin flags the shared edge as a structural domain boundary.

```javascript
// Calculate the 3D angular distance between two normal vectors
function calculateAngularDistance(n1, n2) {
    var dot = Math.abs(dotProduct(n1, n2));
    dot = Math.max(-1, Math.min(1, dot)); // Clamp to avoid NaN
    return Math.acos(dot) * 180 / Math.PI;
}
// Compare neighboring cells
var neighbors = [[x1+1, y1, "right"], [x1, y1+1, "top"], /* ... */];
for (var n = 0; n < neighbors.length; n++) {
    var nKey = neighbors[n][0] + "," + neighbors[n][1];
    if (grid[nKey]) {
        var avg1 = calculateAverageNormal(grid[keys[i]]); 
        var avg2 = calculateAverageNormal(grid[nKey]); 
        var angle = calculateAngularDistance(avg1, avg2);
        
        if (angle > thresholdAngle) { 
            boundaries.push({ x1: x1, y1: y1, edge: neighbors[n][2] }); 
        }
    }
}
```
  
### 3. Spatial Color Mapping
To help visualize structural domains, the plugin uses a continuous color wheel. 
*   **On the Map:** The color is determined by the azimuth (trend) of the vector, allowing  to see domains of similar orientation as distinct blocks of color.
*   **On the Stereonet:** The color wheel is mapped to the **X-Y geographic location** of the measurement. This means points on the stereonet are colored according to where they were found on the map, making it easy to see if specific orientations cluster in specific geographic areas.

```javascript
// Map the X-Y geographic location to an RGB color wheel for the stereonet
var normX = ((pt.x - minX) / (maxX - minX)) * 2 - 1;
var normY = ((pt.y - minY) / (maxY - minY)) * 2 - 1;
var mapAngle = Math.atan2(normX, normY) * 180 / Math.PI;
if (mapAngle < 0) mapAngle += 360;

// Assign color based on the geographic angle
if (mapAngle >= 0 && mapAngle < 90) { var t = mapAngle / 90; r = 255; g = t*255; } 
else if (mapAngle >= 90 && mapAngle < 180) { var t = (mapAngle-90)/90; r = (1-t)*255; g = 255; } 
// ... (color mapping continues)
```
  
## Tab 1: Plane Intersection (2-Planes)

### What it does
This tab calculates the line where two planes meet in 3D space, the planes bisectors and the point at 90 degrees in one of the planes from the line of intersection. This is commonly used to find the fold axis when you measure two limbs of a fold, or to find the movement direction on a fault using Riedel shears.

### How it works
1.  **The Intersection:** The plugin takes the 3D orientation of both planes and finds the one line they share. It outputs this as a **Trend and Plunge**.
2.  **The Bisectors:** It also calculates the two planes that cut exactly halfway between your input planes. In fold analysis, one of these represents the **Axial Plane**.
3.  **The Angle:** It tells you the true 3D angle between the two planes (the inter-limb angle).
4.  **The Line Perpendicular:** The direction of shear on a fault plane at 90 degrees from the line of intersection with a Riedel shear.

```javascript
// The core math simply finds the cross product of the two plane normals
var line = crossProduct(n1, n2);
```
  
## Tab 2: Line Perpendicular in Plane (1-Line, 1-Plane)

### What it does
If you have a plane (like a fault) and a line on it (like a drag fold hinge), this tab calculates the line that sits exactly 90 degrees away from it on that same plane (like the direction of shear). The sense of shear is given by observing the geometry of the fold.

### How it works
1.  **The Check:** The plugin first checks to make sure the line you entered actually lies on the plane (within a small margin of error).
2.  **The Rotation:** It then rotates the line 90 degrees within the 3D plane.
3.  **The Result:** It outputs the **Trend and Plunge** of the new perpendicular line.

```javascript
// Finds the vector perpendicular to both the plane's normal and the original line
var perpendicular = crossProduct(planeNormal, existingLine);
```
  
## Tab 3: Backtilting (Rotation)

### What it does
This tab allows you to "undo" tectonic tilting. If you know a specific plane (like bedding) was once horizontal, this tool rotates all your other measurements (planes or lines) by that exact same amount to see how they were oriented originally.

### How it works
1.  **The Reference:** You input the plane that you want to rotate back to horizontal.
2.  **The Target:** You input the current orientation of the feature you want to investigate.
3.  **The Rotation:** The plugin mathematically rotates the target feature around the strike of the reference plane by the dip angle.
4.  **The Result:** It outputs the original, pre-tilt **Trend/Plunge** (for lines) or **Dip/Dip Direction** (for planes).

```javascript
// Rotates a 3D vector around the strike axis by the negative of the dip angle
var rotatedVector = rotateVectorAroundAxis(targetVector, strikeAxis, -refDip);
```
  
## Tab 4: Apparent Dip

### What it does
When you draw a geological cross-section that is not perfectly perpendicular to the strike of a layer, the dip of that layer will appear shallower than it actually is. This tab calculates that "apparent dip" for your specific cross-section angle.

### How it works
1.  **The True Plane:** You input the actual strike and dip of the rock layer.
2.  **The Section:** You input the compass direction (trend) of your cross-section line.
3.  **The Result:** The plugin calculates the exact angle the layer will appear to dip on your final cross-section drawing.

```javascript
// Calculates apparent dip based on the angle between the strike and the section line
var appDipRad = Math.atan(Math.tan(trueDipRad) * Math.sin(betaRad));
```
  
## Tab 5: Best-Fit Plane (Pi-Diagram)

### What it does
If you have measured multiple planes that are folded (like different parts of a fold hinge and limbs), this tab finds the single plane that best fits all of them with the theoretical fold axis. Can also be used to derive the kinematics along a fault plane from multiple plane measurements, assuming that the waved geometry corresponds with the direction of slip.

### How it works
1.  **The Input:** You enter three or more plane measurements.
2.  **The Math:** The plugin calculates the pole (normal vector) for each plane and finds the "average" plane that fits them best.
3.  **The Result:** 
    *   **The Fold Axis:** The line where all these planes generally intersect.
    *   **The Pi-Plane:** The plane that best represents the overall fold geometry.

```javascript
// Uses eigenvector analysis to find the best-fit plane through the poles
var vec3 = crossProduct(vec1, vec2);
```
  
## Tab 6: Best-Fit Lines

### What it does
If you have measured multiple lineations (like slickensides or mineral alignments) that are scattered, this tab finds the average "best-fit" line and the plane that best contains all of them.

### How it works
1.  **The Input:** You enter two or more line measurements.
2.  **The Mean Line:** The plugin calculates the mathematical average of all the lines, giving you a single **Trend and Plunge**.
3.  **The Best Plane:** If you enter three or more lines, the plugin calculates the single plane that best fits all of your lineations (useful for finding a fault plane from scattered slickenlines).
4.  **The Angle:** It also calculated the sngle between the first two lines entered in teh calculation.

```javascript
// Calculates the vector average for the mean line
var meanVec = normalizeVector({x: sumX, y: sumY, z: sumZ});
```

## Settings & Limitations

### 1. Magnetic Declination
To ensure that all strike and trend measurements are relative to True North rather than Magnetic North, the compass has a module to automatically adjusts for magnetic declination based on your device's location settings, but is **NOT enabled. Make sure you implement the magnetic declination yourselves manually!**
 
```javascript
// Magnetic declination is applied directly to the raw compass heading
hd += plugin.magneticDeclination;
```
 
### 2. Limitations in your Qfield project
When using this plugin in the field, keep the following in mind:
*   **Zero Values:** Use `360` instead of `0` for azimuths. QField often confuses `0` with a `NULL` (empty) value.
*   **Inclinations:** Avoid using exactly `0` or `90` degrees for dips or plunges if possible, as this can cause mathematical ambiguities in the shear sense calculations.
