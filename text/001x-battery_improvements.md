  * Start date: 2022-03-26
  * Contributors: Hamish Willee <hamishwillee@gmail.com>, ...
  * Related issues: 
    - [16-cell support #1747](https://github.com/mavlink/mavlink/pull/1747)
	- [common: added voltage and current multipliers to BATTERY_STATUS #233](https://github.com/ArduPilot/mavlink/pull/233)
    - [Add MAV_BATTERY_CHARGE_STATE_CHARGING #1068](https://github.com/mavlink/mavlink/pull/1068)
    - dronecan / DSDL : [WIP smart battery messages](https://github.com/dronecan/DSDL/pull/7) 
    - [DS-013 Pixhawk Smart Battery Standard](https://docs.google.com/document/d/1xYBhhgjND_RS2W3Hq0Seyc-R661ge3zonk9DTIyHclc/edit) v0.4.0

  
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
        Note that smart batteries should set the MAV_BATTERY_STATUS_FLAGS_CAPACITY_RELATIVE_TO_FULL bit to indicate that supplied capacity values are relative to a battery that is known to be full.
        Power monitors would not set this bit, indicating that capacity_consumed is relative to drone power-on, and that other values are estimated based on the assumption that the battery was full on power-on.
      </description>
      <field type="uint8_t" name="id" instance="true">Battery ID</field>
      <field type="int16_t" name="temperature" units="cdegC" invalid="INT16_MAX">Temperature of the whole battery pack (not internal electronics). INT16_MAX field not provided.</field>
      <field type="uint32_t" name="voltage" units="mV" invalid="UINT32_MAX">Battery voltage (total). UINT32_MAX: field not provided.</field>
      <field type="int32_t" name="current" units="mA" invalid="INT32_MAX">Battery current (through all cells/loads). Positive value when discharging and negative if charging. INT32_MAX: field not provided.</field>
      <field type="uint32_t" name="capacity_consumed" units="mAh" invalid="UINT32_MAX">Consumed charge. UINT32_MAX: field not provided. This is either the consumption since power-on or since the battery was full, depending on the value of MAV_BATTERY_STATUS_FLAGS_CAPACITY_RELATIVE_TO_FULL.</field>
      <field type="uint32_t" name="capacity_remaining" units="mAh" invalid="UINT32_MAX">Remaining charge (until empty). UINT32_MAX: field not provided. Note: If MAV_BATTERY_STATUS_FLAGS_CAPACITY_RELATIVE_TO_FULL is unset, this value is based on the assumption the battery was full when the system was powered.</field>
      <field type="uint8_t" name="percent_remaining" units="%" invalid="UINT8_MAX">Remaining battery energy. Values: [0-100], UINT8_MAX: field not provided.</field>
      <field type="uint32_t" name="status_flags" display="bitmask" enum="MAV_BATTERY_STATUS_FLAGS">Fault, health, readiness, and other status indications.</field>
    </message>
```

`MAV_BATTERY_STATUS_FLAGS` is a new enum that includes faults, charge state, and battery mode:

```xml
    <enum name="MAV_BATTERY_STATUS_FLAGS" bitmask="true">
      <description>Battery status flags for fault, health and state indication.</description>
      <entry value="1" name="MAV_BATTERY_STATUS_FLAGS_NOT_READY_TO_USE">
        <description>
          The battery is not ready to use (fly).
          Set if the battery has faults or other conditions that make it unsafe to fly with.
          Note: It will be the logical OR of other status bits (chosen by the manufacturer/integrator).
        </description>
      </entry>
      <entry value="2" name="MAV_BATTERY_STATUS_FLAGS_CHARGING">
        <description>
          Battery is charging.
        </description>
      </entry>
      <entry value="4" name="MAV_BATTERY_STATUS_FLAGS_CELL_BALANCING">
        <description>
          Battery is cell balancing (during charging).
          Not ready to use (MAV_BATTERY_STATUS_FLAGS_NOT_READY_TO_USE may be set).
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
          Not ready to use (MAV_BATTERY_STATUS_FLAGS_NOT_READY_TO_USE would be set).
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
          Note that battery protection monitoring should only be enabled when the vehicle is landed. Once the vehicle is armed, or starts moving, the protections should be disabled to prevent false positives from disabling the output.
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
      <entry value="262144" name="MAV_BATTERY_STATUS_FLAGS_CAPACITY_RELATIVE_TO_FULL">
        <description>
          Battery capacity values are relative to a known-full battery.
          If set: the supplied capacity_consumed and capacity_remaining are relative to battery full.
          If unset: capacity_consumed is relative to drone power-on, and capacity_remaining estimated from capacity_consumed and the assumption that the battery was full at power on.
          This bit should be set by smart batteries and unset for power modules.
          If unset a GCS is recommended to advise that users fully charge the battery on power on.
        </description>
      </entry>
      <entry value="4,294,967,295" name="MAV_BATTERY_STATUS_FLAGS_EXTENDED">
        <description>Reserved (not used). If set, this will indicate that an additional status field exists for higher status values.</description>
      </entry>
    </enum>
```

The message is heavily based on [BATTERY_STATUS](https://mavlink.io/en/messages/common.html#BATTERY_STATUS) but:
- removes the cell voltage arrays: `voltages` and `voltages_ext`
- adds `voltage`, the total cell voltage. This is a uint32_t to allow batteries with more than 65V.
- `current_consumed` has changed to capacity_consumed, and from an `int32_t` to a `uint32_t`.
  This future proofs from 32767 mAh limit to 4294967295 mAh 
- removes `energy_consumed`, which essentially duplicates `capacity_consumed` for most purposes, and `capacity_consumed` in mAh is nearly ubiquitous.
- adds `capacity_remaining`(mAh).
  - This allows a GCS to more accurately determine available current and remaining time than inferring from the `capacity_consumed` and `percent_remaining`.
  - This will be reliable for smart batteries.
  - A flag has been added to indicate whether this is calculated from an assumed or known-full battery.
    A GCS can use this to prompt that batteries be fully charged for power modules.
- Note that with capacity consumed and remaining, you have the full capacity and you could calculate the percentage remaining.
  However percentage remaining is supplied anyway, as the other values are optional, and this is actually the one value that most users really want.
- change `current` from a `int16_t` (cA) to a `int32_t` (mA). Maximum size was previously 327.67A, which is not large enough to be future proof. New value gives up to 2,147,483A. The value is positive when discharging, and negative when charging.
- removes `time_remaining`.
  ```xml
  <field type="uint32_t" name="time_remaining" units="s" invalid="UINT32_MAX">Remaining battery time (estimated), UINT32_MAX: Remaining battery time estimate not provided.</field>
  ```
  - This is an estimated "convenience" value which can be calculated as well or better by a GCS, in particular on multi-battery systems (from original charge, `capacity_consumed` and looking at the rate of `current` over some time period).
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
        For batteries with more than 12 cells the message should be sent multiple times, iterating the index value.
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

