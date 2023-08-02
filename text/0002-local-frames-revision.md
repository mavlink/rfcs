* Start date: 2018-03-21
* Contributors: Andrei Korigodski <akorigod@gmail.com>, Oleg Kalachev <okalachev@gmail.com>, Hamish Willee <hamishwillee@gmail.com>
* RFC PR: [mavlink/rfcs#2](https://github.com/mavlink/rfcs/pull/2)
* Related issues: [mavlink/mavlink#861](https://github.com/mavlink/mavlink/issues/861)

# Summary

Revise MAVLink local frames of reference to create a clear and comprehensive frames system. Agree on the frames naming convention, add some useful frames and correct the descriptions.

# Motivation

## Importance of an appropriate frames system

Rich enough but clear set of coordinate frames is essential for effective drone control.

For example, let's consider a setup in which a companion computer with a camera is used for navigation by recognizing fiducial markers with known coordinates. The location of the drone is calculated and `VISION_POSITION_ESTIMATE` messages are transmitted.

Different frames of reference are necessary in different cases:

* the camera can be installed externally (e.g. motion capture system) — in this case coordinates are naturally in fixed w.r.t. the Earth NED-oriented frame;
* the camera can be installed on the 2D gimbal, then the origin of the coordinate system should be fixed to the vehicle and yaw orientation should match vehicle yaw;
* the camera can be mounted onboard without gimbal — in this case both the origin and the orientation of the coordinate system should be fixed to the vehicle.

When using such a setup without appropriate frames developers need to receive the attitude information from the vehicle, transform the calculated coordinates using this attitude to supported frame and send it to the vehicle, which complicates the process and lowers the precision as attitude data is available with a certain latency.

The same reasoning is correct for a variety of different cases e.g. following a target which is recognized using computer vision or for creating missions with items such as "fly 10 m forward".

It's also necessary in some cases to have a continuous position, without discrete jumps, like integrated vehicle velocity, which always quite correctly represents vehicle movement in short-term although can drift in long-term. In ROS such a frame is called `odom` [[1]](http://www.ros.org/reps/rep-0105.html).

## Disadvantages of the current frame set

The current frame set is quite obscure, lacks some useful frames and often leads to confusion ([[2]](https://github.com/ArduPilot/ardupilot/issues/2447), [[3]](https://github.com/ArduPilot/ardupilot/issues/4717), [[4]](https://groups.google.com/forum/#!topic/px4users/X9rclmM9AUw)).

Let's check current non-global coordinate frames and their description:

* `MAV_FRAME_LOCAL_NED` — Local coordinate frame, Z-down (x: north, y: east, z: down).
* `MAV_FRAME_LOCAL_ENU` — Local coordinate frame, Z-up (x: east, y: north, z: up).
* `MAV_FRAME_LOCAL_OFFSET_NED` — Offset to the current local frame. Anything expressed in this frame should be added to the current local frame position.
* `MAV_FRAME_BODY_NED` — Setpoint in body NED frame. This makes sense if all position control is externalized - e.g. useful to command 2 m/s^2 acceleration to the right.
* `MAV_FRAME_BODY_OFFSET_NED` — Offset in body NED frame. This makes sense if adding setpoints to the current flight path, to avoid an obstacle - e.g. useful to command 2 m/s^2 acceleration to the east.

The meaning of the first two frames, `MAV_FRAME_LOCAL_NED` and `MAV_FRAME_LOCAL_ENU`, is obvious. The next three are much less clear. First of all, they are defined as "setpoints" or "offsets" instead of frames of reference.

`MAV_FRAME_BODY_NED` description makes clear that it's frame with body orientation (fixed to vehicle): _"e.g. useful to command 2 m/s^2 acceleration to the right"_, however it's name implies it's NED frame, which is confusing. Description of `MAV_FRAME_BODY_OFFSET_NED` makes thing even more complicated because it looks like it's a real NED frame: _"e.g. useful to command 2 m/s^2 acceleration to the east"_.

The only detailed explanation of current local frames meaning is in APM documentation [[5]](http://ardupilot.org/dev/docs/copter-commands-in-guided-mode.html#set-position-target-local-ned). It describes `MAV_FRAME_LOCAL_OFFSET_NED` as vehicle-carried NED frame and `MAV_FRAME_BODY_OFFSET_NED` as vehicle-carried Forward-Right-Down frame which is clear. However, behavior of `MAV_FRAME_BODY_NED` frame is complicated:

_Positions are relative to the vehicle’s home position in the North, East, Down (NED) frame. Use this to specify a position x metres north, y metres east and (-) z metres above the home position. Velocity directions are relative to the current vehicle heading. Use this to specify the speed forward, right and down (or the opposite if you use negative values)._

So the behavior of frames for positions and for velocities is not always the same, which is confusing and should be avoided. The naming pattern is unclear:

* it uses three fields (`LOCAL` or `BODY`, `OFFSET` or not, `NED` or `ENU`) to describe in fact two entities: frame of reference translation (origin) and rotation. Futhermore, rotation is somehow defined by combination of `LOCAL`/`BODY` and `NED`/`ENU` which is excessive;
* `BODY` frames are not always aligned with respect to the vehicle orientation;
* `NED` doesn't really mean anything except direction of z axis, e.g. `MAV_FRAME_BODY_OFFSET_NED` is not NED-oriented.

Both `_OFFSET_` frames are not supported by PX4 firmware at all, while `MAV_FRAME_BODY_NED` is supported only for velocity setpoints (where it acts as Forward-Right-Down oriented frame, not NED).

Furthermore, `MAV_FRAME` enumeration lacks a frame which is fixed in orientation to the moving vehicle. Most similar frame, `MAV_FRAME_BODY_OFFSET_NED`, have only the yaw fixed to the vehicle.

# Detailed Design

## Frames of reference naming

The proposed frames naming convention is:

`MAV_FRAME_origin_rotation[_modifier]`,

where `origin` must be one of the following:

* `LOCAL` for frames with local origin fixed with respect to the Earth;
* `BODY` for frames with origin fixed to the vehicle;

`rotation` must be one of the following:

* `NED` for North-East-Down;
* `ENU` for East-North-Up;
* `FRD` for Forward-Right-Down, where Forward and Right are tangential to the Earth and Down is normal to it;
* `FLU` for Forward-Left-Up, where Forward and Left are tangential to the Earth and Up is normal to it;
* `RPY` for Roll-Pitch-Yaw (fixed in orientation to the moving vehicle, z axis points down when vehicle is leveled, right-handed);

and `modifier` can be one of the following:

* `TERRAIN` for frames with z equal to the terrain altitude, i.e. an altitude estimated using sonar or laser rangefinder. For underwater vehicles it's the negative distance to the surface;
* `ODOM` for frames with continuous position, which always quite correctly represents vehicle movement in short-term although can drift in long-term.

When describing vector values such as velocities, accelerations, forces etc. only the orientation (rotation) of the frame must be taken into account. The norm (length) of the vector is always specified relative to the Earth, and not to the moving frame of reference.

Not all combinations of these designations are proposed to be implemented as part of the current RFC. However, frames of reference named according to proposed convention could be added without separate RFC as pull requests against mavlink/mavlink [[6]](https://github.com/mavlink/mavlink) repository directly.

## Local frames set

Proposed non-global frames are:

* `MAV_FRAME_LOCAL_NED`;
* `MAV_FRAME_LOCAL_NED_ODOM`;
* `MAV_FRAME_LOCAL_ENU`;
* `MAV_FRAME_LOCAL_FRD`;
* `MAV_FRAME_BODY_NED`;
* `MAV_FRAME_BODY_FRD`;
* `MAV_FRAME_BODY_RPY`.

## Implementation

To implement the proposed changes `MAV_FRAME` enumeration shall be extended with the following entries which shall be assigned consecutive integer values:

* `MAV_FRAME_LOCAL_NED_ODOM`;
* `MAV_FRAME_LOCAL_FRD`;
* `MAV_FRAME_BODY_FRD`;
* `MAV_FRAME_BODY_RPY`.

The decriptions shall be updated as follows:

* `MAV_FRAME_LOCAL_OFFSET_NED` and `MAV_FRAME_BODY_OFFSET_NED` shall be marked deprecated;
* `MAV_FRAME_BODY_NED` description shall be aligned with the proposed meaning.

# Drawbacks

* Changes will require corresponding amendments of APM and PX4 firmwares and some other software which is using MAVLink as well as corresponding adjustments of the documentation. However, everything will still work as there will not be introduced any breaking changes in type enumerations. New developers can be confused if frames will behave differently than MAVLink descriptions tell but in fact they are confused now as well because current definitions are obscure anyway. APM docs can be changed simultaneously with the code (and therefore the firmware behavior) so it's not a major problem and it seems like other platforms just don't have any docs on this matter.
* `MAV_FRAME` type enumeration will be extended significantly.
* Naming convention and meaning of existing frame `MAV_FRAME_BODY_NED` will be changed which can cause confusion.
* Name for Forward-Left-Up variant of `MAV_FRAME_LOCAL_RPY` is not proposed.
* `FRD` abbreviation is used in MAVROS to represent a frame which corresponds to `MAV_FRAME_BODY_RPY` (`fcu_frd`).

# Alternatives

* Don't change meaning of the existing frame `MAV_FRAME_BODY_NED`, propose another naming convention instead.
* Drop `LOCAL` for frames with zero in local origin (so `MAV_FRAME_LOCAL_NED` will become `MAV_FRAME_NED`).
* Use `HOR` or `HORIZ` instead of `FRD`.
* Use `RPY_FRD` and `RPY_FLU` to distinguish `RPY` frame axes orientation.
* Use `BODY` instead of `RPY` to describe frames with axes tied to vehicle body. In this case to describe frames with origin fixed to vehicle some other symbol can be used instead of `BODY`. However, there is still need for Forward-Left-Up variant.
* Replace `TERRAIN` modifier with `LOCAL_TERRAIN` and/or `BODY_TERRAIN` frame origin designations.
* Assign large int values (like 50+) to all local `MAV_FRAME`s to prevent mixing of global and local frames in docs and source code. However, `MAV_FRAME_LOCAL_NED`, `MAV_FRAME_LOCAL_ENU` and `MAV_FRAME_BODY_NED` is already assigned with integer values.

# Prior art

## Large aircraft common frames

Common non-global frames ([[7]](http://www.perfectlogic.com/articles/avionics/flightdynamics/flightpart2.html), [[8]](https://www.mathworks.com/help/aeroblks/about-aerospace-coordinate-systems.html)) are:

* Vehicle-carried NED (corresponds to `MAV_FRAME_LOCAL_NED`);
* Velocity-oriented, or wind (with x axis aligned with vehicle velocity);
* Body (corresponds to `MAV_FRAME_BODY_RPY`).

## ROS frames convention

REP-103 [[9]](http://www.ros.org/reps/rep-0103.html) specifies axis orientation. In relation to a body the standard is Forward-Left-Up and for frames fixed w.r.t. the Earth it's East-North-Up.

REP-105 [[1]](http://www.ros.org/reps/rep-0105.html) specifies naming conventions and semantic meaning for coordinate frames of mobile platforms used with ROS. The basic frames are:

* `map` (corresponds to `MAV_FRAME_LOCAL_ENU`);
* `odom` (corresponds to `MAV_FRAME_LOCAL_ENU_ODOM`);
* `base_link` (Forward-Left-Up variant of `MAV_FRAME_LOCAL_RPY`).

## MAVROS frames

MAVROS [[10]](http://wiki.ros.org/mavros) is a ROS package for communication with MAVLink devices. It provides following frames of reference:

* `map` (corresponds to `MAV_FRAME_LOCAL_ENU`);
* `base_link` (Forward-Left-Up variant of `MAV_FRAME_LOCAL_RPY`);
* `fcu_frd` (corresponds to `MAV_FRAME_BODY_RPY`).

## ardrone_autonomy frames

Ardrone_autonomy is a ROS package for AR.Drone control. It provides [[11]](http://ardrone-autonomy.readthedocs.io/en/latest/frames.html) following frames of reference:

* `odom` (corresponds to `MAV_FRAME_LOCAL_ENU_ODOM`);
* `ardrone_base_link` (Forward-Left-Up variant of `MAV_FRAME_LOCAL_RPY`);
* `ardrone_base_frontcam`;
* `ardrone_base_bottomcam`.

## CLEVER drone kit frames

CLEVER [[12]](https://github.com/CopterExpress/clever) is an open source PX4-compatible platform based on ROS. It supports following frames of reference:

* `local_origin` (corresponds to `MAV_FRAME_LOCAL_ENU`);
* `fcu_horiz` (corresponds to `MAV_FRAME_LOCAL_FLU`);
* `fcu` (Forward-Left-Up variant of `MAV_FRAME_LOCAL_RPY`).

ENU is used instead of NED to comply with ROS guidelines [[9]](http://www.ros.org/reps/rep-0103.html).

## DJI Mobile SDK frames

DJI Mobile SDK supports two frames of reference ([[13]](https://developer.dji.com/mobile-sdk/documentation/introduction/flightController_concepts.html#coordinate-systems), [[14]](https://developer.dji.com/mobile-sdk/documentation/introduction/component-guide-flightController.html)):

* `Ground` (corresponds to `MAV_FRAME_LOCAL_NED`);
* `Body` (corresponds to `MAV_FRAME_BODY_FRD`).

Yaw angle is always relative to the north.

# Unresolved Questions

* The naming of Forward-Left-Up variant of `MAV_FRAME_LOCAL_RPY`.
* The necessity of some frame with `BODY_TERRAIN` origin.
* The necessity of `MAV_FRAME_LOCAL_FRD` and `MAV_FRAME_LOCAL_NED_ODOM` frames is not obvious.
* On some platforms yaw is specified w.r.t. the north even in frames with the orientation fixed to the vehicle (like `Body` frame in DJI SDK). It would be possibly better to explicitly prohibit this behavior as it leads to inconsistent frame meaning.
