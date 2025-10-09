# RFC: Generic Payload Protocol for MAVLink

- Start Date: 2025-09-19
- Contributors: Thomas Watters (Skydio)
- Related Issues: N/A

## Summary

This RFC proposes a standardized Generic Payload Protocol for MAVLink that provides a flexible interface for controlling and monitoring arbitrary payloads attached to UAVs. The protocol supports various data types, control modes, and telemetry streaming through a set of five new MAVLink messages.

## Motivation

### Generic Payload Examples

The message set defined below should be generic enough to support the following lists of payload types:

- Spotlight (Illuminator)
- Radiation / Gas Sensor
- Gripper
- Actuated Designator / Illuminator
- Servos
- Winch
- Spot / Distance Meter
- Multi-channel low throughput sensors
- Parachute
- Multi-Stage Dropper
- Dispenser

As an example, we show how Illuminator protocol could be replaced with the Generic Payload Protocol below. We should note that the intent of the Generic Payload Protocol is to be generic enough to support all of the above examples in such a way that attachment developers can build their app and consume its functionality through a UI without significant changes to the UI. In many cases a more specific protocol may be better suited to give a better user experience (e.g. Illuminator protocol). The Generic Payload Protocol is not intended to replace existing protocols but to provide a generic interface for payloads that don't fit into existing message categories.

### Limitations of Existing MAVLink Payload Interface

Current MAVLink lacks a standardized way to interface with generic payloads that don't fit into existing message categories. While MAVLink does provide some [payload services](https://mavlink.io/en/services/payload.html), these have significant limitations for generic payload integration:

1. **Payload-Specific Design**: Current commands are tailored to specific payload types (grippers, winches, illuminators) rather than providing a generic framework. The documentation explicitly recommends "use the commands for known payload types where possible as they are more intuitive for users."

2. **Limited Generic Commands**: The few generic commands available (`MAV_CMD_DO_SET_ACTUATOR`, `MAV_CMD_DO_SET_SERVO`) are:
   - Rudimentary in functionality (basic PWM/position control only)
   - Inconsistently implemented ("only implemented on PX4" for actuator commands)
   - Lack metadata and discovery mechanisms
   - Provide no type safety or validation

3. **No Discovery Protocol**: Existing interfaces require prior knowledge of payload capabilities - there's no way for a GCS to discover what functions a payload provides or their acceptable value ranges.

4. **Missing Telemetry Framework**: No standardized way for payloads to stream sensor data or status information back to the GCS.

5. **Integration Complexity**: Each new payload type requires either:
   - Creating custom MAVLink messages (requiring message ID allocation and standardization)
   - Using inadequate generic commands that lack proper discovery and metadata
   - Implementing proprietary protocols outside MAVLink

### Benefits of a Comprehensive Generic Payload Protocol

A standardized generic payload protocol would address these limitations by providing:

- **Self-Describing Capabilities**: Payloads announce their functions and telemetry channels with metadata
- **Type-Safe Operations**: Strong typing prevents value interpretation errors
- **Plug-and-Play Discovery**: Zero-configuration payload detection and capability enumeration
- **Consistent UI/UX**: Standardized interface across different GCS implementations
- **Extensible Framework**: Support for future payload types without protocol changes
- **Reduced Integration Time**: Manufacturers can implement once and work with any compliant GCS
- **MAVLink Ecosystem Compatibility**: Maintains compatibility with existing infrastructure

## Detailed Design

### Protocol Architecture

The protocol consists of three main components:

1. **Status Reporting**: Periodic broadcast of payload presence and capabilities
2. **Function Control**: Command/response interface for payload functions
3. **Telemetry Monitoring**: Streaming of payload sensor data

### Message Definitions

#### Core Messages:

