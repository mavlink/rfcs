- **Start date:** 2021-02-21
  - **State:** Accepted Draft (2023-04-26)
    - Accepted in principle
    - Not prototyped and therefore expected to change
  - **Contributors:** HamishWillee <hamishwillee@gmail.com>, Lorenz Meier <lorenz@px4.io>, Beat Kung, ...
  - **Related issues:** 
    - Discussion PR: https://github.com/mavlink/mavlink/issues/1165, 
    - Initial proposal: https://docs.google.com/document/d/1LIcfOL3JrX-EznvXArna1h-sZ7va7LRTteIUzISuD8c/edit
    - https://github.com/mavlink/mavlink/pull/1915/ - changes arising from prototyping
  - **Modification PRs:** 
    - https://github.com/mavlink/rfcs/pull/24 - remove unnecessary base_mode info from messages
    - https://github.com/mavlink/rfcs/pull/23 - Metadata support/overrides and dynamic modes
    - https://github.com/mavlink/rfcs/pull/25 - Add intended custom mode.
    - https://github.com/mavlink/rfcs/commit/3e25c19b73a77b0a8fabc62cc752a90acf3a7160 - Add MAV_MODE_PROPERTY flag

# Summary

This RFC proposes a microservice that will allow a GCS (or MAVLink SDK) to safely use a "standard" set of flight modes without any prior knowledge of a flight stack.

The proposal defines a small (initial) set of standard autopilot modes, along with mechanism to query available modes, determine if available modes have changed, set the standard mode, and determine the current standard mode (if a standard mode is active) or custom mode.
This is sufficient to determine what modes are supported, command a flight stack into a standard mode, and have it behave in a predictable way.

The mechanism also enables, but does not define, standard modes for other non-autopilot components like cameras, gimbals, etc.

The design uses a new message for returning the available modes and determining when the available modes have changed, and a command for setting the standard mode.
An extension field is added to the [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT) to publish the current standard mode (if enabled).

The service is a pure addition: it has no impact or side effects when used with systems that do not implement or understand it.

> **Note:** The proposed design allows both custom and standard modes to be discovered.
> A GCS could therefore share these if desired, though without any semantic understanding of their meaning.


# Motivation

This service will allow a GCS to provide baseline support for common flight behaviour and test behaviour without explicit customisation for each autopilot.
This is therefore a big step towards MAVLink being capable of being truly autopilot-agnostic for a useful minimal set of functionality.

In addition it will allow at least some support for a ground station to present custom modes in the UI (both static and dynamic)

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
- be notified if the available modes change
- set the standard mode
- infer the current standard mode, if active
- determine how the mode should be displayed

There are additional optional messages/features to allow:
- Modes to be enabled and disabled dynamically
- Override of mode metadata (provide a metadata key)


## Standard Modes

Standard modes are those that are implemented in a similar way by most flight stacks, and which a GCS can present as more or less the same thing for any flight stack.

