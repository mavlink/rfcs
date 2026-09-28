  * Start date: 2026-07-21
  * Contributors: Andrew Tridgell <andrew@tridgell.net>
  * Related issues: incorporates explicit bytewise types and requester negotiation from [RFC PR #18](https://github.com/mavlink/rfcs/pull/18)

# Summary

Extend the existing parameter protocol with explicit bytewise types and
GCS opt-in. Signed and unsigned 32-bit integers occupy the existing four-byte
`param_value` field. Signed and unsigned 64-bit integers, REAL64, and 128-byte custom values use a
typed MAVLink2 extension. A negotiated IN_PROGRESS status supports asynchronous
writes. Together these allow components to replace PARAM_EXT with the existing
parameter microservice. This replaces the earlier extended-int32 encoding.

# Motivation

C-cast parameter transport rounds large int32 values. Legacy bytewise
transport avoids that rounding, but its type values overlap C-cast types and
float handling can corrupt integer bit patterns that represent signalling
NaNs. Explicit types make decoding unambiguous; raw-byte transport preserves
every bit.

Parameter-over-MAVFTP already preserves int32 downloads, but it does not cover
writes, acknowledgements, individual reads, or change notifications. Extending
the existing messages covers these operations without a second protocol.

# Wire format

Add these entries to `MAV_PARAM_TYPE`:

| Value | Name | Value location |
| --- | --- | --- |
| 11 | `MAV_PARAM_TYPE_EXTENDED` | `extended_data`, interpreted using `extended_type` |
| 12 | `MAV_PARAM_TYPE_BYTEWISE_INT32` | Four little-endian bytes in `param_value` |
| 13 | `MAV_PARAM_TYPE_BYTEWISE_UINT32` | Four little-endian bytes in `param_value` |
| 14 | `MAV_PARAM_TYPE_IN_PROGRESS` | Write status in PARAM_VALUE only; no stored value |

`PARAM_VALUE` and `PARAM_SET` gain these extension fields, in this order:

```xml
<extensions/>
<field type="uint8_t" name="extended_type" enum="MAV_PARAM_EXTENDED_TYPE">Datatype of extended_data.</field>
<field type="uint8_t[128]" name="extended_data">Extended parameter value.</field>
```

The first byte of the extension area is therefore the type discriminator.
`MAV_PARAM_EXTENDED_TYPE` defines:

| Value | Name | Encoding |
| --- | --- | --- |
| 0 | `MAV_PARAM_EXTENDED_TYPE_NONE` | No extended value |
| 1 | `MAV_PARAM_EXTENDED_TYPE_BYTEWISE_INT64` | Little-endian signed integer in the first eight data bytes |
| 2 | `MAV_PARAM_EXTENDED_TYPE_BYTEWISE_UINT64` | Little-endian unsigned integer in the first eight data bytes |
| 3 | `MAV_PARAM_EXTENDED_TYPE_BYTEWISE_REAL64` | IEEE-754 binary64, little-endian in the first eight data bytes |
| 4 | `MAV_PARAM_EXTENDED_TYPE_CUSTOM` | Opaque 128-byte value |

Signed integers use two's complement. For either 32-bit type, `extended_type`
and all `extended_data` bytes must be zero. For an extended type, `param_type`
is EXTENDED and `param_value` is NaN. For INT64, UINT64 and REAL64 the
remaining 120 data bytes are zero. Unknown extended types must not be
interpreted as a float value.

CUSTOM has the same capacity as PARAM_EXT_TYPE_CUSTOM. All 128 bytes,
including trailing zeros, belong to the value. MAVLink2 trimming removes zero
bytes only on the wire: receivers restore the full array before interpreting
it. Shorter application values are zero-padded; variable-length schemas must
encode their own length. Metadata or a component-specific schema defines
interpretation. There is no implicit text encoding or NUL termination. No
extended int32 subtype is defined.

# Negotiation

Append a `uint32_t supported_types` MAVLink2 extension to both
`PARAM_REQUEST_READ` and `PARAM_REQUEST_LIST`. It is a bitmask of
`MAV_PARAM_TYPES_SUPPORTED`, independent of the numeric values of the type enums:

| Bit value | Encoding understood |
| --- | --- |
| 1 | BYTEWISE_INT32 |
| 2 | BYTEWISE_UINT32 |
| 4 | EXTENDED / BYTEWISE_INT64 |
| 8 | EXTENDED / BYTEWISE_UINT64 |
| 16 | EXTENDED / BYTEWISE_REAL64 |
| 32 | EXTENDED / CUSTOM |
| 64 | IN_PROGRESS write status |

A zero or missing extension requests the existing encoding. Unknown bits are
ignored. The component may only emit a new type understood by the receiving
clients. Support applies to read replies, list streams, set acknowledgements
and unsolicited updates, not just the response to that particular request.

A component advertises `MAV_PROTOCOL_CAPABILITY_PARAM_BYTEWISE` (2097152) when
it implements explicit bytewise encodings and requester negotiation. This does
not imply storage support for all storage types. A GCS checks this capability
before sending a new PARAM_SET type and advertises its receive mask first,
including when its parameter dictionary was obtained over FTP.

PARAM_VALUE is broadcast and carries no destination. Implementations must
account for clients sharing a channel. The ArduPilot reference implementation
records each channel's first requester, allows that sole requester to replace
its mask, and intersects masks once another requester appears. After multiple
requesters have been observed it never enlarges the common mask until the
channel is reinitialized. A legacy request therefore prevents new encodings
from being sent on that shared channel. Replies queued before a downgrade are
also downgraded before transmission. This is conservative if clients leave; it
cannot detect passive listeners or multiple clients sharing one identity.
Separate links should be used when clients require different encodings.

New types are only selected after MAVLink2 negotiation. MAVLink1 requests
imply zero support. A component must not silently cast extended-only values
into the legacy float field. If a requested parameter cannot be represented
using the negotiated mask, return PARAM_ERROR_TYPE_UNSUPPORTED with its name
and index. For a list, preserve a stable catalog, count and indices: send
PARAM_VALUE for representable entries and PARAM_ERROR_TYPE_UNSUPPORTED for the
others. An updated client records those indices as unavailable, rather than
retrying forever or treating an error as a value. If every entry is
unavailable, PARAM_ERROR alone provides no count; the client must report an
incomplete download after a bounded timeout. A legacy client cannot obtain a
complete catalog containing such entries; use a separate component/link or
retain PARAM_EXT while migrating. Do not renumber parameters depending on
requester capability. ArduPilot has no extended-only parameter storage in this
implementation.

# Asynchronous writes

A requester advertises IN_PROGRESS before writing. For a write that takes longer
than the normal response timeout, the component sends PARAM_VALUE with
`param_type = MAV_PARAM_TYPE_IN_PROGRESS`, the pending parameter's name,
`param_value = NaN`, and zero extension fields. Count and index are ignored.
This is a status, not a parameter type or value: it is invalid in PARAM_SET and
must never replace cached values/types or advance parameter-download accounting.

Match a notification by source system, source component and parameter name.
Only a matching pending write has its response timeout restarted; unrelated
notifications have no effect. Send progress before the client's normal timeout
expires and repeat it while the operation is running. Clients may impose an
application-level total deadline. If progress stops, normal bounded retries
and timeout apply. Retransmitting an identical write must not restart an
operation already in progress. Components must serialize writes to each
parameter and reject conflicting writes with PARAM_ERROR_PERMISSION_DENIED
while busy.

Completion is an ordinary PARAM_VALUE with the actual type and stored value.
Validation failures use existing PARAM_ERROR codes; add
`MAV_PARAM_ERROR_WRITE_FAIL = 9` for a supported write that fails during
execution. An error terminates the pending operation and does not change the
client's cached value. Clients check PARAM_ERROR destination as well as source
and parameter name, and may read again after failure to obtain the current value.
The resulting value must be acknowledged in an encoding the requester accepts;
otherwise reject the write before modifying storage.

Unlike PARAM_EXT_ACK, PARAM_VALUE has no transaction ID or explicit ACCEPTED
result. Clients serialize writes per component/name and compare the returned
value with the requested value; unrelated reads or concurrent writers can
still make correlation ambiguous. Exact-value acknowledgements are the
contract here: a component must reject an unacceptable value rather than
silently clamp it. For REAL64 and CUSTOM, compare encoded bytes, preserving
signed zero, NaN payloads and custom padding. PARAM_ERROR also has no
operation identifier, so avoid concurrent read/write operations on the same
parameter during a pending write.

If IN_PROGRESS is not negotiated, a server must not emit that marker. It can
complete within the normal timeout, safely coalesce retries until completion,
or reject an asynchronous operation with PARAM_ERROR_PERMISSION_DENIED before
starting it. This permits migration without exposing a new status to legacy
clients.

# Replacing PARAM_EXT

PARAM_EXT uses binary values in its 128-byte container, not decimal strings.
The replacement mapping is:

| PARAM_EXT type or result | Replacement |
| --- | --- |
| UINT8, INT8, UINT16, INT16, REAL32 | Existing PARAM types and component's existing encoding |
| INT32, UINT32 | Explicit BYTEWISE_INT32 / BYTEWISE_UINT32 |
| INT64, UINT64 | EXTENDED with BYTEWISE_INT64 / BYTEWISE_UINT64 |
| REAL64 | EXTENDED with BYTEWISE_REAL64 |
| CUSTOM | EXTENDED with CUSTOM, all 128 bytes preserved |
| ACK ACCEPTED | PARAM_VALUE with actual type and exact stored value |
| ACK IN_PROGRESS | Negotiated PARAM_VALUE / IN_PROGRESS |
| ACK VALUE_UNSUPPORTED | PARAM_ERROR_VALUE_OUT_OF_RANGE or TYPE_MISMATCH as appropriate |
| ACK FAILED | PARAM_ERROR_WRITE_FAIL, or a more specific existing error |

This covers the value capacity and asynchronous-write operations of PARAM_EXT,
with the correlation limitations above. Migration is per component: existing
PARAM_EXT clients still need that protocol until they adopt the new
negotiation and status handling. No PARAM_EXT messages or enum values are
removed.

# Implementation requirements

The 32-bit float field is a byte container for the explicit bytewise types.
Never obtain those bytes by converting an integer to a floating-point number,
or round-trip them through a float variable: signalling-NaN patterns may
change. Preserve raw payload bytes when decoding and forwarding messages, and
place raw bytes into outgoing packets before checksum and signature
calculation. Payload offsets are independent of header extensions such as
32-bit system IDs.

ArduPilot sends BYTEWISE_INT32 for all int32 parameters on opted-in MAVLink2
channels, including small values. Other parameter types retain legacy
encoding. It accepts BYTEWISE_INT32 into int32 storage and BYTEWISE_UINT32
when the value fits signed int32. Type mismatch and overflow return
PARAM_ERROR; unsupported extended types and IN_PROGRESS writes return
TYPE_UNSUPPORTED. Rejected writes do not change storage. `MAV_OPTIONS` bit 1
disables the capability and bytewise output; receive support remains
available.

pymavlink provides raw field access before packing, exact decoding, request
mask helpers, and exact integer parsing and file storage up to UINT64_MAX. Its
Python generator preserves raw PARAM_VALUE/PARAM_SET bytes when forwarding
explicit 32-bit types. Low-level generated send functions that take a float
must not be used directly to send bytewise32 values: use the raw-byte wrapper
instead. pymavlink and MAVProxy extend pending-write timeouts for matching
IN_PROGRESS notifications and terminate on PARAM_ERROR. Neither caches a
progress marker. MAVProxy negotiates before bytewise sets and retains exact
values from messages and FTP logs. Floating-point parameter files use
round-trip decimal precision; CUSTOM values use an explicit `hex:` prefix
followed by hexadecimal bytes, alongside legacy numeric file entries. PX4 is
outside this project's scope.

# Bandwidth and compatibility

Message IDs, base layouts and CRC extras are unchanged. MAVLink2 removes zero
extension tails, so explicit 32-bit values have the same payload length as
legacy values: 25 bytes for PARAM_VALUE and 23 for PARAM_SET. A 64-bit value
adds at most nine bytes (one type and eight data bytes), with zero tails
removed. CUSTOM uses up to 129 extension bytes, making maximum PARAM_VALUE and
PARAM_SET payloads 154 and 152 bytes respectively, within MAVLink2's 255-byte
limit. Request masks add up to four bytes; zero masks add nothing. IN_PROGRESS
has zero extensions and the ordinary 25-byte PARAM_VALUE base payload.

Legacy clients receive legacy encoding unless they share an already opted-in
channel without identifying themselves. Legacy servers ignore the new request
extensions. Updated clients must continue supporting legacy C-cast and
bytewise protocols for existing vehicles. Numeric assignments in this proposal
are provisional until upstream allocation.

# Alternatives

* Putting int32 in the extension avoids float API issues but costs up to five
  extra bytes per value. This proposal instead requires raw-byte access and
  uses negotiation to keep legacy clients on their existing path.
* PARAM_EXT_* provides a 128-byte binary container and explicit write results,
  but requires a separate message family and does not preserve the compact
  four-byte path for common values.
* FTP alone does not provide exact individual writes or acknowledgements.
* A double extension holds int32 exactly but cannot hold every int64/uint64.

# References

* [Parameter protocol](https://mavlink.io/en/services/parameter.html)
* [Earlier explicit encoding proposal](https://github.com/mavlink/rfcs/pull/18)
* [ArduPilot project](https://github.com/orgs/ArduPilot/projects/34)