- `GENERIC_PAYLOAD_DESCRIPTION` (TBD): Payload presence and capability announcement
- `GENERIC_PAYLOAD_STATUS` (TBD): Discovery and status broadcast
- `GENERIC_PAYLOAD_FUNCTION_DESCRIPTION` (TBD): Function metadata description
- `GENERIC_PAYLOAD_FUNCTION_STATUS` (TBD): Function state reporting
- `GENERIC_PAYLOAD_FUNCTION_CONTROL` (TBD): Function command interface
- `MAV_CMD_GENERIC_PAYLOAD_FUNCTION` (TBD): Command-based function control for missions
- `GENERIC_PAYLOAD_TELEMETRY_DESCRIPTION` (TBD): Telemetry channel metadata
- `GENERIC_PAYLOAD_TELEMETRY_DATA` (TBD): High-rate telemetry streaming

#### Key Features:

- **Type Safety**: Strongly typed value system supporting 6 data types (INT32/UINT32/REAL32/INT64/UINT64/REAL64)
- **Extensibility**: Extension fields for additional metadata without breaking compatibility
- **Discovery**: Self-describing payloads that announce their capabilities
- **Flexibility**: Supports logical, continuous, and discrete function types
- **Control Modes**: Latching and momentary control with configurable timeouts

### Protocol Operation

1. **Discovery Phase**: Payload broadcasts `GENERIC_PAYLOAD_STATUS` at 1Hz
2. **Capability Query**: Vehicle requests function/telemetry metadata via `MAV_CMD_REQUEST_MESSAGE`
3. **Operation**: Vehicle sends control commands, payload streams telemetry and status updates

### Enumerations

#### Control Modes

- `GENERIC_PAYLOAD_CONTROL_MODE`: Single-value enumeration for selecting control mode
  - `LATCHING` (1): Function maintains state until changed
  - `MOMENTARY` (2): Function auto-deactivates after timeout
- `GENERIC_PAYLOAD_CONTROL_MODE_FLAGS`: Bitmask for supported control modes
  - `SUPPORTS_LATCHING` (1): Function supports latching mode
  - `SUPPORTS_MOMENTARY` (2): Function supports momentary mode

#### Value Types

Support for 6 data types covering most payload needs:

- 32-bit: INT32, UINT32, REAL32
- 64-bit: INT64, UINT64, REAL64

#### Function Types

- `LOGICAL`: Boolean controls (on/off, enable/disable)
- `CONTINUOUS`: Analog controls with min/max ranges (servo angles, speeds)
- `DISCRETE`: Digital controls with enumerated values (modes, frequencies)

### Message ID Allocation

Message IDs are TBD and will be allocated during the standardization process. Final standardization will require official MAVLink message ID allocation.

### Extension Fields

All messages include extension fields for future enhancements:

- Power consumption monitoring
- Temperature sensing
- Mass/inertia properties
- 64-bit value support


## Implementation Considerations

### Bandwidth Management

- Status messages at low rate (1Hz) for discovery
- Telemetry data messages can be rate-controlled per channel
- Function status only sent on state changes or when requested

### Payload Discovery

- Payloads self-announce via periodic status broadcasts
- Vehicle can request detailed capability information on-demand
- Supports hot-plug scenarios where payloads are connected during flight

### Multi-Payload Systems

- Each payload uses unique component ID
- Messages include payload-specific addressing
- Supports heterogeneous payload mixes on single vehicle

### Validation and Safety

- Strong typing prevents value interpretation errors
- Range checking via min/max fields
- Error flags provide diagnostic information
- Timeout mechanisms prevent stuck states

## Appendix A: Complete Message Definitions

### Enumerations

#### GENERIC_PAYLOAD_CONTROL_MODE

Control mode for generic payload functions (enumeration - mutually exclusive values).

| Value | Name                                   | Description                                                                                                                                            |
| ----- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1     | GENERIC_PAYLOAD_CONTROL_MODE_LATCHING  | Function maintains its state until explicitly changed (toggle on/off).                                                                                 |
| 2     | GENERIC_PAYLOAD_CONTROL_MODE_MOMENTARY | Function is active when commanded and automatically deactivates after timeout_ms milliseconds. If timeout_ms is 0, a default timeout of 100ms is used. |

