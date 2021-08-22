/**
  CC License 2020 by ACME CAD CAM
  3D additive printer post configuration.

  $Revision: 42614 ccbc0b14704b013ada243633a5bc25f45bcb39f5 $
  $Date: 2019-12-20 12:00:51 $

  FORKID {A316FBC4-FA6E-41C5-A347-3D94F72F5D06}
*/

description = 'Reprap and Duet3d Firmware'
vendor = 'ACME CAD CAM'
vendorUrl = 'http://acmecadcam.com'
legal = 'Attribution-NonCommercial-ShareAlike 4.0 International'
certificationLevel = 2
minimumRevision = 45633

longDescription =
  'Simple post to export toolpath for Duet3D machines in reprap firmware gcode format'

extension = 'gcode'
setCodePage('ascii')

capabilities = CAPABILITY_ADDITIVE
tolerance = spatial(0.002, MM)
highFeedrate = unit == MM ? 6000 : 236
minimumChordLength = spatial(0.25, MM)
minimumCircularRadius = spatial(0.4, MM)
maximumCircularRadius = spatial(1000, MM)
minimumCircularSweep = toRad(0.01)
maximumCircularSweep = toRad(180)
allowHelicalMoves = false // disable helical support
allowSpiralMoves = false // disable spiral support
allowedCircularPlanes = 1 << PLANE_XY // allow XY circular motion

// User-defined properties
properties = {
  // REPRAP firmware workaround features
  standbyTemp: {
    title: 'Standby Temp',
    description: 'Specifies the standby temperature for extruders',
    type: 'number',
    value: 100,
    group: 'reprapSettings'
  },
  toolOverride: {
    title: 'Tool 0 Override',
    description: 'Override the primary tool with a specific ( Set tool 0 - 3)',
    type: 'number',
    value: 0,
    group: 'reprapSettings'
  },

  // temperature tower features
  _trigger: {
    title: 'Trigger',
    description:
      'Specifies whether to use the Z-height or layer number as the trigger to change temperature of the active Extruder.',
    type: 'enum',
    values: [
      { title: 'Disabled', id: 'disabled' },
      { title: 'by Height', id: 'height' },
      { title: 'by Layer', id: 'layer' }
    ],
    value: 'disabled',
    scope: 'post',
    group: 'temperatureTower'
  },
  _triggerValue: {
    title: 'Trigger Value',
    description:
      'This number specifies either the Z-height or the layer number increment on when a change should be triggered.',
    type: 'number',
    value: 10,
    scope: 'post',
    group: 'temperatureTower'
  },
  tempStart: {
    title: 'Start Temperature',
    description:
      'Specifies the starting temperature for the active Extruder (degrees C). Note that the temperature specified in the print settings will be overridden by this value.',
    type: 'integer',
    value: 190,
    scope: 'post',
    group: 'temperatureTower'
  },
  tempInterval: {
    title: 'Temperature Interval',
    description:
      'Every step, increase the temperature of the active Extruder by this amount (degrees C).',
    type: 'integer',
    value: 5,
    scope: 'post',
    group: 'temperatureTower'
  }
}

// Post property group
groupDefinitions = {
  reprapSettings: {
    title: 'REPRAP Settings',
    description: 'Settings to specific functions for REPRAP firmware printers',
    collapsed: false,
    order: 0
  },
  temperatureTower: {
    title: 'Temperature Tower',
    description:
      'Temperature Towers are used to test new filaments in order to identify the best printing temperature. ' +
      'When utilized, this functionality generates a Gcode file where the temperature increases by a set amount, every step in height or layer number.',
    collapsed: true,
    order: 0
  }
}

// needed for range checking, will be effectively passed from Fusion
var printerLimits = {
  x: { min: 0, max: 300.0 }, //Defines the x bed size
  y: { min: 0, max: 300.0 }, //Defines the y bed size
  z: { min: 0, max: 300.0 } //Defines the z bed size
}

// User-defined property definitions
/* propertyDefinitions = {
  standbyTemp: {
    title: 'Standby Temp',
    description: 'Specifies the standby temperature for extruders',
    type: 'number'
  },
  toolOverride: {
    title: 'Tool 0 Override',
    description: 'Override the primary tool with a specific ( Set tool 0 - 3)',
    type: 'number'
  }
} */

// Workaround properties
var extruderOffsets = [
  [0, 0, 0],
  [0, 0, 0]
]
var activeExtruder = 0 // Track the active extruder

