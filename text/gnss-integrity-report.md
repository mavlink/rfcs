  * Start date: 2026-06-25
  * Contributors: bgptiste

# Summary

This RFC proposes restructuring the `GNSS_INTEGRITY` message into two separate messages. One provides resilience and integrity information global to a GNSS receiver. The other provides RF interference diagnostics per frequency band. The goal for both messages is to be as generic and vendor-agnostic as possible.

# Motivation 

The current `GNSS_INTEGRITY` MAVLink message reports only global (per-receiver) resilience information. For jamming, for instance, the user can find out whether a detection or mitigation has occurred, but no further detail is available: which frequency band is affected, or how many bands are impacted. The idea is therefore to expose this per-band information, allowing operators to take action or log the data for post-flight analysis.

A secondary goal is to make both messages as future-proof as possible. This requires limiting receiver-specific scales and abstract units. If a field cannot be populated by two different receiver brands (Septentrio and u-blox for instance) because it is defined on a proprietary scale, that field will be useless for half of all deployments.

By contrast, if a field uses a concrete, standard unit (Hz, seconds, etc.) or maps to an explicit enumeration (detected, not detected, mitigated, etc.), it can remain unpopulated today and be filled in transparently when either a receiver firmware update exposes the data or a driver is updated to parse it. In both cases, the protocol will remain unchanged. 

However, there are cases where vendor-specific data genuinely aids diagnostics with a more user-friendly approach. Septentrio's quality indicators are one example: they present complex receiver health metrics as a simple 0-10 scale, similar to how a phone displays signal strength or battery level. One option would be a dedicated, and potentially optional, vendor extension message carrying this kind of data, keeping the main integrity messages vendor-agnostic. This remains an open design question. A proposal is presented in the [Alternatives](#alternatives) section. 