#### GENERIC_PAYLOAD_CONTROL_MODE_FLAGS

Bitmask of supported control modes for generic payload functions.

| Value | Name                               | Description                               |
| ----- | ---------------------------------- | ----------------------------------------- |
| 1     | GENERIC_PAYLOAD_SUPPORTS_LATCHING  | Function supports latching control mode.  |
| 2     | GENERIC_PAYLOAD_SUPPORTS_MOMENTARY | Function supports momentary control mode. |

#### GENERIC_PAYLOAD_VALUE_TYPE

Data type for generic payload function values.

| Value | Name                              | Description                     |
| ----- | --------------------------------- | ------------------------------- |
| 0     | GENERIC_PAYLOAD_VALUE_TYPE_INT32  | 32-bit signed integer.          |
| 1     | GENERIC_PAYLOAD_VALUE_TYPE_UINT32 | 32-bit unsigned integer.        |
| 2     | GENERIC_PAYLOAD_VALUE_TYPE_REAL32 | 32-bit IEEE-754 floating point. |
| 3     | GENERIC_PAYLOAD_VALUE_TYPE_INT64  | 64-bit signed integer.          |
| 4     | GENERIC_PAYLOAD_VALUE_TYPE_UINT64 | 64-bit unsigned integer.        |
| 5     | GENERIC_PAYLOAD_VALUE_TYPE_REAL64 | 64-bit IEEE-754 floating point. |
| 6     | GENERIC_PAYLOAD_VALUE_TYPE_BITMASK_8  | Bitmask of values.          |
| 7     | GENERIC_PAYLOAD_VALUE_TYPE_BITMASK_16 | Bitmask of values.          |
| 8     | GENERIC_PAYLOAD_VALUE_TYPE_BITMASK_32 | Bitmask of values.          |
| 9     | GENERIC_PAYLOAD_VALUE_TYPE_BITMASK_64 | Bitmask of values.          |

#### GENERIC_PAYLOAD_FUNCTION_TYPE

Type of generic payload function.

| Value | Name                                     | Description                                                                |
| ----- | ---------------------------------------- | -------------------------------------------------------------------------- |
| 0     | GENERIC_PAYLOAD_FUNCTION_TYPE_LOGICAL    | Logical state control (true/false, on/off, high/low).                      |
| 1     | GENERIC_PAYLOAD_FUNCTION_TYPE_CONTINUOUS | Continuous value control (e.g., servo angle, motor speed). Uses min/max.   |
| 2     | GENERIC_PAYLOAD_FUNCTION_TYPE_DISCRETE   | Discrete value selection (e.g., mode number, PWM frequency). Uses min/max. |
| 3     | GENERIC_PAYLOAD_FUNCTION_TYPE_BITMASK    | Bitmask value selection                                                    |

#### GENERIC_PAYLOAD_ERROR_FLAGS

Error flags for a generic payload. This is a bitmask enumeration.

| Value | Name                                       | Description                                                                                                              |
| ----- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| 1     | GENERIC_PAYLOAD_ERROR_FLAGS_SOFTWARE_ERROR | There is an error with the generic payload's software.                                                                   |
| 2     | GENERIC_PAYLOAD_ERROR_FLAGS_HARDWARE_ERROR | There is an error with the generic payload's hardware.                                                                   |
| 4     | GENERIC_PAYLOAD_ERROR_FLAGS_OVERTEMP_FAULT | A specified limit has been reached by the generic payload's temperature sensor. Applies if payload monitors temperature. |
| 8     | GENERIC_PAYLOAD_ERROR_FLAGS_CUSTOM         | Generic payload custom failure. See custom error flag bitmask for details.                                               |

### Messages

#### GENERIC_PAYLOAD_DESCRIPTION (Message ID: TBD)

Message broadcasted at a low rate (nominally < 1 Hz or on request) to announce the payload's presence and capabilities. This message must be broadcasted at some non-zero rate to indicate the payload's existence and to allow the vehicle to discover the Generic Payload Protocol.