var totalFilament = 0 // Track the total filament

var zHolder = 0
var layerOneHeight = 0
var layerTwoHeight = 0
var layerAllHeight = 0

var xyzFormat = createFormat({ decimals: unit == MM ? 3 : 4 })
var xFormat = createFormat({ decimals: unit == MM ? 3 : 4 })
var yFormat = createFormat({ decimals: unit == MM ? 3 : 4 })
var zFormat = createFormat({ decimals: unit == MM ? 3 : 4 })
var gFormat = createFormat({
  prefix: 'G',
  width: 1,
  zeropad: false,
  decimals: 0
})
var mFormat = createFormat({
  prefix: 'M',
  width: 2,
  zeropad: true,
  decimals: 0
})
var tFormat = createFormat({
  prefix: 'T',
  width: 1,
  zeropad: false,
  decimals: 0
})
var pFormat = createFormat({
  prefix: 'P',
  zeropad: false,
  decimals: 0
})
var feedFormat = createFormat({ decimals: unit == MM ? 0 : 1 })
var heightFormat = createFormat({ decimals: 2 })
var integerFormat = createFormat({ decimals: 0 })
var dimensionFormat = createFormat({
  decimals: unit == MM ? 3 : 4,
  zeropad: false,
  suffix: unit == MM ? 'mm' : 'in'
})

var gMotionModal = createModal(
  {
    force: true
  },
  gFormat
) // Modal group 1 // G0-G3, ...
var gPlaneModal = createModal(
  {
    onchange: function () {
      gMotionModal.reset()
    }
  },
  gFormat
) // Modal group 2 // G17-19 //Actually unused
var gAbsIncModal = createModal({}, gFormat) // Modal group 3 // G90-91

var xOutput = createVariable({ prefix: 'X' }, xFormat)
var yOutput = createVariable({ prefix: 'Y' }, yFormat)
var zOutput = createVariable({ prefix: 'Z' }, zFormat)
var feedOutput = createVariable({ prefix: 'F' }, feedFormat)
var eOutput = createVariable({ prefix: 'E' }, xyzFormat) // Extrusion length
var sOutput = createVariable({ prefix: 'S', force: true }, xyzFormat) // Parameter temperature or speed
var rOutput = createVariable({ prefix: 'R', force: true }, xyzFormat)
var iOutput = createReferenceVariable({ prefix: 'I', force: true }, xyzFormat) // circular output
var jOutput = createReferenceVariable({ prefix: 'J', force: true }, xyzFormat) // circular output

// generic functions

// writes the specified block.
function writeBlock () {
  writeWords(arguments)
}

function writeComment (text) {
  writeln(';' + text)
}

function setFeedRate (value) {
  feedOutput.reset()
  writeBlock(gFormat.format(1), feedOutput.format(value))
}

function forceXYZE () {
  xOutput.reset()
  yOutput.reset()
  zOutput.reset()
  eOutput.reset()
}

// Write G-code pass through custom commands
function writeCustomCommand (text) {
  if (text.length > 0) {
    writeln(text)
  }
}

