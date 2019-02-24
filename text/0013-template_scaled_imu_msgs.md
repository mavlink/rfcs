  * Start date: 2019-02-25
  * Contributors: Mark Sauder <mcsauder@gmail.com>, ...
  * Related issues: 
  
# Summary

This RFC proposes adding a struct member to identify the scaled imu instance, `uint8_t sensor_index` (or some similarly named variable).  This RFC would allow the three `mavlink_scaled_imu`, `mavlink_scaled_imu2`, and `mavlink_scaled_imu3` message definitions to be consolidated into a single definition, potentially freeing messages 116 and 129 for other uses.

This RFC would impact the MAVLink protocol in two ways:
  1) Impacting the `mavlink_scaled_imu` message defintion directly, and
  2) Allowing `MAVLINK_MSG_ID_SCALED_IMU2 116` and `MAVLINK_MSG_ID_SCALED_IMU3 129` to be deprecated/re-purposed.
  
# Motivation

The primary motication of this RFC is to reduce code duplication in mavlink protocol and projects utilizing the protocol.

By adding a sensor index/instance value to the message, the scaled_imu message will also more closely resemble the current usage of `mavlink_msg_actuator_control_target.h` and `mavlink_msg_servo_output_raw` messages.

# Detailed Design

The proposed implementation would add a struct member variable **`uint8_t sensor_index`** to the `mavlink_scaled_imu_t` type definition in `mavlink_msg_scaled_imu.h`.

LOC added/impacted would look something like these:

```c++ hl_lines=3
MAVPACKED(
typedef struct __mavlink_scaled_imu_t {
...
 uint8_t sensor_index; /*< IMU instance*/
}) mavlink_scaled_imu_t;

#define MAVLINK_MSG_ID_SCALED_IMU_LEN 23
#define MAVLINK_MSG_ID_SCALED_IMU_MIN_LEN 23
#define MAVLINK_MSG_ID_26_LEN 23
#define MAVLINK_MSG_ID_26_MIN_LEN 23

#define MAVLINK_MSG_ID_SCALED_IMU_CRC XXX
#define MAVLINK_MSG_ID_26_CRC XXX


#if MAVLINK_COMMAND_24BIT
#define MAVLINK_MESSAGE_INFO_SCALED_IMU { \
    26, \
    "SCALED_IMU", \
...
         { "sensor_index", NULL, MAVLINK_TYPE_UINT8_T, 0, 21, offsetof(mavlink_scaled_imu_t, sensor_index) }, \
         } \
}
#else
#define MAVLINK_MESSAGE_INFO_SCALED_IMU { \
    "SCALED_IMU", \
...
         { "sensor_index", NULL, MAVLINK_TYPE_UINT8_T, 0, 21, offsetof(mavlink_scaled_imu_t, sensor_index) }, \
         } \
}
#endif
```

`_mav_put_uint8_t(buf, 21, sensor_index);`

...

`packet.sensor_index = sensor_index;`

etc.



# Alternatives
The proposed change places the sensor_index field such that it does not impact offsets for all other values, however, a personal preference would have been to place the index at the beginning of the typedef prior to sensor values.

There are likely alternatives to this RFC, please suggest additional potential solutions.

# Unresolved Questions

# References

- Mavlink github issue [949](https://github.com/mavlink/mavlink/issues/949)
- PX4/Firmware PR [#9556](https://github.com/PX4/Firmware/pull/9556)