| Field Name             | Type        | Min | Description                                                                                                       |
| ---------------------- | ----------- | --- | ----------------------------------------------------------------------------------------------------------------- |
| payload_id             | uint8_t     | 1   | Component ID of the generic payload.                                                                              |
| num_functions          | uint16_t    | 0   | Number of functions this payload provides.                                                                        |
| num_telemetry_channels | uint16_t    | 0   | Number of telemetry channels this payload provides.                                                               |
| name                   | char[32]    |     | Name of the generic payload for UI display (NULL-terminated string).                                              |
| mass                   | uint16_t    |     | Mass of the payload in grams. 0 if not available.                                                                 |
| torque_arm             | uint16_t[3] |     | Vector3 describing the CoM offset from the vehicle's payload frame CoM (mm). Optional, 0s indicate not specified. |
| metadata_crc           | uint32_t    |     | CRC32 checksum of the metadata file. 0 if metadata_uri is not used.                                               |
| metadata_uri           | char[100]   |     | URI to component metadata file (NULL-terminated string). All zeros if not used.                                   |

#### GENERIC_PAYLOAD_STATUS (Message ID: TBD)

Status for a generic payload. This should be broadcast at a low rate (nominally 1 Hz) to announce the payload's presence and capabilities.

| Field Name             | Type     | Min | Description                                                                          |
| ---------------------- | -------- | --- | ------------------------------------------------------------------------------------ |
| payload_id             | uint8_t  | 1   | Component ID of the generic payload.                                                 |
| uptime_ms              | uint32_t | 0   | Time since payload boot (in milliseconds).                                           |
| error_flags            | uint32_t | 0   | Current error flags (bitmask). See GENERIC_PAYLOAD_ERROR_FLAGS.                      |
| custom_error_flags     | uint32_t | 0   | Bitmap for custom error flags specific to this payload type.                         |
| power_draw             | uint16_t | 0   | Power consumption of the payload in mW. UINT16_MAX if not available.                 |
| temperature            | uint16_t | 0   | Temperature of the payload (0.01 °C per unit, 0 = 0°C). UINT16_MAX if not available. |


#### GENERIC_PAYLOAD_FUNCTION_DESCRIPTION (Message ID: TBD)

Generic payload function description, sent on request with MAV_CMD_REQUEST_MESSAGE or MAV_CMD_SET_MESSAGE_INTERVAL, with param2 set to payload_id. Param 3 can be set to 0 to trigger emission of the message for all functions, or a function index to get information for that function.

| Field Name    | Type       | Min | Description                                                                      |
| ------------- | ---------- | --- | -------------------------------------------------------------------------------- |
| payload_id    | uint8_t    | 1   | Component ID of the generic payload.                                             |
| index         | uint16_t   | 1   | Index of this function on the generic payload.                                   |
| type          | uint8_t    | 0   | Type of function. See GENERIC_PAYLOAD_FUNCTION_TYPE.                             |
| value_type    | uint8_t    | 0   | Data type for value/min/max fields. See GENERIC_PAYLOAD_VALUE_TYPE.              |
| enabled       | uint8_t    | 0   | 0: Disabled, 1: Enabled                                                          |
| min_low       | uint8_t[4] | 0   | Lower 32 bits of minimum value. Little-endian.                                   |
| max_low       | uint8_t[4] | 0   | Lower 32 bits of maximum value. Little-endian.                                   |
| control_modes | uint16_t   | 0   | Bitmask of supported control modes. See GENERIC_PAYLOAD_CONTROL_MODE_FLAGS.      |
| timeout_ms    | uint32_t   | 0   | Timeout in milliseconds for MOMENTARY mode. 0 means use default timeout (100ms). |
| name          | char[32]   |     | Name of the function for UI display. NULL-terminated string.                     |
| units         | char[16]   |     | Units for the value field (optional). NULL-terminated string.                    |
| min_high      | uint8_t[4] | 0   | Upper 32 bits of minimum value. Only used for 64-bit types. Little-endian        |
| max_high      | uint8_t[4] | 0   | Upper 32 bits of maximum value. Only used for 64-bit types. Little-endian        |

