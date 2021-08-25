# ACME-REPRAP-F360Post

Fusion 360 Post for Duet FFF cartesian printers.

## Features

This Post is used by Fusion 360 to configure how FFF manufacturing setups are exported (posted) to gcode.
It is used to ensure the gcode complies with the Duet line of FFF mainboard's firmware gcode expectations. Posts are Java script document and can be edited using any IDE of your choice.

This post should be able to be used with any Duet/Reprap firmware (2.x/3.x) printer.

Users should ensure that bed size and other options match their printer in their custom machine configuration.

There are two workarounds:

1.  The standby temps are not working with the print settings. The post has a user value that can be used to set standby temps
2.  The standard print setting defaults all primary extrusion to Tool 0. The post workaround allow you to select a different primary tool.

Other special modes are also available.
The post properties enables a special temp tower option that allows you to set start temp, by layer or by height and the the corresponding increment to increase temp. Makes temp towers very easy to setup. These temp values override any temps set in the print settings.

In the print settings, on the gcode tab, you can enable G2 radial moves. Duet hardware has support for true radial moves and this post allows you to turn this on and post as gcode G2 and I J arcs. This is still WIP. Please send issues and suggestions.

## Installation

Download the cps file.
If using Fusion 360 cloud posts. Upload the cps to the post folder in your Team's asset folder. This requires Team Admin privileges.

If using local posts, move this post to your local post directory.

- On Windows this is located in C:\Users\ << Your user >> \AppData\Roaming\Autodesk\Fusion 360 CAM\Posts\
- On MAC OS this is located in ~/Autodesk/Fusion 360 CAM/Posts/
