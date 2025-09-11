# AM32 Mavlink Settings Protocol
Send and receive the AM32 Settings key/values over MAVLink.

**Requirements**
1. The FC Firmware (FW) must support MAVLink
2. The FC FW must support an ESC communication protocol:
    - Four-way protocol: one-wire, bidirectional serial protocol, over the signal wire between FC <--> ESC
    - DShot Programming Mode: two-wire, dshot over the signal wire and DShot Serial Telemetry
3. The Ground Control Station (GCS) must provide a user interface and implement the AM32 Mavlink Protocol

### Motivation
Changing the settings on your AM32 ESC is an integral part of configuring your drone. The status quo requires that in order to communicate with the ESCs you need to have them connected to an FC that supports "ESC Passthrough" and you must connect that FC over USB to a PC and run the AM32 Configurator in your browser. This workflow poses some challenges under certain conditions:
1. The user has already integrated their ESCs/FC into the airframe and the FC USB is not easily accessible.
2. The FC does not have an exposed USB port. (ARK Jetson Carrier, ARK Pi6X)
3. The FC firmware does not support ESC Passthrough (PX4)
4. The user is in the field and cannot access https://am32.ca/configurator

**Requirements**
1. FC has a USB port. You must connect the USB port to a host PC.
2. FC FW supports ESC Passthrough
3. Must have internet to use AM32 Configurator

---

### AM32 EEPROM

There are 48 bytes in the AM32 EEPROM data structure, 39 of which are user configurable settings.
https://github.com/am32-firmware/AM32/blob/main/Inc/eeprom.h

