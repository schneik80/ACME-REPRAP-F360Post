/**
  Copyright (C) 2018-2019 by Autodesk, Inc.
  All rights reserved.

  3D additive printer post configuration.

  $Revision: 42614 ccbc0b14704b013ada243633a5bc25f45bcb39f5 $
  $Date: 2019-12-20 12:00:51 $
  
  FORKID {A316FBC4-FA6E-41C5-A347-3D94F72F5D06}
*/

description = "Reprap and Duet3d Firmware";
vendor = "ACME CAD CAM";
vendorUrl = "http://acmecadcam.com";
legal = "Attribution-NonCommercial-ShareAlike 4.0 International";
certificationLevel = 2;
minimumRevision = 45621;

longDescription = "Simple post to export toolpath for generic FFF Machine in gcode format";

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_ADDITIVE;
tolerance = spatial(0.002, MM);
highFeedRate = toPreciseUnit(6000, MM);

// needed for range checking
var printerLimits = {
  x: {min: 0, max: 300.0}, //Defines the x bed size
  y: {min: 0, max: 300.0}, //Defines the y bed size
  z: {min: 0, max: 300.0} //Defines the z bed size
};

// For information only
var bedCenter = {
  x: 150.0,
  y: 150.0,
  z: 0.0
};

var extruderOffsets = [[0, 0, 0], [0, 0, 0]];
var activeExtruder = 0;  //Track the active extruder.

var xyzFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var xFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var yFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var zFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var gFormat = createFormat({prefix: "G", width: 1, zeropad: false, decimals: 0});
var mFormat = createFormat({prefix: "M", width: 2, zeropad: true, decimals: 0});
var tFormat = createFormat({prefix: "T", width: 1, zeropad: false, decimals: 0});
var pFormat = createFormat({ prefix: "P", zeropad: false, decimals: 0 });
var feedFormat = createFormat({decimals: (unit == MM ? 0 : 1)});
var integerFormat = createFormat({decimals:0});
var dimensionFormatSuffixed = createFormat({decimals: (unit == MM ? 3 : 4), zeropad: false, suffix: (unit == MM ? "mm" : "in")});

