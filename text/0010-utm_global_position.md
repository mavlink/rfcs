  * Start date: 2018-10-4
  * Contributors: Michael Schaeuble <michael@auterion.com>, DFS Deutsche Flugsicherung
  * Related issues:

# Summary

Proposal for a MAVLink message to communicate with various unmanned traffic management (UTM) systems and to generalize the interface between vehicle and external UTM services. The message contains a unique ID, position, velocity, mission and flight status information. The proposed message was created in collaboration with DFS Deutsche Flugsicherung.

# Motivation

Due to recent developments with regards to UTM services and different regional UTM efforts, a generalized interface should be defined to communicate the vehicles information and state to an external UTM service. The message contains a field for a unique identifier and provides information on the vehicle's status and current mission goal. Depending on the capabilities of the vehicle or the current flight state, selected fields can be invalidated using a data available flag.

# Detailed Design

The message contains fields for the following data:
* Unique identifier
* Global position, altitude and height above ground
* Velocities
* Indicators for the position and velocity uncertainty
* Current mission target
* Update rate of the message itself, with information when the next update will be published
* Flight state of the vehicle
* Data available flags to invalidate fields that are not initialized

The subsequent sections describe the proposed message and enums related to the UTM interface.

## Proposed enums

<enum name="UTM_FLIGHT_STATE">
  <description>Airborne status of UAS.</description>
  <entry value="1" name="UTM_FLIGHT_STATE_UNKNOWN">
    <description>The flight state can't be determined.</description>
  </entry>
  <entry value="2" name="UTM_FLIGHT_STATE_GROUND">
    <description>UAS on ground.</description>
  </entry>
  <entry value="3" name="UTM_FLIGHT_STATE_AIRBORNE">
    <description>UAS airborne.</description>
  </entry>
</enum>

<enum name="UTM_DATA_AVAIL_FLAGS">
  <description>Flags for the global position report.</description>
  <entry value="1" name="UTM_DATA_AVAIL_FLAGS_TIME_VALID">
    <description>The field time contains valid data.</description>
  </entry>
  <entry value="2" name="UTM_DATA_AVAIL_FLAGS_UAS_ID_AVAILABLE">
    <description>The field uas_id contains valid data.</description>
  </entry>
  <entry value="4" name="UTM_DATA_AVAIL_FLAGS_POSITION_AVAILABLE">
    <description>The fields lat, lon and h_acc contain valid data.</description>
  </entry>
  <entry value="8" name="UTM_DATA_AVAIL_FLAGS_ALTITUDE_AVAILABLE">
    <description>The fields alt and v_acc contain valid data.</description>
  </entry>
  <entry value="16" name="UTM_DATA_AVAIL_FLAGS_RELATIVE_ALTITUDE_AVAILABLE">
    <description>The field relative_alt contains valid data.</description>
  </entry>
  <entry value="32" name="UTM_DATA_AVAIL_FLAGS_HORIZONTAL_VELO_AVAILABLE">
    <description>The fields vx and vy contain valid data.</description>
  </entry>
  <entry value="64" name="UTM_DATA_AVAIL_FLAGS_VERTICAL_VELO_AVAILABLE">
    <description>The field vz contains valid data.</description>
  </entry>
  <entry value="128" name="UTM_DATA_AVAIL_FLAGS_NEXT_WAYPOINT_AVAILABLE">
    <description>The fields next_lat, next_lon and next_alt contain valid data.</description>
  </entry>
</enum>

## Proposed message

<message id="334" name="UTM_GLOBAL_POSITION">
  <description>The global position resulting from GPS and sensor fusion.</description>
  <field type="uint64_t" name="time" units="us">Time of applicability of position (microseconds since UNIX epoch).</field>
  <field type="uint8_t[18]" name="uas_id">Unique UAS ID.</field>
  <field type="int32_t" name="lat" units="degE7">Latitude (WGS84), in degrees * 1E7.</field>
  <field type="int32_t" name="lon" units="degE7">Longitude (WGS84), in degrees * 1E7.</field>
  <field type="int32_t" name="alt" units="mm">Altitude (WGS84), in meters * 1000.</field>
  <field type="int32_t" name="relative_alt" units="mm">Altitude above ground in meters * 1000.</field>
  <field type="int16_t" name="vx" units="cm/s">Ground X Speed (Latitude, positive north), expressed as m/s * 100.</field>
  <field type="int16_t" name="vy" units="cm/s">Ground Y Speed (Longitude, positive east), expressed as m/s * 100.</field>
  <field type="int16_t" name="vz" units="cm/s">Ground Z Speed (Altitude, positive down), expressed as m/s * 100.</field>
  <field type="uint32_t" name="h_acc" units="mm">Horizontal Position uncertainty in meters * 1000. (standard deviation)</field>
  <field type="uint32_t" name="v_acc" units="mm">Altitude uncertainty in meters * 1000. (standard deviation)</field>
  <field type="uint32_t" name="vel_acc" units="mm/s">Speed uncertainty in m/s * 1000. (standard deviation)</field>
  <field type="int32_t" name="next_lat" units="degE7">Next waypoint, Latitude (WGS84), in degrees * 1E7.</field>
  <field type="int32_t" name="next_lon" units="degE7">Next waypoint, Longitude (WGS84), in degrees * 1E7.</field>
  <field type="int32_t" name="next_alt" units="mm">Next waypoint, Altitude (WGS84), in meters * 1000.</field>
  <field type="uint16_t" name="update_rate">Seconds * 1E2 until next update. Set to 0 if unknown or in data driven mode.</field>
  <field type="uint8_t" name="flight_state">The flight state defined in enum \verb|UTM_FLIGHT_STATE|.</field>
  <field type="uint8_t" name="flags">Bitwise OR combination of the enums \verb|UTM_DATA_AVAIL_FLAGS|.</field>
</message>