#### GENERIC_PAYLOAD_FUNCTION_STATUS (Message ID: TBD)

Generic payload function status.

| Field Name    | Type       | Min | Description                                                                                     |
| ------------- | ---------- | --- | ----------------------------------------------------------------------------------------------- |
| payload_id    | uint8_t    | 1   | Component ID of the generic payload.                                                            |
| index         | uint16_t   | 1   | Index of this function on the generic payload.                                                  |
| value_low     | uint8_t[4] | 0   | Lower 32 bits of current value. For 32-bit types, this is the entire value. Little-endian.      |
| value_high    | uint8_t[4] | 0   | Upper 32 bits of current value. Only used for 64-bit types. Little-endian.                      |

#### GENERIC_PAYLOAD_FUNCTION_CONTROL (Message ID: TBD)

Command to control a generic payload function.

| Field Name   | Type       | Min | Description                                                                                |
| ------------ | ---------- | --- | ------------------------------------------------------------------------------------------ |
| payload_id   | uint8_t    | 1   | Component ID of the generic payload.                                                       |
| index        | uint16_t   | 1   | Index of this function on the generic payload.                                             |
| control_mode | uint8_t    | 0   | Desired Control Mode. See GENERIC_PAYLOAD_CONTROL_MODE.                                    |
| enable       | uint8_t    | 0   | 0: Disable, 1: Enable                                                                      |
| value_low    | uint8_t[4] | 0   | Lower 32 bits of value to set. For 32-bit types, this is the entire value. Little-endian.  |
| timeout_ms   | uint32_t   | 0   | Timeout for momentary operation if control_mode is GENERIC_PAYLOAD_CONTROL_MODE_MOMENTARY. |
| value_high   | uint8_t[4] | 0   | Upper 32 bits of value to set. Only used for 64-bit types. Little-endian.                  |

#### MAV_CMD_GENERIC_PAYLOAD_FUNCTION (Command ID: TBD)

Command to control a generic payload function. This command provides an alternative interface to the `GENERIC_PAYLOAD_FUNCTION_CONTROL` message for mission planning and command-based control.

| Param | Label        | Units | Values                            | Description                                                                                         |
| ----- | ------------ | ----- | --------------------------------- | --------------------------------------------------------------------------------------------------- |
| 1     | Payload ID   |       | min: 1, max: 255                  | Component ID of the generic payload. Used in missions only.                                         |
| 2     | Index        |       | min: 1                            | Index of this function on the generic payload.                                                      |
| 3     | Control Mode |       | GENERIC_PAYLOAD_CONTROL_MODE      | Desired Control Mode.                                                                               |
| 4     | Enable       |       | 0: Disable, 1: Enable             | Enable or disable the function.                                                                     |
| 5     | Value Low    |       |                                   | Lower 32 bits of value to set. For 32-bit types, this is the entire value. Little-endian.          |
| 6     | Value High   |       |                                   | Upper 32 bits of value to set. Only used for 64-bit types. Little-endian.                          |
| 7     | Timeout      | ms    | min: 0                            | Timeout for momentary operation if control_mode is GENERIC_PAYLOAD_CONTROL_MODE_MOMENTARY.         |

#### GENERIC_PAYLOAD_TELEMETRY_DESCRIPTION (Message ID: TBD)

Generic payload telemetry channel description, sent on request with MAV_CMD_REQUEST_MESSAGE or MAV_CMD_SET_MESSAGE_INTERVAL, with param2 set to payload_id, and param3 set to function index.