// Start G-codes
function onOpen () {
  getPrinterGeometry()

  if (programName) {
    writeComment(programName)
  }
  if (programComment) {
    writeComment(programComment)
  }

  var pad = function (num, size) {
      return ('000' + num).slice(size * -1)
    },
    // Time calculation
    time = parseFloat(printTime).toFixed(3),
    hours = Math.floor(time / 60 / 60),
    minutes = Math.floor(time / 60) % 60,
    seconds = Math.floor(time - minutes * 60),
    pTime =
      pad(hours, 2) +
      ' hours ' +
      pad(minutes, 2) +
      ' minutes ' +
      pad(seconds, 2) +
      ' seconds'

  // Write Job info
  writeComment('Build time: ' + pTime)
  writeComment('G-code generated on: ' + getGlobalParameter('generated-at'))
  writeComment(
    'G-code generated by Fusion 360 ' + getGlobalParameter('version')
  )
  writeComment('Username: ' + getGlobalParameter('username'))
  writeComment('Layer count: ' + getGlobalParameter('layer-cnt'))
  writeComment('Number of bodies: ' + integerFormat.format(partCount))
  writeComment(
    'Extruder 1 Material used: ' +
      dimensionFormat.format(getExtruder(1).extrusionLength)
  )

  totalFilament = totalFilament + getExtruder(1).extrusionLength

  writeComment('Extruder 1 Material name: ' + getExtruder(1).materialName)
  writeComment(
    'Extruder 1 Filament diameter: ' +
      dimensionFormat.format(getExtruder(1).filamentDiameter)
  )
  writeComment(
    'Extruder 1 Nozzle diameter: ' +
      dimensionFormat.format(getExtruder(1).nozzleDiameter)
  )
  writeComment(
    'Extruder 1 offset x: ' + dimensionFormat.format(extruderOffsets[0][0])
  )
  writeComment(
    'Extruder 1 offset y: ' + dimensionFormat.format(extruderOffsets[0][1])
  )
  writeComment(
    'Extruder 1 offset z: ' + dimensionFormat.format(extruderOffsets[0][2])
  )

  if (
    hasGlobalParameter('ext2-extrusion-len') &&
    hasGlobalParameter('ext2-nozzle-dia') &&
    hasGlobalParameter('ext2-temp') &&
    hasGlobalParameter('ext2-filament-dia') &&
    hasGlobalParameter('ext2-material-name')
  ) {
    writeComment(
      'Extruder 2 material used: ' +
        dimensionFormat.format(getExtruder(2).extrusionLength)
    )

    totalFilament = totalFilament + getExtruder(2).extrusionLength

    writeComment('Extruder 2 material name: ' + getExtruder(2).materialName)
    writeComment(
      'Extruder 2 filament diameter: ' +
        dimensionFormat.format(getExtruder(2).filamentDiameter)
    )
    writeComment(
      'Extruder 2 nozzle diameter: ' +
        dimensionFormat.format(getExtruder(2).nozzleDiameter)
    )
    writeComment(
      'Extruder 2 max temp: ' + integerFormat.format(getExtruder(2).temperature)
    )
    writeComment(
      'Extruder 2 offset x: ' + dimensionFormat.format(extruderOffsets[1][0])
    )
    writeComment(
      'Extruder 2 offset y: ' + dimensionFormat.format(extruderOffsets[1][1])
    )
    writeComment(
      'Extruder 2 offset z: ' + dimensionFormat.format(extruderOffsets[1][2])
    )
  }
  writeComment('Max temp: ' + integerFormat.format(getExtruder(1).temperature))
  writeComment('Bed temp: ' + integerFormat.format(bedTemp))
  writeComment('Temp Tower mode: ' + properties._trigger)
  writeComment('Tower Z height or Layer value: ' + properties._triggerValue)
  writeComment('Tower start temp: ' + properties.tempStart)
  writeComment('Tower increment: ' + properties.tempInterval)
  writeComment('Standby temp; ' + properties.standbyTemp)
  writeComment('Print volume X: ' + dimensionFormat.format(printerLimits.x.max))
  writeComment('Print volume Y: ' + dimensionFormat.format(printerLimits.y.max))
  writeComment('Print volume Z: ' + dimensionFormat.format(printerLimits.z.max))
}

function onSection () {
  var range = currentSection.getBoundingBox()
  axes = ['x', 'y', 'z']
  formats = [xFormat, yFormat, zFormat]
  for (var element in axes) {
    var min = formats[element].getResultingValue(range.lower[axes[element]])
    var max = formats[element].getResultingValue(range.upper[axes[element]])
    if (
      printerLimits[axes[element]].max < max ||
      printerLimits[axes[element]].min > min
    ) {
      error(localize('A toolpath is outside of the build volume.'))
    }
  }

  // Set unit
  switch (unit) {
    case IN:
      writeBlock(gFormat.format(20) + ' ; Use inches')
      break
    case MM:
      writeBlock(gFormat.format(21) + ' ; Use mm')
      break
  }
  writeBlock(gAbsIncModal.format(90)) // Absolute spatial co-ordinates
  writeBlock(mFormat.format(82)) // Absolute extrusion co-ordinates

  // homing
  writeRetract(Z) // retract in Z

  // lower build plate before homing in XY
  feedOutput.reset()
  var initialPosition = getFramePosition(currentSection.getInitialPosition())
  writeBlock(
    gMotionModal.format(1),
    zOutput.format(initialPosition.z),
    feedOutput.format(toPreciseUnit(highFeedrate, MM))
  )

  // home XY
  writeRetract(X, Y)
  writeBlock(gFormat.format(92), eOutput.format(0))
  forceXYZE()
}