For reference, the original `GNSS_INTEGRITY` message, as defined in `development.xml`, is as follows:
```xml
<message id="441" name="GNSS_INTEGRITY">
    <description>Information about key components of GNSS receivers, like signal authentication, interference and system errors.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="system_errors" enum="GPS_SYSTEM_ERROR_FLAGS">Errors in the GPS system.</field>
    <field type="uint8_t" name="authentication_state" enum="GPS_AUTHENTICATION_STATE">Signal authentication state of the GPS system.</field>
    <field type="uint8_t" name="jamming_state" enum="GPS_JAMMING_STATE">Signal jamming state of the GPS system.</field>
    <field type="uint8_t" name="spoofing_state" enum="GPS_SPOOFING_STATE">Signal spoofing state of the GPS system.</field>
    <field type="uint8_t" name="raim_state" enum="GPS_RAIM_STATE">The state of the RAIM processing.</field>
    <field type="uint16_t" name="raim_hfom" units="cm" invalid="UINT16_MAX">Horizontal expected accuracy using satellites successfully validated using RAIM.</field>
    <field type="uint16_t" name="raim_vfom" units="cm" invalid="UINT16_MAX">Vertical expected accuracy using satellites successfully validated using RAIM.</field>
    <field type="uint8_t" name="corrections_quality" minValue="0" maxValue="10" invalid="UINT8_MAX">An abstract value representing the estimated quality of incoming corrections, or 255 if not available.</field>
    <field type="uint8_t" name="system_status_summary" minValue="0" maxValue="10" invalid="UINT8_MAX">An abstract value representing the overall status of the receiver, or 255 if not available.</field>
    <field type="uint8_t" name="gnss_signal_quality" minValue="0" maxValue="10" invalid="UINT8_MAX">An abstract value representing the quality of incoming GNSS signals, or 255 if not available.</field>
    <field type="uint8_t" name="post_processing_quality" minValue="0" maxValue="10" invalid="UINT8_MAX">An abstract value representing the estimated PPK quality, or 255 if not available.</field>
</message>
```
The related enumerations are as follows: 
```xml
<enum name="GPS_SYSTEM_ERROR_FLAGS" bitmask="true">
    <description>Flags indicating errors in a GPS receiver.</description>
    <entry value="1" name="GPS_SYSTEM_ERROR_INCOMING_CORRECTIONS"><description>There are problems with incoming correction streams.</description></entry>
    <entry value="2" name="GPS_SYSTEM_ERROR_CONFIGURATION"><description>There are problems with the configuration.</description></entry>
    <entry value="4" name="GPS_SYSTEM_ERROR_SOFTWARE"><description>There are problems with the software on the GPS receiver.</description></entry>
    <entry value="8" name="GPS_SYSTEM_ERROR_ANTENNA"><description>There are problems with an antenna connected to the GPS receiver.</description></entry>
    <entry value="16" name="GPS_SYSTEM_ERROR_EVENT_CONGESTION"><description>There are problems handling all incoming events.</description></entry>
    <entry value="32" name="GPS_SYSTEM_ERROR_CPU_OVERLOAD"><description>The GPS receiver CPU is overloaded.</description></entry>
    <entry value="64" name="GPS_SYSTEM_ERROR_OUTPUT_CONGESTION"><description>The GPS receiver is experiencing output congestion.</description></entry>
</enum>
<enum name="GPS_AUTHENTICATION_STATE">
    <description>Signal authentication state in a GPS receiver.</description>
    <entry value="0" name="GPS_AUTHENTICATION_STATE_UNKNOWN"><description>The GPS receiver does not provide GPS signal authentication info.</description></entry>
    <entry value="1" name="GPS_AUTHENTICATION_STATE_INITIALIZING"><description>The GPS receiver is initializing signal authentication.</description></entry>
    <entry value="2" name="GPS_AUTHENTICATION_STATE_ERROR"><description>The GPS receiver encountered an error while initializing signal authentication.</description></entry>
    <entry value="3" name="GPS_AUTHENTICATION_STATE_OK"><description>The GPS receiver has correctly authenticated all signals.</description></entry>
    <entry value="4" name="GPS_AUTHENTICATION_STATE_DISABLED"><description>GPS signal authentication is disabled on the receiver.</description></entry>
</enum>
<enum name="GPS_JAMMING_STATE">
    <description>Signal jamming state in a GPS receiver.</description>
    <entry value="0" name="GPS_JAMMING_STATE_UNKNOWN"><description>The GPS receiver does not provide GPS signal jamming info.</description></entry>
    <entry value="1" name="GPS_JAMMING_STATE_NOT_JAMMED"><description>The GPS receiver detected no signal jamming.</description></entry>
    <entry value="2" name="GPS_JAMMING_STATE_MITIGATED"><description>The GPS receiver detected and mitigated signal jamming.</description></entry>
    <entry value="3" name="GPS_JAMMING_STATE_DETECTED"><description>The GPS receiver detected signal jamming.</description></entry>
</enum>
<enum name="GPS_SPOOFING_STATE">
    <description>Signal spoofing state in a GPS receiver.</description>
    <entry value="0" name="GPS_SPOOFING_STATE_UNKNOWN"><description>The GPS receiver does not provide GPS signal spoofing info.</description></entry>
    <entry value="1" name="GPS_SPOOFING_STATE_NOT_SPOOFED"><description>The GPS receiver detected no signal spoofing.</description></entry>
    <entry value="2" name="GPS_SPOOFING_STATE_MITIGATED"><description>The GPS receiver detected and mitigated signal spoofing.</description></entry>
    <entry value="3" name="GPS_SPOOFING_STATE_DETECTED"><description>The GPS receiver detected signal spoofing but still has a fix.</description></entry>
</enum>
<enum name="GPS_RAIM_STATE">
    <description>State of RAIM processing.</description>
    <entry value="0" name="GPS_RAIM_STATE_UNKNOWN"><description>RAIM capability is unknown.</description></entry>
    <entry value="1" name="GPS_RAIM_STATE_DISABLED"><description>RAIM is disabled.</description></entry>
    <entry value="2" name="GPS_RAIM_STATE_OK"><description>RAIM integrity check was successful.</description></entry>
    <entry value="3" name="GPS_RAIM_STATE_FAILED"><description>RAIM integrity check failed.</description></entry>
</enum>
```

# Detailed Design 

The proposal relies on two messages: an updated `GNSS_INTEGRITY` for global receiver-level information, and a new `GNSS_BANDS` reporting diagnostics for each frequency band individually. 

