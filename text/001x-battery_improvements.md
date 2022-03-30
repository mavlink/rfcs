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

The proposed message is:

```xml
    <message id="???" name="BATTERY_STATUS_V2">
      <description>Battery dynamic information. This should be streamed (nominally at 1Hz). Static battery information is sent in SMART_BATTERY_INFO.</description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
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

The message is heavily based on [BATTERY_STATUS](https://mavlink.io/en/messages/common.html#BATTERY_STATUS) but:
- removes the cell voltage arrays: `voltages` and `voltages_ext`
- adds `voltage`, the total cell voltage. This is a uint32_t to allow batteries with more than 65V.
- removes `energy_consumed`. This essentially duplicates `current_consumed` for most purposes, and `current_consumed`/mAh is nearly ubiquitous.
- removes `battery_function` and `type` (chemistry) as these are present in `SMART_BATTERY_INFO` and invariant.
  ```xml
     <field type="uint8_t" name="battery_function" enum="MAV_BATTERY_FUNCTION">Function of the battery</field>
     <field type="uint8_t" name="type" enum="MAV_BATTERY_TYPE">Type (chemistry) of the battery</field>
  ```
  - A GCS that needs invariant information should read `SMART_BATTERY_INFO` on startup
  - A vehicle that allows battery swapping must stream `SMART_BATTERY_INFO` (at low rate) to ensure that battery changes are notifie (and ideally also emit it on battery change).

#### Questions

- Do we need all the other fields?
- Are there any other fields missing?


## Battery Cell Voltages

The proposed battery message is:

```xml
    <message id="???" name="BATTERY_CELL_VOLTAGES">
      <description>Battery cell voltages.
        This message is provided primarily for cell fault debugging.
	For batteries with more than 10 cells the message should be sent multiple times, iterating the index value.
	It should not be streamed at very low rate (less than once a minute) or streamed only on request.</description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="uint8_t" name="index">Cell index (0 by default). This can be iterated for batteries with more than 10 cells.</field>
      <field type="uint16_t[10]" name="voltages" units="mV" invalid="[0]">Battery voltage of 10 cells at current index. Cells above the valid cell count for this battery should be set to 0.</field>
    </message>
```

Cell voltages can be used to verify that poorly performing batteries have failing cells, and to providing early warning of longer term battery degradation.
It is useful to have long term trace information in logs, but not necessary for this to be at particularly high rate.
Therefore the message provides all information about the battery voltages, but is expected to be sent at low rate, or on request.

As designed, the message will not be zero-byte truncated (field re-ordering means that the array is last).
The message might be modified to make:
- `voltages` an extension field. For a 4S battery this would save 12 bytes per message but lose checking. If we do this we might as well mandate "no extension".
- `id` and `index` into `uint16_t`. For a 4S battery this would save 10 bytes per message,and retain mavlink checking on field. It would cost 2 additional bytes on every new message.


#### Alternatives

An alternative is just to send fault information.
This assumes that the smart battery is capable of providing the long term trend analysis that can be obtained from logs using the above message.

```xml
    <message id="???" name="BATTERY_CELL_VOLTAGES">
      <description>Battery cell fault information.</description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="uint8_t" name="index">Cell index (0 by default). This is iterated for every 64 cells, allowing very large cell fault information. </field>
      <field type="uint64_t" name="fault_mask">Fault/health indications.</field>
    </message>
```

## SMART_BATTERY_INFO

No changes are required to [SMART_BATTERY_INFO](https://mavlink.io/en/messages/common.html#SMART_BATTERY_INFO) fields

Note however that it must be streamed at a low rate in order to allow detection of battery change, and should also be sent when the battery changes. 
We should specify the rate.

Questions:
- What low rate is OK for streaming? is there another alternative?


## Migration/Discovery

`BATTERY_STATUS` consumes significant bandwidth: sending `BATTERY_STATUS_V2` at the same time would just increase the problem.

[
What are options here?
- Add support for either format in QGC/Mission Planner etc.
- Flight stack send `BATTERY_STATUS` but ground station can request BATTERY_STATUS_V2 and turn off BATTERY_STATUS using SET_INTERVAL?
- In a few releases we allow ground stations to set BATTERY_STATUS_V2 by default. 
]


# Alternatives

TBD

# Unresolved Questions

TBD

# References

* ?

