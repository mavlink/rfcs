  * Start date: 2018-03-26
  * Contributors: Dennis Mannhart <dennis@px4.io>, Martina Rivizzigno <martina@px4.io>, Christoph Tobler <christoph@px.4io>
  * Related PR: [avoidance-msg](https://github.com/mavlink/mavlink/pull/856)
  * Related document: [avoidance-proposal](https://docs.google.com/document/d/1BQp1a6yszl9f6LDrxrkKUDDGyXxBs5C86BzvJwVbRrU/edit#heading=h.huol20joi641)
  
# Summary

A general message that provides information about the desired kinematics over some time horizon. Any avoidance- or trajectory-module can exploit this message to pass trajectory
information to the autopilot. 

  
# Motivation

As obstacle-detection and avoidance receive more attention among UAVs, the current lack of a general avoidance interface/protocol becomes a bottleneck in supporting existing avoidance modules. An offboard
avoidance module requires an interface over which it receives or sends trajectory- and obstacle-information. This rcf is about sharing trajectory information between the autopilot
and the offboard module.

# Detailed Design

The trajectory message should comply with following requirements:
* support a range of trajectory representations
* a well-defined base message that can be extended
* serves as input to and output from any offboard module

The core of the message are five kinematic points in space, which we call `Anchor-Points`. Each `Anchor-Point` consists of an array of 11 elements. The `type`-field defines the interpretation of the 11 indices that 
applies to all 5 `Anchor-Points`. 
The first two suggested types are:
* WAYPOINTS: Each `Anchor-Point` corresponds to a waypoint.
  *	`[0-2]`: position
  * `[3-5]`: velocity
  * `[6-8]`: acceleration
  * `[9]`  : yaw
  * `[10]` : yaw-speed
* BEZIER: `Anchor-Points` serve as spline parameters.
  * `[0-2]`:  Bezier point
  * `[3]`: Time horizon 
  
The interface does not require to have all 5 `Anchor-Points` active. For instance, a quadratic bezier only requires three `Anchor-Points`, a cubic bezier 4 `Anchor-Points` and a simple velocity setpoint
just the velocity part of the first `Anchor-Point`. The number of active `Anchor-Points` is defined by the field `point_valid`, which is an array of 5 elements. Each index corresponds to one `Anchor-Point` (order is preserved), where
`0` means invalid and  `1` means valid. Any element of an active `Anchor-Point`, which is set to `NAN`, is considered as unused. For instance, a simple velocity setpoint has only the first `Anchor-Point` valid and the indices `[3-5]` set to
a finite number with all other indices set to `NAN`. 

# Unresolved Questions

The number of 5 `Anchor-Points` is a suggestion. The main reason for choosing 5 is because from a computational feasibility point of view, spline parametrization with more than 4 parameters is not very common for the simple reason that it is hard to solve. 5 `Anchor-Point` can be mapped
to a range of different spline parametrization.

