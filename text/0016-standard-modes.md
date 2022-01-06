  * Start date: 2021-02-21
  * Contributors: HamishWillee <hamishwillee@gmail.com>, Lorenz Meier <lorenz@px4.io>, ...
  * Related issues: 
    - Discussion PR: https://github.com/mavlink/mavlink/issues/1165, 
    - Initial proposal: https://docs.google.com/document/d/1LIcfOL3JrX-EznvXArna1h-sZ7va7LRTteIUzISuD8c/edit

# Summary

This RFC proposes a microservice that will allow a GCS (or MAVLink SDK) to use a safely use a "standard" set of flight modes without any prior knowledge of a flight stack.

The proposal defines a small (initial) set of standard autopilot modes, along with mechanism to query available modes, set the standard mode, and determine the current standard mode (if a standard mode is active).
This is sufficient to determine what modes are supported, command a flight stack into a standard mode, and have it behave in a predictable way.

The mechanism also enables, but does not define, standard modes for other non-autopilot components like cameras, gimbals, etc.

The design uses a new message for returning the available modes, and for setting the standard mode.
An extension field is added to the [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT) to publish the current standard mode (if enabled).

The service is a pure addition: it has no impact or side effects when used with systems that do not implement or understand it.

> **Note:** The proposed design allows both custom and standard modes to be discovered.
> A GCS could therefore share these if desired, though without any semantic understanding of their meaning.


# Motivation

This service will allow a GCS to provide baseline support for common flight behaviour and test behaviour without explicit customisation for each autopilot.

This is therefore a big step towards MAVLink being capable of being truly autopilot-agnostic for a useful minimal set of functionality.


### Background