The precise mechanics and behaviour do not have to be identical, but the broad intent has to be similar, and any differing behaviour across flight stacks should not be unexpected by a user.

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
          This mode can only be set by vehicles that can hold a fixed position.
          Multicopter (MC) vehicles actively brake and hold both position and altitude against wind and external forces.
          Hybrid MC/FW ("VTOL") vehicles first transition to multicopter mode (if needed) but otherwise behave in the same way as MC vehicles.
          Fixed-wing (FW) vehicles must not support this mode.
          Other vehicle types must not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="2" name="MAV_STANDARD_MODE_ORBIT">
        <description>Orbit (manual).
          Position-controlled and stabilized manual mode.
          The vehicle circles around a fixed setpoint in the horizontal plane at a particular radius, altitude, and direction.
          Flight stacks may further allow manual control over the setpoint position, radius, direction, speed, and/or altitude of the circle, but this is not mandated.
          Flight stacks may support the [MAV_CMD_DO_ORBIT](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_ORBIT) for changing the orbit parameters.
          MC and FW vehicles may support this mode.
          Hybrid MC/FW ("VTOL") vehicles may support this mode in MC/FW or both modes; if the mode is not supported by the current configuration the vehicle should transition to the supported configuration.
          Other vehicle types must not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="3" name="MAV_STANDARD_MODE_CRUISE">
        <description>Cruise mode (manual).
          Position-controlled and stabilized manual mode.
          When sticks are released vehicles return to their level-flight orientation and hold their original track against wind and external forces.
          Fixed-wing (FW) vehicles level orientation and maintain current track and altitude against wind and external forces.
          Hybrid MC/FW ("VTOL") vehicles first transition to FW mode (if needed) but otherwise behave in the same way as MC vehicles.
          Multicopter (MC) vehicles must not support this mode.
          Other vehicle types must not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="4" name="MAV_STANDARD_MODE_ALTITUDE_HOLD">
        <description>Altitude hold (manual).
          Altitude-controlled and stabilized manual mode.
          When sticks are released vehicles return to their level-flight orientation and hold their altitude.
          MC vehicles continue with existing momentum and may move with wind (or other external forces).
          FW vehicles continue with current heading, but may be moved off-track by wind.
          Hybrid MC/FW ("VTOL") vehicles behave according to their current configuration/mode (FW or MC).
          Other vehicle types must not support this mode (this may be revisited through the PR process).
        </description>
      </entry>
      <entry value="5" name="MAV_STANDARD_MODE_RETURN_HOME">
        <description>Return home mode (auto).
          Automatic mode that returns vehicle to home via a safe flight path.
          It may also automatically land the vehicle (i.e. RTL).
          The precise flight path and landing behaviour depend on vehicle configuration and type.
        </description>
      </entry>
      <entry value="6" name="MAV_STANDARD_MODE_SAFE_RECOVERY">
        <description>Safe recovery mode (auto).
          Automatic mode that takes vehicle to a predefined safe location via a safe flight path (rally point or mission defined landing) .
          It may also automatically land the vehicle.
          The precise return location, flight path, and landing behaviour depend on vehicle configuration and type.
        </description>
      </entry>
      <entry value="7" name="MAV_STANDARD_MODE_MISSION">
        <description>Mission mode (automatic).
          Automatic mode that executes MAVLink missions.
          Missions are executed from the current waypoint as soon as the mode is enabled.
        </description>
      </entry>
      <entry value="8" name="MAV_STANDARD_MODE_LAND">
        <description>Land mode (auto).
          Automatic mode that lands the vehicle at the current location.
          The precise landing behaviour depends on vehicle configuration and type.
        </description>
      </entry>
      <entry value="9" name="MAV_STANDARD_MODE_TAKEOFF">
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

A new message will be added for enumerating all available modes (standard and custom) for the current vehicle type:
- The message will include the total number of modes and the index of the current mode.
  This indexing is provided to allow a GCS to confirm that all modes have been collected, and re-request any that are missing.
  It is internal and should not be relied upon to have any order between reboots.