| Field Name  | Type       | Min | Description                                                                 |
| ----------- | ---------- | --- | --------------------------------------------------------------------------- |
| payload_id  | uint8_t    | 1   | Component ID of the generic payload.                                        |
| index       | uint16_t   | 1   | Index of this telemetry channel on the generic payload.                     |
| value_type  | uint8_t    | 0   | Data type for value/min/max fields. See GENERIC_PAYLOAD_VALUE_TYPE.         |
| update_rate | uint8_t    | 0   | Rate at which the value is updated (in Hz). 0 if unknown.                   |
| min_low     | uint8_t[4] | 0   | Lower 32 bits of minimum value. Used for scaling/display. Little-endian.    |
| max_low     | uint8_t[4] | 0   | Lower 32 bits of maximum value. Used for scaling/display. Little-endian.    |
| name        | char[32]   |     | Name of the telemetry channel for UI display. NULL-terminated string.       |
| units       | char[16]   |     | Units for the value field (optional). NULL-terminated string.               |
| min_high    | uint8_t[4] | 0   | Upper 32 bits of minimum value. Only used for 64-bit types. Little-endian.  |
| max_high    | uint8_t[4] | 0   | Upper 32 bits of maximum value. Only used for 64-bit types. Little-endian.  | 

#### GENERIC_PAYLOAD_TELEMETRY_DATA (Message ID: TBD)

Lightweight telemetry data message for streaming single values.

| Field Name | Type       | Min | Description                                                                                |
| ---------- | ---------- | --- | ------------------------------------------------------------------------------------------ |
| payload_id | uint8_t    | 1   | Component ID of the generic payload.                                                       |
| index      | uint16_t   | 1   | Index of this telemetry channel on the generic payload.                                    |
| value_low  | uint8_t[4] | 0   | Lower 32 bits of current value. For 32-bit types, this is the entire value. Little-endian. |
| value_high | uint8_t[4] | 0   | Upper 32 bits of current value. Only used for 64-bit types. Little-endian.                 |

## Appendix B: Illuminator Replacement Example

The following is an example of how an existing protocol, the Illuminator protocol, can be replaced with the Generic Payload protocol. It does incur a small amount of additional overhead, but the benefits of the Generic Payload protocol are worth it to allow for more flexible and extensible payloads.

### GENERIC_PAYLOAD_DESCRIPTION

- payload_id = 1
- num_functions = 5
  - 1 for MAV_CMD_ILLUMINATOR_ON_OFF
  - 4 for the fields in MAV_CMD_DO_ILLUMINATOR_CONFIGURE
- num_telemetry_channels = 0
  - fields in ILLUMINATOR_STATUS map to similar fields in GENERIC_PAYLOAD_STATUS or are FUNCTION values

The following fields in ILLUMINATOR_STATUS map to similar fields in GENERIC_PAYLOAD_STATUS

- uptime_ms
- error_status
- temp_c

The following fields in ILLUMINATOR_STATUS map to functions and therefore to GENERIC_PAYLOAD_FUNCTION_STATUS

- mode
- brightness
- strobe_period (min_strobe_period, max_strobe_period in function description)
- strobe_duty_cycle

### MAV_CMD_ILLUMINATOR_ON_OFF

**GENERIC_PAYLOAD_FUNCTION_DESCRIPTION**

On/Off:
- index = 0
- type = GENERIC_PAYLOAD_FUNCTION_TYPE_LOGICAL
- value_type = GENERIC_PAYLOAD_VALUE_TYPE_UINT32
- enabled = 1
- min_low = 0
- max_low = 1
- control_modes = GENERIC_PAYLOAD_SUPPORTS_LATCHING
- timeout_ms = 0
- name = "On/Off"
- units = ""

**GENERIC_PAYLOAD_FUNCTION_STATUS**

On:
- payload_id = 1
- index = 0
- value_low = union(uint32_t, uint8_t b = 1) -> b

Off:
- payload_id = 1
- index = 0
- value_low = union(uint32_t, uint8_t b = 0) -> b
 
**GENERIC_PAYLOAD_FUNCTION_CONTROL**

