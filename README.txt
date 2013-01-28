ManetLab
--------

A simple testbed for mobile adhoc networks.



Version:
--------

1.0
Check http://doplab.unil.ch/manetlab for latest version.

Binary:
-------

A Binary version is also available at http://doplab.unil.ch/manetlab.

Requirements:
-------------

- OS X 10.7 or higher
- a wired interface
- wireless interface

Dependencies:
-------------

- MacMapKit (http://github.com/Oomph/MacMapKit)

Content:
--------

- MLBasePlugin:			Plugin with probabilistic algorithms for MANETs
- ManetLabFramework:		Core of ManetLab
- ManetLabPrefs:		System Preferences tab of ManetLab
- MyFirstManetLabPlugin:	Tutorial to create your own plugin
- mlcontroller:			ManetLab controller GUI app
- mllauncherd:			ManetLab daemon

Installation:
-------------

Compile the sources with Xcode and move the built product to the following paths:

mllauncherd: 		/usr/local/libexec
ManetLabFramework: 	/Library/Frameworks
ManetLabPrefs: 		/Library/Preferences
mlcontroller: 		/Applications
MLBasePlugin: 		/Library/Application Support/ManetLab/Plugins

Documentation:
--------------

Available on http://doplab.unil.ch/manetlab.

Feedback & bug reports:
-----------------------

Contact francois.vessaz@unil.ch