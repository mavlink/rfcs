  * Start date: 2022-03-26
  * Contributors: Hamish Willee <hamishwillee@gmail.com>, ...
  * Related issues: 
    - [16-cell support #1747](https://github.com/mavlink/mavlink/pull/1747)
	- [common: added voltage and current multipliers to BATTERY_STATUS #233](https://github.com/ArduPilot/mavlink/pull/233)

  
# Summary

This RFC proposes:
- a new `BATTERY_STATUS_V2` message that has a single cumulative voltage value rather than individual cell voltage arrays.
- a new (optional) `BATTERY_VOLTAGES` message that can be scaled to as many cells as needed, and which reports them as faults.
- mechanisms to ease supporting both message types until we can eventually deprecate `BATTERY_STATUS`

  
# Motivation

The motivation is to:
- reduce the memory required for battery reporting ([anecdotal evidence](https://github.com/ArduPilot/mavlink/pull/233#issuecomment-976197179) indicates cases with 15% of bandwidth on a default RF channel).
- Provide a cleaner message and design for both implementers and consumers.

The [BATTERY_STATUS](https://mavlink.io/en/messages/common.html#BATTERY_STATUS) has two arrays that can be used to report individual cell voltages (up to 14), or a single cumulative voltage, and which cannot be truncated.
The vast majority of consumers are only interested in the total battery voltage, and either sum the battery cells or get the cumulative voltage.
By separating the cell voltage reporting into a separate message the new battery status can be much smaller, and the cell voltages need only be sent if the consumer is actually interested.

# Detailed Design

There are three parts to the design:
1. A more efficient status message
2. A scalable battery voltage message.
3. Mechanisms that allow the new messages to seamlessly coexist with the old one along with eventual deprecation of the older message.

## BATTERY_STATUS_V2

The message is heavily based on [BATTERY_STATUS](https://mavlink.io/en/messages/common.html#BATTERY_STATUS) but:
- removes the cell voltage arrays: `voltages` and `voltages_ext`
- adds `voltage`, the total cell voltage. This is a uint32_t to allow batteries with more than 65V.
- removes `energy_consumed`. This essentially duplicates `current_consumed` for most purposes, and `current_consumed`/mAh is nearly ubiquitous.


```xml
    <message id="???" name="BATTERY_STATUS_V2">
      <description>Battery information. Updates GCS with flight controller battery status. Smart batteries also use this message, but may additionally send SMART_BATTERY_INFO.</description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="uint8_t" name="battery_function" enum="MAV_BATTERY_FUNCTION">Function of the battery</field>
      <field type="uint8_t" name="type" enum="MAV_BATTERY_TYPE">Type (chemistry) of the battery</field>
      <field type="int16_t" name="temperature" units="cdegC" invalid="INT16_MAX">Temperature of the battery. INT16_MAX for unknown temperature.</field>
      <field type="uint32_t" name="voltage" units="mV" invalid="[UINT32_MAX]">Battery voltage (total).</field>
      <field type="int16_t" name="current" units="cA" invalid="UINT16_MAX">Battery current (through all cells/loads). Positive if discharging, negative if charging. UINT16_MAX: field not provided.</field>
      <field type="int32_t" name="current_consumed" units="mAh" invalid="-1">Consumed charge, -1: Current consumption estimate not provided.</field>
      <field type="int8_t" name="percent_remaining" units="%" invalid="-1">Remaining battery energy. Values: [0-100], -1: Remaining battery energy is not provided.</field>
      <field type="uint32_t" name="time_remaining" units="s" invalid="UINT32_MAX">Remaining battery time (estimated), UINT32_MAX: Remaining battery time estimate not provided.</field>
      <field type="uint8_t" name="charge_state" enum="MAV_BATTERY_CHARGE_STATE">State for extent of discharge, provided by autopilot for warning or external reactions</field>
      <field type="uint8_t" name="mode" enum="MAV_BATTERY_MODE">Battery mode. Default (0) is that battery mode reporting is not supported or battery is in normal-use mode.</field>
      <field type="uint32_t" name="fault_bitmask" display="bitmask" enum="MAV_BATTERY_FAULT">Fault/health indications. These should be set when charge_state is MAV_BATTERY_CHARGE_STATE_FAILED or MAV_BATTERY_CHARGE_STATE_UNHEALTHY (if not, fault reporting is not supported).</field>
    </message>
```


Questions:
- It is desirable to move static fields like the `type` (battery chemistry) and `battery_function` out of the new message because they only need to be read once, and afterwards are dead weight.
  For this to be OK, the information either has to be non-essential (i.e might never be provided) or guaranteed to be sent in another message (this info is present in [SMART_BATTERY_INFO](https://mavlink.io/en/messages/common.html#SMART_BATTERY_INFO)).
  - Is it non-essential?
  - If it is essential, do we leave it in the message or mandate sending of `SMART_BATTERY_INFO`?
- Do we need all the other fields?
- Are there any other fields missing?


## Battery Voltages

The proposed battery message is below.

This assumes that the reason you might need the individual battery voltages is in order to identify that a particular cell has a significantly different voltage, and is hence in fault.
It simply sends information about which cells are in fault, providing battery manufacturers a way of reporting more detailed debugging information.

```xml
    <message id="???" name="BATTERY_VOLTAGE_FAULT">
      <description>Battery information. Updates GCS with flight controller battery status. Smart batteries also use this message, but may additionally send SMART_BATTERY_INFO.</description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="uint8_t" name="index">Cell index (0 by default). This is iterated for every 64 cells, allowing very large cell fault information. </field>
      <field type="uint64_t" name="fault_mask">Fault/health indications. .</field>
    </message>
```

## Migration/Discovery

`BATTERY_STATUS` consumes significant bandwidth: sending `BATTERY_STATUS_V2` at the same time would just increase the problem.

[
What are options here?
- Add support for either format in QGC/Mission Planner etc.
- Flight stack send `BATTERY_STATUS` but ground station can request BATTERY_STATUS_V2 and turn off BATTERY_STATUS_V2 using SET_INTERVAL?
- In a few releases we allow ground stations to set BATTERY_STATUS_V2 by default. 
]



# Alternatives

TBD

# Unresolved Questions

TBD

# References
  * ?



