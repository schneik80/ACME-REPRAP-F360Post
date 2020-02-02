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
minimumRevision = 45266;

longDescription = " Fusion 360 Post for Duet FFF cartesian printers.";

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_ADDITIVE;
tolerance = spatial(0.002, MM);
highFeedRate = toPreciseUnit(6000, MM);

var bedCenter = {
  x: 502.5,
  y: 502.5,
  z: 0.0
};

//Printer limits as variable as they will be overriden by properties in onOpen
var printerLimits = {
  x: {min: 0, max: 300.0}, //Defines the x bed size
  y: {min: 0, max: 300.0}, //Defines the y bed size
  z: {min: 0, max: 300.0} //Defines the z bed size
};

var extruderOffsets = [[0, 0, 0], [0, 0, 0]];

var xyzFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var xFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var yFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var zFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var gFormat = createFormat({prefix: "G", width: 1, zeropad: false, decimals: 0});
var mFormat = createFormat({prefix: "M", width: 2, zeropad: true, decimals: 0});
var tFormat = createFormat({prefix: "T", width: 1, zeropad: false, decimals: 0});
var pFormat = createFormat({ prefix: "P", zeropad: false, decimals: 0 });
var feedFormat = createFormat({decimals: (unit == MM ? 0 : 1)});

var gMotionModal = createModal({force: true}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange: function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91

var xOutput = createVariable({prefix: "X"}, xFormat);
var yOutput = createVariable({prefix: "Y"}, yFormat);
var zOutput = createVariable({prefix: "Z"}, zFormat);
var feedOutput = createVariable({prefix: "F"}, feedFormat);
var eOutput = createVariable({prefix: "E"}, xyzFormat);
var sOutput = createVariable({prefix: "S", force: true}, xyzFormat);
var rOutput = createVariable({prefix: "R", force: true }, xyzFormat);

var activeExtruder = 0;
var extrusionLength = 0;

/**
  Writes the specified block.
*/
function writeBlock() {
  writeWords(arguments);
}

function onOpen() {

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  printerLimits.x.max = parseFloat(getGlobalParameterSafe("machine-width", "0"));
  printerLimits.y.max = parseFloat(getGlobalParameterSafe("machine-depth", "0"));
  printerLimits.z.max = parseFloat(getGlobalParameterSafe("machine-height", "0"));

  bedCenter.x = parseFloat(getGlobalParameterSafe("bed-center-x", "0"));
  bedCenter.y = parseFloat(getGlobalParameterSafe("bed-center-y", "0"));
  bedCenter.z = parseFloat(getGlobalParameterSafe("bed-center-z", "0"));

  extruderOffsets[0][0] = parseFloat(getGlobalParameterSafe("ext1-offset-x", 0));
  extruderOffsets[0][1] = parseFloat(getGlobalParameterSafe("ext1-offset-y", 0));
  extruderOffsets[0][2] = parseFloat(getGlobalParameterSafe("ext1-offset-z", 0));

  writeComment("Printer Name: " + getGlobalParameterSafe("printer-name", "Generic"));
  writeComment("Print time: " + getGlobalParameterSafe("print-time", "0") + "s");
  writeComment("Extruder 1 Material used: " + getGlobalParameterSafe("ext1-extrusion-len", "0"));
  writeComment("Extruder 1 Material name: " + getGlobalParameterSafe("ext1-material-name", "PLA"));
  writeComment("Extruder 1 Filament diameter: " + getGlobalParameterSafe("ext1-filament-dia", "1.75") + "mm");
  writeComment("Extruder 1 Nozzle diameter: " + getGlobalParameterSafe("ext1-nozzle-dia", "0.4"));
  writeComment("Extruder 1 offset x: " + getGlobalParameterSafe("ext1-offset-x", "0"));
  writeComment("Extruder 1 offset y: " + getGlobalParameterSafe("ext1-offset-y", "0"));
  writeComment("Extruder 1 offset z: " + getGlobalParameterSafe("ext1-offset-z", "0"));
  writeComment("Max temp: " + getGlobalParameterSafe("ext1-temp", "0"));
  writeComment("Bed temp: " + getGlobalParameterSafe("bed-temp", "0"));
  writeComment("Layer Count: " + getGlobalParameterSafe("layer-cnt", "0"));

  if (hasGlobalParameter("ext2-extrusion-len") &&
    hasGlobalParameter("ext2-nozzle-dia") &&
    hasGlobalParameter("ext2-temp") && hasGlobalParameter("ext2-filament-dia") &&
    hasGlobalParameter("ext2-material-name") &&
    hasGlobalParameter("ext2-extrusion-len")
  ) {
    writeComment("Extruder 2 material used: " + getGlobalParameterSafe("ext2-extrusion-len", "0"));
    writeComment("Extruder 2 material name: " + getGlobalParameterSafe("ext2-material-name", ""));
    writeComment("Extruder 2 filament diameter: " + getGlobalParameterSafe("ext2-filament-dia", "0"));
    writeComment("Extruder 2 nozzle diameter: " + getGlobalParameterSafe("ext2-nozzle-dia", "0.4"));
    writeComment("Extruder 2 max temp: " + getGlobalParameterSafe("ext2-temp", "0"));
    writeComment("Extruder 2 offset x: " + getGlobalParameterSafe("ext2-offset-x", "0"));
    writeComment("Extruder 2 offset y: " + getGlobalParameterSafe("ext2-offset-y", "0"));
    writeComment("Extruder 2 offset z: " + getGlobalParameterSafe("ext2-offset-z", "0"));
    extruderOffsets[1] = [];
    extruderOffsets[1][0] = parseFloat(getGlobalParameterSafe("ext2-offset-x", 0));
    extruderOffsets[1][1] = parseFloat(getGlobalParameterSafe("ext2-offset-y", 0));
    extruderOffsets[1][2] = parseFloat(getGlobalParameterSafe("ext2-offset-z", 0));
  }
  writeComment("width: " + getGlobalParameterSafe("machine-width", "0"));
  writeComment("depth: " + getGlobalParameterSafe("machine-depth", "0"));
  writeComment("height: " + getGlobalParameterSafe("machine-height", "0"));
  writeComment("center x: " + getGlobalParameterSafe("bed-center-x", "0"));
  writeComment("center y: " + getGlobalParameterSafe("bed-center-y", "0"));
  writeComment("center z: " + getGlobalParameterSafe("bed-center-z", "0"));
  writeComment("Count of bodies: " + getGlobalParameterSafe("cnt-parts", "0"));
  writeComment("Version of Fusion: " + getGlobalParameterSafe("version", "0"));
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
  extrusionLength = _e;
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
  writeBlock(tFormat.format(id));
  activeExtruder = id;
  onExtrusionReset(0);
}

function onExtrusionReset(length) {
  eOutput.reset();
  writeBlock(gFormat.format(92), eOutput.format(length));
}

function onLayer(num) {
  writeComment("Layer: " + num);
}

function onExtruderTemp(temp, wait, id) {
  if (wait) {
    writeBlock(mFormat.format(109), sOutput.format(temp), tFormat.format(id));
  } else {
    writeBlock(mFormat.format(104), sOutput.format(temp), tFormat.format(id));
  }
}

function onFanSpeed(speed, id) {
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