MAVLink currently standardizes *very high level* _base modes_ (defined in [MAV_MODE](https://mavlink.io/en/messages/common.html#MAV_MODE)), which cover things like whether the vehicle is ready to fly, being tested, manually controlled, under GCS manual control, or executing a mission.

More specific flight behaviour/modes are defined in _custom modes_, which are specific to each flight stack.
Mechanisms are provided to set the base and custom modes ([MAV_CMD_DO_SET_MODE](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_SET_MODE)).
The `HEARTBEAT` contains the current/active `base_mode` and `custom_mode`.
There are no mechanisms query the available custom modes.

Most autopilots implement a set of custom flight modes that have very similar behaviour or intent, for example: position-hold mode, altitude-hold mode, mission mode, safety return/RTL.

However because these are all identified by different custom mode identifiers on different flight stacks, there is no way to be sure what these "mean" without pre-existing knowledge.


# Detailed Design

The design proposes a small set of modes that are (broadly speaking) commonly implemented across flight stacks, along with mechanisms to:
- determine what modes are available
- set the standard mode
- infer the current standard mode, if active.


## Standard modes

Standard modes are those that are implemented in a similar way by most flight stacks, and which a GCS can present as more or less the same thing for any flight stack.

The precise mechanics and behaviour do not have to be identical, but the broad intent has to be similar, and any differing behaviour across flight statcks should not be unexpected by a user.

A flight stack is not _required_ to support all of these modes.

The standard modes will be defined in an enum `MAV_STANDARD_MODE`, which has an initial value `0` is an enum that indicates "not a standard mode".

The proposed initial set of modes is:
```xml
    <enum name="MAV_STANDARD_MODE">
      <description>Standard modes with a well understood meaning across flight stacks and vehicle types.
        For example, most flight stack have the concept of a "return" or "RTL" mode that takes a vehicle to safety, even though the precise mechanics of this mode may differ.
        Modes may be set using MAV_CMD_DO_SET_STANDARD_MODE.
      </description>
      <entry value="0" name="MAV_STANDARD_MODE_NON_STANDARD">
        <description>Non standard mode.
          This may be used when reporting the mode if the current flight mode is not a standard mode.
        </description>
      </entry>
      <entry value="1" name="MAV_STANDARD_MODE_POSITION_HOLD">
        <description>Position mode (manual).
          Position-controlled and stabilized manual mode.
          When sticks are released vehicles return to their level-flight orientation and hold both position and altitude against wind and external forces.
          Note that the precise meaning of "hold position" depends on vehicle type (for example, an MC can hold to a specify point, while a boat might either loiter around a circle centered on fixed point or drift within that circle).
          Multicopter (MC) vehicles actively brake and hold both position and altitude against wind and external forces.
          Hybrid MC/FW ("VTOL") vehicles first transition to multicopter mode (if needed) but otherwise behave in the same way as MC vehicles.
          Fixed-wing (FW) vehicles may not support this mode.
          Other vehicle types may not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="2" name="MAV_STANDARD_MODE_CRUISE">
        <description>Cruise mode (manual).
          Position-controlled and stabilized manual mode.
          When sticks are released vehicles return to their level-flight orientation and hold their original track against wind and external forces.
          Fixed-wing (FW) vehicles level orientation and maintain current track and altitude against wind and external forces.
          Hybrid MC/FW ("VTOL") vehicles first transition to FW mode (if needed) but otherwise behave in the same way as MC vehicles.
          Multicopter (MC) vehicles may not support this mode.
          Other vehicle types may not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="3" name="MAV_STANDARD_MODE_ALTITUDE_HOLD">
        <description>Altitude hold (manual).
          Altitude-controlled and stabilized manual mode.
          When sticks are released vehicles return to their level-flight orientation and hold their altitude.
          MC vehicles continue with existing momentum and may move with wind (or other external forces).
          FW vehicles continue with current heading, but may be moved off-track by wind.
          Hybrid MC/FW ("VTOL") vehicles behave according to their current configuration/mode (FW or MC).
          Other vehicle types may not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="4" name="MAV_STANDARD_MODE_RETURN_HOME">
        <description>Return home mode (auto).
          Automatic mode that returns vehicle to home via a safe flight path.
          It may also automatically land the vehicle (i.e. RTL).
          The precise flight path and landing behaviour depend on vehicle configuration and type.
        </description>
      </entry>
      <entry value="5" name="MAV_STANDARD_MODE_SAFE_RECOVERY">
        <description>Safe recovery mode (auto).
          Automatic mode that takes vehicle to a predefined safe location via a safe flight path (rally point or mission defined landing) .
          It may also automatically land the vehicle.
          The precise return location, flight path, and landing behaviour depend on vehicle configuration and type.
        </description>
      </entry>
      <entry value="6" name="MAV_STANDARD_MODE_MISSION">
        <description>Mission mode (automatic).
          Automatic mode that executes MAVLink missions.
          Missions are executed from the current waypoint as soon as the mode is enabled.
        </description>
      </entry>
      <entry value="7" name="MAV_STANDARD_MODE_LAND">
        <description>Land mode (auto).
          Automatic mode that lands the vehicle at the current location.
          The precise landing behaviour depends on vehicle configuration and type.
        </description>
      </entry>
      <entry value="8" name="MAV_STANDARD_MODE_TAKEOFF">
        <description>Takeoff mode (auto).
          Automatic takeoff mode.
          The precise takeoff behaviour depends on vehicle configuration and type.
        </description>
      </entry>
    </enum>
```

Notes:
- In future this set may be extended with additional flight modes and component specific modes.
- The "return home" and "safe recovery" modes both serve the same function: getting the vehicle to a safe location in the event of a failsafe or for landing.
  They are separated because from the user perspective the behaviour is quite different and the GCS needs to be able to present that behaviour differently.
  - The existance of these as separate modes means that the autopilot must have separate custom modes for these if we don't publish the standard mode independently. 


## Setting Modes

A standard mode should be set using a new command: `MAV_CMD_DO_SET_STANDARD_MODE`.

```xml
      <entry value="262" name="MAV_CMD_DO_SET_STANDARD_MODE" hasLocation="false" isDestination="false">
        <description>Enable the specified standard MAVLink mode.
          If the mode is not supported the vehicle should ACK with MAV_RESULT_FAILED.
        </description>
        <param index="1" label="Standard Mode" enum="MAV_STANDARD_MODE">The mode to set.</param>
        <param index="2" reserved="true" default="0"/>
        <param index="3" reserved="true" default="0"/>
        <param index="4" reserved="true" default="0"/>
        <param index="5" reserved="true" default="0"/>
        <param index="6" reserved="true" default="0"/>
        <param index="7" reserved="true" default="NaN"/>
      </entry>
```


## Getting Available Modes

A new message will be added for enumerating all available modes (standard, base, and custom) for the current vehicle type:
- The message will include the total number of modes and the index of the current mode.
  This indexing is provided to allow a GCS to confirm that all modes have been collector and re-request any that are missing.
  It is internal and should not be relied upon to have any order between reboots.
- If there is a direct correlation between a standard mode and a custom mode this should be treated as just one mode (the standard mode) and emitted once.
- The GCS can request this message using `MAV_CMD_REQUEST_MESSAGE`, specifying either "send all modes" or "send mode with this index".
- The message will include a mode name that will be used to provide a string for the GCS to represent custom modes.
  It would be empty for standard modes, for which name strings and translations may be hard coded into the GCS.
- The flight should only emit each mode once.
  If a mode is both custom and standard it should be emitted as a "standard mode" (this allows the GCS to list the "standard modes" and separately show the additional "custom modes").
- The modes that are emitted depend on the current vehicle type.
  For example, "takeoff" would not be emitted for a rover type, but would for a copter.

A proposal for the message is provided below.

```xml
    <message id="435" name="AVAILABLE_MODES">
      <description>Get information about a particular flight modes.
        The message can be enumerated or requested for a particular mode using MAV_CMD_REQUEST_MESSAGE.
        Specify 0 in param2 to request that the message is emitted for all available modes or the specific index for just one mode.
        The modes must be available/settable for the current vehicle/frame type.
        Each modes should only be emitted once (even if it is both standard and custom).
      </description>
      <field type="uint8_t" name="number_modes">The total number of available modes for the current vehicle type.</field>
      <field type="uint8_t" name="mode_index">The current mode index within number_modes, indexed from 1.</field>
      <field type="uint8_t" name="standard_mode" enum="MAV_STANDARD_MODE">Standard mode.</field>
      <field type="uint8_t" name="base_mode" enum="MAV_MODE_FLAG" display="bitmask">System mode bitmap.</field>
      <field type="uint32_t" name="custom_mode">A bitfield for use for autopilot-specific flags</field>
      <field type="char[50]" name="mode_name">Name of custom mode, without null termination character. Should be omitted for standard modes.</field>
    </message>
```

## Getting Current Standard Mode

We need to be able to know the current active standard mode (if any) so that a GCS can configure itself appropriately and the user can understand the behaviour.

The current base and custom modes are currently published in the [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT).
The proposal is to add the standard mode to `HEARTBEAT` as an extension field as this is the easiest for flight stacks/SDKs to use and provides the most flexibile design when 

```xml
      <extensions/>
      <field type="uint16_t" name="standard_mode" enum="MAV_STANDARD_MODE">The current active standard mode (or 0 for a custom-only mode).</field>
```

Note that extending the `HEARTBEAT` is not mandatory but has costs/implications as discussed in teh [alternatives below](#current-mode-infer-from-custombase-modes).

# Alternatives

## Current mode: Infer from custom/base modes

The current base and custom modes are currently published in the [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT).
The proposal is to add the standard mode to `HEARTBEAT` as an extension field.
There are several reasons for this, one being that this is where the other mode information is. 

We could instead:
- Publish mode in a separate mode message
- Infer the current standard mode from the custom/base modes in `HEARTBEAT`

The argument for using a separate message for getting the mode is that mode information should not be in the `HEARTBEAT` anyway.
The heartbeat is for indicating connection; using it for modes does not make sense for autopilots particularly and none for other components.
We could publish this separately, giving us a path for eventually moving to "HEARTBEAT2"

We might also infer the current standard mode from the existing base and custom mode fields in the `HEARTBEAT`.
This would mean that the message would not have to change, but would have the following implications:
- Requires caching the mapping to custom modes, which scales by number of autopilots in the system.
- Requires a discrete custom mode for every standard mode.
  For ArduPilot and PX4 this means a custom mode would have to be defined for the different return options of rally points vs RTL.


## Setting modes: Set standard mode using mapped base/custom modes

We might instead set desired standard mode using the mapped custom/based modes in [MAV_CMD_DO_SET_MODE](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_SET_MODE).

This is not considered desirable because:
- This would imply there _must_ always be a specific custom mode for each standard mode.
- It is more complicated for GCS/SDKs, which will have to maintain a record of the mapping between modes.
  Maybe not a problem for just one node, but scales badly.
- Overall it is simpler for all users for the mapping to be provided by the stack.

## Setting modes: Updated generic mode setter

The proposed setter command (`MAV_CMD_DO_SET_STANDARD_MODE`) just sets the standard mode, while the old command (`MAV_CMD_DO_SET_MODE`) sets base and custom modes.

We can't just use [MAV_CMD_DO_SET_MODE.param4](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_SET_MODE) to set the standard mode as a system that does not understand this service will ignore the value and attempt to set the base/custom mode.

But we could make this new setter command more generic `MAV_CMD_DO_SET_MODE_V2` and include custom and base modes in it too:
```xml
      <entry value="262" name="MAV_CMD_DO_SET_MODE_V2" hasLocation="false" isDestination="false">
        <description>Set a standard or custom mode.
          If the mode is not supported the vehicle should ACK with MAV_RESULT_FAILED.
        </description>
        <param index="1" label="Standard Mode" enum="MAV_STANDARD_MODE">Standard mode to set. Set to MAV_CMD_DO_SET_STANDARD_MODE if setting a custom mode.</param>
        <param index="2" label="base mode">Base mode. Ignored if standard mode (param1) is non-zero.</param>
        <param index="3" label="custom mode">Custom mode. Ignore if standard mode (param1) is non-zero.</param>
        <param index="4" reserved="true" default="0"/>
        <param index="5" reserved="true" default="0"/>
        <param index="6" reserved="true" default="0"/>
        <param index="7" reserved="true" default="NaN"/>
      </entry>
```

## Getting Available modes: Flags instead of mode enumeration

Instead of enumerating all available modes we could define a flag indicating the _standard_ modes that are supported.

We could indicate this on a per-mode basis, for example y making `MAV_STANDARD_MODE` into a bitmask and `AVAILABLE_MODES` is just a value indicating the supported modes (or we could use a comma separated list of enum values, or whatever). 

Or we could have `MAV_PROTOCOL_CAPABILITY` flags indicating that specific groups are supported - e.g. a base set, takeoff and landing, etc.

All these approaches would be more efficient but would mean:
- No support for getting custom modes.
- The must be a way to get the current active mode as a standard mode - you could not omit publishing the standard mode as a heartbeat or otherwise.

## Setting: Use standard commands rather than standard modes

The main goal is to allow a vehicle to be put into standard "flight behaviours".
This could also be done by defining suitably generic commands: e.g. [MAV_CMD_NAV_TAKEOFF](https://mavlink.io/en/messages/common.html#MAV_CMD_NAV_TAKEOFF).

Modes have the slight benefit that the commands already have definitions which may not be suitably generic.
Further commands do not have to match a specific mode in all cases: using modes means that the behaviour will have an expected display in the UI.

# Unresolved Questions

- [ ] Should we use a new specific setter for standard modes or a new "generic" setter for standard, custom, base modes - i.e. replacement for current mode setter?
- [ ] If we don't publish the standard mode as a standard mode (e.g. in the heartbeat) but only infer it from the base modes we create a need for a defined mapping between custom modes and standard mode. Further, a GCS will have to maintain the 
- [ ] Do we need support for getting available custom modes? If we only need standard modes then we could have a much simpler `AVAILABLE_MODES` and much easier interaction for GCS. But we also must publish the standard mode.
- What modes make sense for other components? Camera etc.


# References

* PRs/Issues for discussion:
  - https://github.com/mavlink/mavlink/pull/1750
  - https://github.com/mavlink/mavlink/issues/1165
  - [Initial proposal google doc](https://docs.google.com/document/d/1LIcfOL3JrX-EznvXArna1h-sZ7va7LRTteIUzISuD8c/edit) - mostly a problem statement.
  
