  * Start date: 2018-05-21
  * Contributors: Achermann Florian, <acfloria@ethz.ch>
  * Related issues: 
  
# Summary

The goal of this document is to present a design on how to handle commands which are sent over different links with significantly different latencies from the ground control station to a vehicle.
  
# Motivation

When transmitting commands over multiple links with significantly different latencies to a single vehicle the order in which the commands are sent might not be equal to the order in which they are received. This can lead to an undesired response of the vehicle especially when using commands such as MAV_CMD_DO_CHANGE_ALTITUDE, MAV_CMD_DO_SET_MODE, or MAV_CMD_DO_REPOSITION.

# Detailed Design

A new type of command is created: COMMAND_STAMPED. This command is basically a COMMAND_LONG with additional metadata:
  * (uint64) vehicle_time: The vehicle time since boot in ms
  * (uint64) utc_time: The seconds elapsed since Jan 01 1970 (UTC)

The vehicle_time field is filled in with the value of the timestamp field of the last received vehicle time on the groundstation (SYSTEM_TIME or HIGH_LATENCY2). This indicates on which vehicle status the command is sent. On the groundstation the last vehicle is reset to 0 after some time not receiving an update to avoid that any sent command is rejected.

The utc_time provides a reference between different flights. Which is necessary as for example Satellite Communication messages can be queued on the network and arrive on the plane on the next flight.

A field is added to the MAV_PROTOCOL_CAPABILITY if the COMMAND_STAMPED is supported. Based on the value of this field the ground control station decides if the COMMAND_STAMPED is sent instead of the COMMAND_LONG. Optionally also the user of the Ground Station can decide if he wants to use this new feature.

By separating the COMMAND_LONG and COMMAND_STAMPED and the ability of the user to decline to use the new feature the interference with the existing functionalities is kept to a minimum.

If a command arrives on the vehicle based on the metadata of the COMMAND_STAMPED it is decided if the command is declined or accepted. A command is rejected if:
 1. the vehicle_time of a previously received command is larger (this check is only executed if vehicle_time of the received command is larger than 0)
 2. the utc_time of a previously received command is larger
 3. vehicle_time + dt is smaller than the current vehicle time
 4. the vehicle_time is larger than the current vehicle time

The third criteria prevents the vehicle acting on commands which are based on outdated vehicle data. To indicate this special case it is answered with an acknowledge using a new MAV_RESULT: MAV_RESULT_EXPIRED.