The settings can be read using the four-way protocol or by sending the [DSHOT_CMD_ESC_INFO](https://brushlesswhoop.com/dshot-and-bidirectional-dshot/#special-commands) dshot command. When the dshot command is sent the settings are received over the DShot Serial Telemetry wire as a 49 byte block with 48 bytes being the EEPROM data and 1 byte CRC.

### MAVLink message design
We need to send settings key/value pairs between the GCS and the FC. This can be accomplished a few ways:

#### Option 1: Single Message
Send the data using a single mavlink message. The message is used for both reading and writing. After writing the settings the message will be emitted back to the GCS with the updated settings values.
```xml
    <message id="292" name="AM32_EEPROM">
      <description>AM32 ESC EEPROM data. Direction of transfer depends on mode field: either reports current configuration from ESC or commands new configuration to ESC. For write requests, a bitmask allows selective writing of specific bytes to avoid corrupting unchanged values.</description>
      <field type="uint8_t" name="target_system">System ID (ID of target system, normally flight controller).</field>
      <field type="uint8_t" name="target_component">Component ID (normally 0 for broadcast).</field>
      <field type="uint8_t" name="index">Index of the ESC (0 = ESC1, 1 = ESC2, etc.).</field>
      <field type="uint8_t" name="mode">Operation mode: 0 = readout, 1 = write request.</field>
      <field type="uint32_t[6]" name="write_mask">Bitmask indicating which bytes in the data array should be written (only used in write mode). Each bit corresponds to a byte index in the data array (bit 0 of write_mask[0] = data[0], bit 31 of write_mask[0] = data[31], bit 0 of write_mask[1] = data[32], etc.). Set bits indicate bytes to write, cleared bits indicate bytes to skip. This allows precise updates of individual parameters without overwriting the entire EEPROM.</field>
      <field type="uint8_t" name="length">Number of valid bytes in data array.</field>
      <field type="uint8_t[192]" name="data">Raw AM32 EEPROM data. Unused bytes should be set to zero. Note: the AM32 EEPROM is currently only 192 bytes long. This array has been sized to use the maximum payload length for a MAVLink message in an attempt to future-proof the message in case AM32 extends the EEPROM data length.</field>
    </message>
```

#### Option 2: Generic Read Message and Write Command
Send each read setting as a single generic mavlink message. Write each setting using a MAV_CMD. The settings are defined in an enum and the FC is responsible for the implementation details. This would allow supporting other ESCs than AM32.
```xml
    <enum name="ESC_TYPE_ENUM">
      <entry value="0" name="ESC_TYPE_ENUM_AM32">
        <description>The ESC is AM32</description>
      </entry>
      <entry value="1" name="ESC_TYPE_ENUM_BLUEJAY">
        <description>The ESC is Bluejay</description>
      </entry>
      <entry value="2" name="ESC_TYPE_ENUM_BLHELI32">
        <description>The ESC is BLHeli32</description>
      </entry>
      <entry value="3" name="ESC_TYPE_ENUM_ETC">
        <description>etc</description>
      </entry>
    </enum>
    <enum name="ESC_SETTING_ENUM">
      <entry value="0" name="ESC_SETTING_ENUM_POLE_COUNT">
        <description>Motor pole count</description>
      </entry>
      <entry value="1" name="ESC_SETTING_ENUM_MOTOR_KV">
        <description>Motor KV</description>
      </entry>
      <entry value="2" name="ESC_SETTING_ENUM_DIRECTION_REVERSED">
        <description>Motor spin direction</description>
      </entry>
      <entry value="3" name="ESC_SETTING_ENUM_ETC">
        <description>etc</description>
      </entry>
    </enum>
    <message id="292" name="ESC_SETTING">
      <description>The read ESC setting value from the ESC</description>
      <field type="uint8_t" name="esc" enum="ESC_TYPE_ENUM">ESC Type</field>
      <field type="uint8_t" name="setting" enum="ESC_SETTING_ENUM">ESC Setting</field>
      <field type="uint8_t" name="value">Value to write</field>
    </message>
    <entry value="312" name="MAV_CMD_ESC_WRITE_SETTING" hasLocation="false" isDestination="false">
        <description>Write an ESC Setting.</description>
        <param index="1" label="Index" minValue="0" maxValue="255" increment="1">Index of the ESC (0 = ESC1, 1 = ESC2, etc.). 255 = request from all.</param>
        <param index="2" label="Setting" minValue="0" maxValue="255" increment="1">ESC_SETTING_ENUM enum.</param>
        <param index="3" label="Value" increment="1">Value to write</param>
        <param index="4" reserved="true" default="NaN"/>
        <param index="5" reserved="true" default="NaN"/>
        <param index="6" reserved="true" default="NaN"/>
        <param index="7" reserved="true" default="NaN"/>
    </entry>
```

#### Option 3: Leverage existing Parameter protocol
We could use Parameters for each setting. This would allow leveraging the existing mechanisms for reading/writing parameters. I think it's a bad idea for a number of reasons I will list in the below pros/cons section.

#### Common

In all cases we need to be able to request the reading of AM32 Settings
```xml
      <entry value="312" name="MAV_CMD_AM32_REQUEST_EEPROM" hasLocation="false" isDestination="false">
        <description>Request EEPROM data from an AM32 ESC.</description>
        <param index="1" label="Index" minValue="0" maxValue="255" increment="1">Index of the ESC to query (0 = ESC1, 1 = ESC2, etc.). 255 = request from all.</param>
        <param index="2" reserved="true" default="NaN"/>
        <param index="3" reserved="true" default="NaN"/>
        <param index="4" reserved="true" default="NaN"/>
        <param index="5" reserved="true" default="NaN"/>
        <param index="6" reserved="true" default="NaN"/>
        <param index="7" reserved="true" default="NaN"/>
      </entry>
```

---

# Pros and Cons

#### Option 1: Single Message
**Pros**
- Settings are read and written as a block (save-model). This results in reduced user friction since the UI will look and function the same as the AM32 Configurator.
- The FC can treat the eeprom update operation atomically. It writes all of the settings indicated in the write_mask and sends a save command when finished.
- Simple flow, easy to implement, FC does not need to carry the settings details (name, range, eeprom address, etc)
- I've already completed and tested the work in PX4 and QGC using DShot Programming Mode

**Cons**
- GCS would need to be updated to support a new settings layout if the `eeprom_version` is bumped. But this applies to all options, it just changes where the update is needed (GCS vs FC).
- Low level passthrough style implementation. Some people might not like the use of low level details like this at the GCS level.

#### Option 2: Generic Read Message and Write Command
**Pros**
- Not AM32 specific, allows supporting other ESCs in the future.
- Each setting write gets an ACK, NACK would indicate setting does not exist.
- GCS only needs to know about a settings type/min/max/increment/decimals/units and nothing else.
- GCS can implement a no-save model which is consistent with existing QGC parameter update model.

**Cons**
- FC needs to carry the `setting --> address` mapping
- FC needs to perfom the conversion of the value from real to uint8 format and vice versa
- FC needs to sanitize the value before writing (min/max/increment)
- FC needs to know when the start/stop of settings writes happens. Both four-way and dshot programming protocols require atomic updates.
- **OR** Settings are updated individually (no-save model). The change of a single setting (drag slider and release) will trigger the atomic write/save/read.
- GCS can only update the 39 settings. No option to write the entire eeprom (TBD if there is a use case for this)
- GCS needs to have a different UI to support other ESCs since the available settings may differ as well as the settings min/max/increment/decimals/units
- Generic messages means more time and effort to implement -- we incur the Generalization Tax. Would the other ESC vendors ever actually implement this?

#### Option 3: Leverage existing Parameter protocol
**Pros**
- Leverage exisiting read/write mechanisms in FC FW and GCS.

**Cons**
- parameters are typically associated with "mavlink systems" and the ESC is not a mavlink system
- if associated with sysid 1 (FC) and compid N it would require each ESC to have a mavlink componenet ID -- the ESC is not a mavlink component
- if a FW supported 8 ESCs max this introduces 39 x 8 new parameters (flash usage gets bigger, param file gets bigger)
- opens the can of worms of the FC "owning the ESC params". In other words, a user might want to have the FC check the settings and write them if they don't match the configured parameters.