var gMotionModal = createModal({force: true}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange: function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19 //Actually unused
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91

var xOutput = createVariable({prefix: "X"}, xFormat);
var yOutput = createVariable({prefix: "Y"}, yFormat);
var zOutput = createVariable({prefix: "Z"}, zFormat);
var feedOutput = createVariable({prefix: "F"}, feedFormat);
var eOutput = createVariable({prefix: "E"}, xyzFormat);  // Extrusion length
var sOutput = createVariable({prefix: "S", force: true}, xyzFormat);  // Parameter temperature or speed
var rOutput = createVariable({prefix: "R", force: true }, xyzFormat);

// Writes the specified block.
function writeBlock() {
  writeWords(arguments);
}

function onOpen() {
  getPrinterGeometry();

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  writeComment("Printer Name: " + getGlobalParameter("printer-name", "Generic"));
  writeComment("Print time: " + xyzFormat.format(printTime) + "s");
  writeComment("Extruder 1 Material used: " + dimensionFormatSuffixed.format(getExtruder(1).extrusionLength));
  writeComment("Extruder 1 Material name: " + getExtruder(1).materialName);
  writeComment("Extruder 1 Filament diameter: " + dimensionFormatSuffixed.format(getExtruder(1).filamentDiameter));
  writeComment("Extruder 1 Nozzle diameter: " + dimensionFormatSuffixed.format(getExtruder(1).nozzleDiameter));
  writeComment("Extruder 1 offset x: " + dimensionFormatSuffixed.format(extruderOffsets[0][0]));
  writeComment("Extruder 1 offset y: " + dimensionFormatSuffixed.format(extruderOffsets[0][1]));
  writeComment("Extruder 1 offset z: " + dimensionFormatSuffixed.format(extruderOffsets[0][2]));
  writeComment("Max temp: " + integerFormat.format(getExtruder(1).temperature));
  writeComment("Bed temp: " + integerFormat.format(bedTemp));
  writeComment("Layer Count: " + integerFormat.format(layerCount));

  if (hasGlobalParameter("ext2-extrusion-len") &&
  hasGlobalParameter("ext2-nozzle-dia") &&
  hasGlobalParameter("ext2-temp") && hasGlobalParameter("ext2-filament-dia") &&
  hasGlobalParameter("ext2-material-name")
) {
  writeComment("Extruder 2 material used: " + dimensionFormatSuffixed.format(getExtruder(2).extrusionLength));
  writeComment("Extruder 2 material name: " + getExtruder(2).materialName);
  writeComment("Extruder 2 filament diameter: " + dimensionFormatSuffixed.format(getExtruder(2).filamentDiameter));
  writeComment("Extruder 2 nozzle diameter: " + dimensionFormatSuffixed.format(getExtruder(2).nozzleDiameter));
  writeComment("Extruder 2 max temp: " + integerFormat.format(getExtruder(2).temperature));
  writeComment("Extruder 2 offset x: " + dimensionFormatSuffixed.format(extruderOffsets[1][0]));
  writeComment("Extruder 2 offset y: " + dimensionFormatSuffixed.format(extruderOffsets[1][1]));
  writeComment("Extruder 2 offset z: " + dimensionFormatSuffixed.format(extruderOffsets[1][2]));
}

writeComment("width: " + dimensionFormatSuffixed.format(printerLimits.x.max));
writeComment("depth: " + dimensionFormatSuffixed.format(printerLimits.y.max));
writeComment("height: " + dimensionFormatSuffixed.format(printerLimits.z.max));
writeComment("center x: " + dimensionFormatSuffixed.format(bedCenter.x));
writeComment("center y: " + dimensionFormatSuffixed.format(bedCenter.y));
writeComment("center z: " + dimensionFormatSuffixed.format(bedCenter.z));
writeComment("Count of bodies: " + integerFormat.format(partCount));
writeComment("Version of Fusion: " + getGlobalParameter("version"));
}

function getPrinterGeometry() {
machineConfiguration = getMachineConfiguration();

// Get the printer geometry from the machine configuration
printerLimits.x.min = 0;
printerLimits.y.min = 0;
printerLimits.z.min = 0;
printerLimits.x.max = machineConfiguration.getWidth();
printerLimits.y.max = machineConfiguration.getDepth();
printerLimits.z.max = machineConfiguration.getHeight();

if (machineConfiguration.hasCenterPosition()) {
  bedCenter.x = machineConfiguration.getCenterPositionX();
  bedCenter.y = machineConfiguration.getCenterPositionY();
  bedCenter.z = machineConfiguration.getCenterPositionZ();
} else {
  bedCenter.x = printerLimits.x.max / 2;
  bedCenter.y = printerLimits.y.max / 2;
  bedCenter.z = printerLimits.x.max / 2;
}

extruderOffsets[0][0] = machineConfiguration.getExtruderOffsetX(1);
extruderOffsets[0][1] = machineConfiguration.getExtruderOffsetY(1);
extruderOffsets[0][2] = machineConfiguration.getExtruderOffsetZ(1);
if (numberOfExtruders > 1) {
  extruderOffsets[1] = [];
  extruderOffsets[1][0] = machineConfiguration.getExtruderOffsetX(2);
  extruderOffsets[1][1] = machineConfiguration.getExtruderOffsetY(2);
  extruderOffsets[1][2] = machineConfiguration.getExtruderOffsetZ(2);
}

//Adjust the limits depending on the bed center
if (bedCenter.x == 0 && bedCenter.y == 0) {
  printerLimits.x.min = -machineConfiguration.getWidth() / 2;
  printerLimits.y.min = -machineConfiguration.getDepth() / 2;
  printerLimits.z.min = 0;
  printerLimits.x.max = machineConfiguration.getWidth() / 2;
  printerLimits.y.max = machineConfiguration.getDepth() / 2;
  printerLimits.z.max = machineConfiguration.getHeight();
}

if (bedCenter.z > 0) {printerLimits.z.min += bedCenter.z;}
}

function onClose() {
  writeComment("END OF GCODE");
}

function onComment(message) {
  writeComment(message);
}

function onSection() {
  var range = currentSection.getBoundingBox();
  axes = ["x", "y", "z"];
  formats = [xFormat, yFormat, zFormat];
  for (var element in axes) {
    var min = formats[element].getResultingValue(range.lower[axes[element]]);
    var max = formats[element].getResultingValue(range.upper[axes[element]]);
    if (printerLimits[axes[element]].max < max || printerLimits[axes[element]].min > min) {
      error(localize("A toolpath is outside of the build volume."));
    }
  }

  // set unit
  switch (unit) {
  case IN:
    writeBlock(gFormat.format(20));
    break;
  case MM:
    writeBlock(gFormat.format(21));
    break;
  }
  writeBlock(gAbsIncModal.format(90)); // absolute spatial co-ordinates
  writeBlock(mFormat.format(82)); // absolute extrusion co-ordinates

  //homing
  writeRetract(Z); // retract in Z

  //lower build plate before homing in XY
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  writeBlock(gMotionModal.format(1), zOutput.format(initialPosition.z), feedOutput.format(highFeedRate));

  // home XY
  writeRetract(X, Y);
  writeBlock(gFormat.format(92), eOutput.format(0));
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    writeBlock(gMotionModal.format(0), x, y, z);
  }
}