For each, a proposed implementation is provided alongside a table showing field presence in the original `GNSS_INTEGRITY` message and the corresponding data sources in Septentrio and u-blox receiver outputs. These two manufacturers were chosen as the primary references to guide the redesign: they represent different implementation philosophies, which makes their comparison a useful tool for identifying the right level of abstraction for vendor-agnostic fields. NovAtel receiver outputs were then examined as a secondary reference to validate the proposed approach, as described in the [Approach validation based on NovAtel receiver outputs](#approach-validation-based-on-novatel-receiver-outputs) subsection of the [Alternatives](#alternatives) section.

Moreover, the relevant fields and enumerations have all been renamed, changing the prefix from `GPS_*` to `GNSS_*`. 

## Global integrity and resilience status for a GNSS receiver

Most of the original `GNSS_INTEGRITY` has been retained. The changes are as follows:
- Main antenna status and power have been added. While both concepts are exposed by Septentrio and u-blox, the available diagnostics differ (in fault classification or power reporting, for example), so not all mappings can be provided for every vendor. More details are available in the related table. <br> Combining the status and power fields into a single one by adding an `OFF` entry to the `GNSS_ANTENNA_STATE` enumeration is also a possibility.

- Septentrio's quality indicators (0-10 scale) have been removed.

- `corrections_age`, `cpu_load`, and `up_time` have been added with standard units, to aid debugging. 
Both Septentrio and u-blox expose these fields. However, `corrections_age` requires a lookup table on the u-blox side as the receiver reports it in time intervals rather than a direct value. 
Feedback on the relevance of these three fields is welcome.

- The enumeration entries `GNSS_JAMMING_STATE_NOT_JAMMED` and `GNSS_SPOOFING_STATE_NOT_SPOOFED` have been renamed to `GNSS_JAMMING_STATE_SPECTRUM_CLEAN` and `GNSS_SPOOFING_STATE_SPECTRUM_CLEAN`, respectively, to clarify that the receiver has not detected indicators of jamming or spoofing, rather than asserting a proven absence of such threats. In practice, most GNSS receivers do not prove the absence of jamming or spoofing because they only assess that the observed RF environment appears normal when no detection mechanisms have been triggered.
These states are also reused for the per-band reports.

- `GNSS_SPOOFING_STATE_MITIGATED` has been replaced by `GNSS_SPOOFING_STATE_AFFECTED` to avoid implying a clearly defined spoofing mitigation stage, since spoofing mitigation is not explicitly reported by receivers and corresponding countermeasures may operate across multiple internal receiver layers (hence the difficulty in reporting them). Instead, the new state indicates that receiver output (position or raw measurements) may be impacted by non-authentic GNSS signals. <br> For Septentrio, this mapping can be based on `RFStatus.Flags` Bit 0 (`SIG_AUTH_ALERT`), which indicates potential loss of signal authenticity and possible impact on receiver output based on built-in checks. Detection based solely on navigation message authentication (NMA) failure (`RFStatus.Flags` Bit 1, `NAV_MSG_AUTH_ALERT`) can be mapped to `GNSS_SPOOFING_STATE_DETECTED`. <br> For u-blox, spoofing is reported using "indicated" and "affirmed" detection levels, which may be mapped to `AFFECTED` depending on interpretation of internal receiver checks, or conservatively to `DETECTED` in both cases when ambiguity remains. <br> In both vendor implementations, future firmware updates may improve the separation between detection levels and output-impact indicators. In the current model, `GNSS_SPOOFING_STATE_DETECTED` represents a generic detection state, while `GNSS_SPOOFING_STATE_AFFECTED` is reserved for cases where receiver output is known or indicated to be impacted by non-authentic signals. Although this distinction is not perfectly aligned with current receiver internal states, introducing it increases long-term extensibility of the message.

- The description of the `GNSS_AUTHENTICATION_STATE_OK` entry in the `authentication_state` field has been changed from *"The GNSS receiver has correctly authenticated all signals"* to *"GNSS signal authentication is operating normally"*. This field indicates the state of the receiver's authentication process (currently primarily OSNMA), rather than whether all received signals or navigation messages have been successfully authenticated. 
Authentication failures are instead reflected by the `spoofing_state` field. <br> Renaming the `OK` entry to `OPERATIONAL`, `ENABLED`, `ACTIVE`, or `AUTHENTICATING` may also be worth considering. However, `OPERATIONAL` seems to be used by u-blox to indicate the availability of the OSNMA service (`UBX-SEC-OSNMA.nmaStatus`), while `ENABLED` and `ACTIVE` do not necessarily imply that authentication is functioning correctly. <br> Septentrio additionally reports which satellites (for Galileo and GPS only) transmitted unauthenticated navigation messages via the `GalAuthenticMask` and `GpsAuthenticMask` fields of the `GALAuthStatus` block. However, this level of detail is likely too specific to expose through MAVLink.

The updated and new enumerations are defined in the [Updated and new enumerations](#updated-and-new-enumerations) section.

Updated `GNSS_INTEGRITY` message:
```xml
<message id="441" name="GNSS_INTEGRITY">
    <description>Global integrity and resilience status for a GNSS receiver, like jamming and spoofing summary states, signal authentication and system errors. Per-band RF diagnostics are in GNSS_BANDS.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="system_errors" enum="GNSS_SYSTEM_ERROR_FLAGS">Bitmask of errors in the GPS system. Vendors set only the bits they can detect.</field>
    <field type="uint8_t" name="antenna_state" enum="GNSS_ANTENNA_STATE">Status of the main antenna supervisor.</field>
    <field type="uint8_t" name="antenna_power" enum="GNSS_ANTENNA_POWER">Power state of the main antenna.</field>
    <field type="uint8_t" name="authentication_state" enum="GNSS_AUTHENTICATION_STATE">Signal authentication state of the GNSS system.</field>
    <field type="uint8_t" name="jamming_state" enum="GNSS_JAMMING_STATE">Signal jamming state of the GNSS system.</field>
    <field type="uint8_t" name="spoofing_state" enum="GNSS_SPOOFING_STATE">Signal spoofing state of the GNSS system.</field>
    <field type="uint8_t" name="raim_state" enum="GNSS_RAIM_STATE">Status of the RAIM processing.</field>
    <field type="uint16_t" name="raim_hfom" units="cm" invalid="UINT16_MAX">Horizontal expected accuracy using satellites successfully validated using RAIM.</field>
    <field type="uint16_t" name="raim_vfom" units="cm" invalid="UINT16_MAX">Vertical expected accuracy using satellites successfully validated using RAIM.</field>
    <field type="uint16_t" name="corrections_age" units="cs" invalid="UINT16_MAX">Age of the most recently applied differential corrections, in centiseconds (10ms units).</field>
    <field type="uint8_t" name="cpu_load" units="%" invalid="UINT8_MAX">Receiver CPU load in percent.</field>
    <field type="uint32_t" name="up_time" units="s" invalid="UINT32_MAX">Time elapsed since the startup or the last reset of the receiver.</field>
</message>
```

| Field | In previous `GNSS_INTEGRITY` | Septentrio source | u-blox source |
|-------|--------------------------|------------------|---------------|
| `system_errors` | Yes | `ReceiverStatus.RxError` + `ExtError` | `UBX-MON-RF.antStatus` indirectly |
| `antenna_state` | No (only antenna error bit) | **Not directly available** (`RxError.ANTENNA` only reports overcurrent conditions, no SHORT/OPEN distinction) | `UBX-MON-RF.antStatus` (per band, then only the first block is read, no overcurrent reporting) |
| `antenna_power` | No | **Not directly available** (`ReceiverStatus.RxState.ACTIVEANTENNA` is set when current is drawn from antenna connector, it does not distinguish passive antenna from powered-off active antenna) | `UBX-MON-RF.antPower` (per band, then only the first block is read) |
| `authentication_state` | Yes | `GALAuthStatus.OSNMAStatus` | Multiple sources available: `UBX-SEC-OSNMA.osnmaEnabled` / `UBX-SEC-OSNMA.nmaStatus` / `UBX-SEC-OSNMA.dsmAuthenticationStatus` / `UBX-NAV-PVT.nmaFixStatus` |
| `jamming_state` | Yes | `RFStatus.RFBand.Info.Mode` (per band, then we take the worst case) |  `UBX-SEC-SIG.jamState` (`UBX-MON-RF.jammingState` deprecated in protocol versions that support `UBX-SEC-SIG`) | 
| `spoofing_state` | Yes | `RFStatus.Flags` bits 0-1 | `UBX-SEC-SIG.spfState` / `UBX-NAV-STATUS.spoofDetState` |
| `raim_state` | Yes | `PVTGeodetic.AlertFlag` bits 0-1 | `UBX-TIM-TP.raim` |
| `raim_hfom` | Yes | `DOP.HPL` | **Not directly available** (`UBX-NAV-PVT.hAcc` is not RAIM-specific) |
| `raim_vfom` | Yes | `DOP.VPL` | **Not directly available** (`UBX-NAV-PVT.vAcc` is not RAIM-specific) |
| `corrections_age` | No | `PVTGeodetic.MeanCorrAge` | `UBX-NAV-PVT.lastCorrectionAge` (lookup table needed) (`NAV-PVT.diffAge`: NMEA only) |
| `cpu_load` | No | `ReceiverStatus.CPULoad` | `UBX-MON-SYS.cpuLoad`  |
| `up_time` | No | `ReceiverStatus.UpTime` | `UBX-MON-SYS.runTime` |

## New per-band RF diagnostics

A new message, `GNSS_BANDS`, has been introduced to provide per-band interference visibility. The main goal is to give operators insight into which individual frequency bands are affected by jamming and whether the receiver is mitigating it.

Two approaches were considered:

- Use the jamming indicators computed by the receivers themselves (the same ones used for `GNSS_INTEGRITY`), but resolved per frequency band block. Specifically, these are `RFStatus.RFBand` for Septentrio and `UBX-SEC-SIG.jamStateCentFreq` for u-blox. Both provide the center frequency of the affected band and indicate whether it is jammed, based on the receiver's internal algorithms. Septentrio additionally exposes mitigation information: whether the band was suppressed manually, automatically, or left unmitigated.

- Supplement or replace this with raw front-end values (noise floor, AGC level, CW jamming level, and I/Q imbalance and magnitude), to allow operators to interpret results themselves. 
However, this data is exposed only by u-blox, and in a different message (`UBX-MON-RF`) from the one that contains the per-band jamming status. That message previously included a per-block jamming status field, but this has since been deprecated in protocol versions that support `UBX-SEC-SIG`, making it difficult to correlate the two sources reliably.

The proposal here is to retain only what is strictly necessary to take action or conduct post-flight investigation: which frequency is affected, whether jamming is present, and whether the receiver is mitigating it.

This keeps the message user-friendly, avoids populating fields that will be empty for half of all deployments, and limits payload size. It also has the advantage that all required data comes from a single receiver output, which greatly simplifies aggregation at the flight controller level. In addition, using the center frequency rather than a band identifier (L1, L2, etc.) is more future-proof. If needed, the ground station can handle the frequency-to-band mapping.

The interference characteristics (bandwidth and power) per band are not included in the minimal message, as they are not available from u-blox. However, they are available from Septentrio and may be worth including, since they are expressed in standard units. This option is presented in the [Alternatives](#alternatives) section, along with the raw front-end fields mentioned above.

Finally, a per-band spoofing detection field could be added speculatively to future-proof the message, even though no vendor currently exposes this data. 

Minimal `GNSS_BANDS` message:
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="frequency" units="Hz" invalid="0">Center frequency of this RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint8_t" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
</message>
```

| Field | In previous `GNSS_INTEGRITY` | Septentrio source | u-blox source |
|-------|--------------------------|------------------|---------------|
| `frequency` | No | `RFStatus.RFBand.Frequency` | `UBX-SEC-SIG.jamStateCentFreq.centFreq` |
| `band_jamming_state` | Yes (but not per-band) | `RFStatus.RFBand.Info.Mode` | `UBX-SEC-SIG.jamStateCentFreq.jammed`  |
| `band_mitigation_state` | No | `RFStatus.RFBand.Info.Mode` bits 0-3 | **Not available** (`UBX-MON-RF.jammingState` deprecated in protocol versions that support `UBX-SEC-SIG`) |

## Updated and new enumerations 

```xml
<enum name="GNSS_ANTENNA_STATE">
    <description>Antenna state in a GNSS receiver.</description>
    <entry value="0" name="GNSS_ANTENNA_STATE_UNKNOWN"><description>Unknown or not reported.</description></entry>
    <entry value="1" name="GNSS_ANTENNA_STATE_INITIALIZING"><description>Antenna is initializing.</description></entry>
    <entry value="2" name="GNSS_ANTENNA_STATE_OK"><description>Antenna operating normally.</description></entry>
    <entry value="3" name="GNSS_ANTENNA_STATE_SHORT"><description>Antenna short circuit detected.</description></entry>
    <entry value="4" name="GNSS_ANTENNA_STATE_OPEN"><description>Antenna open circuit (disconnected).</description></entry>
    <entry value="5" name="GNSS_ANTENNA_STATE_OVERCURRENT"><description>Antenna overcurrent condition detected.</description></entry>
</enum>
<enum name="GNSS_ANTENNA_POWER">
    <description>Antenna power state in a GNSS receiver.</description>
    <entry value="0" name="GNSS_ANTENNA_POWER_UNKNOWN"><description>Power state unknown.</description></entry>
    <entry value="1" name="GNSS_ANTENNA_POWER_OFF"><description>Antenna power is off.</description></entry>
    <entry value="2" name="GNSS_ANTENNA_POWER_ON"><description>Antenna power is on.</description></entry>
</enum>
<enum name="GNSS_AUTHENTICATION_STATE">
    <description>Signal authentication state in a GNSS receiver.</description>
    <entry value="0" name="GNSS_AUTHENTICATION_STATE_UNKNOWN"><description>The GNSS receiver does not provide GNSS signal authentication information.</description></entry>
    <entry value="1" name="GNSS_AUTHENTICATION_STATE_INITIALIZING"><description>The GNSS receiver is initializing signal authentication.</description></entry>
    <entry value="2" name="GNSS_AUTHENTICATION_STATE_ERROR"><description>The GNSS receiver encountered an error while initializing signal authentication.</description></entry>
    <entry value="3" name="GNSS_AUTHENTICATION_STATE_OK"><description>GNSS signal authentication is operating normally.</description></entry>
    <entry value="4" name="GNSS_AUTHENTICATION_STATE_DISABLED"><description>GNSS signal authentication is disabled on the receiver.</description></entry>
</enum>
<enum name="GNSS_SPOOFING_STATE">
    <description>Signal spoofing state in a GNSS receiver.</description>
    <entry value="0" name="GNSS_SPOOFING_STATE_UNKNOWN"><description>The receiver does not provide GNSS signal spoofing information.</description></entry>
    <entry value="1" name="GNSS_SPOOFING_STATE_SPECTRUM_CLEAN"><description>No signal spoofing indicators have been detected by the receiver.</description></entry>
    <entry value="2" name="GNSS_SPOOFING_STATE_DETECTED"><description>Signal spoofing indicators have been detected by the receiver.</description></entry>
    <entry value="3" name="GNSS_SPOOFING_STATE_AFFECTED"><description>The receiver indicates that its measurements or PVT may be affected by non-authentic GNSS signals.</description></entry>
</enum>
<enum name="GNSS_JAMMING_STATE">
    <description>Signal jamming state in a GNSS receiver.</description>
    <entry value="0" name="GNSS_JAMMING_STATE_UNKNOWN"><description>The GNSS receiver does not provide GNSS signal jamming information.</description></entry>
    <entry value="1" name="GNSS_JAMMING_STATE_SPECTRUM_CLEAN"><description>No signal jamming indicators have been detected by the GNSS receiver.</description></entry>
    <entry value="2" name="GNSS_JAMMING_STATE_DETECTED"><description>Signal jamming indicators have been detected by the GNSS receiver.</description></entry>
    <entry value="3" name="GNSS_JAMMING_STATE_MITIGATED"><description>Signal jamming has been detected and active mitigation is applied by the receiver.</description></entry>
</enum>
<enum name="GNSS_JAMMING_MITIGATION_STATE">
    <description>Per-band jamming mitigation state reported by a GNSS receiver. Indicates whether detected interference is being actively mitigated, and by what mechanism.</description>
    <entry value="0" name="GNSS_JAMMING_MITIGATION_UNKNOWN"><description>Mitigation state is not available or not reported by this receiver.</description></entry>
    <entry value="1" name="GNSS_JAMMING_MITIGATION_NOT_MITIGATED"><description>Interference detected in this band but no mitigation is applied.</description></entry>
    <entry value="2" name="GNSS_JAMMING_MITIGATION_CANCELLED"><description>Interference detected in this band and successfully cancelled by the receiver autonomously.</description></entry>
    <entry value="3" name="GNSS_JAMMING_MITIGATION_SUPPRESSED"><description>This band is suppressed by a notch filter configured manually by operator command.</description></entry>
</enum>
```

# Alternatives 

## Extended per-band GNSS integrity message

This section presents the fields that were considered but not included in the proposed `GNSS_BANDS` message, along with three alternative versions:

- **Alternative 1:** The minimal message from the detailed design section, extended with interference characteristics (bandwidth and power), which are not available from u-blox (standard units: kHz, dBm).
- **Alternative 2:** The above, further extended with a per-band spoofing detection state. This field cannot yet be populated by any vendor but is included speculatively to future-proof the message. This possibility was discussed, in particular, with Septentrio. Since spoofing mitigation is not reported even at the receiver level, adding a dedicated per-band mitigation state would not be meaningful. As with per-band jamming detection, the same enumeration as the global spoofing state could be reused. 
- **Alternative 3:** A fully extended version including all interesting fields exposed by at least one vendor, covering the raw front-end diagnostics.

A global field mapping table is provided at the end of this section.

**Alternative 1:** `GNSS_BANDS` with interference characteristics
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="frequency" units="Hz" invalid="0">Center frequency of this RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint16_t" name="interference_bandwidth" units="kHz" invalid="UINT16_MAX">Bandwidth of detected interference in this band (kHz). 0 for pulsed interference.</field>
    <field type="int8_t" name="interference_power" units="dBm" invalid="INT8_MIN">Estimated interference power in this band (dBm). 0 if not estimable or manual notch filter.</field>
    <field type="uint8_t" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
</message>
```

**Alternative 2:** `GNSS_BANDS` extended with per-band spoofing state
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="frequency" units="Hz" invalid="0">Center frequency of this RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint16_t" name="interference_bandwidth" units="kHz" invalid="UINT16_MAX">Bandwidth of detected interference in this band (kHz). 0 for pulsed interference.</field>
    <field type="int8_t" name="interference_power" units="dBm" invalid="INT8_MIN">Estimated interference power in this band (dBm). 0 if not estimable or manual notch filter.</field>
    <field type="uint8_t" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
    <field type="uint8_t" name="band_spoofing_state" enum="GNSS_SPOOFING_STATE">Per-band spoofing state.</field>
</message>
```

**Alternative 3:** `GNSS_BANDS` extended to all currently exposed (and interesting) fields
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="frequency" units="Hz" invalid="0">Center frequency of this RF band in Hz. 0 if not known.</field>
    <field type="uint8_t" name="band_id">RF band id.</field>
    <field type="uint8_t" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
    <!-- Interference characteristics -->
    <field type="uint16_t" name="interference_bandwidth" units="kHz" invalid="UINT16_MAX">Bandwidth of detected interference in this band (kHz). 0 for pulsed interference.</field>
    <field type="int8_t" name="interference_power" units="dBm" invalid="INT8_MIN">Estimated interference power in this band (dBm). 0 if not estimable or manual notch filter.</field>
    <!-- Raw RF front-end diagnostics -->
    <field type="uint16_t" name="noise_floor" invalid="UINT16_MAX">Raw noise floor as measured by the receiver front-end.</field>
    <field type="uint16_t" name="agc_count" invalid="UINT16_MAX">Automatic Gain Control (AGC) level.</field>
    <field type="uint8_t" name="cw_jamming_level" invalid="UINT8_MAX">Continuous Wave (CW) jamming level (0=no CW jamming, 255=strong CW jamming).</field>
    <!-- I/Q diagnostics — antenna / signal chain health -->
    <field type="int8_t" name="ofs_i" invalid="INT8_MAX">Imbalance of I-channel.</field>
    <field type="uint8_t" name="mag_i" invalid="UINT8_MAX">Magnitude of I-channel (0=no signal).</field>
    <field type="int8_t" name="ofs_q" invalid="INT8_MAX">Imbalance of Q-channel.</field>
    <field type="uint8_t" name="mag_q" invalid="UINT8_MAX">Magnitude of Q-channel (0=no signal).</field>
    <!-- Per-band antenna diagnostics -->
    <field type="uint8_t" name="band_antenna_state" enum="GNSS_ANTENNA_STATE">Status of the antenna for this band.</field>
    <field type="uint8_t" name="band_antenna_power" enum="GNSS_ANTENNA_POWER">Power state of the antenna for this band.</field>
</message>
```

| Field | In previous `GNSS_INTEGRITY` | Present in Alternative(s) | Septentrio source | u-blox source |
|-------|--------------------------|-------------|------------------|---------------|
| `frequency` | No | 1, 2, 3 | `RFStatus.RFBand.Frequency` | `UBX-SEC-SIG.jamStateCentFreq.centFreq` |
| `band_id` | No | 3 | **Not available** | ` UBX-MON-RF.blockId` |
| `band_jamming_state` | Yes (but not per-band) | 1, 2, 3 | `RFStatus.RFBand.Info.Mode` | `UBX-SEC-SIG.jamStateCentFreq.jammed` |
| `band_mitigation_state` | No | 1, 2, 3 | `RFStatus.RFBand.Info.Mode` bits 0-3 | **Not available** (`UBX-MON-RF.jammingState` deprecated in protocol versions that support `UBX-SEC-SIG`) |
| `interference_bandwidth` | No | 1, 2, 3 | `RFStatus.RFBand.Bandwidth` (kHz) | **Not available** |
| `interference_power` | No | 1, 2, 3 | `RFStatus.RFBand.Power` (dBm) | **Not available** |
| `noise_floor` | No | 3 | **Not available** | `UBX-MON-RF.noisePerMS` |
| `agc_count` | No | 3 | **Not available** (Gain available in `ReceiverStatus.AGCState.Gain`, expressed in dB) | `UBX-MON-RF.agcCnt` |
| `cw_jamming_level` | No | 3 | **Not available** | `UBX-MON-RF.cwSuppression` |
| `ofs_i`, `mag_i`, `ofs_q`, `mag_q` | No | 3 | **Not available** | `UBX-MON-RF` |
| `band_antenna_state` | No | 3 | Global only (error bit) | `UBX-MON-RF.antStatus` |
| `band_antenna_power` | No | 3 | Global only | `UBX-MON-RF.antPower` |
| `band_spoofing_state` | No | 2 | **Not available** | **Not available** |

## Approach validation based on NovAtel receiver outputs

NovAtel OEM7 outputs were examined as a secondary reference to assess whether the proposed fields generalise beyond Septentrio and u-blox. The key findings are as follows:
- **System errors, receiver status, and antenna status/power monitoring** map directly from the `RXSTATUS` log, which exposes structured status and error words, including bits 3-6 for antenna-related conditions (power, LNA, open circuit, short circuit).
- **RAIM state and protection levels** map directly from the `RAIMSTATUS` log, which exposes an integrity status field (`NOT_AVAILABLE` / `PASS` / `FAIL`) and explicit HPL and VPL values in metres. 
- **Corrections age** maps directly from `BESTPOS.diff_age`, expressed in seconds.
- `cpu_load`, `up_time`, and `authentication_state` have no NovAtel equivalent.
- **Jamming and spoofing status indicators** are available, but with less granularity than that of the proposed enumeration. `RXSTATUS` provides a single global bit for jamming detection (bit 15) and a single bit for spoofing detection (bit 9), with no attenuation status or distinction between detection levels.
- **Per-band interference data** are available via the `ITDETECTSTATUS` log. It reports detected interferences per RF path (L1, L2, L5) and exposes the center frequency in MHz, the bandwidth in MHz, and the estimated interference power in dBm. These map directly to `frequency` (converted to Hz), `interference_bandwidth` (converted to kHz), and `interference_power`. It also provides the highest estimated power spectrum density of the interference in dBmHz, which is not available in Septentrio receivers. 
The `RXSTATUS` Auxiliary 1 status word additionally provides per-RF-path jammer detection bits (RF1 to RF6), which map to `band_jamming_state`, although using RF path identifiers rather than center frequencies.

Given the consistency of interference-related characteristics across Septentrio and NovAtel, it appears justified to consider including them in `GNSS_BANDS`, even if u-blox does not provide equivalent fields.

## Septentrio quality indicators

To prevent Septentrio users from losing information previously transmitted by `GNSS_INTEGRITY`, a dedicated message could also be defined to carry Septentrio's quality indicators, preserving the four fields that were removed from the new `GNSS_INTEGRITY`. While they cannot be populated by other vendors, they provide a simple and immediately readable health summary that is useful for ground station displays and operator situational awareness. It could be optional for example. 
```xml
<message id="450" name="GNSS_SEPT_QUALITY">
    <description>Quality indicators for Septentrio GNSS receivers.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint8_t" name="corrections_quality" minValue="0" maxValue="10" invalid="UINT8_MAX">Septentrio-scale value representing the estimated quality of incoming corrections, or 255 if not available.</field>
    <field type="uint8_t" name="system_status_summary" minValue="0" maxValue="10" invalid="UINT8_MAX">Septentrio-scale value representing the overall status of the receiver, or 255 if not available.</field>
    <field type="uint8_t" name="gnss_signal_quality" minValue="0" maxValue="10" invalid="UINT8_MAX">Septentrio-scale value representing the quality of incoming GNSS signals, or 255 if not available.</field>
    <field type="uint8_t" name="post_processing_quality" minValue="0" maxValue="10" invalid="UINT8_MAX">Septentrio-scale value representing the quality of RTK post-processing, or 255 if not available.</field>
</message>
```
| Field | In previous `GNSS_INTEGRITY` | Septentrio source | u-blox source |
|-------|--------------------------|------------------|---------------|
| `corrections_quality` | Yes | `QualityInd` type 30 (0-10) | No equivalent |
| `system_status_summary` | Yes | `QualityInd` type 0 (0-10) | No equivalent |
| `gnss_signal_quality` | Yes | `QualityInd` type 1 (0-10) | No equivalent |
| `post_processing_quality` | Yes | `QualityInd` type 31 (0-10) | No equivalent |

# Unresolved Questions

Any comments, recommendations, and ideas are welcome.

The following questions remain open:

- Are all the fields added to `GNSS_INTEGRITY` relevant? In particular, is `up_time` worth the 4 bytes it occupies? Would other metrics be useful? 
- Should `antenna_state` and `antenna_power` be kept as two separate fields, or merged into a single field by adding an `OFF` entry to `GNSS_ANTENNA_STATE`? Are all states of `GNSS_ANTENNA_STATE` relevant, given the different possible mappings between vendors?
- Is it useful to distinguish between spoofing detection alone and the indication that receiver output (position or raw measurements) may be affected by spoofing in `GNSS_SPOOFING_STATE`, even if the currently available receiver fields are not perfectly aligned with this distinction? This has been discussed in parallel with Septentrio, which shares the objective of improving the link between spoofing detection and its impact on receiver output, and is continuing development in this direction.
- Should the `GNSS_AUTHENTICATION_STATE_OK` entry be renamed to `OPERATIONAL`, `ENABLED`, `ACTIVE`, or `AUTHENTICATING`?
- Do operators need the raw per-band RF front-end diagnostics in MAVLink at the expense of bandwidth efficiency and vendor agnosticism, or are the processed jamming and mitigation states sufficient? Is interference bandwidth and interference power worth including, given that both are currently not available from u-blox but carry standard units (dBm and kHz respectively)?
- Should a field for per-band spoofing detection be added speculatively to `GNSS_BANDS`, even though no vendor currently provides this information?
- Is a dedicated `GNSS_SEPT_QUALITY` message the right approach for Septentrio's quality indicators?

A separate question concerns the transmission model for `GNSS_BANDS`. Two options can be envisioned, though other solutions are welcome:

- One message per band per cycle, with the band identified by the combination of `id` (the receiver ID) and `frequency`.
- A single message per cycle, with a `band_count` field and per-field arrays indexed by band.

# References 

- PRs/Issues/Discussions:
    - [Initial GNSS_INTEGRITY MAVLink PR #2110](https://github.com/mavlink/mavlink/pull/2110)
    - [MAVLink PR #2461](https://github.com/mavlink/mavlink/pull/2461)
    - [DroneCAN PR #77](https://github.com/dronecan/DSDL/pull/77)
    - [PX4 PR #26438](https://github.com/PX4/PX4-Autopilot/pull/26438)
    - [PX4-GPSDrivers PR #200](https://github.com/PX4/PX4-GPSDrivers/pull/200) 

<br>

- Technical references (GNSS receiver documentation):
    - [Mosaic-G5 Firmware v1.1.0 Reference Guide](https://www.septentrio.com/en/products/gnss-receivers/gnss-receiver-modules/mosaic-G5-P3H)
    - [Mosaic-X5 Firmware v4.15.1 Reference Guide](https://www.septentrio.com/en/products/gnss-receivers/gnss-receiver-modules/mosaic-x5)
    - [u-blox X20 HPG 2.00 Interface Description](https://content.u-blox.com/sites/default/files/documents/u-blox-20-HPG-2.00_InterfaceDescription_UBXDOC-304424225-19888.pdf)
    - [u-blox F9 HPG 1.51 Interface Description](https://content.u-blox.com/sites/default/files/documents/u-blox-F9-HPG-1.51_InterfaceDescription_UBXDOC-963802114-13124.pdf)
    - [Novatel OEM7 Commands and Logs Manual](https://docs.novatel.com/OEM7/Content/PDFs/OEM7_Commands_Logs_Manual.pdf)