On:
- payload_id = 1
- index = 0
- control_mode = GENERIC_PAYLOAD_CONTROL_MODE_LATCHING
- enable = 1
- value_low = union(uint32_t, uint8_t b = 1) -> b

Off:
- payload_id = 1
- index = 0
- control_mode = GENERIC_PAYLOAD_CONTROL_MODE_LATCHING
- enable = 1
- value_low = union(uint32_t, uint8_t b = 0) -> b


### MAV_CMD_DO_ILLUMINATOR_CONFIGURE

#### Mode

**GENERIC_PAYLOAD_FUNCTION_DESCRIPTION**

- index = 1
- type = GENERIC_PAYLOAD_FUNCTION_TYPE_BITMASK
- value_type = GENERIC_PAYLOAD_VALUE_TYPE_BITMASK_8
- enabled = 1
- min_low = 0
- max_low = 2
- control_modes = GENERIC_PAYLOAD_SUPPORTS_LATCHING
- timeout_ms = 0
- name = "Mode"
- units = ""

**GENERIC_PAYLOAD_FUNCTION_STATUS**

Mode at INTERNAL_CONTROL:
- payload_id = 1
- index = 1
- value_low = union(uint32_t, uint8_t b = 1) -> b

**GENERIC_PAYLOAD_FUNCTION_CONTROL**

Mode at EXTERNAL_SYNC:
- payload_id = 1
- index = 1
- control_mode = GENERIC_PAYLOAD_CONTROL_MODE_LATCHING
- enable = 1
- value_low = union(uint32_t, uint8_t b = 2) -> b

#### Brightness

**GENERIC_PAYLOAD_FUNCTION_DESCRIPTION**

- index = 2
- type = GENERIC_PAYLOAD_FUNCTION_TYPE_CONTINUOUS
- value_type = GENERIC_PAYLOAD_VALUE_TYPE_REAL32
- enabled = 1
- min_low = union(uint32_t, float f = 0.0) -> f
- max_low = union(uint32_t, float f = 100.0) -> f
- control_modes = GENERIC_PAYLOAD_SUPPORTS_LATCHING
- timeout_ms = 0
- name = "Brightness"
- units = "%"

**GENERIC_PAYLOAD_FUNCTION_STATUS**

Brightness at 50%:
- payload_id = 1
- index = 2
- value_low = union(uint32_t, float f = 50.0) -> f

**GENERIC_PAYLOAD_FUNCTION_CONTROL**

Brightness set to 75%:
- payload_id = 1
- index = 2
- control_mode = GENERIC_PAYLOAD_CONTROL_MODE_LATCHING
- enable = 1
- value_low = union(uint32_t, float f = 75.0) -> f

#### Strobe Period

**GENERIC_PAYLOAD_FUNCTION_DESCRIPTION**

- index = 3
- type = GENERIC_PAYLOAD_FUNCTION_TYPE_CONTINUOUS
- value_type = GENERIC_PAYLOAD_VALUE_TYPE_REAL32
- enabled = 1
- min_low = union(uint32_t, float f = 0.0) -> f
- max_low = union(uint32_t, float f = float_max) -> f
- control_modes = GENERIC_PAYLOAD_SUPPORTS_LATCHING
- timeout_ms = 0
- name = "Strobe Period"
- units = "s" 

**GENERIC_PAYLOAD_FUNCTION_STATUS**

Strobe Period at 1s:
- payload_id = 1
- index = 3
- value_low = union(uint32_t, float f = 1.0) -> f

**GENERIC_PAYLOAD_FUNCTION_CONTROL**

Strobe Period set to 2s:
- payload_id = 1
- index = 3
- control_mode = GENERIC_PAYLOAD_CONTROL_MODE_LATCHING
- enable = 1
- value_low = union(uint32_t, float f = 2.0) -> f

#### Strobe Duty Cycle

**GENERIC_PAYLOAD_FUNCTION_DESCRIPTION**