function onLinearExtrude(_x, _y, _z, _f, _e) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(_f);
  var e = eOutput.format(_e);
  if (x || y || z || f || e) {
    writeBlock(gMotionModal.format(1), x, y, z, f, e);
  }
}

function onBedTemp(temp, wait) {
  if (wait) {
    writeBlock(mFormat.format(190), sOutput.format(temp));
  } else {
    writeBlock(mFormat.format(140), sOutput.format(temp));
  }
}

function onExtruderChange(id) {
  if (id < numberOfExtruders) {
    writeBlock(tFormat.format(id));
    activeExtruder = id;
    xOutput.reset();
    yOutput.reset();
    zOutput.reset();
  } else {
    error(localize("This printer doesn't support the extruder " + xyzFormat.format(id) + " !"));
  }

}

function onExtrusionReset(length) {
  eOutput.reset();
  writeBlock(gFormat.format(92), eOutput.format(length));
}

function onLayer(num) {
  writeComment("Layer : " + integerFormat.format(num) + " of " + integerFormat.format(layerCount));
}

function onExtruderTemp(temp, wait, id) {
  if (id < numberOfExtruders) {
    if (wait) {
      writeBlock(mFormat.format(109), sOutput.format(temp), tFormat.format(id));
    } else {
      writeBlock(mFormat.format(104), sOutput.format(temp), tFormat.format(id));
    }
  } else {
    error(localize("This printer doesn't support the extruder " + xyzFormat.format(id) + " !"));
  }
}

function onFanSpeed(speed, id) {
   // to do handle id information 
  if (speed == 0) {
    writeBlock(mFormat.format(107));
  } else {
    writeBlock(mFormat.format(106), sOutput.format(speed));
  }
}

function onParameter(name, value) {
  switch (name) {
  //feedrate is set before rapid moves and extruder change
  case "feedRate":
    setFeedRate(value);
    break;
  case "onPrime":
    prime(value);
    break;
      //warning or error message on unhandled parameter?
  }
}

//user defined functions
function setFeedRate(value) {
  feedOutput.reset();
  writeBlock(gFormat.format(1), feedOutput.format(value));
}

function writeComment(text) {
  writeln(";" + text);
}

function writeCustomCommand(text) {
  if (text.length > 0) {
    writeln(text);
  }
}

/** Output block to do safe retract and/or move to home position. */
function writeRetract() {
  if (arguments.length == 0) {
    error(localize("No axis specified for writeRetract()."));
    return;
  }
  var words = []; // store all retracted axes in an array
  for (var i = 0; i < arguments.length; ++i) {
    let instances = 0; // checks for duplicate retract calls
    for (var j = 0; j < arguments.length; ++j) {
      if (arguments[i] == arguments[j]) {
        ++instances;
      }
    }
    if (instances > 1) { // error if there are multiple retract calls for the same axis
      error(localize("Cannot retract the same axis twice in one line"));
      return;
    }
    switch (arguments[i]) {
    case X:
      words.push("X" + xyzFormat.format(machineConfiguration.hasHomePositionX() ? machineConfiguration.getHomePositionX() : 0));
      xOutput.reset();
      break;
    case Y:
      words.push("Y" + xyzFormat.format(machineConfiguration.hasHomePositionY() ? machineConfiguration.getHomePositionY() : 0));
      yOutput.reset();
      break;
    case Z:
      words.push("Z" + xyzFormat.format(0));
      zOutput.reset();
      retracted = true; // specifies that the tool has been retracted to the safe plane
      break;
    default:
      error(localize("Bad axis specified for writeRetract()."));
      return;
    }
  }
  if (words.length > 0) {
    gMotionModal.reset();
    writeBlock(gFormat.format(28), gAbsIncModal.format(90), words); // retract
  }
}

function prime(value) {

  var edgeClearance = 3; //This is just a default value.
  var x = edgeClearance - extruderOffsets[activeExtruder][0];
  var y = activeExtruder == 0 ? edgeClearance : 2 * edgeClearance;
  var z0 = 0.3; //First Layerthickness would be better
  var z1 = 20;
  var definedFeedRate = 1080;

  writeComment("Start of Prime");

  setFeedRate(highFeedRate);
  onRapid(x, y, z1);
  onRapid(x, y, z0);

  var tmpExtrusionLength = extrusionLength;
  x = printerLimits.x.max - edgeClearance;

  extrusionLength += value * x;
  var feedRate = definedFeedRate;
  onLinearExtrude(x, y, z0, feedRate, extrusionLength);
  setFeedRate(highFeedRate);
  onRapid(x, y, z1);
  onExtrusionReset(tmpExtrusionLength);
  extrusionLength = tmpExtrusionLength;
  writeComment("End of Prime");
}

function getGlobalParameterSafe(key, defaultValue) {
  if (hasGlobalParameter(key)) {
    return getGlobalParameter(key);
  } else {
    return defaultValue;
  }
}