  * Start date: 2019-05-28
  * Contributors: Mike Lyons <mlyons@swiftengineering.com>, Swift Engineering, Inc.
  * Related issues:

# Summary

Proposal to extend the manual_control MAVLink message for extra channels. 

# Motivation

Many autonomous vehicles could benefit from the addition of extra control channels for various functions. In addition, many joystick controllers have additional axes that are currently not used.

This provides a generic extension to the manual_control message that developers can use and may be used in a more abstract context from using the RC_OVERRIDE message.

# Detailed Design

The message contains additional *extension* fields for joystick axis values normalized between -1000 to 1000 for the following channels
* Channel 5
* Channel 6
* Channel 7
* Channel 8

## Proposed message extension

```xml
    <message id="69" name="MANUAL_CONTROL">
      <description>This message provides an API for manually controlling the vehicle using standard joystick axes nomenclature, along with a joystick-like input device. Unused axes can be disabled an buttons are also transmit as boolean values of their </description>
      <field type="uint8_t" name="target">The system to be controlled.</field>
      <field type="int16_t" name="x">X-axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Generally corresponds to forward(1000)-backward(-1000) movement on a joystick and the pitch of a vehicle.</field>
      <field type="int16_t" name="y">Y-axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Generally corresponds to left(-1000)-right(1000) movement on a joystick and the roll of a vehicle.</field>
      <field type="int16_t" name="z">Z-axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Generally corresponds to a separate slider movement with maximum being 1000 and minimum being -1000 on a joystick and the thrust of a vehicle. Positive values are positive thrust, negative values are negative thrust.</field>
      <field type="int16_t" name="r">R-axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Generally corresponds to a twisting of the joystick, with counter-clockwise being 1000 and clockwise being -1000, and the yaw of a vehicle.</field>
      <field type="uint16_t" name="buttons">A bitfield corresponding to the joystick buttons' current state, 1 for pressed, 0 for released. The lowest bit corresponds to Button 1.</field>
      <extensions/>
      <field type="int16_t" name="chan5">axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Corresponds to movement on joystick channel 5</field>
      <field type="int16_t" name="chan6">axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Corresponds to movement on joystick channel 6</field>
      <field type="int16_t" name="chan7">axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Corresponds to movement on joystick channel 7</field>
      <field type="int16_t" name="chan8">axis, normalized to the range [-1000,1000]. A value of INT16_MAX indicates that this axis is invalid. Corresponds to movement on joystick channel 8</field>
    </message>
```