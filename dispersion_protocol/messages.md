# Messages

## DISPERSION_DEVICE_INFORMATION

Information about a low level dispersion device. This message should be requested by a source such as the ground control station using [MAV_CMD_REQUEST_MESSAGE](https://mavlink.io/en/messages/common.html#MAV_CMD_REQUEST_MESSAGE). The min/max limits for dispersion rate are driven by the underlying hardware. Software defined limits will be a subset of the limits specified here.

| Field Name          | Type       |        Units         | Values                                                      | Description                                                                                                      |
| :------------------ | :--------- | :------------------: | :---------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| timestamp_ns        | `uint64_t` |          ns          |                                                             | Unix time stamp                                                                                                  |
| vendor_name         | `char[32]` |                      |                                                             | Name of the payload vendor                                                                                       |
| model_name          | `char[32]` |                      |                                                             | Name of the payload model                                                                                        |
| custom_name         | `char[32]` |                      |                                                             | Custom name given by the user                                                                                    |
| firmware_version    | `uint32_t` |                      |                                                             | Version of the payload firmware, encoded as: (Dev & 0xff) << 24                                                  |
| hardware_version    | `uint32_t` |                      |                                                             | Version of the payload hardware, encoded as: (Dev & 0xff) << 24                                                  |
| uid                 | `uint64_t` |                      | Invalid:0                                                   | Integer to uniquely identify this hardware. (0 if unknown)                                                       |
| cap_flags           | `uint16_t` |                      | [DISPERSION_DEVICE_CAP_FLAGS](#dispersion_device_cap_flags) | Bitmap of dispersion device capability flags.                                                                    |
| custom_cap_flags    | `uint16_t` |                      |                                                             | Bitmap for use for dispersion-specific capability flags. flags.                                                  |
| dispersion_rate_min | `float`    | liters/min or kg/min | invalid:NaN, <0                                             | Minimum dispersion rate this device can support                                                                  |
| dispersion_rate_max | `float`    | liters/min or kg/min | invalid:NaN, <=0                                            | Maximum dispersion rate this device can support                                                                  |
| pressure_min        | `uint32_t` |          Pa          |                                                             | If this is a spray dispersion system, minimum pressure the hardware supports independent of nozzle configuration |
| pressure_max        | `uint32_t` |          Pa          | invalid:0                                                   | If this is a spray dispersion system, maximum pressure the hardware supports independent of nozzle configuration |

## DISPERSION_DEVICE_STATUS

Message reporting the low level status of a dispersion device.

This message should be published a low regular rate (e.g. 5 Hz) but also during key events such a flag change. It should also be published in response to a request.

| Field Name        | Type       |        Units         | Values                                                            | Description                                                                    |
| :---------------- | :--------- | :------------------: | :---------------------------------------------------------------- | :----------------------------------------------------------------------------- |
| timestamp_ns      | `uint64_t` |          ns          |                                                                   | Unix time stamp                                                                |
| flags             | `uint16_t` |                      | [DISPERSION_DEVICE_STATUS_FLAGS](#dispersion_device_status_flags) | Current flags set by the device                                                |
| failure_flags     | `uint32_t` |                      | [DISPERSION_DEVICE_ERRORS](#dispersion_device_errors)             | Failure flags (0 for no failure). Any failure indicates the system has stopped |
| warning_flags     | `uint32_t` |                      | [DISPERSION_DEVICE_WARNINGS](#dispersion_device_warnings)         | Warning flags (0 for no warning)                                               |
| custom_codes      | `uint8_t`  |                      |                                                                   | Leave some flexibility for device specific custom state reporting              |
| dispersion_rate   | `float`    | liters/min or kg/min | invalid:<0                                                        | Current dispersion rate of the device                                          |
| fill_level        | `uint16_t` |     liters or kg     |                                                                   | Current tank fill level.                                                       |
| pressure          | `uint32_t` |          Pa          |                                                                   | Current pressure of the dispersion system                                      |
| request_signature | `char[6]`  |                      | invalid:[0]                                                       | Message signature for most recently processed device request.                  |

## DISPERSION_DEVICE_REQUEST

Low level message to control a dispersion device. The core set of requests are on, off, and auto. Manual on immediately turns the system on at the configured rate until it is turned off. Manual off turns off the system immediately and makes the system ignore any corrections comming from an automated system. Only on use of the auto request will the system be configured and ready for automatic input again. All three request types are necessary to effectively handle emergency situations. These requests are acked through the [DISPERSION_DEVICE_STATUS](#dispersion_device_status) message request_signature field.

| Field Name             | Type       |        Units         | Values                                                    | Description                                                                               |
| :--------------------- | :--------- | :------------------: | :-------------------------------------------------------- | :---------------------------------------------------------------------------------------- |
| target_system          | `uint8_t`  |                      |                                                           | System ID uniquely identifying the vehicle this payload device is attached to             |
| target_component       | `uint8_t`  |                      |                                                           | Component ID uniquely identifying this device on the system                               |
| timestamp_ns           | `uint64_t` |          ns          |                                                           | Unix time stamp                                                                           |
| requests               | `uint16_t` |                      | [DISPERSION_DEVICE_REQUESTS](#dispersion_device_requests) | Request changes to dispersion device                                                      |
| target_speed           | `float`    |         m/s          |                                                           | Target system speed for target dispersion rate                                            |
| target_dispersion_rate | `float`    | liters/min or kg/min | invalid:NaN                                               | Target system dispersion rate within the range specified below.                           |
| target_fill_level      | `uint16_t` |     liters or kg     |                                                           | Target dispersion device payload amount for mission                                       |
| dispersion_rate_min    | `float`    | liters/min or kg/min | invalid:NaN                                               | Minimum dispersion rate the current configuration supports                                |
| dispersion_rate_max    | `float`    | liters/min or kg/min | invalid:NaN                                               | Maximum dispersion rate the current configuration supports                                |
| pressure_min           | `uint32_t` |          Pa          |                                                           | If this is a spray dispersion system, minimum pressure the current configuration supports |
| pressure_max           | `uint32_t` |          Pa          | invalid:0                                                 | If this is a spray dispersion system, maximum pressure the current configuration supports |

> [!IMPORTANT]
> We must provide limits for pressure and rate of spray systems at runtime since it is customary to change nozzles based on the target job. The nozzle configurations support variable flow rates up to a point. They have upper and lower limits and each configuration is different. We therefore provide both pressure and flow rate factors to enable mapping between the sets. This is critical for dynamic spray control relative to speed which is essential for keeping lead in and lead out distances short. The problem with flow rate only is that systems might be slow to get from their minimum pressure to target flow rate. With a pressure range the system can stay at the target minimum pressure before turning the system on giving it instant correct flow rate. I would be open to arguments for removing the pressure requirement in order to simplify the protocol, but it seems essential to me.

## AUTOPILOT_STATE_FOR_DISPERSION_DEVICE

Low level message containing autopilot state relevant for a dispersion device. This message is to be sent from the autopilot to the device component. The data of this message are for the device estimator corrections such as speed or wind rejection compensation.

| Field Name                      | Type       | Units | Values                                                                                      | Description                                                                                                                                                 |
| :------------------------------ | :--------- | :---: | :------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| target_system                   | `uint8_t`  |       |                                                                                             | System ID uniquely identifying the vehicle this payload device is attached to                                                                               |
| target_component                | `uint8_t`  |       |                                                                                             | Component ID uniquely identifying this device on the system                                                                                                 |
| timestamp_ns                    | `uint64_t` |  ns   |                                                                                             | Unix time stamp                                                                                                                                             |
| q                               | float[4]   |       |                                                                                             | Quaternion components of autopilot attitude: w, x, y, z (1 0 0 0 is the null-rotation, Hamilton convention).                                                |
| q_estimated_delay_us            | uint32_t   |  us   | invalid:0                                                                                   | Estimated delay of the attitude data. 0 if unknown.                                                                                                         |
| vx                              | float      |  m/s  | invalid:NaN                                                                                 | X Speed in NED (North, East, Down). NAN if unknown.                                                                                                         |
| vy                              | float      |  m/s  | invalid:NaN                                                                                 | Y Speed in NED (North, East, Down). NAN if unknown.                                                                                                         |
| vz                              | float      |  m/s  | invalid:NaN                                                                                 | Z Speed in NED (North, East, Down). NAN if unknown.                                                                                                         |
| v_estimated_delay_us            | uint32_t   |  us   | invalid:0                                                                                   | Estimated delay of the speed data. 0 if unknown.                                                                                                            |
| feed_forward_angular_velocity_z | float      | rad/s | invalid:NaN                                                                                 | Feed forward Z component of angular velocity (positive: yawing to the right). NaN to be ignored. This is to indicate if the autopilot is actively yawing.   |
| estimator_status                | uint16_t   |       | [ESTIMATOR_STATUS_FLAGS](https://mavlink.io/en/messages/common.html#ESTIMATOR_STATUS_FLAGS) | Bitmap indicating which estimator outputs are valid.                                                                                                        |
| landed_state                    | uint8_t    |       | invalid:MAV_LANDED_STATE_UNDEFINED MAV_LANDED_STATE                                         | The landed state. Is set to [MAV_LANDED_STATE_UNDEFINED](https://mavlink.io/en/messages/common.html#MAV_LANDED_STATE_UNDEFINED) if landed state is unknown. |
| angular_velocity_z              | float      | rad/s | invalid:NaN                                                                                 | Z component of angular velocity in NED (North, East, Down). NaN if unknown.                                                                                 |

> [!QUESTION]
> This table is an exact clone of AUTOPILOT_STATE_FOR_GIMBAL_DEVICE because it felt like a good representation of the information a dispersion controller might need to deliver quality corrections. It at a minimum needs velocity. Can we just use something like GLOBAL_POS_INT or the GIMBAL message? I dont love the redundancy.

# Enumerated Types

## MAV_TYPE

MAVLINK component type reported in HEARTBEAT message. Flight controllers must report the type of the vehicle on which they are mounted (e.g. MAV_TYPE_OCTOROTOR). All other components must report a value appropriate for their type (e.g. a camera must use MAV_TYPE_CAMERA).

| Value | Name                                                      | Description                          |
| :---- | :-------------------------------------------------------- | :----------------------------------- |
| ...   | ...                                                       | ...                                  |
| 45    | <span id="mav_type_dispersion">MAV_TYPE_DISPERSION</span> | A device that can disperse a payload |

## MAV_COMPONENT

Component ids (values) for the different types and instances of onboard hardware/software that might make up a MAVLink system (autopilot, cameras, servos, GPS systems, avoidance systems etc.).

Components must use the appropriate ID in their source address when sending messages. Components can also use IDs to determine if they are the intended recipient of an incoming message. The MAV_COMP_ID_ALL value is used to indicate messages that must be processed by all components. When creating new entries, components that can have multiple instances (e.g. cameras, servos etc.) should be allocated sequential values. An appropriate number of values should be left free after these components to allow the number of instances to be expanded.

| Value | Name                                                            | Description          |
| :---- | :-------------------------------------------------------------- | :------------------- |
| ...   | ...                                                             | ...                  |
| 110   | <span id="mav_comp_id_dispersion">MAV_COMP_ID_DISPERSION</span> | Dispersion device #1 |
| ...   | ...                                                             | ...                  |

## DISPERSION_DEVICE_CAP_FLAGS

(Bitmask) Dispersion device (low level) capability flags (bitmap).

| Value | Name                                                  | Description                                                                       |
| :---- | :---------------------------------------------------- | :-------------------------------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_CAP_FLAGS_DYNAMIC_SPEED_CORRECTIONS | Device supports varying dispersion rate with speed changes up to provided limits. |
| 2     | DISPERSION_DEVICE_CAP_FLAGS_SPRAYER                   | Device supports dispersing liquid payloads.                                       |
| 4     | DISPERSION_DEVICE_CAP_FLAGS_SPREADER                  | Device supports dispersing granular payloads.                                     |
| 8     | DISPERSION_DEVICE_CAP_FILL_LEVEL_DETECTION            | Device supports measuring its own fill level.                                     |

## DISPERSION_DEVICE_STATUS_FLAGS

(Bitmask) Flags for the dispersion device (lower level) operation. These flags work together to communicate dispersion device state.

| Value | Name                                          | Description                                                  |
| :---- | :-------------------------------------------- | :----------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_STATUS_FLAGS_DISPERSION_ON  | Dispersion device is delivering payload                      |
| 2     | DISPERSION_DEVICE_STATUS_FLAGS_AUTO_MODE      | True if in auto mode. False if in manual mode.               |
| 4     | DISPERSION_DEVICE_STATUS_FLAGS_CONFIGURED     | System has necessary parameters to properly disperse payload |
| 8     | DISPERSION_DEVICE_STATUS_FLAGS_FILL_AT_TARGET | Dispersion device tank is filled to target amount            |

## DISPERSION_DEVICE_REQUESTS

Dispersion device (low level) requests.

| Value | Name                                  | Description                                                                 |
| :---- | :------------------------------------ | :-------------------------------------------------------------------------- |
| 0     | DISPERSION_DEVICE_REQUESTS_DEFAULT    | Stand in for no device request.                                             |
| 1     | DISPERSION_DEVICE_REQUESTS_AUTO       | Configure the dispersion device and mark ready for auto control             |
| 2     | DISPERSION_DEVICE_REQUESTS_MANUAL_ON  | Force the device to immediately deliver payload at configured rate          |
| 3     | DISPERSION_DEVICE_REQUESTS_MANUAL_OFF | Ensure the device cannot be turned on by any auto source until reconfigured |
| 4     | DISPERSION_DEVICE_REQUESTS_AUTO_ON    | Have device deliver payload at configured rate if configured for auto mode  |
| 5     | DISPERSION_DEVICE_REQUESTS_AUTO_OFF   | Have device stop delivering payload if configured for auto mode             |

## DISPERSION_DEVICE_ERRORS

(Bitmask) Dispersion device (low level) error flags. Any error flag indicates the device has turned off.

| Value | Name                                                | Description                                                 |
| :---- | :-------------------------------------------------- | :---------------------------------------------------------- |
| 1     | DISPERSION_DEVICE_ERRORS_UNKNOWN                    | Device has had an unknown error                             |
| 2     | DISPERSION_DEVICE_ERRORS_CLOGGED                    | Device is clogged                                           |
| 4     | DISPERSION_DEVICE_ERRORS_MOTOR_FAILURE              | Device dispersion motor or pump has failed                  |
| 8     | DISPERSION_DEVICE_ERRORS_FILL_EMPTY                 | Device is empty                                             |
| 16    | DISPERSION_DEVICE_ERRORS_IMPROPER_CONFIGURATION     | Device configuration is not compatible with device limits   |
| 32    | DISPERSION_DEVICE_ERRORS_OVER_SPEED                 | System is moving faster than the device can deliver         |
| 64    | DISPERSION_DEVICE_ERRORS_UNDER_SPEED                | System is moving slower than the device can support         |
| 128   | DISPERSION_DEVICE_ERRORS_UNEXPECTED_FILL            | Device tank was filled to an unexpected level               |
| 256   | DISPERSION_DEVICE_ERRORS_NO_CONFIGURATION           | Device was not configured before trying to disperse payload |
| 512   | DISPERSION_DEVICE_ERRORS_LEAK                       | Device is not maintain pressure as expected                 |
| 1024  | DISPERSION_DEVICE_ERRORS_UNEXPECTED_FLIGHT_BEHAVIOR | Device detected an unexpected event like a crash            |

## DISPERSION_DEVICE_WARNINGS

(Bitmask) Dispersion device (low level) warning flags. Any warning flag indicates an issue that does not block operation of the device.

| Value | Name                                | Description                                   |
| :---- | :---------------------------------- | :-------------------------------------------- |
| 1     | DISPERSION_DEVICE_WARNINGS_UNKNOWN  | Device has had an unknown error               |
| 2     | DISPERSION_DEVICE_WARNINGS_LOG_FULL | Device log file has reached its memory limit. |

# Commands

## MAV_CMD_DO_DISPERSION_DEVICE_SET_DISPERSION

Set dispersion device on/off setpoints (low rate command). This should only be sent by automated controllers. It is not for manual assignment nor initial configuration.

| Param (Label)            | Description                                                                                | Values               |
| :----------------------- | :----------------------------------------------------------------------------------------- | :------------------- |
| 1 (Device On)            | Flag indicating if device should be on. This is the same as an AUTO_ON or AUTO_OFF request | 0: off, otherwise on |
| 2 target_dispersion_rate | Target dispersion rate for the system in liters/min or kg/min                              | Invalid:NaN          |

> [!IMPORTANT] this command is necessary to support turning the device on and off during a mission. It also allows control of dispersion rate. If a rate is not provided it defaults to device configuration set by [DISPERSION_DEVICE_REQUEST](#dispersion_device_request).
