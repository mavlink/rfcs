# Messages

## DISPERSION_DEVICE_INFORMATION

Information about a dispersion device. This message should be requested by a source such as the ground control station using [MAV_CMD_REQUEST_MESSAGE](https://mavlink.io/en/messages/common.html#MAV_CMD_REQUEST_MESSAGE). The min/max limits are driven by the underlying hardware. Software defined limits will be a subset of the limits specified here.

| Field Name          | Type       |        Units         | Values                                                      | Description                                                                                                                                                     |
| :------------------ | :--------- | :------------------: | :---------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| timestamp_us        | `uint64_t` |          us          |                                                             | Unix time stamp in microseconds                                                                                                                                 |
| vendor_name         | `char[32]` |                      |                                                             | Name of the payload vendor                                                                                                                                      |
| model_name          | `char[32]` |                      |                                                             | Name of the payload model                                                                                                                                       |
| custom_name         | `char[32]` |                      |                                                             | Custom name given by the user                                                                                                                                   |
| firmware_version    | `uint32_t` |                      |                                                             | Version of the payload firmware, encoded as: (Dev & 0xff) << 24                                                                                                 |
| hardware_version    | `uint32_t` |                      |                                                             | Version of the payload hardware, encoded as: (Dev & 0xff) << 24                                                                                                 |
| uid                 | `uint64_t` |                      | Invalid:0                                                   | Integer to uniquely identify this hardware. (0 if unknown)                                                                                                      |
| cap_flags           | `uint16_t` |                      | [DISPERSION_DEVICE_CAP_FLAGS](#dispersion_device_cap_flags) | Bitmap of dispersion device capability flags.                                                                                                                   |
| custom_cap_flags    | `uint16_t` |                      |                                                             | Bitmap for use for dispersion-specific capability flags. flags.                                                                                                 |
| logger_dir_ftp_url  | `char[64]` |                      |                                                             | File transfer protocol (FTP) url-like string pointing to the directory of log files                                                                             |
| dispersion_rate_min | `float`    | liters/min or kg/min | invalid:NaN                                                 | Minimum dispersion rate this device can support. Units are determined based on the DISPERSION_DEVICE_CAP_FLAGS. (liters/min or kg/min)                          |
| dispersion_rate_max | `float`    | liters/min or kg/min | invalid:NaN                                                 | Maximum dispersion rate this device can support. Units are determined based on the DISPERSION_DEVICE_CAP_FLAGS. (liters/min or kg/min)                          |
| pressure_min        | `uint32_t` |          Pa          | invalid:UINT32_MAX                                          | If this is a spray dispersion system, minimum pressure the hardware supports independent of nozzle configuration                                                |
| pressure_max        | `uint32_t` |          Pa          | invalid:UINT32_MAX                                          | If this is a spray dispersion system, maximum pressure the hardware supports independent of nozzle configuration                                                |
| max_capacity        | `float`    |     liters or kg     | invalid:NaN                                                 | Maximum fill capacity of this device in Liters for sprayers and Kg for spreaders. Units are determined based on the DISPERSION_DEVICE_CAP_FLAGS. (liters or kg) |

## DISPERSION_DEVICE_STATUS

Message reporting the status of a dispersion device.

This message should be published a low regular rate (e.g. 5 Hz) but also during key events such as a mavlink command, flag change, or rapid pressure change.

| Field Name      | Type       |        Units         | Values                                                            | Description                                                                                                                                                                                                  |
| :-------------- | :--------- | :------------------: | :---------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| timestamp_us    | `uint64_t` |          us          |                                                                   | Unix time stamp in microseconds                                                                                                                                                                              |
| dispersion_type | `uint32_t` |                      | [MAV_DISPERSION_TYPE](#mav_dispersion_type)                       | Dispersion type. Defines units for device capacity and dispersion rate                                                                                                                                       |
| flags           | `uint16_t` |                      | [DISPERSION_DEVICE_STATUS_FLAGS](#dispersion_device_status_flags) | Current flags set by the device                                                                                                                                                                              |
| failure_flags   | `uint32_t` |                      | [DISPERSION_DEVICE_ERRORS](#dispersion_device_errors)             | Failure flags (0 for no failure). Any failure indicates the system has stopped                                                                                                                               |
| warning_flags   | `uint32_t` |                      | [DISPERSION_DEVICE_WARNINGS](#dispersion_device_warnings)         | Warning flags (0 for no warning)                                                                                                                                                                             |
| custom_codes    | `uint8_t`  |                      |                                                                   | Leave some flexibility for device manufacturers to pass more information through. This gives up to 255 codes to represent internal system state.                                                             |
| dispersion_rate | `float`    | liters/min or kg/min | invalid:NaN                                                       | Current dispersion rate of the device. Negative during refill. Units are determined based on the MAV_DISPERSION_TYPE. (liters/min or kg/min)                                                                 |
| fill_level      | `float`    |     liters or kg     | invalid:NaN                                                       | Current tank fill level. This field should be ignored if the device capability flags indicate fill level measurement is not supported. Units are determined based on the MAV_DISPERSION_TYPE. (liters or kg) |
| pressure        | `uint32_t` |          Pa          | invalid:UINT32_MAX                                                | Current pressure of the dispersion system if dispersion type indicates it is a sprayer                                                                                                                       |

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

| Value | Name                        | Description                                                                                                         |
| :---- | :-------------------------- | :------------------------------------------------------------------------------------------------------------------ |
| 0     | MAV_DISPERSION_TYPE_UNKNOWN | Not specified                                                                                                       |
| 1     | MAV_DISPERSION_TYPE_SPRAY   | A generic liquid payload is being dispersed. Units are in Liters for capacity and Liters/min for dispersion rate    |
| 2     | MAV_DISPERSION_TYPE_SPREAD  | A generic solid payload of granules is being dispersed. Units are in Kg for capacity and Kg/min for dispersion rate |

## DISPERSION_DEVICE_CAP_FLAGS

(Bitmask) Dispersion device (low level) capability flags (bitmap).

| Value | Name                                                  | Description                                                                       |
| :---- | :---------------------------------------------------- | :-------------------------------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_CAP_FLAGS_SPRAYER                   | Device supports dispersing liquid payloads.                                       |
| 2     | DISPERSION_DEVICE_CAP_FLAGS_SPREADER                  | Device supports dispersing granular payloads.                                     |
| 4     | DISPERSION_DEVICE_CAP_FLAGS_DYNAMIC_SPEED_CORRECTIONS | Device supports varying dispersion rate with speed changes up to provided limits. |
| 8     | DISPERSION_DEVICE_CAP_FILL_LEVEL_MEASURE              | Device supports measuring its own fill level.                                     |

## DISPERSION_DEVICE_STATUS_FLAGS

(Bitmask) Flags for the dispersion device (lower level) operation. These flags work together to communicate dispersion device state.

| Value | Name                                             | Description                                                    |
| :---- | :----------------------------------------------- | :------------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_STATUS_FLAGS_DISPERSION_ACTIVE | Dispersion device is delivering payload                        |
| 2     | DISPERSION_DEVICE_STATUS_FLAGS_LOCKED            | Dispersion device is locked and wont respond to control inputs |
| 4     | DISPERSION_DEVICE_STATUS_FLAGS_CONFIGURED        | System has necessary parameters to properly disperse payload   |
| 8     | DISPERSION_DEVICE_STATUS_FLAGS_FILL_AT_TARGET    | Dispersion device tank is filled to target amount              |

## DISPERSION_DEVICE_ERRORS

(Bitmask) Dispersion device error flags. Any error flag indicates the device has turned off.

| Value | Name                                                | Description                                                 |
| :---- | :-------------------------------------------------- | :---------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_ERRORS_UNKNOWN                    | Device has had an unknown error                             |
| 2     | DISPERSION_DEVICE_ERRORS_CLOGGED                    | Device is clogged                                           |
| 4     | DISPERSION_DEVICE_ERRORS_MOTOR_FAILURE              | Device dispersion motor or pump has failed                  |
| 8     | DISPERSION_DEVICE_ERRORS_IMPROPER_CONFIGURATION     | Device configuration is not compatible with device limits   |
| 16    | DISPERSION_DEVICE_ERRORS_OVERSPEED                  | System is moving faster than the device can deliver         |
| 32    | DISPERSION_DEVICE_ERRORS_UNDERSPEED                 | System is moving slower than the device can support         |
| 64    | DISPERSION_DEVICE_ERRORS_UNEXPECTED_FILL            | Device tank was filled to an unexpected level               |
| 128   | DISPERSION_DEVICE_ERRORS_NO_CONFIGURATION           | Device was not configured before trying to disperse payload |
| 256   | DISPERSION_DEVICE_ERRORS_LEAK                       | Device is not maintaining pressure as expected              |
| 512   | DISPERSION_DEVICE_ERRORS_UNEXPECTED_FLIGHT_BEHAVIOR | Device detected an unexpected event like a crash            |

## DISPERSION_DEVICE_WARNINGS

(Bitmask) Dispersion device warning flags. Any warning flag indicates an issue that does not block operation of the device.

| Value | Name                                                  | Description                                            |
| :---- | :---------------------------------------------------- | :----------------------------------------------------- |
| 1     | DISPERSION_DEVICE_WARNINGS_UNKNOWN                    | Device has had an unknown warning                      |
| 2     | DISPERSION_DEVICE_WARNINGS_LOG_FULL                   | Device log file has reached its memory limit.          |
| 4     | DISPERSION_DEVICE_WARNINGS_FILL_LEVEL_DETECTOR_BROKEN | There is an issue with the fill level detector system. |

# Commands

## MAV_CMD_DO_CONFIG_DISPERSION_PARAMS

This command provides the necessary run time information for the dispersion device to support a specific configuration associated with the target dispersion profile.

| Param (Label)         | Description                                                                                                                                                                                          | Values                                      |
| :-------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------ |
| 1 dispersion_type     | The type of dispersion this device supports. This indicates target units as outlined in enum                                                                                                         | [MAV_DISPERSION_TYPE](#mav_dispersion_type) |
| 2 reference_speed     | The target speed for which any target dispersion rate applies, since the rate should change with speed                                                                                               | Invalid:NaN Units: m/s                      |
| 3 dispersion_rate_min | Minimum dispersion rate the current configuration supports. Units are determined based on the MAV_DISPERSION_TYPE. (liters/min or kg/min)                                                            |
| 4 dispersion_rate_max | Maximum dispersion rate the current configuration supports. Units are determined based on the MAV_DISPERSION_TYPE. (liters/min or kg/min)                                                            |
| 5 pressure_min        | If this is a spray dispersion system, minimum pressure the current configuration supports                                                                                                            | Invalid:NaN, <0 Units:Pa                    |
| 6 pressure_max        | If this is a spray dispersion system, maximum pressure the current configuration supports                                                                                                            | Invalid:NaN, <pressure_min Units:Pa         |
| 7 target_fill_level   | Target payload amount for device. This will be ignored if the capability flags do not indicate fill level measurement support. Units are determined based on the MAV_DISPERSION_TYPE. (liters or kg) |

## MAV_CMD_DO_SET_DISPERSION_RATE

Command to provide real time adjustment to dispersion device output for a given dispersion profile configured using [MAV_CMD_DO_CONFIG_DISPERSION_PARAMS](#mav-cmd-do-config-dispersion-params).

| Param (Label)            | Description                                                                                                          | Values                                      |
| :----------------------- | :------------------------------------------------------------------------------------------------------------------- | :------------------------------------------ |
| 1 timestamp_us           | The unix timestamp for message creation                                                                              | Unix timestamp in microseconds              |
| 2 dispersion_type        | The type of dispersion this device supports. This indicates units as outlined in enum                                | [MAV_DISPERSION_TYPE](#mav_dispersion_type) |
| 3 target_dispersion_rate | Target dispersion rate for the system. Units are determined based on the MAV_DISPERSION_TYPE. (liters/min or kg/min) |
| 4                        | Empty.                                                                                                               |                                             |
| 5                        | Empty.                                                                                                               |                                             |
| 6                        | Empty.                                                                                                               |                                             |
| 7                        | Empty.                                                                                                               |                                             |

## MAV_CMD_DO_SET_DISPERSION_LOCK

Command for locking/unlocking the device from responding to [MAV_CMD_DO_SET_DISPERSION_RATE](#mav-cmd-do-set-dispersion-rate) messages. When locked, the device should stop dispersing.

| Param (Label)  | Description                                                                                                                 | Values                                    |
| :------------- | :-------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------- |
| 1 timestamp_us | The unix timestamp for message creation                                                                                     | Unix timestamp in microseconds            |
| 2 lock         | Stop dispersion and prevent the dispersion device from responding to input for live dispersion rate changes until unlocked. | 1 to lock. 0 or any other value to unlock |
| 3              | Empty.                                                                                                                      |                                           |
| 4              | Empty.                                                                                                                      |                                           |
| 5              | Empty.                                                                                                                      |                                           |
| 6              | Empty.                                                                                                                      |                                           |
| 7              | Empty.                                                                                                                      |                                           |
