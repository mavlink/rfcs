  * Start date: 2026-06-25
  * Contributors: bgptiste

# Summary

This RFC proposes restructuring the work-in-progress [`GNSS_INTEGRITY`](https://mavlink.io/en/messages/development.html#GNSS_INTEGRITY) message into two separate messages.
The first message is to provide resilience and integrity information for the whole GNSS receiver, while the other provides RF interference diagnostics per frequency band.
The goal for both messages is to be as generic and vendor-agnostic as possible.

# Motivation 

The current `GNSS_INTEGRITY` MAVLink message reports only global (per-receiver) resilience information. For jamming, for instance, the user can find out whether a detection or mitigation has occurred, but no further detail is available: which frequency band is affected, or how many bands are impacted. The idea is therefore to expose this per-band information, allowing operators to take action or log the data for post-flight analysis.

A secondary goal is to make both messages as future-proof as possible. This requires limiting receiver-specific scales and abstract units. If a field cannot be populated by two different receiver brands (Septentrio and u-blox for instance) because it is defined on a proprietary scale, that field will be useless for half of all deployments.

By contrast, if a field uses a concrete, standard unit (Hz, seconds, etc.) or maps to an explicit enumeration (detected, not detected, mitigated, etc.), it can remain unpopulated today and be filled in transparently when either a receiver firmware update exposes the data or a driver is updated to parse it. In both cases, the protocol will remain unchanged. 

However, there are cases where vendor-specific data genuinely aids diagnostics with a more user-friendly approach. Septentrio-specific quality indicators are one example: they present complex receiver health metrics as a simple 0-10 scale, similar to how a phone displays signal strength or battery level. One option would be a dedicated, and potentially optional, vendor extension message carrying this kind of data, keeping the main integrity messages vendor-agnostic. This remains an open design question. A proposal is presented in the [Alternatives](#alternatives) section. 

## Original Design

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

The proposal relies on two messages: an updated `GNSS_INTEGRITY` message for global receiver-level information, and a new `GNSS_BANDS` message for reporting diagnostics at the individual frequency-band level.

For each message, a proposed implementation is provided alongside a table showing field presence in the original `GNSS_INTEGRITY` message and the corresponding data sources in Septentrio and u-blox receiver outputs. These two manufacturers were selected as the primary references for this redesign: both are already supported by PX4 and ArduPilot, and they represent different implementation approaches, making their comparison useful for identifying the appropriate level of abstraction for vendor-agnostic fields. NovAtel receiver outputs were then examined as a secondary reference to validate the proposed approach, as described in the [Approach validation based on NovAtel receiver outputs](#approach-validation-based-on-novatel-receiver-outputs) subsection of the [Alternatives](#alternatives) section.

The intended transmission rates for these messages, as well as the bandwidth overhead they introduce, are discussed in the [Intended message rates](#intended-message-rates) and [Intended message overhead](#intended-message-overhead) sections.

Additionally, all relevant fields and enumerations have been renamed by replacing the `GPS_*` prefix with `GNSS_*`, in order to better reflect support for multiple satellite constellations.

## Global integrity and resilience status for a GNSS receiver

**Updated `GNSS_INTEGRITY` message:**
```xml
<message id="441" name="GNSS_INTEGRITY">
    <description>Global integrity and resilience status for a GNSS receiver, like jamming and spoofing summary states, signal authentication and system errors. Per-band RF diagnostics are in GNSS_BANDS.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="system_errors" enum="GNSS_SYSTEM_ERROR_FLAGS">Bitmask of errors in the GNSS system. Vendors set only the bits they can detect.</field>
    <field type="uint8_t" name="antenna_state" enum="GNSS_ANTENNA_STATE">Status of the main antenna supervisor.</field>
    <field type="uint8_t" name="antenna_power" enum="GNSS_ANTENNA_POWER">Power state of the main antenna.</field>
    <field type="uint8_t" name="cpu_load" units="%" invalid="UINT8_MAX">Receiver CPU load in percent.</field>
    <field type="uint32_t" name="up_time" units="s" invalid="UINT32_MAX">Time elapsed since the startup or the last reset of the receiver.</field>
    <field type="uint16_t" name="corrections_age" units="cs" invalid="UINT16_MAX">Age of the most recently applied differential corrections, in centiseconds (10ms units).</field>
    <field type="uint8_t" name="authentication_state" enum="GNSS_AUTHENTICATION_STATE">Signal authentication state of the GNSS system.</field>
    <field type="uint8_t" name="jamming_state" enum="GNSS_JAMMING_STATE">Signal jamming state of the GNSS system.</field>
    <field type="uint8_t" name="spoofing_state" enum="GNSS_SPOOFING_STATE">Signal spoofing state of the GNSS system.</field>
    <field type="uint8_t" name="raim_state" enum="GNSS_RAIM_STATE">Status of the RAIM (Receiver Autonomous Integrity Monitoring) processing.</field>
    <field type="uint16_t" name="raim_hpl" units="cm" invalid="UINT16_MAX">Horizontal Protection Level (HPL) representing a statistical upper bound on the horizontal position error.</field>
    <field type="uint16_t" name="raim_vpl" units="cm" invalid="UINT16_MAX">Vertical Protection Level (VPL) representing a statistical upper bound on the vertical position error.</field>
</message>
```

**Field source mapping:**
| Field | In previous `GNSS_INTEGRITY` | Septentrio source | u-blox source |
|-------|--------------------------|------------------|---------------|
| `system_errors` | Yes | `ReceiverStatus.RxError` + `ExtError` | `UBX-MON-RF.antStatus` indirectly |
| `antenna_state` | No (only antenna error bit) | **Not directly available** (`RxError.ANTENNA` only reports overcurrent conditions, no SHORT/OPEN distinction) | `UBX-MON-RF.antStatus` (per band, then only the first block is read, no overcurrent reporting) |
| `antenna_power` | No | **Not directly available** (`ReceiverStatus.RxState.ACTIVEANTENNA` is set when current is drawn from antenna connector, it does not distinguish passive antenna from powered-off active antenna) | `UBX-MON-RF.antPower` (per band, then only the first block is read) |
| `cpu_load` | No | `ReceiverStatus.CPULoad` (%) | `UBX-MON-SYS.cpuLoad` (%) |
| `up_time` | No | `ReceiverStatus.UpTime` (seconds) | `UBX-MON-SYS.runTime` (seconds) |
| `corrections_age` | No | `PVTGeodetic.MeanCorrAge` (0.01 s, i.e. centiseconds) | `UBX-NAV-PVT.lastCorrectionAge` (4-bit encoded index into time interval ranges in seconds, lookup table needed) |
| `authentication_state` | Yes | `GALAuthStatus.OSNMAStatus` | Multiple sources available: `UBX-SEC-OSNMA.osnmaEnabled` / `UBX-SEC-OSNMA.nmaStatus` / `UBX-SEC-OSNMA.dsmAuthenticationStatus` / `UBX-NAV-PVT.nmaFixStatus` |
| `jamming_state` | Yes | `RFStatus.RFBand.Info.Mode` (per band, then we take the worst case) |  `UBX-SEC-SIG.jamState` (`UBX-MON-RF.jammingState` deprecated in protocol versions that support `UBX-SEC-SIG`) | 
| `spoofing_state` | Yes | `RFStatus.Flags` bits 0-1 | `UBX-SEC-SIG.spfState` / `UBX-NAV-STATUS.spoofDetState` |
| `raim_state` | Yes | `PVTGeodetic.AlertFlag` bits 0-1 | `UBX-TIM-TP.raim` |
| `raim_hpl` | Yes | `DOP.HPL` (meters) | **Not directly available** (`UBX-NAV-PVT.hAcc` is not RAIM-specific) |
| `raim_vpl` | Yes | `DOP.VPL` (meters) | **Not directly available** (`UBX-NAV-PVT.vAcc` is not RAIM-specific) |

The updated and new enumerations are defined in the [Updated and new enumerations](#updated-and-new-enumerations) section. 

Field types, units, and resolutions are mostly derived from the native output formats documented by the receivers, to avoid unnecessary precision loss in the driver mapping.

Most of the original `GNSS_INTEGRITY` has been retained. The changes are as follows:

- **Main antenna status and power have been added.** While both concepts are exposed by Septentrio and u-blox, the available diagnostics differ (in fault classification or power reporting, for example), so not all mappings can be provided for every vendor. More details are available in the related table. <br> Combining the status and power fields into a single one by adding an `OFF` entry to the `GNSS_ANTENNA_STATE` enumeration is also a possibility.

- **Septentrio-specific quality indicators (0-10 scale) have been removed.**

- **`cpu_load`, `up_time`, and `corrections_age` have been added with standard units**, to aid debugging. 
Both Septentrio and u-blox expose these fields. However, `corrections_age` requires a lookup table on the u-blox side as the receiver reports it in time intervals rather than a direct value. 
Feedback on the relevance of these three fields is welcome.

- **The description of the `GNSS_AUTHENTICATION_STATE_OK` entry in the `authentication_state` field has been changed** from *"The GNSS receiver has correctly authenticated all signals"* to *"GNSS signal authentication is operating normally"*. This field indicates the state of the receiver's authentication process (currently primarily OSNMA), rather than whether all received signals or navigation messages have been successfully authenticated. 
Authentication failures are instead reflected by the `spoofing_state` field. <br> Renaming the `OK` entry to `OPERATIONAL`, `ENABLED`, `ACTIVE`, or `AUTHENTICATING` may also be worth considering. However, `OPERATIONAL` seems to be used by u-blox to indicate the availability of the OSNMA service (`UBX-SEC-OSNMA.nmaStatus`), while `ENABLED` and `ACTIVE` do not necessarily imply that authentication is functioning correctly. <br> Septentrio additionally reports which satellites (for Galileo and GPS only) transmitted unauthenticated navigation messages via the `GalAuthenticMask` and `GpsAuthenticMask` fields of the `GALAuthStatus` block. However, this level of detail is likely too specific to expose through MAVLink.

- **The enumeration entries `GNSS_JAMMING_STATE_NOT_JAMMED` and `GNSS_SPOOFING_STATE_NOT_SPOOFED` have been renamed to `GNSS_JAMMING_STATE_SPECTRUM_CLEAN` and `GNSS_SPOOFING_STATE_SPECTRUM_CLEAN`**, respectively, to clarify that the receiver has not detected indicators of jamming or spoofing, rather than asserting a proven absence of such threats. In practice, most GNSS receivers do not prove the absence of jamming or spoofing because they only assess that the observed RF environment appears normal when no detection mechanisms have been triggered.
These states are also reused for the per-band reports.

- **`GNSS_SPOOFING_STATE_MITIGATED` has been replaced by `GNSS_SPOOFING_STATE_AFFECTED`** to avoid implying a clearly defined spoofing mitigation stage, since spoofing mitigation is not explicitly reported by receivers and corresponding countermeasures may operate across multiple internal receiver layers (hence the difficulty in reporting them). Instead, the new state indicates that receiver output (position or raw measurements) may be impacted by non-authentic GNSS signals. <br> For Septentrio, this mapping can be based on `RFStatus.Flags` Bit 0 (`SIG_AUTH_ALERT`), which indicates potential loss of signal authenticity and possible impact on receiver output based on built-in checks. Detection based solely on navigation message authentication (NMA) failure (`RFStatus.Flags` Bit 1, `NAV_MSG_AUTH_ALERT`) can be mapped to `GNSS_SPOOFING_STATE_DETECTED`. <br> For u-blox, spoofing is reported using "indicated" and "affirmed" detection levels, which may be mapped to `AFFECTED` depending on interpretation of internal receiver checks, or conservatively to `DETECTED` in both cases when ambiguity remains. <br> In both vendor implementations, future firmware updates may improve the separation between detection levels and output-impact indicators. In the current model, `GNSS_SPOOFING_STATE_DETECTED` represents a generic detection state, while `GNSS_SPOOFING_STATE_AFFECTED` is reserved for cases where receiver output is known or indicated to be impacted by non-authentic signals. Although this distinction is not perfectly aligned with current receiver internal states, introducing it increases long-term extensibility of the message.

- **`raim_hfom` and `raim_vfom` have been renamed to `raim_hpl` and `raim_vpl` respectively**, and their descriptions updated accordingly. [RAIM (Receiver Autonomous Integrity Monitoring)](https://gssc.esa.int/navipedia/index.php/RAIM) is a technique that uses redundancy among tracked satellites to detect and isolate faulty measurements, and to compute protection levels from the remaining consistent set. These protection levels, HPL and VPL, are statistical upper bounds on the horizontal and vertical position error, not accuracy estimates (in SBAS-aided mode, for example, they are derived from SBAS error estimates instead). The original field names (`hfom`, `vfom`) and descriptions ("expected accuracy") incorrectly implied an accuracy metric rather than an integrity bound. The new names follow the DO-229 standard terminology, as used in the Septentrio receiver documentation. <br> Both fields are encoded as `uint16_t` in centimeters, giving a maximum representable value of 655.34 m. This is considered sufficient, as the Horizontal and Vertical Alert Limits (HAL/VAL) for non-precision approach navigation are 556 m (0.3 nm) and 50 m respectively according to the [NovAtel OEM7 documentation](https://docs.novatel.com/OEM7/Content/PDFs/OEM7_Commands_Logs_Manual.pdf), meaning protection levels above this range already indicate that integrity requirements cannot be met.

## New per-band RF diagnostics

A new message, `GNSS_BANDS`, has been introduced to provide per-band interference visibility. The main goal is to give operators insight into which individual frequency bands are affected by jamming and whether the receiver is mitigating it.

The proposed structure stores the information for all reported bands in a single `GNSS_BANDS` message. The `band_count` field indicates the number of frequency bands contained in the arrays below. Each field is therefore defined as a static array of size `GNSS_MAX_BANDS` (not yet defined), with the same index referring to the same reported band across all arrays. This avoids the overhead of multiple small messages while keeping the message structure simple for flight controller implementations. The choice of this structure is further discussed and justified in the [Intended message overhead](#intended-message-overhead) section.

**Minimal `GNSS_BANDS` message:**
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint8_t" name="band_count">Number of active RF bands reported in the arrays below.</field>
    <field type="uint32_t[GNSS_MAX_BANDS]" name="frequency" units="Hz" invalid="[0]">Center frequency of each RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
</message>
```

**Field source mapping:**
| Field | In previous `GNSS_INTEGRITY` | Septentrio source | u-blox source |
|-------|--------------------------|------------------|---------------|
| `band_count` | No | `RFStatus.N` | `UBX-SEC-SIG.jamNumCentFreqs` |
| `frequency` | No | `RFStatus.RFBand.Frequency` (Hz) | `UBX-SEC-SIG.jamStateCentFreq.centFreq` (kHz) |
| `band_jamming_state` | Yes (but not per-band) | `RFStatus.RFBand.Info.Mode` | `UBX-SEC-SIG.jamStateCentFreq.jammed`  |
| `band_mitigation_state` | No | `RFStatus.RFBand.Info.Mode` bits 0-3 | **Not available** (`UBX-MON-RF.jammingState` deprecated in protocol versions that support `UBX-SEC-SIG`) |

Two approaches were considered when defining `GNSS_BANDS`:

- **Use the jamming indicators computed by the receivers themselves** (the same ones used for `GNSS_INTEGRITY`), but resolved per frequency band block. Specifically, these are `RFStatus.RFBand` for Septentrio and `UBX-SEC-SIG.jamStateCentFreq` for u-blox. Both provide the center frequency of the affected band and indicate whether it is jammed, based on the receiver's internal algorithms. Septentrio additionally exposes mitigation information: whether the band was suppressed manually, automatically, or left unmitigated.

- **Supplement or replace this with raw front-end values** (noise floor, AGC level, CW jamming level, and I/Q imbalance and magnitude), to allow operators to interpret results themselves. 
However, this data is exposed only by u-blox, and in a different message (`UBX-MON-RF`) from the one that contains the per-band jamming status. That message previously included a per-block jamming status field, but this has since been deprecated in protocol versions that support `UBX-SEC-SIG`, making it difficult to correlate the two sources reliably.

The proposal here is to retain only what is strictly necessary to take action or conduct post-flight investigation: **which frequency is affected, whether jamming is present, and whether the receiver is mitigating it.**

This keeps the message user-friendly, avoids populating fields that will be empty for half of all deployments, and limits payload size. It also has the advantage that all required data comes from a single receiver output, which greatly simplifies aggregation at the flight controller level. In addition, using the center frequency rather than a band identifier (L1, L2, etc.) is more future-proof. If needed, the ground station can handle the frequency-to-band mapping.

The interference characteristics (bandwidth and power) per band are not included in the minimal message, as they are not available from u-blox. However, they are available from Septentrio and may be worth including, since they are expressed in standard units. This option is presented in the [Alternatives](#alternatives) section, along with the raw front-end fields mentioned above.

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

## Intended message rates

To minimize serial and CAN link utilization while providing comprehensive diagnostic capabilities, we propose streaming both `GNSS_INTEGRITY` and `GNSS_BANDS` at a low, synchronized rate. These diagnostic messages monitor resilience and interference metrics that evolve on a much slower timescale than high-frequency positioning and navigation streams such as `GPS_RAW_INT`, which typically update at 5 Hz to 10 Hz.

The proposed message rates are as follows:
- **`GNSS_INTEGRITY`: 1 Hz.** Global status metrics change slowly and do not require high-frequency updates. Moreover, 1 Hz is the default output rate for most native receiver status messages, such as Septentrio's `ReceiverStatus`, `RFStatus`, and `GALAuthStatus`.
- **`GNSS_BANDS`: 1 Hz.** Since these diagnostics are generally extracted from the same receiver outputs as those used for the global integrity message, publishing both messages at the same rate allows the flight controller to build a consistent multi-band diagnostic snapshot once per second.

It should be noted that, for both Septentrio and u-blox, the band-specific diagnostic structures do not report a static list of all supported RF bands, but only a subset of them:
- **u-blox (via `jamStateCentFreq` sub-blocks)** provides information only for center frequencies associated with at least one active signal for which sufficient RF information is available to evaluate the jamming state.
- **Septentrio (via `RFBand` sub-blocks)** reports only frequency bands where jamming has been detected or mitigated and does not report bands that are clean.

As a result, the number of reported bands may vary over time depending on the receiver's current operating conditions and the surrounding RF environment. In both receiver formats, this value is already available through a count field in the parent message and maps directly to the `band_count` field of `GNSS_BANDS`.

## Intended message overhead

To evaluate the bandwidth overhead of `GNSS_INTEGRITY`, the fixed framing overhead introduced by each MAVLink v2 message must be considered. Each message adds a [12-byte overhead](https://mavlink.io/en/guide/serialization.html#mavlink2_packet_format), consisting of a 10-byte header and a 2-byte checksum, while the signature field is optional:
```
0   1   2   3   4   5   6   7   8   9   10                      n+10    n+12          n+24
+---+---+---+---+---+---+---+---+---+---+---------[...]---------+---+---+----[...]----+
|STX|LEN|INC|CMP|SEQ|SYS|COM|  MSG ID   | PAYLOAD (0-255 bytes) |  CHK  |  SIG (OPT)  |
+---+---+---+---+---+---+---+---+---+---+-----------------------+---+---+-------------+
```
The proposed `GNSS_INTEGRITY` payload size is 22 bytes, resulting in a total wire size of 34 bytes per message. Compared with the original `GNSS_INTEGRITY` message, this represents an increase of only 5 payload bytes, which is a reasonable trade-off for the additional diagnostic information provided.

However, in this new design, the `GNSS_BANDS` message must also be included in the bandwidth budget. Since `GNSS_BANDS` can report multiple frequency bands, two transmission approaches can be considered, although other solutions are welcome:
- **Option 1:** One message is transmitted for each reported band, with the band identified by the combination of `id` (receiver ID) and `frequency`.
- **Option 2:** A single message is transmitted per cycle, with a `band_count` field and one array per field indexed by band.

The main difference between these two approaches is the resulting bandwidth overhead. 

**Option 1: Sequential single-band messages**

```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint32_t" name="frequency" units="Hz" invalid="0">Center frequency of this RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint8_t" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
</message>
```
Bandwidth analysis (3 reported bands, 1 Hz):
- Payload size: **7 bytes** (`id` + `frequency` + `band_jamming_state` + `band_mitigation_state`)
- Protocol overhead per message: **12 bytes** (10-byte header + 2-byte checksum)
- Total bandwidth: 3 * (7 + 12) = **57 bytes/sec**

```
+---------------------------+---------------------+----+
|        HEADER (10B)       | BAND 1 PAYLOAD (7B) | 2B | 19 bytes
+---------------------------+---------------------+----+ 

+---------------------------+---------------------+----+
|        HEADER (10B)       | BAND 2 PAYLOAD (7B) | 2B | 19 bytes
+---------------------------+---------------------+----+

+---------------------------+---------------------+----+ 
|        HEADER (10B)       | BAND 3 PAYLOAD (7B) | 2B | 19 bytes  
+---------------------------+---------------------+----+
                                                  Total: 57 bytes/sec
```
**Option 2: Single multi-band array message**
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint8_t" name="band_count">Number of active RF bands reported in the arrays below.</field>
    <field type="uint32_t[GNSS_MAX_BANDS]" name="frequency" units="Hz" invalid="[0]">Center frequency of each RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
</message>
```
The second approach requires defining a `GNSS_MAX_BANDS` constant that specifies the maximum number of frequency bands that can be encoded in a single `GNSS_BANDS` message. One possibility would be to derive this value from the maximum number of dynamic sub-blocks supported by the drivers, since each sub-block corresponds to one center frequency.

However, since static arrays are used, their size determines the transmitted payload, even if fewer bands are reported. As an illustrative example, assume that three frequency bands are reported and `GNSS_MAX_BANDS` is set to three.

The resulting bandwidth overhead is as follows (3 reported bands, 1 Hz):
- Payload size: **20 bytes** (`id` + `band_count` + 3 * (`frequency` + `band_jamming_state` + `band_mitigation_state`))
- Total bandwidth: 20 + 12 = **32 bytes/sec**
```
+---------------------------+-------------------------------------------------------------------------------------+----+
|        HEADER (10B)       | BAND HEADER (2B) + FREQ[3] (3 * 4B)  + JAMMING[3] (3 * 1B) + MITIGATION[3] (3 * 1B) | 2B | 32 bytes
+---------------------------+-------------------------------------------------------------------------------------+----+ 
                                                                                                                  Total: 32 bytes/sec
```
Because each individual band payload is small, the protocol overhead associated with transmitting multiple MAVLink messages becomes significant in the first approach. In this three-band example, using a single array-based message reduces bandwidth usage by **25 bytes/sec** while transmitting all reported bands in a single message, making it both more efficient and easier for the flight controller to process.

For these reasons, this is the approach proposed in this RFC. Its limitations when larger values of `GNSS_MAX_BANDS` are used are discussed below.

To put the proposed bandwidth into perspective, the following table compares the updated `GNSS_INTEGRITY` and `GNSS_BANDS` messages with the standard high-frequency `GPS_RAW_INT` stream and the original `GNSS_INTEGRITY` message:
| Message | Payload size (bytes) | Total size (bytes) | Rate | Bandwidth (bytes/sec) |
| ------- | ------------------- | ------------------ | ---------------- | --------------------------- |
| `GPS_RAW_INT` (base only) | 30 | 42 | 5 Hz | 210 |
| `GPS_RAW_INT` (fully extended) | 52 | 64 | 5 Hz | 320 |
| `GNSS_INTEGRITY` (original) | 17 | 29 | 1 Hz | 29 |
| `GNSS_INTEGRITY` (proposed) | 22 | 34 | 1 Hz | 34 |
| `GNSS_BANDS` (multiple single-band messages) | 21 | 57 | 1 Hz | 57 |
| `GNSS_BANDS` (single multi-band message) | 20 | 32 | 1 Hz | 32 |
| Proposed integrity report (`GNSS_INTEGRITY` + single `GNSS_BANDS`) | 42 | 66 | 1 Hz | 66 |

Compared with standard high-frequency navigation data, the combined `GNSS_INTEGRITY` and `GNSS_BANDS` messages require less than one-third of the bandwidth of a basic 5 Hz `GPS_RAW_INT` stream, and only about one-fifth of that required by the fully extended version. 

Compared with the original `GNSS_INTEGRITY` message, the proposed split-message architecture transmitted at 1 Hz increases bandwidth usage by only **37 bytes/sec**. This additional overhead is modest compared with existing MAVLink traffic, representing less than one-fifth of the bandwidth required by a standard 5 Hz `GPS_RAW_INT` stream while providing more detailed GNSS resilience and per-band interference diagnostics than the original single-message design.

However, real receivers may expose more than three frequency bands, and the number of reported bands is dynamic. Depending on the receiver implementation and the surrounding RF environment, this number may be greater than three or even zero. In this context, the array-based approach has two limitations that must be taken into account:

1. If fewer than `GNSS_MAX_BANDS` bands are reported, or even none at all, the unused array entries still occupy space in the payload. For example, if `GNSS_MAX_BANDS` is set to 8 but only 3 bands are reported, the remaining five entries are transmitted using invalid values, resulting in a bandwidth of **62 bytes/sec** instead of **32 bytes/sec**. In this case, transmitting three individual single-band messages (**57 bytes/sec**) would actually be more efficient, as the unused array elements introduce **30 bytes/sec** of unnecessary bandwidth overhead.  
   When no frequency bands are reported, unused array elements could be initialized to zero so that [MAVLink 2 payload truncation](https://mavlink.io/en/guide/serialization.html#payload_truncation) can truncate empty bytes at the end of the serialized message payload (except for the first byte). This optimization applies only to trailing zero bytes and therefore cannot eliminate unused array entries that precede populated fields.
2. Defining a fixed `GNSS_MAX_BANDS` also limits the maximum number of center frequencies that can be reported in a single message.

Given these limitations and the dynamic nature of the per-band information reported by receivers, selecting an appropriate value for `GNSS_MAX_BANDS` is therefore a key design decision if the array-based approach is adopted.

## DroneCAN standardization

Whatever message structures are ultimately adopted in MAVLink should have a 1:1 or 1-to-many equivalent standardized in DroneCAN. To avoid feature gaps between serial-connected GNSS receivers and CAN-based peripherals, the same diagnostic information should be available over both transports. This standardization can follow once the MAVLink messages have been agreed upon and validated.

# Alternatives 

## Extended per-band GNSS integrity message

This section presents the fields that were considered but not included in the proposed minimal `GNSS_BANDS` message, along with three alternative designs:

- **Alternative 1:** The minimal message from the [Detailed design](#detailed-design) section, extended with interference characteristics (bandwidth and power). Although these fields are not available from u-blox, they are reported by Septentrio using standard units (kHz and dBm). Including them would allow operators to better characterize detected interference and provide more insight than binary jamming states alone.
- **Alternative 2:** Alternative 1, further extended with a per-band spoofing detection state. This field cannot currently be populated by any vendor but is included speculatively to future-proof the message. This possibility was discussed with Septentrio. Since spoofing mitigation is not reported even at the receiver level, introducing a dedicated per-band mitigation state would not be meaningful. As with per-band jamming detection, the same enumeration as the global spoofing state could be reused.
- **Alternative 3:** A fully extended version including all currently available jamming- and antenna-related per-band fields exposed by at least one vendor, including raw RF front-end diagnostics.

A global field mapping table summarizing the source availability for all alternatives is provided at the end of this section. For each alternative, the corresponding payload sizes and bandwidth impacts are provided, assuming a three-band report transmitted at 1 Hz. In these calculations, `GNSS_MAX_BANDS` is set to 3.

**Alternative 1: `GNSS_BANDS` with interference characteristics**
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint8_t" name="band_count">Number of active RF bands reported in the arrays below.</field>
    <field type="uint32_t[GNSS_MAX_BANDS]" name="frequency" units="Hz" invalid="[0]">Center frequency of each RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint16_t[GNSS_MAX_BANDS]" name="interference_bandwidth" units="kHz" invalid="[UINT16_MAX]">Bandwidth of detected interference in each band (kHz). 0 for pulsed interference.</field>
    <field type="int8_t[GNSS_MAX_BANDS]" name="interference_power" units="dBm" invalid="[INT8_MIN]">Estimated interference power in each band (dBm). 0 if not estimable or manual notch filter.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
</message>
```

**Alternative 2: `GNSS_BANDS` extended with per-band spoofing state**
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint8_t" name="band_count">Number of active RF bands reported in the arrays below.</field>
    <field type="uint32_t[GNSS_MAX_BANDS]" name="frequency" units="Hz" invalid="[0]">Center frequency of each RF band in Hz. 0 if not known (could be mapped to a frequency band).</field>
    <field type="uint16_t[GNSS_MAX_BANDS]" name="interference_bandwidth" units="kHz" invalid="[UINT16_MAX]">Bandwidth of detected interference in each band (kHz). 0 for pulsed interference.</field>
    <field type="int8_t[GNSS_MAX_BANDS]" name="interference_power" units="dBm" invalid="[INT8_MIN]">Estimated interference power in each band (dBm). 0 if not estimable or manual notch filter.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_spoofing_state" enum="GNSS_SPOOFING_STATE">Per-band spoofing state.</field>
</message>
```

**Alternative 3: `GNSS_BANDS` including all jamming- and antenna-related per-band fields**
```xml
<message id="442" name="GNSS_BANDS">
    <description>Per-band RF front-end diagnostics for a GNSS receiver. Sent once per RF front-end / frequency band. Global resilience states are in GNSS_INTEGRITY.</description>
    <field type="uint8_t" name="id" instance="true">GNSS receiver id. Must match instance ids of other messages from same receiver.</field>
    <field type="uint8_t" name="band_count">Number of active RF bands reported in the arrays below.</field>
    <field type="uint32_t[GNSS_MAX_BANDS]" name="frequency" units="Hz" invalid="[0]">Center frequency of each RF band in Hz. 0 if not known.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_id">RF band id.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_jamming_state" enum="GNSS_JAMMING_STATE">Per-band jamming state.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_mitigation_state" enum="GNSS_JAMMING_MITIGATION_STATE">Per-band jamming mitigation state.</field>
    <!-- Interference characteristics -->
    <field type="uint16_t[GNSS_MAX_BANDS]" name="interference_bandwidth" units="kHz" invalid="[UINT16_MAX]">Bandwidth of detected interference in each band (kHz). 0 for pulsed interference.</field>
    <field type="int8_t[GNSS_MAX_BANDS]" name="interference_power" units="dBm" invalid="[INT8_MIN]">Estimated interference power in each band (dBm). 0 if not estimable or manual notch filter.</field>
    <!-- Raw RF front-end diagnostics -->
    <field type="uint16_t[GNSS_MAX_BANDS]" name="noise_floor" invalid="[UINT16_MAX]">Raw noise floor as measured by the receiver front-end.</field>
    <field type="uint16_t[GNSS_MAX_BANDS]" name="agc_count" invalid="[UINT16_MAX]">Automatic Gain Control (AGC) level.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="cw_jamming_level" invalid="[UINT8_MAX]">Continuous Wave (CW) jamming level (0=no CW jamming, 255=strong CW jamming).</field>
    <!-- I/Q diagnostics — antenna / signal chain health -->
    <field type="int8_t[GNSS_MAX_BANDS]" name="ofs_i" invalid="[INT8_MAX]">Imbalance of I-channel.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="mag_i" invalid="[UINT8_MAX]">Magnitude of I-channel (0=no signal).</field>
    <field type="int8_t[GNSS_MAX_BANDS]" name="ofs_q" invalid="[INT8_MAX]">Imbalance of Q-channel.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="mag_q" invalid="[UINT8_MAX]">Magnitude of Q-channel (0=no signal).</field>
    <!-- Per-band antenna diagnostics -->
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_antenna_state" enum="GNSS_ANTENNA_STATE">Status of the antenna for each band.</field>
    <field type="uint8_t[GNSS_MAX_BANDS]" name="band_antenna_power" enum="GNSS_ANTENNA_POWER">Power state of the antenna for each band.</field>
</message>
```

**Global field mapping table for all alternatives:**
| Field | In previous `GNSS_INTEGRITY` | Included in Alternative(s) | Septentrio source | u-blox source |
|-------|--------------------------|-------------|------------------|---------------|
| `band_count` | No | 1, 2, 3 | `RFStatus.N` | `UBX-SEC-SIG.jamNumCentFreqs` |
| `frequency` | No | 1, 2, 3 | `RFStatus.RFBand.Frequency` (Hz) | `UBX-SEC-SIG.jamStateCentFreq.centFreq` (kHz) |
| `band_id` | No | 3 | **Not available** | `UBX-MON-RF.blockId` |
| `band_jamming_state` | Yes (but not per-band) | 1, 2, 3 | `RFStatus.RFBand.Info.Mode` | `UBX-SEC-SIG.jamStateCentFreq.jammed` |
| `band_mitigation_state` | No | 1, 2, 3 | `RFStatus.RFBand.Info.Mode` bits 0-3 | **Not available** (`UBX-MON-RF.jammingState` deprecated in protocol versions that support `UBX-SEC-SIG`) |
| `interference_bandwidth` | No | 1, 2, 3 | `RFStatus.RFBand.Bandwidth` (kHz) | **Not available** |
| `interference_power` | No | 1, 2, 3 | `RFStatus.RFBand.Power` (dBm) | **Not available** |
| `noise_floor` | No | 3 | **Not available** | `UBX-MON-RF.noisePerMS` |
| `agc_count` | No | 3 | **Not available** (Gain available in `ReceiverStatus.AGCState.Gain`, expressed in dB) | `UBX-MON-RF.agcCnt` (%) |
| `cw_jamming_level` | No | 3 | **Not available** | `UBX-MON-RF.cwSuppression` (0=no CW jamming, 255=strong CW jamming) |
| `ofs_i`, `ofs_q` | No | 3 | **Not available** | `UBX-MON-RF` (-128 = max. negative imbalance, 127 = max. positive imbalance) |
| `mag_i`, `mag_q` | No | 3 | **Not available** | `UBX-MON-RF` (0 = no signal, 255 = max.magnitude) |
| `band_antenna_state` | No | 3 | Global antenna diagnostics only | `UBX-MON-RF.antStatus` |
| `band_antenna_power` | No | 3 | Global antenna diagnostics only | `UBX-MON-RF.antPower` |
| `band_spoofing_state` | No | 2 | **Not available** | **Not available** |

**Bandwidth impact of the proposed and alternative `GNSS_BANDS` designs (3 reported bands, 1 Hz transmission):**
| Message design | Payload size (bytes) | Total size (bytes) | Rate | Bandwidth (bytes/sec) | Increase compared with minimal message |
| --------------- | ------------------------------ | ------------------ | --------- | --------------------- | -------------------------------------- |
| Minimal `GNSS_BANDS` | 20 | 32 | 1 Hz | 32 | - |
| Alternative 1: interference characteristics | 29 | 41 | 1 Hz | 41 | +9 bytes/sec |
| Alternative 2: per-band spoofing state | 32 | 44 | 1 Hz | 44 | +12 bytes/sec |
| Alternative 3: raw RF and antenna diagnostics | 65 | 77 | 1 Hz | 77 | +45 bytes/sec |

## Approach validation based on NovAtel receiver outputs

NovAtel OEM7 outputs were examined as a secondary reference to assess whether the proposed fields generalise beyond Septentrio and u-blox. The key findings are as follows:
- **System errors, receiver status, and antenna status/power monitoring** map directly from the `RXSTATUS` log, which exposes structured status and error words, including bits 3-6 for antenna-related conditions (power, LNA, open circuit, short circuit).
- **RAIM state and protection levels** map directly from the `RAIMSTATUS` log, which exposes an integrity status field (`NOT_AVAILABLE` / `PASS` / `FAIL`) and explicit Horizontal and Vertical Protection Level (HPL/VPL) values in meters. 
- **Corrections age** maps directly from `BESTPOS.diff_age`, expressed in seconds.
- `cpu_load`, `up_time`, and `authentication_state` have no NovAtel equivalent.
- **Jamming and spoofing status indicators** are available, but with less granularity than that of the proposed enumeration. `RXSTATUS` provides a single global bit for jamming detection (bit 15) and a single bit for spoofing detection (bit 9), with no attenuation status or distinction between detection levels.
- **Per-band interference data** are available via the `ITDETECTSTATUS` log. It reports detected interferences per RF path (L1, L2, L5) and exposes the center frequency in MHz, the bandwidth in MHz, and the estimated interference power in dBm. These map directly to `frequency` (converted to Hz), `interference_bandwidth` (converted to kHz), and `interference_power`. It also provides the highest estimated power spectrum density of the interference in dBmHz, which is not available in Septentrio receivers. 
The `RXSTATUS` Auxiliary 1 status word additionally provides per-RF-path jammer detection bits (RF1 to RF6), which map to `band_jamming_state`, although using RF path identifiers rather than center frequencies.

Given the consistency of interference-related characteristics across Septentrio and NovAtel, it appears justified to consider including them in `GNSS_BANDS`, even if u-blox does not provide equivalent fields.

## Septentrio quality indicators

To prevent Septentrio users from losing information previously transmitted by `GNSS_INTEGRITY`, a dedicated message could also be defined to carry Septentrio-specific quality indicators, preserving the four fields that were removed from the new `GNSS_INTEGRITY`. While they cannot be populated by other vendors, they provide a simple and immediately readable health summary that is useful for ground station displays and operator situational awareness. This message could be optional, for example.

**Proposed `GNSS_SEPT_QUALITY` message:**
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

**Field source mapping:**
| Field | In previous `GNSS_INTEGRITY` | Septentrio source | u-blox source |
|-------|--------------------------|------------------|---------------|
| `corrections_quality` | Yes | `QualityInd` type 30 (0-10) | No equivalent |
| `system_status_summary` | Yes | `QualityInd` type 0 (0-10) | No equivalent |
| `gnss_signal_quality` | Yes | `QualityInd` type 1 (0-10) | No equivalent |
| `post_processing_quality` | Yes | `QualityInd` type 31 (0-10) | No equivalent |

# Unresolved Questions

Any comments, recommendations, and ideas are welcome.

The following questions remain open:

- Are all the fields added to `GNSS_INTEGRITY` relevant? In particular, is `up_time` worth the 4 bytes it occupies, or would other metrics provide more value?
- Should `antenna_state` and `antenna_power` remain two separate fields, or be merged into a single field by adding an `OFF` entry to `GNSS_ANTENNA_STATE`? Are all states currently defined in `GNSS_ANTENNA_STATE` relevant, given the different mappings available across vendors?
- Is it useful to distinguish between spoofing detection alone and the indication that receiver output (position or raw measurements) may be affected by spoofing in `GNSS_SPOOFING_STATE`, even if the currently available receiver fields are not perfectly aligned with this distinction? This topic has been discussed in parallel with Septentrio, which shares the objective of improving the link between spoofing detection and its impact on receiver output, and is continuing development in this direction.
- Should the `GNSS_AUTHENTICATION_STATE_OK` entry be renamed to `OPERATIONAL`, `ENABLED`, `ACTIVE`, or `AUTHENTICATING`?
- Is representing all reported bands in a single `GNSS_BANDS` message, with each per-band field defined as an array, the best approach, given that the number of available bands is dynamic (and may be zero)? If so, what should be the maximum array size (`GNSS_MAX_BANDS`) to limit the transfer of unused fields while ensuring that all relevant bands can be reported?
- Do operators need raw per-band RF front-end diagnostics in MAVLink, at the cost of reduced bandwidth efficiency and vendor agnosticism, or are the processed jamming and mitigation states sufficient? Are interference bandwidth and interference power worth including, given that they are currently not available from u-blox but are expressed in standard units (kHz and dBm, respectively)?
- Should a field for per-band spoofing detection be added speculatively to `GNSS_BANDS`, even though no vendor currently provides this information and this would extend the scope of the message beyond interference reporting?
- Is a dedicated (and potentially optional) `GNSS_SEPT_QUALITY` message the right approach for reporting Septentrio-specific quality indicators?

# References 

- PRs/Issues/Discussions:
    - [Initial GNSS_INTEGRITY MAVLink PR #2110](https://github.com/mavlink/mavlink/pull/2110)
    - [MAVLink PR #2461](https://github.com/mavlink/mavlink/pull/2461)
    - [DroneCAN PR #77](https://github.com/dronecan/DSDL/pull/77)
    - [PX4 PR #26438](https://github.com/PX4/PX4-Autopilot/pull/26438)
    - [PX4-GPSDrivers PR #200](https://github.com/PX4/PX4-GPSDrivers/pull/200) 

<br>

- Technical references:
    - [Mosaic-G5 Firmware v1.1.0 Reference Guide](https://www.septentrio.com/en/products/gnss-receivers/gnss-receiver-modules/mosaic-G5-P3H)
    - [Mosaic-X5 Firmware v4.15.1 Reference Guide](https://www.septentrio.com/en/products/gnss-receivers/gnss-receiver-modules/mosaic-x5)
    - [u-blox X20 HPG 2.00 Interface Description](https://content.u-blox.com/sites/default/files/documents/u-blox-20-HPG-2.00_InterfaceDescription_UBXDOC-304424225-19888.pdf)
    - [u-blox F9 HPG 1.51 Interface Description](https://content.u-blox.com/sites/default/files/documents/u-blox-F9-HPG-1.51_InterfaceDescription_UBXDOC-963802114-13124.pdf)
    - [Novatel OEM7 Commands and Logs Manual](https://docs.novatel.com/OEM7/Content/PDFs/OEM7_Commands_Logs_Manual.pdf)
    - [MAVLink Packet Serialization Guide](https://mavlink.io/en/guide/serialization.html)
