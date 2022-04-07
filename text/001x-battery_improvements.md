  * Start date: 2022-03-26
  * Contributors: Hamish Willee <hamishwillee@gmail.com>, ...
  * Related issues: 
    - [16-cell support #1747](https://github.com/mavlink/mavlink/pull/1747)
	- [common: added voltage and current multipliers to BATTERY_STATUS #233](https://github.com/ArduPilot/mavlink/pull/233)
    - [Add MAV_BATTERY_CHARGE_STATE_CHARGING #1068](https://github.com/mavlink/mavlink/pull/1068)

  
# Summary

This RFC proposes:
- a new `BATTERY_STATUS_V2` message that has a single cumulative voltage value rather than individual cell voltage arrays.
- a new (optional) `BATTERY_VOLTAGES` message that can be scaled to as many cells as needed, and which reports them as faults.

  
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
      <field type="uint8_t" name="percent_remaining" units="%" invalid="UINT8_MAX">Remaining battery energy. Values: [0-100], UINT32_MAX: Remaining battery energy is not provided.</field>
      <field type="uint32_t" name="fault_bitmask" display="bitmask" enum="MAV_BATTERY_FAULT">Fault/health/ready-to-use indications.</field>
    </message>
```

With `MAV_BATTERY_FAULT` having the following **additions** (from `MAV_BATTERY_CHARGE_STATE` and `MAV_BATTERY_MODE`):
```xml
    <enum name="MAV_BATTERY_FAULT" bitmask="true">
      <description>Battery supply status flags (bitmask) indicating battery health and readiness for flight.</description>
      ...
      <entry value="512" name="BATTERY_FAULT_CHARGING">
        <description>Battery is charging. Not ready to use.</description>
      </entry>
      <entry value="1024" name="BATTERY_FAULT_AUTO_DISCHARGING">
        <description>Battery is auto discharging (towards storage level). Not ready to use.</description>
      </entry>
      <entry value="2048" name="BATTERY_FAULT_HOT_SWAP">
        <description>Battery in hot-swap mode (current limited to prevent spikes that might damage sensitive electrical circuits). Not ready to use.</description>
      </entry>
```

The message is heavily based on [BATTERY_STATUS](https://mavlink.io/en/messages/common.html#BATTERY_STATUS) but:
- removes the cell voltage arrays: `voltages` and `voltages_ext`
- adds `voltage`, the total cell voltage. This is a uint32_t to allow batteries with more than 65V.
- removes `energy_consumed`. This essentially duplicates `current_consumed` for most purposes, and `current_consumed`/mAh is nearly ubiquitous.
- removes `time_remaining`.
  ```xml
  <field type="uint32_t" name="time_remaining" units="s" invalid="UINT32_MAX">Remaining battery time (estimated), UINT32_MAX: Remaining battery time estimate not provided.</field>
  ```
  - This is an estimated "convenience" value which can be calculated as well or better by a GCS, in particular on multi-battery systems (from original charge, `current_consumed` and looking at the rate of `current` over some time period).
  - Better to be lightweight.
- `percent_remaining` changed from int8 to uint8 (and max value set to invalid value).
  This is consistent with other MAVLink percentage fields.
- removes `battery_function` and `type` (chemistry) as these are present in `SMART_BATTERY_INFO` and invariant.
  ```xml
     <field type="uint8_t" name="battery_function" enum="MAV_BATTERY_FUNCTION">Function of the battery</field>
     <field type="uint8_t" name="type" enum="MAV_BATTERY_TYPE">Type (chemistry) of the battery</field>
  ```
  - A GCS that needs invariant information should read `SMART_BATTERY_INFO` on startup
  - A vehicle that allows battery swapping must stream `SMART_BATTERY_INFO` (at low rate) to ensure that battery changes are notifie (and ideally also emit it on battery change).
- Removes [`charge_state`](https://mavlink.io/en/messages/common.html#MAV_BATTERY_CHARGE_STATE) [`mode`](https://mavlink.io/en/messages/common.html#MAV_BATTERY_MODE)
  ```xml
  <field type="uint8_t" name="charge_state" enum="MAV_BATTERY_CHARGE_STATE">State for extent of discharge, provided by autopilot for warning or external reactions</field>
  <field type="uint8_t" name="mode" enum="MAV_BATTERY_MODE">Battery mode. Default (0) is that battery mode reporting is not supported or battery is in normal-use mode.</field>
  ```
  - The state is almost all inferred from the battery remaining. Traditionally the GCS sets appropriate levels for warning - the battery has a less accurate view on appropriate warning levels for a particular system, making this redundant. The exception is charging status.
  - The mode is reasonable enough, but can be expressed as a fault "there is a concern with using this battery".



#### Questions

- Do we need all the other fields?
- Are there any other fields missing?
- Should we have `MAV_BATTERY_FAULT` for critical level "just before deep discharge"? The battery can know this, and it might prevent over discharge.
  ```xml
      <entry value="1024" name="BATTERY_FAULT_CRITICAL_LEVEL">
        <description>Battery is at critically low level. Undamaged, but not ready to use.</description>
      </entry>
  ```
 - Should we have `MAV_BATTERY_FAULT` summarising "not ready to use"? Simplifies things for GCS/user as unhealthy vs you can't use this at all.
  ```xml
      <entry value="1024" name="BATTERY_FAULT_NOT_READY">
        <description>Battery is not ready/safe to use. Check other bitmasks for reasons.</description>
      </entry>
  ``` 
- Is the size of the `current` field large enough. It has maximum value of 327.67A. We could make it a float or a uint_16 and change units to mA.


## Battery Cell Voltages

The proposed battery message is:

```xml
    <message id="???" name="BATTERY_CELL_VOLTAGES">
      <description>Battery cell voltages.
        This message is provided primarily for cell fault debugging.
	For batteries with more than 10 cells the message should be sent multiple times, iterating the index value.
	It should not be streamed at very low rate (less than once a minute) or streamed only on request.</description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="uint8_t" name="index">Cell index (0 by default). This can be iterated for batteries with more than 12 cells.</field>
      <field type="uint16_t[12]" name="voltages" units="mV" invalid="[0]">Battery voltage of 12 cells at current index. Cells above the valid cell count for this battery should be set to 0.</field>
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

[SMART_BATTERY_INFO](https://mavlink.io/en/messages/common.html#SMART_BATTERY_INFO) is already deployed and it is not clear if it can be modified. It may be possible to extend.

Add note that it must be streamed at a low rate in order to allow detection of battery change, and should also be sent when the battery changes. 

Questions:
- What low rate is OK for streaming? is there another alternative for tracking battery change
 


## Migration/Discovery

`BATTERY_STATUS` consumes significant bandwidth: sending `BATTERY_STATUS_V2` at the same time would just increase the problem.

The proposal here is that GCS should support both messages for the forseeable future.
Flight stacks should manage their own migration after relevant ground stations have been updated.


# Alternatives

TBD

# Unresolved Questions

TBD

# References

* ?