- type = GENERIC_PAYLOAD_FUNCTION_TYPE_CONTINUOUS
- value_type = GENERIC_PAYLOAD_VALUE_TYPE_REAL32
- enabled = 1
- min_low = union(uint32_t, float f = 0.0) -> f
- max_low = union(uint32_t, float f = 100.0) -> f
- control_modes = GENERIC_PAYLOAD_SUPPORTS_LATCHING
- timeout_ms = 0
- name = "Strobe Duty Cycle"
- units = "%" 

**GENERIC_PAYLOAD_FUNCTION_STATUS**

Strobe Duty Cycle at 50%:
- payload_id = 1
- index = 4
- value_low = union(uint32_t, float f = 50.0) -> f

**GENERIC_PAYLOAD_FUNCTION_CONTROL**

Strobe Duty Cycle set to 75%:
- payload_id = 1
- index = 4
- control_mode = GENERIC_PAYLOAD_CONTROL_MODE_LATCHING
- enable = 1
- value_low = union(uint32_t, float f = 75.0) -> f

## Appendix C: Alternatives Considered

### Alternative 1: Extend Existing Payload Commands

Build upon the current [MAVLink payload services](https://mavlink.io/en/services/payload.html) by adding more generic commands and standardizing implementation.
**Analysis**: The existing `MAV_CMD_DO_SET_ACTUATOR` and `MAV_CMD_DO_SET_SERVO` commands could theoretically be extended with additional parameters for type information and metadata.

**Key Limitations**:

- Commands are stateless and don't provide discovery mechanisms
- Inconsistent implementation across flight stacks ("only implemented on PX4")
- Limited parameter space in command messages prevents rich metadata
- No built-in telemetry streaming capabilities
- Would require significant breaking changes to existing command semantics

### Alternative 2: Parameter-Only Approach

Use MAVLink's parameter system (`PARAM_*` messages) to expose payload functions as parameters.

**Analysis**: Parameters provide get/set functionality and some metadata (min/max, type). Could potentially expose payload functions as settable parameters.

**Key Limitations**:

- Parameters are designed for configuration, not real-time control
- No standardized discovery of which parameters belong to payloads
- Limited data types (mostly float32)
- No support for momentary operations or complex control modes
- Parameter namespace pollution with payload-specific entries
- No built-in telemetry streaming for sensor data

### Alternative 3: Extend Component Information Service

Build upon the [MAVLink Component Information Service](https://mavlink.io/en/services/component_information.html) to include payload metadata and add control messages.

**Analysis**: The component information service provides sophisticated metadata discovery through JSON files and supports actuator configuration. This could potentially be extended to describe payload capabilities.

**Key Limitations**:

- Currently "work in progress" with limited adoption
- Designed for static configuration metadata, not dynamic control
- Requires external file hosting or on-device storage for metadata
- JSON parsing overhead for simple operations
- No real-time control or telemetry streaming mechanisms
- Metadata assumed invariant after boot, limiting dynamic payloads

## Unresolved Questions

1. **Message ID Range**: Should we request official MAVLink message IDs or remain in vendor-specific range?
2. **Backward Compatibility**: How should payloads indicate protocol version support?
3. **Performance Limits**: What are reasonable limits for number of functions/telemetry channels per payload?
4. **Rate Control**: How should high-rate telemetry interact with existing MAVLink rate limiting mechanisms?
5. **Error Recovery**: Should we define standard error recovery procedures for failed commands?

## References

- [MAVLink Message Definition Standard](https://mavlink.io/en/guide/define_xml_element.html)
- [MAVLink Common Message Set](https://mavlink.io/en/messages/common.html)
- [Existing Payload Interfaces in MAVLink](https://mavlink.io/en/messages/common.html#camera-protocol)
- [MAVLink Extension Fields](https://mavlink.io/en/guide/message_definitions.html#extension_fields)
- [MAVLink Message Rate Control](https://mavlink.io/en/messages/common.html#MAV_CMD_SET_MESSAGE_INTERVAL)