/** output block to do safe retract and/or move to home position. */
function writeRetract () {
  if (arguments.length == 0) {
    error(localize('No axis specified for writeRetract().'))
    return
  }
  var words = [] // store all retracted axes in an array
  for (var i = 0; i < arguments.length; ++i) {
    let instances = 0 // checks for duplicate retract calls
    for (var j = 0; j < arguments.length; ++j) {
      if (arguments[i] == arguments[j]) {
        ++instances
      }
    }
    if (instances > 1) {
      // error if there are multiple retract calls for the same axis
      error(localize('Cannot retract the same axis twice in one line'))
      return
    }
    switch (arguments[i]) {
      case X:
        words.push(
          'X' +
            xyzFormat.format(
              machineConfiguration.hasHomePositionX()
                ? machineConfiguration.getHomePositionX()
                : 0
            )
        )
        xOutput.reset()
        break
      case Y:
        words.push(
          'Y' +
            xyzFormat.format(
              machineConfiguration.hasHomePositionY()
                ? machineConfiguration.getHomePositionY()
                : 0
            )
        )
        yOutput.reset()
        break
      case Z:
        words.push('Z' + xyzFormat.format(0))
        zOutput.reset()
        retracted = true // specifies that the tool has been retracted to the safe plane
        break
      default:
        error(localize('Bad axis specified for writeRetract().'))
        return
    }
  }
  if (words.length > 0) {
    gMotionModal.reset()
    writeBlock(gFormat.format(28), gAbsIncModal.format(90), words) // retract
  }
}

// End G-codes
function onClose () {
  writeBlock(tFormat.format(-1) + ' ; Drop tool off')
  writeBlock(mFormat.format(400) + ' ; Clear move buffer')
  writeBlock(mFormat.format(117) + ' PRINT FINISHED')
  writeBlock('M0 ; All heaters off')
  writeComment('END OF GCODE')
  writeComment('--------------------------------')
  writeComment('Print Statistics')
  writeComment('--------------------------------')
  writeComment('Fist Layer height: ' + layerOneHeight)
  writeComment('Layer height: ' + layerAllHeight)
  writeComment('Layer count: ' + getGlobalParameter('layer-cnt'))
  writeComment('Filament length: ' + dimensionFormat.format(totalFilament))
}

function getPrinterGeometry () {
  machineConfiguration = getMachineConfiguration()

  // Get the printer geometry from the machine configuration
  printerLimits.x.min = 0 - machineConfiguration.getCenterPositionX()
  printerLimits.y.min = 0 - machineConfiguration.getCenterPositionY()
  printerLimits.z.min = 0 + machineConfiguration.getCenterPositionZ()

  printerLimits.x.max =
    machineConfiguration.getWidth() - machineConfiguration.getCenterPositionX()
  printerLimits.y.max =
    machineConfiguration.getDepth() - machineConfiguration.getCenterPositionY()
  printerLimits.z.max =
    machineConfiguration.getHeight() + machineConfiguration.getCenterPositionZ()

  extruderOffsets[0][0] = machineConfiguration.getExtruderOffsetX(1)
  extruderOffsets[0][1] = machineConfiguration.getExtruderOffsetY(1)
  extruderOffsets[0][2] = machineConfiguration.getExtruderOffsetZ(1)
  if (numberOfExtruders > 1) {
    extruderOffsets[1] = []
    extruderOffsets[1][0] = machineConfiguration.getExtruderOffsetX(2)
    extruderOffsets[1][1] = machineConfiguration.getExtruderOffsetY(2)
    extruderOffsets[1][2] = machineConfiguration.getExtruderOffsetZ(2)
  }
}

function onRapid (_x, _y, _z) {
  var x = xOutput.format(_x)
  var y = yOutput.format(_y)
  var z = zOutput.format(_z)
  zHolder = _z
  if (x || y || z) {
    writeBlock(gMotionModal.format(0), x, y, z)
  }
}

function onLinearExtrude (_x, _y, _z, _f, _e) {
  var x = xOutput.format(_x)
  var y = yOutput.format(_y)
  var z = zOutput.format(_z)
  var f = feedOutput.format(_f)
  var e = eOutput.format(_e)
  if (x || y || z || f || e) {
    writeBlock(gMotionModal.format(1), x, y, z, f, e)
  }
}

function onCircularExtrude (_clockwise, _cx, _cy, _cz, _x, _y, _z, _f, _e) {
  var x = xOutput.format(_x)
  var y = yOutput.format(_y)
  var z = zOutput.format(_z)
  var f = feedOutput.format(_f)
  var e = eOutput.format(_e)
  var start = getCurrentPosition()
  var i = iOutput.format(_cx - start.x, 0)
  var j = jOutput.format(_cy - start.y, 0)

  switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(_clockwise ? 2 : 3), x, y, i, j, f, e)
      break
    default:
      linearize(tolerance)
  }
}

