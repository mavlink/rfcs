* Start date: 2018-04-11
* Contributors: Dennis Mannhart <dennis@px4.io>, Martina Rivizzigno <martina@px4.io>, Christoph Tobler <christoph@px.4io>
* Related PR: [avoidance msg](https://github.com/mavlink/mavlink/pull/856#issuecomment-371438983)

# Summary

A general message that provides information about obstacles that are close to the vehicle. Any avoidance- or sensor-module can use this message to send information about obstacles to the autopilot or get information from the autopilot.

# Motivation

Scenarios where this could be useful:

* In the future, the autopilot will have an internal obstacle avoidance that runs after the external avoidance. That means that this internal avoidance needs to have some sort of information about obstacles close-by.
* Trajectory planning/smoothing can use this information to avoid obstacles
* Geofence could use the same representation.
* Sensors attached to the autopilot can provide information for companion computers.
* Sensor drivers could provide this message directly to the autopilot for basic avoidance without having a complex avoidance module.

# Detailed Design

2D/3D PCA as obstacle representation
TBD

# Alternatives

* Polygons
* Voxels

# Unresolved Questions

# References
* [PCA Wikipedia](https://en.wikipedia.org/wiki/Principal_component_analysis)