- If there is a direct correlation between a standard mode and a custom mode this should be treated as just one mode (the standard mode) and emitted once.
- The GCS can request this message using `MAV_CMD_REQUEST_MESSAGE`, specifying either "send all modes" or "send mode with this index".
- The message will include a `mode_name` field that can act as both a key for determining mode metadata, or as a fallback string if the GCS has no metadata for the mode.
  This can be used to override metadata on existing modes, for example to enhance standard metadata with additional information about autopilot-specific behaviour, or can provide metadata for any other static or dynamic mode.
  The field must be human readable and autopilot-unique.
  Generally it need not be set for standard modes, where the ground station might be expected to already have metadata.
  For more information see [Modes Metadata](#modes-metadata) below.
- The flight stack should only emit each mode once on request.
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
      <field type="uint32_t" name="custom_mode">A bitfield for use for autopilot-specific flags</field>
      <field type="uint32_t" name="properties" enum="MAV_MODE_PROPERTY">Mode properties.</field>
      <field type="char[50]" name="mode_name">Mode name, with null termination character. Used as a metadata key if GCS has matching metadata, otherwise as a fallback mode name string for use in GCS.</field>
    </message>
```

The message includes a `properties` field that can take any of the following enumerated values.
These flags allow the flight stack to provide a hint to a GCS about how a mode should be used, and is primarily intended for custom modes.
For example, the `MAV_MODE_PROPERTY_ADVANCED` indicates a mode that is harder to fly, and might be separated from other modes in the UI.

```xml
    <enum name="MAV_MODE_PROPERTY" bitmask="true">
      <description>Mode properties.
      </description>
      <entry value="1" name="MAV_MODE_PROPERTY_ADVANCED">
        <description>If set, this mode is an advanced mode.
          For example a rate-controlled manual mode might be advanced, whereas a position-controlled manual mode is not.
          A GCS can optionally use this flag to configure the UI for its intended users.
        </description>
      </entry>
      <entry value="2" name="MAV_MODE_PROPERTY_NOT_USER_SELECTABLE">
        <description>If set, this mode should not be added to the list of selectable modes.
          The mode might still be selected by the FC directly (for example as part of a failsafe).
        </description>
      </entry>
    </enum>
```

## Getting Current Active Mode

We need to be able to know the current active standard mode (if any) so that a GCS can configure itself appropriately and the user can understand the behaviour.

The proposal is to create new message with both standard and custom mode information.
This would be emitted on mode change, and also streamed at low rate (a GCS might also query for it explicity, for example, if it noted the custom mode changing in the heartbeat).

```xml
    <message id="436" name="CURRENT_MODE">
      <description>Get the current mode.
        This should be emitted on any mode change, and broadcast at low rate (nominally 0.5 Hz).
        It may be requested using MAV_CMD_REQUEST_MESSAGE.
      </description>
      <field type="uint8_t" name="standard_mode" enum="MAV_STANDARD_MODE">Standard mode.</field>
      <field type="uint32_t" name="custom_mode">A bitfield for use for autopilot-specific flags</field>
      <field type="uint32_t" name="intended_custom_mode" invalid="0">The custom_mode of the mode that was last commanded by the user (for example, with MAV_CMD_DO_SET_STANDARD_MODE, MAV_CMD_DO_SET_MODE or via RC). This should usually be the same as custom_mode. It will be different if the vehicle is unable to enter the intended mode, or has left that mode due to a failsafe condition. 0 indicates the intended custom mode is unknown/not supplied</field>
    </message>
```

The message also includes a field `intended_custom_mode`, which indicates the last (custom) mode that was commanded.
This should match the `custom_mode` but might not if a commanded mode cannot be entered, or if the mode is exited due to a failsafe.

Note that the current custom mode is also published in the [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT).
Including the standard mode in the `HEARTBEAT` was discussed and discarded.
See "Get Current mode from HEARTBEAT" section below.

## Dynamic Mode Changes

MAVLink systems that support dynamic creation and removal of modes at runtime (for example, using Lua or other onboard scripting languages, or offboard from a companion computer) may emit the following message, iterating a sequence number, to notify a GCS of that the modes have changed.
The GCS is then expected to re-request the list of modes (`AVAILABLE_MODES`).

The message is an optional part of the specification.
If supported it should be emitted on mode change, and otherwise at low rate (nominally 0.1 Hz).

```xml
    <message id="437" name="AVAILABLE_MODES_MONITOR">
      <description>A change to the sequence number indicates that the set of AVAILABLE_MODES has changed.
        A receiver must re-request all available modes whenever the sequence number changes.
        This is only emitted after the first change and should then be broadcast at low rate (nominally 0.3 Hz) and on change.
      </description>
      <field type="uint8_t" name="seq">Sequence number. The value iterates sequentially whenever AVAILABLE_MODES changes (e.g. support for a new mode is added/removed dynamically).</field>
    </message>
```

## Mode Metadata

Mode metadata is the information that a ground station uses represent a mode in the UI.
Minimally this includes the mode name, but might also include descriptions, translations and other information (mode metadata schema is yet to be defined).

Ground stations are expected to use the following "fallback" approach for matching modes to their metadata:

1. `mode_name` field as a metadata key. This should be used if it is defined and there is matching metadata.
2. `standard_mode`: Use if no metadata can be matched using `mode_name`.
3. `custom_mode`: Use if no metadata can be matched using `mode_name` or `standard_mode`.
4. `mode_name` field as a fallback mode name string. This should be used as the name if no other metadata can be mapped.

This allows "full" autopilot-specific metadata to be provided for modes, including dynamic modes such as Lua scripts (where the `custom_mode` might be dynamically allocated).
It also allows overriding of any existing metadata for any mode with vehicle-specific data.
 
Note that the `mode_name` must be human readable and unique for the autopilot.


# Alternatives

## Get Current mode from HEARTBEAT

The current custom mode (and base mode) are published in the [HEARTBEAT](https://mavlink.io/en/messages/common.html#HEARTBEAT).
The proposal is to get the current standard mode using a separate message.

We could instead:
- Infer the current standard mode from the custom/base modes in `HEARTBEAT`
- Publish the current standard mode as an extension field in the `HEARTBEAT`.
- Publish mode in a separate mode message

The original proposal was to add the standard mode to `HEARTBEAT` as an extension field, as this is the easiest for flight stacks/SDKs to use:

```xml
      <extensions/>
      <field type="uint16_t" name="standard_mode" enum="MAV_STANDARD_MODE">The current active standard mode (or 0 for a custom-only mode).</field>
```

The arguments against were:
- `HEARTBEAT` is absolutely core to MAVLink. It is risky to update.
- Modes logically shouldn't be in the `HEARTBEAT` - extending this with standard modes is compounding the issue.
- Having a separate message means that this is completely separate/orthogonal to the existing implementation.

We might also infer the current standard mode from the existing custom mode field in the `HEARTBEAT`.
This would mean that the message would not have to change, but would have the following implications:
- Requires caching the mapping to custom modes, which scales by number of autopilots in the system.
- Requires a discrete custom mode for every standard mode.
  For ArduPilot and PX4 this means a custom mode would have to be defined for the different return options of rally points vs RTL.


## Setting modes: Set standard mode using mapped custom modes

We might instead set desired standard mode using the mapped custom/based modes in [MAV_CMD_DO_SET_MODE](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_SET_MODE).

This is not considered desirable because:
- This would imply there _must_ always be a specific custom mode for each standard mode.
- It is more complicated for GCS/SDKs, which will have to maintain a record of the mapping between modes.
  Maybe not a problem for just one node, but scales badly.
- Overall it is simpler for all users for the mapping to be provided by the stack.

## Setting modes: Updated generic mode setter

The proposed setter command (`MAV_CMD_DO_SET_STANDARD_MODE`) just sets the standard mode, while the old command (`MAV_CMD_DO_SET_MODE`) sets base and custom modes.

We can't just use [MAV_CMD_DO_SET_MODE.param4](https://mavlink.io/en/messages/common.html#MAV_CMD_DO_SET_MODE) to set the standard mode as a system that does not understand this service will ignore the value and attempt to set the custom mode.

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

## Getting Available modes: Component Metadata rather than Message

We could get the available mode information using a component metadata file.
This has been discarded for now because component metadata has not yet formally part of the standard.
It might reasonably replace or be used as well as the messages.

The benefits are:
- Can be extended easily with other metadata, including grouping of manual vs autonomous, standard vs custom. 
- Provides mechanism for delivering standard documentation and additional descriptions of modes out of the box. 
- Provides mechanism for delivering minor customisations of standard documentation out of the box - e.g. two flight stack both support standard orbit mode, but one controls altitude with sticks, and the other controls rotation direction.
- Translation out of the box
- Works for both custom and standard modes as peers - current approach does not allow anything other than one string for custom modes.
- Get all the information at once using same infrastructure as for other data.
- Avoids "yet another metadata" mechanism.

The downsides are that
- component information is not yet in the standard.
- component information takes more effort to implement first time (e.g. mavftp, parsers), and more than parsing just a message.
- It is less dynamic to update, though this can be supported if needed (i.e. for things like lua-script injected modes).


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

## Mode MetaData: Use a specific metadata key rather than mode name

Using a specific metadata key would make the implementation more "clear", separating the fallback mode name string from the key used for translation.
This would reduce the chance of name clashes.
However the cost would be addition of a specific field, potentially losing the effect of zero-byte truncation.

Note that the `custom_mode` field cannot be used as the key because it may need to be dynamically allocated (otherwise it would need to be allocated ahead of time, or inferred using a hash, potentially resulting in clashes).

# Unresolved Questions

- [ ] Can only a flight stack support this protocol, or can it be supported by a Companion computer, or both? If so, how are conflicts resolved.
- [ ] What modes make sense for other components? Camera etc.
- [ ] Codify standard mode metadata? English string to be emitted? Long name, short name, Standard description text? 

# References

* PRs/Issues for discussion:
  - https://github.com/mavlink/mavlink/pull/1750
  - https://github.com/mavlink/mavlink/issues/1165
  - [Initial proposal google doc](https://docs.google.com/document/d/1LIcfOL3JrX-EznvXArna1h-sZ7va7LRTteIUzISuD8c/edit) - mostly a problem statement.
  
