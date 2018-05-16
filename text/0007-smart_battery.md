  * Start date: 2018-05-16
  * Contributors: Alex Klimaj <alex.klimaj@tealdrones.com>
  * Add to BATTERY_STATUS extensions to communicate smart battery info #907: https://github.com/mavlink/mavlink/pull/907

# Summary

This document describes the new messages for communicating information from a smart battery over mavlink.

# Motivation

Fuel gauge IC's such as TI's BQ40Z50-R2 provide more useful information than the current BATTERY_STATUS message can communicate.
The batt_smbus driver in PX4 reads the serial number, average current, run time until empty, total capacity, remaining capacity, cycle count, and temperature.
The BATTERY_STATUS message already has "time_remaining" and "charge_state" in <extensions/>.
A companion computer in retail/commercial drones based on PX4 can act on this information and or pass it onto a user or tech support.

# Detailed Design

Add new fields for smart battery information under <extensions/> in the BATTERY_STATUS message.

# Alternatives

Create a new BATTERY_EXTENDED message to handle the new feilds instead of under <extensions/> in the BATTERY_STATUS message.

# Unresolved Questions

# References
  * BQ40Z50-R2: http://www.ti.com/product/BQ40Z50-R2
  * Firmware/src/drivers/batt_smbus/batt_smbus.cpp: https://github.com/PX4/Firmware/blob/master/src/drivers/batt_smbus/batt_smbus.cpp
