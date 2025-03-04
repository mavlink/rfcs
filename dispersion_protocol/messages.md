# Messages

## DISPERSION_DEVICE_INFORMATION

Information about a dispersion device. This message should be requested by a source such as the ground control station using [MAV_CMD_REQUEST_MESSAGE](https://mavlink.io/en/messages/common.html#MAV_CMD_REQUEST_MESSAGE). The min/max limits are driven by the underlying hardware. Software defined limits will be a subset of the limits specified here.

| Field Name           | Type       |        Units         | Values                                                      | Description                                                                                                                                                                      |
| :------------------- | :--------- | :------------------: | :---------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| timestamp_us         | `uint64_t` |          us          |                                                             | Unix time stamp in microseconds                                                                                                                                                  |
| subcomponent_id      | `uint8_t`  |                      |                                                             | Subcomponent id (ie nozzle) this message is associated with, 0 represents the entire device. Send information multiple times for multiple subcomponents.                         |
| subcomponent_count   | `uint8_t`  |                      | invalid:UINT8_MAX                                           | Number of controllable subcomponents this dispersion device has. (ie variable nozzle bodies or boom segment control). 0 or 1 indicates the subcomponent and device are the same. |
| cap_flags            | `uint16_t` |                      | [DISPERSION_DEVICE_CAP_FLAGS](#dispersion_device_cap_flags) | Bitmap of dispersion device or subcomponent capability flags.                                                                                                                    |
| custom_cap_flags     | `uint16_t` |                      |                                                             | Bitmap for use for dispersion-specific capability flags.                                                                                                                         |
| workspace_ftp_url    | `char[64]` |                      |                                                             | File transfer protocol (FTP) url-like string pointing to the workspace directory for device. You can find the param file, logging files, and prescription files located here.    |
| dispersion_rate_min  | `float`    | liters/min or kg/min | invalid:NaN                                                 | Minimum dispersion rate this device can support. Units are determined based on the DISPERSION_DEVICE_CAP_FLAGS. (liters/min or kg/min)                                           |
| dispersion_rate_max  | `float`    | liters/min or kg/min | invalid:NaN                                                 | Maximum dispersion rate this device can support. Units are determined based on the DISPERSION_DEVICE_CAP_FLAGS. (liters/min or kg/min)                                           |
| capacity_max         | `float`    |     liters or kg     | invalid:NaN                                                 | Maximum fill capacity of this device in Liters for sprayers and Kg for spreaders. Units are determined based on the DISPERSION_DEVICE_CAP_FLAGS. (liters or kg)                  |
| pressure_min         | `uint32_t` |          Pa          | invalid:UINT32_MAX                                          | If this is a spray dispersion system, minimum pressure the hardware supports independent of nozzle configuration                                                                 |
| pressure_max         | `uint32_t` |          Pa          | invalid:UINT32_MAX                                          | If this is a spray dispersion system, maximum pressure the hardware supports independent of nozzle configuration                                                                 |
| droplet_diameter_min | `uint16_t` |     um (microns)     | invalid: 0                                                  | Minimum supported droplet diameter if system supports variable droplet size nozzles                                                                                              |
| droplet_diameter_max | `uint16_t` |     um (microns)     | invalid: 0                                                  | Maximum supported droplet diameter if system supports variable droplet size nozzles                                                                                              |

## DISPERSION_DEVICE_STATUS

Message reporting the status of a dispersion device and its subcomponents.

This message should be published at a low regular rate (e.g. 5 Hz) but also during key events such as a mavlink command, flag change, or rapid pressure change. If a message creation is in response to a key event, the timestamp field should note when the key event occurred and not when the message was created. For all other status messages, the timestamp should just be when the message gets created.

| Field Name       | Type       |        Units         | Values                                                    | Description                                                                                                                                                                                                         |
| :--------------- | :--------- | :------------------: | :-------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| timestamp_us     | `uint64_t` |          us          |                                                           | Unix time stamp in microseconds                                                                                                                                                                                     |
| subcomponent_id  | `uint8_t`  |                      |                                                           | Subcomponent id (ie nozzle) this message is associated with, 0 represents the entire device. Send status multiple times for multiple subcomponents.                                                                 |
| dispersion_type  | `uint8_t`  |                      | [MAV_DISPERSION_TYPE](#mav_dispersion_type)               | Dispersion type. Defines units for device capacity and dispersion rate                                                                                                                                              |
| state            | `uint8_t`  |                      | [DISPERSION_DEVICE_STATE](#dispersion_device_state)       | Code representing current device state                                                                                                                                                                              |
| error_code       | `uint8_t`  |                      | [DISPERSION_DEVICE_ERRORS](#dispersion_device_errors)     | An error code indicating what specific fatal error has occurred to halt the device from functioning                                                                                                                 |
| warning_flags    | `uint16_t` |                      | [DISPERSION_DEVICE_WARNINGS](#dispersion_device_warnings) | Warning flags (0 for no warning)                                                                                                                                                                                    |
| custom_codes     | `uint8_t`  |                      |                                                           | Leave some flexibility for device manufacturers to pass more information through. This gives up to 255 codes to represent internal system state.                                                                    |
| fill_level       | `float`    |     liters or kg     | invalid:NaN                                               | Current device tank fill level. This field should be ignored if the device capability flags indicate fill level measurement is not supported. Units are determined based on the MAV_DISPERSION_TYPE. (liters or kg) |
| dispersion_rate  | `float`    | liters/min or kg/min | invalid:NaN                                               | Current dispersion rate of the device. Negative during refill. Units are determined based on the MAV_DISPERSION_TYPE. (liters/min or kg/min)                                                                        |
| pressure         | `uint32_t` |          Pa          | invalid:UINT32_MAX                                        | Current pressure of the dispersion system if dispersion type indicates it is a sprayer                                                                                                                              |
| droplet_diameter | `uint16_t` |     um (microns)     | invalid: 0                                                | Current droplet size if dispersion_type is MAV_DISPERSION_TYPE_SPRAY_VARIABLE_SIZE                                                                                                                                  |

# Enumerated Types

## MAV_TYPE

MAVLINK component type reported in HEARTBEAT message. Flight controllers must report the type of the vehicle on which they are mounted (e.g. MAV_TYPE_OCTOROTOR). All other components must report a value appropriate for their type (e.g. a camera must use MAV_TYPE_CAMERA).

| Value | Name                | Description                          |
| :---- | :------------------ | :----------------------------------- |
| ...   | ...                 | ...                                  |
| 45    | MAV_TYPE_DISPERSION | A device that can disperse a payload |

## MAV_COMPONENT

Component ids (values) for the different types and instances of onboard hardware/software that might make up a MAVLink system (autopilot, cameras, servos, GPS systems, avoidance systems etc.).

Components must use the appropriate ID in their source address when sending messages. Components can also use IDs to determine if they are the intended recipient of an incoming message. The MAV_COMP_ID_ALL value is used to indicate messages that must be processed by all components. When creating new entries, components that can have multiple instances (e.g. cameras, servos etc.) should be allocated sequential values. An appropriate number of values should be left free after these components to allow the number of instances to be expanded.

| Value | Name                   | Description          |
| :---- | :--------------------- | :------------------- |
| ...   | ...                    | ...                  |
| 110   | MAV_COMP_ID_DISPERSION | Dispersion device #1 |
| ...   | ...                    | ...                  |

## MAV_DISPERSION_TYPE

The dispersion type a device is setup for. Dispersion types specify the units for capacity and dispersion rate.

| Value | Name                                    | Description                                                                                                                                                                                               |
| :---- | :-------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0     | MAV_DISPERSION_TYPE_UNKNOWN             | Not specified                                                                                                                                                                                             |
| 1     | MAV_DISPERSION_TYPE_SPRAY_FIXED_SIZE    | A generic liquid payload is being dispersed via fixed droplet size nozzles. Units are in Liters for capacity and Liters/min for dispersion rate                                                           |
| 2     | MAV_DISPERSION_TYPE_SPRAY_VARIABLE_SIZE | A generic liquid payload is being dispersed via a nozzle that supports variable droplet sizes. Units are in Liters for capacity, Liters/min for dispersion rate, and micrometers for target droplet size. |
| 3     | MAV_DISPERSION_TYPE_SPREAD              | A generic solid payload of granules is being dispersed. Units are in Kg for capacity and Kg/min for dispersion rate                                                                                       |

## MAV_DISPERSION_FRAME

The reference frame for dispersion device command values.

| Value | Name                          | Description                                                                                               |
| :---- | :---------------------------- | :-------------------------------------------------------------------------------------------------------- |
| 0     | MAV_DISPERSION_FRAME_UNKNOWN  | Not specified.                                                                                            |
| 1     | MAV_DISPERSION_FRAME_ABSOLUTE | Dispersion device control values should be set to the exact values provided in control message.           |
| 2     | MAV_DISPERSION_FRAME_OFFSET   | Default dispersion device control values should be offset by the amount specified in the control message. |

## DISPERSION_DEVICE_CAP_FLAGS

(Bitmask) Dispersion device (low level) capability flags (bitmap).

| Value | Name                                                  | Description                                                                       |
| :---- | :---------------------------------------------------- | :-------------------------------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_CAP_FLAGS_SPRAYER                   | Device supports dispersing liquid payloads.                                       |
| 2     | DISPERSION_DEVICE_CAP_FLAGS_SPREADER                  | Device supports dispersing granular payloads.                                     |
| 4     | DISPERSION_DEVICE_CAP_FLAGS_VARIABLE_DROP_SIZE        | Device supports control of droplet size at individual nozzles.                    |
| 8     | DISPERSION_DEVICE_CAP_FLAGS_DYNAMIC_SPEED_CORRECTIONS | Device supports varying dispersion rate with speed changes up to provided limits. |
| 16    | DISPERSION_DEVICE_CAP_FILL_LEVEL_MEASURE              | Device supports measuring its own fill level.                                     |

## DISPERSION_DEVICE_STATE

Dispersion device states as unique identified codes.

| Value | Name                                | Description                                             |
| :---- | :---------------------------------- | :------------------------------------------------------ |
| 0     | DISPERSION_DEVICE_STATE_UNKNOWN     | Device state is unknown.                                |
| 1     | DISPERSION_DEVICE_STATE_READY       | Dispersion device is ready for control inputs.          |
| 2     | DISPERSION_DEVICE_STATE_ACTIVE      | Dispersion device is delivering payload.                |
| 3     | DISPERSION_DEVICE_STATE_LOCKED      | Dispersion device is locked and wont respond to inputs. |
| 4     | DISPERSION_DEVICE_STATE_FATAL_ERROR | Dispersion device has a fatal error blocking operation. |
| 5     | DISPERSION_DEVICE_STATE_RESUPPLYING | Dispersion device is being supplied for next mission.   |

## DISPERSION_DEVICE_ERRORS

Dispersion device error codes. A non-zero value indicates the device has a fatal error and has turned off.

| Value | Name                                                 | Description                                          |
| :---- | :--------------------------------------------------- | :--------------------------------------------------- |
| 0     | DISPERSION_DEVICE_ERRORS_NO_ERRORS                   | Device has no errors.                                |
| 1     | DISPERSION_DEVICE_ERRORS_UNKNOWN                     | Device has had an unknown error.                     |
| 2     | DISPERSION_DEVICE_ERRORS_CLOGGED                     | Device is clogged.                                   |
| 3     | DISPERSION_DEVICE_ERRORS_MOTOR_FAILURE               | Device dispersion motor or pump has failed.          |
| 4     | DISPERSION_DEVICE_ERRORS_IMPROPER_CONFIGURATION      | Device configuration is not compatible with limits.  |
| 5     | DISPERSION_DEVICE_ERRORS_OVERSPEED                   | System is moving faster than the device can deliver. |
| 6     | DISPERSION_DEVICE_ERRORS_UNDERSPEED                  | System is moving slower than the device can support. |
| 7     | DISPERSION_DEVICE_ERRORS_LEAK                        | Device is not maintaining pressure as expected.      |
| 8     | DISPERSION_DEVICE_ERRORS_UNEXPECTED_VEHICLE_BEHAVIOR | Device detected an unexpected event like a crash.    |
| 9     | DISPERSION_DEVICE_ERRORS_FILL_EMPTY                  | Device ran out of its payload.                       |

## DISPERSION_DEVICE_WARNINGS

(Bitmask) Dispersion device warning flags. Any warning flag indicates an issue that does not block operation of the device.

| Value | Name                                                         | Description                                             |
| :---- | :----------------------------------------------------------- | :------------------------------------------------------ |
| 1     | DISPERSION_DEVICE_WARNINGS_UNKNOWN                           | Device has had an unknown warning                       |
| 2     | DISPERSION_DEVICE_WARNINGS_LOG_FULL                          | Device log file has reached its memory limit.           |
| 4     | DISPERSION_DEVICE_WARNINGS_CLAMPED_DROPLET_SIZE              | An unsupported droplet size was requested and clamped.  |
| 8     | DISPERSION_DEVICE_WARNINGS_UNEXPECTED_FILL_LEVEL_MEASUREMENT | Dispersion device was filled to an unexpected level.    |
| 16    | DISPERSION_DEVICE_WARNINGS_FILL_LEVEL_MEASURE_BROKEN         | There is an issue with the fill level measuring system. |

# Commands

## MAV_CMD_DO_SET_DISPERSION_TARGETS

Command to provide real time adjustment to a dispersion device and its subcomponents. This can be sent from any source including during automated missions.

| Param (Label)            | Description                                                                                                                                                       | Values                                             |
| :----------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------- |
| 1 timestamp_us           | The unix timestamp for message creation                                                                                                                           | Unix timestamp in microseconds                     |
| 2 device_id              | Component ID of dispersion device to address, 0 for all dispersion device components. Send command multiple times for more than one device (but not all devices). | [MAV_COMPONENT](#mav_component)                    |
| 3 subcomponent_id        | Subcomponent id (ie nozzle) to address, 0 for all subcomponents. Send command multiple times for multiple subcomponents.                                          |                                                    |
| 4 dispersion_type        | The type of dispersion this device supports. This indicates units as outlined in enum                                                                             | [MAV_DISPERSION_TYPE](#mav_dispersion_type)        |
| 5 dispersion_frame       | The reference frame for the provided target values that allows use of relative or absolute corrections.                                                           | [MAV_DISPERSION_FRAME](#mav_dispersion_frame)      |
| 6 target_dispersion_rate | Target dispersion rate for the system. Units are determined based on the MAV_DISPERSION_TYPE. (liters/min or kg/min)                                              |                                                    |
| 7 target_droplet_size_um | Target droplet size for spray nozzles if dispersion type indicates atomizer spray                                                                                 | Invalid:NaN, <=0. Droplet diameter in micrometers. |

## MAV_CMD_SET_DISPERSION_LOCK

Command for locking/unlocking the device from responding to [MAV_CMD_DO_SET_DISPERSION_TARGETS](#mav_cmd_do_set_dispersion_targets) messages. When locked, the device or targeted subcomponent should stop dispersing.

| Param (Label)     | Description                                                                                                                                                       | Values                                    |
| :---------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------- |
| 1 timestamp_us    | The unix timestamp for message creation                                                                                                                           | Unix timestamp in microseconds            |
| 2 device_id       | Component ID of dispersion device to address, 0 for all dispersion device components. Send command multiple times for more than one device (but not all devices). | [MAV_COMPONENT](#mav_component)           |
| 3 subcomponent_id | Subcomponent id (ie nozzle) to address, 0 for all subcomponents. Send command multiple times for multiple subcomponents.                                          |                                           |
| 4 lock            | Stop dispersion and prevent the dispersion device from responding to input for live dispersion rate changes until unlocked.                                       | 1 to lock. 0 or any other value to unlock |
| 5                 | Empty.                                                                                                                                                            |                                           |
| 6                 | Empty.                                                                                                                                                            |                                           |
| 7                 | Empty.                                                                                                                                                            |                                           |
