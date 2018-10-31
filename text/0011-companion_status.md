  * Start date: 2018-10-31
  * Contributors: Tanja Baumann <tanja@auterion.com>
  * Related PR: [companion_status #1014](https://github.com/mavlink/mavlink/pull/1014)
 
# Summary

Proposal for a MAVLink message to monitor processes on the companion computer. The companion process will report a state including its PID, the type of process.

  
# Motivation

Currently the autopilot has no knowledge about the state of processes running on the companion computer. Those are potentially critical processes like the avoidance algorithm or VIO which the user relies on. Having those processes report a state allows for user warnings in QGC if something is not running correctly or eventually integraton in the preflight checks. 

# Detailed Design

The message contains fields for the following data:
* timestamp
* pid (process ID)
* type (generic, avoidance, VIO, ...)
* state 


## Proposed Enums

    <enum name="COMPANION_STATE">
      <description> Status of a companion process</description>
      <entry value="0" name="COMPANION_STATE_HEALTHY"/>
      <entry value="1" name="COMPANION_STATE_TIMEOUT"/>
      <entry value="2" name="COMPANION_STATE_ABORT"/>
      <entry value="3" name="COMPANION_STATE_STARTING"/>
      <entry value="4" name="COMPANION_STATE_COMPONENT_FAIL"/>
   </enum>
   <enum name="COMPANION_TYPE">
      <description> Type of a companion process</description>
      <entry value="0" name="COMPANION_TYPE_GENERIC"/>
      <entry value="1" name="COMPANION_TYPE_AVOIDANCE"/>
      <entry value="2" name="COMPANION_TYPE_VIO"/>
   </enum>



## Proposed Message
    <message id="334" name="COMPANION_STATUS">
      <description> Message to monitor the state of processes on the companion computer </description>
      <field type="uint64_t" name="time_usec" units="us">Timestamp (since system boot or since UNIX epoch).</field>
      <field type="uint8_t" name="state" enum="COMPANION_STATE">Status of a component on the companion computer.</field>
      <field type="uint8_t" name="type" enum="COMPANION_TYPE">Source on the companion computer reporting the status.</field>
      <field type="uint16_t" name="pid">process ID of source</field>
    </message>

