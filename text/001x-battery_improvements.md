  * Start date: 2022-03-26
  * Contributors: Hamish Willee <hamishwillee@gmail.com>, ...
  * Related issues: 
    - [16-cell support #1747](https://github.com/mavlink/mavlink/pull/1747)
	- [common: added voltage and current multipliers to BATTERY_STATUS #233](https://github.com/ArduPilot/mavlink/pull/233)
    - [Add MAV_BATTERY_CHARGE_STATE_CHARGING #1068](https://github.com/mavlink/mavlink/pull/1068)
    - dronecan / DSDL : [WIP smart battery messages](https://github.com/dronecan/DSDL/pull/7) 

  
# Summary

This RFC proposes:
- a new `BATTERY_STATUS_V2` message that has a single cumulative voltage value rather than individual cell voltage arrays.
- a new (optional) `BATTERY_VOLTAGES` message that can be scaled to as many cells as needed, and which reports them as faults.

  
# Motivation

The motivation is to:
- reduce the memory required for battery reporting ([anecdotal evidence](https://github.com/ArduPilot/mavlink/pull/233#issuecomment-976197179) indicates cases with 15% of bandwidth on a default RF channel).
- Provide a cleaner message and design for both implementers and consumers.
- Align with DroneCan battery messages to ease transport and data conversion across different transports.

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
    <message id="369" name="BATTERY_STATUS_V2">
      <description>Battery dynamic information.
        This should be streamed (nominally at 1Hz).
        Static/invariant battery information is sent in SMART_BATTERY_INFO.

        The full-battery charge can be inferred from current_remaining and percent_remaining if both values are supplied.
        The `current_remaining` field should only be sent if it is guaranteed to be near-accurate.
        Power monitors do not normally send the `current_remaining` field as it can only be accurate if the battery is fully charged when the drone is turned on.
        (A GCS can use `current_remaining` being invalid as a trigger to notify the user to fully charge the battery before flight).
      </description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="int16_t" name="temperature" units="cdegC" invalid="INT16_MAX">Temperature of the whole battery pack (not internal electronics). INT16_MAX field not provided.</field>
      <field type="uint32_t" name="voltage" units="mV" invalid="UINT32_MAX">Battery voltage (total). UINT32_MAX: field not provided.</field>
      <field type="uint32_t" name="current" units="mA" invalid="UINT32_MAX">Battery current (through all cells/loads). UINT32_MAX: field not provided.</field>
      <field type="uint32_t" name="current_consumed" units="mAh" invalid="UINT32_MAX">Consumed charge (since vehicle powered on). UINT32_MAX: field not provided. Note: For power modules the expectation is that batteries are fully charged before turning on the vehicle.</field>
      <field type="uint32_t" name="current_remaining" units="mAh" invalid="UINT32_MAX">Remaining charge (until empty). UINT32_MAX: field not provided. Note: Power monitors should not set this value.</field>
      <field type="uint8_t" name="percent_remaining" units="%" invalid="UINT8_MAX">Remaining battery energy. Values: [0-100], UINT32_MAX: field not provided.</field>
      <field type="uint32_t" name="status_flags" display="bitmask" enum="MAV_BATTERY_STATUS_FLAGS">Fault, health, and readiness status indications.</field>
    </message>
```

`MAV_BATTERY_STATUS_FLAGS` is a new enum that includes faults, charge state, and battery mode:

```xml
    <enum name="MAV_BATTERY_STATUS_FLAGS" bitmask="true">
      <description>Battery status flags for fault, health and state indication.</description>
      <entry value="1" name="MAV_BATTERY_STATUS_FLAGS_READY_TO_USE">
        <description>
          The battery is ready to use (fly).
          Only set if the battery is safe and ready to fly with (not charging, no critical faults, such as those that would set MAV_BATTERY_STATUS_FLAGS_REQUIRES_SERVICE or MAV_BATTERY_STATUS_FLAGS_BAD_BATTERY, etc.).
        </description>
      </entry>
      <entry value="2" name="MAV_BATTERY_STATUS_FLAGS_CHARGING">
        <description>
          Battery is charging.
          Not ready to use (MAV_BATTERY_STATUS_FLAGS_READY_TO_USE would not be set).
        </description>
      </entry>
      <entry value="4" name="MAV_BATTERY_STATUS_FLAGS_CELL_BALANCING">
        <description>
          Battery is cell balancing (during charging).
          Not ready to use (MAV_BATTERY_STATUS_FLAGS_READY_TO_USE would not be set).
        </description>
      </entry>
      <entry value="8" name="MAV_BATTERY_STATUS_FLAGS_FAULT_CELL_IMBALANCE">
        <description>
          Battery cells are not balanced.
          Not ready to use.
        </description>
      </entry>
      <entry value="16" name="MAV_BATTERY_STATUS_FLAGS_AUTO_DISCHARGING">
        <description>
          Battery is auto discharging (towards storage level).
          Not ready to use (MAV_BATTERY_STATUS_FLAGS_READY_TO_USE would not be set).
        </description>
      </entry>
      <entry value="32" name="MAV_BATTERY_STATUS_FLAGS_REQUIRES_SERVICE">
        <description>
          Battery requires service (not safe to fly). 
          This is set at vendor discretion.
          It is likely to be set for most faults, and may also be set according to a maintenance schedule (such as age, or number of recharge cycles, etc.).
        </description>
      </entry>
      <entry value="64" name="MAV_BATTERY_STATUS_FLAGS_BAD_BATTERY">
        <description>
          Battery is faulty and cannot be repaired (not safe to fly). 
          This is set at vendor discretion.
          The battery should be disposed of safely.
        </description>
      </entry>
      <entry value="128" name="MAV_BATTERY_STATUS_FLAGS_PROTECTIONS_ENABLED">
        <description>
          Automatic battery protection monitoring is enabled. 
          When enabled, the system will monitor for certain kinds of faults, such as cells being over-voltage.
          If a fault is triggered then and protections are enabled then a safety fault (MAV_BATTERY_STATUS_FLAGS_FAULT_PROTECTION_SYSTEM) will be set and power from the battery will be stopped.
          Note that the associated fault (such as MAV_BATTERY_STATUS_FLAGS_FAULT_OVER_VOLT) should always be set whether or not the protection system is engaged.
        </description>
      </entry>
      <entry value="256" name="MAV_BATTERY_STATUS_FLAGS_FAULT_PROTECTION_SYSTEM">
        <description>
          The battery fault protection system had detected a fault and cut all power from the battery.
          This will only trigger if MAV_BATTERY_STATUS_FLAGS_PROTECTIONS_ENABLED is set.
          Other faults like MAV_BATTERY_STATUS_FLAGS_FAULT_OVER_VOLT may also be set, indicating the cause of the protection fault.
        </description>
      </entry>
      <entry value="512" name="MAV_BATTERY_STATUS_FLAGS_FAULT_OVER_VOLT">
        <description>One or more cells are above their maximum voltage rating.</description>
      </entry>
      <entry value="1024" name="MAV_BATTERY_STATUS_FLAGS_FAULT_UNDER_VOLT">
        <description>
          One or more cells are below their minimum voltage rating.
          A battery that had deep-discharged might be irrepairably damaged, and set both MAV_BATTERY_STATUS_FLAGS_FAULT_UNDER_VOLT and MAV_BATTERY_STATUS_FLAGS_BAD_BATTERY.
        </description>
      </entry>
      <entry value="2048" name="MAV_BATTERY_STATUS_FLAGS_FAULT_OVER_TEMPERATURE">
        <description>Over-temperature fault.</description>
      </entry>
      <entry value="4096" name="MAV_BATTERY_STATUS_FLAGS_FAULT_UNDER_TEMPERATURE">
        <description>Under-temperature fault.</description>
      </entry>
      <entry value="8192" name="MAV_BATTERY_STATUS_FLAGS_FAULT_OVER_CURRENT">
        <description>Over-current fault.</description>
      </entry>
      <entry value="16384" name="MAV_BATTERY_STATUS_FLAGS_FAULT_SHORT_CIRCUIT">
        <description>
          Short circuit event detected.
          The battery may or may not be safe to use (check other flags).
        </description>
      </entry>
      <entry value="32768" name="MAV_BATTERY_STATUS_FLAGS_FAULT_INCOMPATIBLE_VOLTAGE">
        <description>Voltage not compatible with power rail voltage (batteries on same power rail should have similar voltage).</description>
      </entry>
      <entry value="65536" name="MAV_BATTERY_STATUS_FLAGS_FAULT_INCOMPATIBLE_FIRMWARE">
        <description>Battery firmware is not compatible with current autopilot firmware.</description>
      </entry>
      <entry value="131072" name="MAV_BATTERY_STATUS_FLAGS_FAULT_INCOMPATIBLE_CELLS_CONFIGURATION">
        <description>Battery is not compatible due to cell configuration (e.g. 5s1p when vehicle requires 6s).</description>
      </entry>
    </enum>
```

The message is heavily based on [BATTERY_STATUS](https://mavlink.io/en/messages/common.html#BATTERY_STATUS) but:
- removes the cell voltage arrays: `voltages` and `voltages_ext`
- adds `voltage`, the total cell voltage. This is a uint32_t to allow batteries with more than 65V.
- `current_consumed` has changed from an `int32_t` to a `uint32_t`. This allows future proofs from 32767 mAh limit to 4294967295 mAh 
- removes `energy_consumed`. This essentially duplicates `current_consumed` for most purposes, and `current_consumed`/mAh is nearly ubiquitous.
- adds `current_remaining`(mAh) estimate.
  - This allows a GCS to more accurately determine available current and remaining time than inferring from the `current_consumed` and `percent_remaining`.
  - Note that this also gives the current reliably on plug-in. 
    All the other information provided by messages (other than `percent_remaining`) assumes that the battery was full when it was plugged in.
  - Includes a note that should not be set by power modules.
    Power modules can only provide this reliably if the battery is fully charged when they are turned on.
    A GCS can still infer the battery remaining from the consumed current, but by setting this as empty, we tell the GCS that it can't be "sure" of the value, and should prompt the user to use full batteries.
- change `current` from a `int16_t` (cA) to a `uint32_t` (mA). Maximum size was previously 327.67A, which is not large enough to be future proof. The value is absolute - if you're charging the value can be assumed to be in a reversed direction.
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
- New `battery_status` (`MAV_BATTERY_STATUS_FLAGS`) replaces [`fault_bitmask`](https://mavlink.io/en/messages/common.html#MAV_BATTERY_FAULT), [`charge_state`](https://mavlink.io/en/messages/common.html#MAV_BATTERY_CHARGE_STATE) and [`mode`](https://mavlink.io/en/messages/common.html#MAV_BATTERY_MODE)
  ```xml
  <field type="uint8_t" name="charge_state" enum="MAV_BATTERY_CHARGE_STATE">State for extent of discharge, provided by autopilot for warning or external reactions</field>
  <field type="uint8_t" name="mode" enum="MAV_BATTERY_MODE">Battery mode. Default (0) is that battery mode reporting is not supported or battery is in normal-use mode.</field>
  <field type="uint32_t" name="fault_bitmask" display="bitmask" enum="MAV_BATTERY_FAULT">Fault/health/ready-to-use indications.</field>
  ```
  - The state is almost all inferred from the battery remaining. Traditionally the GCS sets appropriate levels for warning - the battery has a less accurate view on appropriate warning levels for a particular system, making this redundant. The exception is charging status.
  - The mode and fault are reasonable, but make more sense as general status indication.
  - The status loses some faults which make no sense (e.g. `MAV_BATTERY_FAULT_SPIKES`) or which can now be inferred (like deep discharge).


#### Questions

- Do we need all the other fields?
- Are there any other fields missing?
- Should we have `MAV_BATTERY_FAULT` for critical level "just before deep discharge"? The battery can know this, and it might prevent over discharge.
  ```xml
      <entry value="1024" name="BATTERY_FAULT_CRITICAL_LEVEL">
        <description>Battery is at critically low level. Undamaged, but not ready to use.</description>
      </entry>
  ```
- `MAV_BATTERY_STATUS_FLAGS`
  - Should this include `MAV_BATTERY_STATUS_FLAGS_IN_USE` (connected, drawing significant power to fly). Not clear when you would need this or how you would use it. Or precisely what would count as "in use".

## Battery Cell Voltages

The proposed battery message is:

```xml
    <message id="371" name="BATTERY_CELL_VOLTAGES">
      <description>Battery cell voltages.
        This message is provided primarily for cell fault debugging.
        For batteries with more than 10 cells the message should be sent multiple times, iterating the index value.
        It should be streamed at very low rate (less than once a minute) or streamed only on request.</description>
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

