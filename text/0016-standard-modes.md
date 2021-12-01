  * Start date: 2021-02-21
  * Contributors: HamishWillee <hamishwillee@gmail.com>, Lorenz Meier <lorenz@px4.io>, ...
  * Related issues: 
    - Discussion PR: https://github.com/mavlink/mavlink/issues/1165, 
    - Initial proposal: https://docs.google.com/document/d/1LIcfOL3JrX-EznvXArna1h-sZ7va7LRTteIUzISuD8c/edit

# Summary

This RFC proposes a microservice that will allow a GCS (or MAVLink SDK) to use a safely use a "standard" set of flight modes without any prior knowledge of a flight stack.

The proposal defines a small (initial) set of standard autopilot modes, along with mechanism to query available modes, set the standard mode, and publish the current standard mode (if a standard mode is active).
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

Most autopilots implement a set of custom flight modes that have very similar behaviour, including: takeoff, land, safety return/RTL, position mode, altitude mode, mission mode, hold mode.
However because these are all identified by different custom mode identifiers on different flight stacks, there is no way to be sure what these "mean" without pre-existing knowledge.


# Detailed Design

The design proposes a small set of modes that are (broadly speaking) commonly implemented across flight stacks, along with mechanisms to:
- set the standard mode
- get the current standard mode, if active.
- determine what modes are available

## Standard modes

Standard modes are those that are implemented in a similar way by most flight stacks, and which a GCS can present as more or less the same thing for any flight stack.

The precise mechanics and behaviour do not have to be identical, but the broad intent has to be similar.
For example, most flight stacks have the concept of a safety return mode, which flies the vehicle back to a safe place.
While the destination, path, and whether the vehicle lands may differ for a particular flight stack or based on settings, the concept is similar, and would not be unexpected by a user.

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
          When sticks are released vehicles return to their level-flight orientation.
          Hovering vehicles actively brake and hold both position and altitude against wind and external forces,
          Forward-traveling vehicles maintain current track and altitude.
        </description>
      </entry>
      <entry value="2" name="MAV_STANDARD_MODE_ALTITUDE_HOLD">
        <description>Altitude hold (manual).
          Altitude-controlled and stabilized manual mode.
          When sticks are released vehicles return to their level-flight orientation.
          Hovering vehicles hold altitude but continue with existing momentum and may move with wind.
          Forward-traveling vehicles maintain altitude but may be moved off their current heading by exernal forces.
        </description>
      </entry>
      <entry value="3" name="MAV_STANDARD_MODE_SAFETY_RETURN">
        <description>Return mode (auto).
          Automatic mode that returns vehicle to a safe location via a safe flight path.
          It may also automatically land the vehicle.
          The precise return location, flight path, and landing behaviour depend on vehicle configuration and type.
        </description>
      </entry>
      <entry value="4" name="MAV_STANDARD_MODE_LAND">
        <description>Land mode (auto).
          Automatic mode that lands the vehicle at the current location.
          The precise landing behaviour depends on vehicle configuration and type.
        </description>
      </entry>
      <entry value="5" name="MAV_STANDARD_MODE_TAKEOFF">
        <description>Takeoff mode (auto).
          Automatic takeoff mode.
          The precise takeoff behaviour depends on vehicle configuration and type.
        </description>
      </entry>
      <entry value="6" name="MAV_STANDARD_MODE_MISSION">
        <description>Mission mode (automatic).
          Automatic mode that executes MAVLink missions.
          Missions are executed from the current waypoint as soon as the mode is enabled.
          If a mission cannot be executed the mission is paused.
        </description>
      </entry>
    </enum>
```

In future this may be extended with additional flight modes and component specific modes.


## Setting Modes

The mode will be set using a new command: `MAV_CMD_DO_SET_STANDARD_MODE`.

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

> **Note:** 
> - Preferably we would extend [MAV_CMD_DO_SET_MODE](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_SET_MODE) to set the standard mode using `param4`.
>   This is risky because a system that does not support the service will try to set the base and custom modes.
> - We could make this command more generic `MAV_CMD_DO_SET_MODE_V2` and include custom and base modes in it too.

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

> **Note** This message provides all modes.
> If we only want to get standard modes (not enumerate custom modes we might instead) the message could just list the enum values for supported modes (i.e. in a comma separated string, or an array of values.

## Getting Current Standard Mode

The current standard mode will be added to [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT) as an extension field.
This allows it to be obtained alongside the base and custom modes.
Metadata about the mode is either from the standard mode definitions or simply a name provided for custom-only modes.

```xml
      <extensions/>
      <field type="uint16_t" name="standard_mode" enum="MAV_STANDARD_MODE">The current active standard mode (or 0 for a custom-only mode).</field>
```

Notes:
- A separate message was considered, in particular because `HEARTBEAT` is so critical.
  However this is the logical and consistent way to share modes.
- The mode is a double byte to allow the `MAV_STANDARD_MODE` to be extended to support non-autopilot modes in future.


# Alternatives

## Use standard commands rather than standard modes

The main goal is to allow a vehicle to be put into standard "flight behaviours".
This could also be done by defining suitably generic commands: e.g. [MAV_CMD_NAV_TAKEOFF](https://mavlink.io/en/messages/common.html#MAV_CMD_NAV_TAKEOFF).

Modes have the slight benefit that the commands already have definitions which may not be suitably generic.
Further commands do not have to match a specific mode in all cases: using modes means that the behaviour will have an expected display in the UI.


## Only expose standard modes

`AVAILABLE_MODES` (as designed) is emitted for all modes.

This is useful as it allows a UI where the GCS can display all the standard modes if it wants, or all the standard modes and separately all the custom modes (albeit these could not be translated etc).

However this may be unnecessarily complicated. If we agree that we only need to list the supported modes then we could simplify work for the GCS by providing all the supported modes in a single message. Something like:

```xml
    <message id="435" name="AVAILABLE_MODES">
      <description>Get the list of all available standard modes.
        The message can be requested using MAV_CMD_REQUEST_MESSAGE.
      </description>
      <field type="char[250]" name="modes">List of enum values for all standard modes, comma separated, without null termination character.</field>
    </message>
```

## Only expose custom modes

Just implementing `AVAILABLE_MODES` would allow an anonymous flight stack to be used by a ground station in a limited way.

However there would be no reliable common understanding of what each of the modes meant or what they actually are, so a GCS could not necessarily provide useful information to a user other than the name of the mode that has been entered.



# Unresolved Questions

- Do we need support for getting available custom modes? If we only need standard modes then we could have a much simpler `AVAILABLE_MODES` and much easier interaction for GCS.

- Can we we provide more information about the current mode. E.g. in return mode, the user doesn't care about the behaviour, but a GCS might better configure itself if it knows that rally points are being used, or a mission landing.
- What modes make sense for other components? Camera etc.


# References

* PRs/Issues for discussion:
  - https://github.com/mavlink/mavlink/pull/1750
  - https://github.com/mavlink/mavlink/issues/1165
  - [Initial proposal google doc](https://docs.google.com/document/d/1LIcfOL3JrX-EznvXArna1h-sZ7va7LRTteIUzISuD8c/edit) - mostly a problem statement.
  
