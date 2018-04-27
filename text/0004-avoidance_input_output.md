  * Start date: 2018-03-26
  * Contributors: Dennis Mannhart <dennis@px4.io>, Martina Rivizzigno <martina@px4.io>, Christoph Tobler <christoph@px4.io>, Lorenz Meier <lorenz@px4.io>
  * Related PR: [trajectory-msg](https://github.com/mavlink/mavlink/pull/856)
 
# Summary

A general message that provides information about the desired kinematics over some time horizon. Independent of the type of vehicle, any avoidance- or trajectory-module can exploit this message to pass kinematic related trajectory
information to the onboard autopilot. 

  
# Motivation

As obstacle-detection and avoidance receive more attention among UAVs, the current lack of a general avoidance interface/protocol becomes a bottleneck in supporting existing avoidance modules. An offboard
avoidance module requires an interface over which it receives or sends trajectory- and obstacle-information. This rcf is about sharing kinematic trajectory information between an offboard module and an onboard 
autopilot that possess a full kinematic control pipeline.

# Detailed Design

The trajectory message should comply with following requirements:
* support a range of trajectory representations
* a well-defined base message that can be extended
* serves as input to and output from any offboard module

```
WORK IN PROGRESS: The definition below will be revisited before this RFC is final
```

The core of the message are five kinematic points in space, which we call `Anchor-Points`. Each `Anchor-Point` consists of an array of 11 elements. The `type`-field defines the interpretation of the 11 indices that 
applies to all 5 `Anchor-Points`. 
The first two suggested types are (to be revised after initial prototyping):

* WAYPOINTS: Each `Anchor-Point` corresponds to a waypoint.
  *	`[0-2]`: position
  * `[3-5]`: velocity
  * `[6-8]`: acceleration
  * `[9]`  : yaw
  * `[10]` : yaw-speed
* BEZIER: `Anchor-Points` serve as spline parameters.
  * `[0-2]`:  bezier point
  * `[3]`: time horizon 
  * `[4]`: yaw
  
The interface does not require to have all 5 `Anchor-Points` active. For instance, a quadratic bezier only requires three `Anchor-Points`, a cubic bezier 4 `Anchor-Points` and a simple velocity setpoint
just the velocity part of the first `Anchor-Point`. The number of active `Anchor-Points` is defined by the field `point_valid`, which is an array of 5 elements. Each index corresponds to one `Anchor-Point` (order is preserved), where
`0` means invalid and  `1` means valid. Any element of an active `Anchor-Point`, which is set to `NAN`, is considered as unused. For instance, a simple velocity setpoint has only the first `Anchor-Point` valid and the indices `[3-5]` set to
a finite number with all other indices set to `NAN`. 

The number of `Anchor-Points` define the reachesness of the trajectory information. The higher the parametrization of the spline, the more kinematic information can be extracted from that spline:
* 2 point-spline provides information up to constant velocity
* 3 point-spline provides information up to constant acceleration
* 4 point-spline provides information up to constant jerk
* 5 point-spline provides information up to constant snap

Most today's onboard autopilots contain a position and velocity controller and therefore 2- and 3 point-spline parametrization contains all the information needed.


## Yaw / yaw-speed 

For some of the vehicles the heading is already predefined (ground vehicle, fixed-wing etc.). In contrast, for multi-rotors the heading can be varied while the kinematic constraints are still satisfied. For these vehicles, the
yaw- and yaw-speed field can be used to specify the heading at a particular location.

### Waypoints

Each waypoint (=`Anchor-Point`) contains a yaw- and yaw-speed field. A fintie yaw-value corresponds to the desired heading at a particular waypoint. A non-finite yaw value means that the heading should be kept. 
If the yaw field is valid, then the yaw-speed field serves as feed-forward term at a particular waypoint. Otherwise it serves as a general yaw-speed demeand. It is to note that the yaw-speed field makes in particular
sense when there is only one `Anchor-Point` valid where the yaw-speed setpoint corresponds to current desired vehcile yaw-speed. This is useful for avoidance systems which provide a new position/velocity and yaw/yaw-speed 
setpoint at each time stamp. 

### Bezier-splines

One kinematic spline provides continuous kinematic state information along some trajectory, which is defined by the bezier points. However, it does not contain any heading information. To overcome this drawback, each bezier point contains
a yaw-field. For the first and last bezier point, the yaw-field is handled the same as for the waypoints. For the other bezier points, the yaw field corresponds to the pose on the trajectory closest to that particular bezier point. The heading in between the
bezier points is not defined by the message and has to be defined by the auto-pilot. It can be anything from simple interpolation to step inputs directly. If the yaw-field is set to NAN, then the demanded heading will be set along the direction of motion. 

# Alternatives

The current trajectory proposal does not deal with orientation. In order to optimize for orientation as well, an alternative is to do the entire trajectory computation on a companion computer and just send 
thrust and angular velocity commands to the autopilot. The advantage of such a control scheme with a fast inner control loop is that the dynamics of the vehicle can be simplifed with angular
velocity and thrust scalar as output. The benefits of such a system are the following:
* more sophisticated trajectory algorithms can be run on companion computer (for instance MPC)
* more optimization toolboxes available on well supported OS's
* the companion MCU can run at low frequency 
* the autopilot controller is very simple with just a rate controller and a mixer

The disadvantage is that the autopilot relies heavily on the companion MCU with almost all flight related responsibilities being moved to the companion controller. This drawback, however, can be overcome by keeping a simple
position/velocity-controller present in the autopilot that will take over once a failure of the companion computer is detected. 

# Unresolved Questions

The number of 5 `Anchor-Points` is a suggestion. The main reason for choosing 5 is because from a computational feasibility point of view, spline parametrization with more than 4 parameters is not very common for the simple reason that it is hard to solve. 
5 `Anchor-Points` provide information up to snap which already exceeds the capacity of most onboard controllers.

# References 
 * [avoidance-proposal](https://docs.google.com/document/d/1BQp1a6yszl9f6LDrxrkKUDDGyXxBs5C86BzvJwVbRrU/edit#heading=h.huol20joi641)
 * [pievewise-bezier-curve](https://users.soe.ucsc.edu/~elkaim/Documents/ChoiBezierChapter.pdf)
 * [curvature-continuous trajectory](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.294.6253&rep=rep1&type=pdf)
 * [trajectory and control with fast inner loop](http://flyingmachinearena.org/wp-content/publications/2011/hehn_dandrea_trajectory_generation_control.pdf)

