  * Start date: 2026-07-21
  * Contributors: Andrew Tridgell <andrew@tridgell.net>
  * Related issues: incorporates explicit bytewise types and requester negotiation from [RFC PR #18](https://github.com/mavlink/rfcs/pull/18)

# Summary

Extend the existing parameter protocol with explicit bytewise integer types and
GCS opt-in. Signed and unsigned 32-bit integers occupy the existing four-byte
`param_value` field. Signed and unsigned 64-bit integers use a typed MAVLink2
extension. This replaces the earlier proposal to put int32 in the extension.

# Motivation

C-cast parameter transport rounds large int32 values. Legacy bytewise transport
avoids that rounding, but its type values overlap C-cast types and float handling
can corrupt integer bit patterns that represent signalling NaNs. Explicit types
make decoding unambiguous; raw-byte transport preserves every bit.

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

`PARAM_VALUE` and `PARAM_SET` gain these extension fields, in this order:

```xml
<extensions/>
<field type="uint8_t" name="extended_type" enum="MAV_PARAM_EXTENDED_TYPE">Datatype of extended_data.</field>
<field type="uint8_t[32]" name="extended_data">Extended parameter value.</field>
```

The first byte of the extension area is therefore the type discriminator.
`MAV_PARAM_EXTENDED_TYPE` defines:

| Value | Name | Encoding |
| --- | --- | --- |
| 0 | `MAV_PARAM_EXTENDED_TYPE_NONE` | No extended value |
| 1 | `MAV_PARAM_EXTENDED_TYPE_BYTEWISE_INT64` | Little-endian signed integer in the first eight data bytes |
| 2 | `MAV_PARAM_EXTENDED_TYPE_BYTEWISE_UINT64` | Little-endian unsigned integer in the first eight data bytes |

Signed integers use two's complement. For either 32-bit type, `extended_type` and
all `extended_data` bytes must be zero. For a 64-bit type, `param_type` is
EXTENDED, `param_value` is NaN and the remaining 24 data bytes are zero.
Unknown extended types must not be interpreted as a float value.

The 32-byte container reserves space for future types without further message
changes. No extended int32 subtype is defined.

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

A zero or missing extension requests the existing encoding. Unknown bits are
ignored. The component may only emit a new type understood by the receiving
clients. Support applies to read replies, list streams, set acknowledgements and
unsolicited updates, not just the response to that particular request.

A component advertises `MAV_PROTOCOL_CAPABILITY_PARAM_BYTEWISE` (2097152) when
it implements explicit bytewise encodings and requester negotiation. This does
not imply storage support for all integer widths. A GCS checks this capability
before sending a new PARAM_SET type and advertises its receive mask first,
including when its parameter dictionary was obtained over FTP.

PARAM_VALUE is broadcast and carries no destination. Implementations must
account for clients sharing a channel. The ArduPilot reference implementation
records each channel's first requester, allows that sole requester to replace
its mask, and intersects masks once another requester appears. After multiple
requesters have been observed it never enlarges the common mask until the
channel is reinitialized. A legacy request therefore prevents new encodings
from being sent on that shared channel. Replies queued before a downgrade are
also downgraded before transmission. This is conservative if clients leave;
it cannot detect passive listeners or multiple clients sharing one identity.
Separate links should be used when clients require different encodings.

New types are only selected after MAVLink2 negotiation. MAVLink1 requests imply
zero support. A component with 64-bit storage must reject a request it cannot
represent rather than silently cast that value to float; the exact error policy
for such a component remains to be specified. ArduPilot has no 64-bit parameter
storage in this implementation.

# Implementation requirements

The 32-bit float field is a byte container for the explicit bytewise types.
Never obtain those bytes by converting an integer to a floating-point number,
or round-trip them through a float variable: signalling-NaN patterns may change.
Preserve raw payload bytes when decoding and forwarding messages, and place
raw bytes into outgoing packets before checksum and signature calculation.
Payload offsets are independent of header extensions such as 32-bit system IDs.

ArduPilot sends BYTEWISE_INT32 for all int32 parameters on opted-in MAVLink2
channels, including small values. Other parameter types retain legacy encoding.
It accepts BYTEWISE_INT32 into int32 storage and BYTEWISE_UINT32 when the value
fits signed int32. Type mismatch and overflow return PARAM_ERROR; unsupported
64-bit and unknown extended types return TYPE_UNSUPPORTED. Rejected writes do
not change storage. `MAV_OPTIONS` bit 1 disables the capability and bytewise
output; receive support remains available.

pymavlink provides raw field access before packing, exact decoding, request mask
helpers, and exact integer parsing and file storage up to UINT64_MAX. Its Python
generator preserves raw PARAM_VALUE/PARAM_SET bytes when forwarding explicit
32-bit types. Low-level generated send functions that take a float must not be
used directly to send bytewise32 values: use the raw-byte wrapper instead.
MAVProxy negotiates before bytewise sets and retains exact values from messages
and FTP logs. PX4 is outside the implementation scope of this project.

# Bandwidth and compatibility

Message IDs, base layouts and CRC extras are unchanged. MAVLink2 removes zero
extension tails, so explicit 32-bit values have the same payload length as
legacy values: 25 bytes for PARAM_VALUE and 23 for PARAM_SET. A 64-bit value
adds at most nine bytes (one type and eight data bytes), with zero tails removed.
Request masks add up to four bytes; zero masks add nothing.

Legacy clients receive legacy encoding unless they share an already opted-in
channel without identifying themselves. Legacy servers ignore the new request
extensions. Updated clients must continue supporting legacy C-cast and bytewise
protocols for existing vehicles. Numeric assignments in this proposal are
provisional until upstream allocation.

# Alternatives

* Putting int32 in the extension avoids float API issues but costs up to five
  extra bytes per value. This proposal instead requires raw-byte access and
  uses negotiation to keep legacy clients on their existing path.
* PARAM_EXT_* provides string transport but requires a separate protocol.
* FTP alone does not provide exact individual writes or acknowledgements.
* A double extension holds int32 exactly but cannot hold every int64/uint64.

# References

* [Parameter protocol](https://mavlink.io/en/services/parameter.html)
* [Earlier explicit encoding proposal](https://github.com/mavlink/rfcs/pull/18)
* [ArduPilot project](https://github.com/orgs/ArduPilot/projects/34)