function onBedTemp (temp, wait) {
  if (wait) {
    writeBlock(mFormat.format(190), sOutput.format(temp) + ' ; DELETE ME')
  } else {
    writeBlock(mFormat.format(140), sOutput.format(temp))
  }
}

function onExtruderChange (id) {
  if (id < numberOfExtruders) {
    writeBlock(tFormat.format(id) + ' ; Us tool ' + id)
    activeExtruder = id
    xOutput.reset()
    yOutput.reset()
    zOutput.reset()
    writeBlock(gFormat.format(29) + ' S1')
  } else {
    error(
      localize("This printer doesn't support the extruder ") +
        integerFormat.format(id) +
        ' !'
    )
  }
}

function onExtrusionReset (length) {
  eOutput.reset()
  writeBlock(gFormat.format(92), eOutput.format(length))
}

function onLayer (num) {
  if (num == 2) {
    layerOneHeight = heightFormat.format(zHolder)
  }

  if (num == 3) {
    layerTwoHeight = heightFormat.format(zHolder)
    layerAllHeight = layerTwoHeight - layerOneHeight
  }

  executeTempTowerFeatures(num)

  writeComment(
    'Layer : ' +
      integerFormat.format(num) +
      ' of ' +
      integerFormat.format(layerCount)
  )
}

function onExtruderTemp (temp, wait, id) {
  if (getProperty('_trigger') != 'disabled' && getCurrentPosition().z == 0) {
    temp = getProperty('tempStart') // override temperature with the starting temperature for the temp tower feature
  }
  if (id < numberOfExtruders) {
    if (id == 0) {
      id = properties.toolOverride
      if (wait) {
        writeBlock(
          gFormat.format(10),
          pFormat.format(id),
          sOutput.format(temp),
          rOutput.format(properties.standbyTemp)
        )
        writeBlock(tFormat.format(id) + ' ; Use Tool ' + id)
        writeBlock(gFormat.format(29) + ' S1')
        writeBlock(mFormat.format(116))
      } else {
        writeBlock(
          gFormat.format(10),
          pFormat.format(id),
          sOutput.format(temp),
          rOutput.format(properties.standbyTemp) + ' ; DELETE ME'
        )
      }
    } else {
    }
  } else {
    error(
      localize("This printer doesn't support the extruder ") +
        integerFormat.format(id) +
        ' !'
    )
  }
}

function onFanSpeed (speed, id) {
  // TODO handle id information
  if (speed == 0) {
    writeBlock(mFormat.format(107) + ' ; Fan off')
  } else {
    writeBlock(mFormat.format(106), sOutput.format(speed) + ' ; Set fan')
  }
}

var nextTriggerValue
var newTemperature
var maximumExtruderTemp = 260
function executeTempTowerFeatures (num) {
  if (getProperty('_trigger') != 'disabled') {
    var multiplier = getProperty('_trigger') == 'height' ? 100 : 1
    var currentValue =
      getProperty('_trigger') == 'height'
        ? xyzFormat.format(getCurrentPosition().z * 100)
        : num - 1
    if (num == 1) {
      // initialize
      nextTriggerValue = getProperty('_triggerValue') * multiplier
      newTemperature = getProperty('tempStart')
    } else {
      if (currentValue >= nextTriggerValue) {
        newTemperature += getProperty('tempInterval')
        nextTriggerValue += getProperty('_triggerValue') * multiplier
        if (newTemperature <= maximumExtruderTemp) {
          onExtruderTemp(newTemperature, false, activeExtruder)
        } else {
          error(
            subst(
              localize(
                "Requested extruder temperature of '%1' exceeds the maximum value of '%2'."
              ),
              newTemperature,
              maximumExtruderTemp
            )
          )
        }
      }
    }
  }
}

function onParameter (name, value) {
  switch (name) {
    // Feedrate is set before rapid moves and extruder change
    case 'feedRate':
      setFeedRate(value)
      break
    case 'customCommand':
      if (value == 'start_gcode') {
        // Anything you want to write before setting temps
        writeBlock(gFormat.format(28) + ' Z ; Probe Z')
      }
      if (value == 'end_gcode') {
        // Anything you want to write before end gcodes
      }
      break
    // Warning or error message on unhandled parameter?
  }
}
