  * Start date: 2026-07-21
  * Contributors: Andrew Tridgell <andrew@tridgell.net>
  * Related issues: replaces [RFC 0017 / PR #18](https://github.com/mavlink/rfcs/pull/18)

# Summary

Add an extended parameter value encoding to the existing parameter
protocol messages. PARAM_VALUE and PARAM_SET gain two MAVLink2
extension fields: a one byte `extended_type` and a 32 byte
`extended_data` array. A new `MAV_PARAM_TYPE_EXTENDED` value of the
existing `param_type` field indicates that the parameter value is
carried in the extension fields rather than the `param_value` float
field, which is set to NaN.

This gives the parameter protocol a general, typed container for
values the float field cannot represent. The first defined extended
encoding, `MAV_PARAM_EXTENDED_TYPE_INT32`, provides lossless
transport of 32-bit integer parameter values; future encodings such
as 64-bit integers and short strings only need a new
`MAV_PARAM_EXTENDED_TYPE` value, with no further message changes.

A new capability bit `MAV_PROTOCOL_CAPABILITY_PARAM_EXTENDED` lets a
GCS discover support before using the encoding in PARAM_SET.

# Motivation

The parameter protocol carries all values in a 32-bit float field. On
flight stacks that use the C-cast encoding
(`MAV_PROTOCOL_CAPABILITY_PARAM_ENCODE_C_CAST`, e.g. ArduPilot), a
32-bit integer parameter whose magnitude exceeds 2^24 cannot be
represented exactly: the cast to float silently rounds the value. Bit
mask parameters with high bits set, large baud rates and device IDs
are all affected. Flight stacks that use the byte-wise encoding
(`MAV_PROTOCOL_CAPABILITY_PARAM_ENCODE_BYTEWISE`, e.g. PX4) do not
lose precision for int32, but that encoding cannot be adopted by
C-cast systems without breaking every deployed GCS, and it makes the
float field unreadable without out-of-band type knowledge (a problem
for log analysis, and the subject of the earlier RFC 0017 proposal).

Byte-wise transport of an int32 inside the float field itself (the
approach previously proposed for this problem as
`MAV_PARAM_TYPE_UNION_INT32`) turns out to be fragile: integer values
in the ranges 0x7F800001..0x7FFFFFFF and 0xFF800001..0xFFFFFFFF have
float NaN bit patterns, and many language runtimes and float ABIs
quieten signalling NaNs in transit, corrupting the value. Avoiding
that required raw payload patching in every implementation.

Note that the parameter-over-MAVFTP protocol (bulk download of
`@PARAM/param.pck`) already carries int32 parameter values without
error, and ground stations using it already receive exact values for
the full parameter list. That covers only the download direction:
PARAM_SET, the PARAM_VALUE acknowledgement it triggers, individual
PARAM_REQUEST_READ replies and spontaneous parameter change
broadcasts all still go through the float field, so a GCS cannot
losslessly write a large int32 back, and any non-FTP consumer (or
partial log) is still exposed to rounded values. This RFC closes
those paths.

Carrying the value in a plain byte array avoids all float semantics,
is trivially safe in every language, and the MAVLink2 zero truncation
rule means the extension fields cost no bandwidth when unused.

A major motivation for the typed byte-array container, rather than a
mechanism specific to int32, is to open the parameter protocol to
types it has never been able to carry at all. The 32 byte
`extended_data` array with a one byte `extended_type` discriminator
allows future encodings such as 64-bit integers (epoch timestamps,
64-bit device IDs, large bitmasks) and short strings (SSIDs,
passphrases, names) to be added by defining a new
`MAV_PARAM_EXTENDED_TYPE` value, without new messages, without
changing existing field semantics, and with the same
capability-gated compatibility story as int32.

# Detailed Design

## Message changes

Both PARAM_VALUE and PARAM_SET gain the same two extension fields:

```xml
<extensions/>
<field type="uint8_t" name="extended_type" enum="MAV_PARAM_EXTENDED_TYPE">Datatype of extended_data. Set (non-zero) only when param_type is MAV_PARAM_TYPE_EXTENDED, in which case param_value should be set to NaN.</field>
<field type="uint8_t[32]" name="extended_data">Extended parameter value, encoded according to extended_type.</field>
```

## Enum changes

A new entry in `MAV_PARAM_TYPE`:

```xml
<entry value="11" name="MAV_PARAM_TYPE_EXTENDED">
  <description>Value carried in the extended_type and extended_data fields of PARAM_VALUE and PARAM_SET. Only for use with components that advertise MAV_PROTOCOL_CAPABILITY_PARAM_EXTENDED.</description>
</entry>
```

A new enum describing the payload of `extended_data`:

```xml
<enum name="MAV_PARAM_EXTENDED_TYPE">
  <entry value="0" name="MAV_PARAM_EXTENDED_TYPE_NONE">
    <description>No extended data. Used when param_type is not MAV_PARAM_TYPE_EXTENDED.</description>
  </entry>
  <entry value="1" name="MAV_PARAM_EXTENDED_TYPE_INT32">
    <description>32-bit signed integer, little-endian in the first 4 bytes of extended_data. Used for values that are not exactly representable as a 32-bit float.</description>
  </entry>
</enum>
```

A new capability bit in `MAV_PROTOCOL_CAPABILITY`:

```xml
<entry value="2097152" name="MAV_PROTOCOL_CAPABILITY_PARAM_EXTENDED">
  <description>Component accepts PARAM_SET and emits PARAM_VALUE with MAV_PARAM_TYPE_EXTENDED and the extended_type/extended_data extension fields, for lossless transport of parameter values that are not exactly representable in the param_value float field, such as large 32-bit integers. Ground stations must not send MAV_PARAM_TYPE_EXTENDED to a component that does not advertise this capability.</description>
</entry>
```

## Sender rules

  * A component may choose to only use `MAV_PARAM_TYPE_EXTENDED` when
    the parameter value is not exactly representable in the
    `param_value` float field. With that strategy values that fit keep
    the existing wire format, so the vast majority of parameter
    traffic is unchanged, and GCS that do not understand the encoding
    are only exposed to it for values they could not have received
    correctly anyway. ArduPilot will do this initially; once client
    support has been widespread for a sufficient time a component may
    use the extended encoding for all parameter values, which becomes
    the natural choice once types like int64 that have no non-extended
    representation are supported.
  * When the extended encoding is used, `param_value` is set to NaN.
    A consumer that does not understand the extension then sees an
    unmistakably invalid value rather than a plausible-looking float
    that it might silently accept, display, or worse, write back. An
    alternative considered was setting `param_value` to the closest
    float representation of the value for graceful degradation; the
    final choice depends on how deployed ground stations that predate
    this RFC behave when receiving each variant.
  * The extension fields can only be carried in MAVLink2 frames. A
    sender must not use `MAV_PARAM_TYPE_EXTENDED` on a MAVLink1
    channel; it falls back to the existing (lossy) encoding there.
  * A GCS must not send `MAV_PARAM_TYPE_EXTENDED` in PARAM_SET unless
    the target advertises `MAV_PROTOCOL_CAPABILITY_PARAM_EXTENDED` in
    AUTOPILOT_VERSION.

## Receiver rules

  * On receiving `param_type == MAV_PARAM_TYPE_EXTENDED` with
    `extended_type == MAV_PARAM_EXTENDED_TYPE_INT32`, the value is the
    little-endian int32 in `extended_data[0..3]`. The `param_value` field is ignored for
    extended values.
  * A PARAM_SET with an unknown (or `NONE`) `extended_type` and
    `param_type == MAV_PARAM_TYPE_EXTENDED` is rejected; components
    implementing PARAM_ERROR should report
    `MAV_PARAM_ERROR_TYPE_UNSUPPORTED`. This also covers the case of
    an extended PARAM_SET arriving via a MAVLink1 frame, where the
    extension fields are lost and decode as zero.
  * An extended PARAM_SET whose encoding does not match the storage
    type of the target parameter (e.g. INT32 onto a float parameter)
    is rejected; components implementing PARAM_ERROR should report
    `MAV_PARAM_ERROR_TYPE_MISMATCH`.
  * Receive support is independent of any user-facing option that
    disables extended sending: a component that understands the
    encoding always accepts it in PARAM_SET.

## Bandwidth

MAVLink2 truncates trailing zero payload bytes. When the extension
fields are unused they are zero and the messages are byte-identical to
today's. An extended int32 PARAM_VALUE grows by 5 bytes
(`extended_type` plus 4 value bytes).

## Future encodings

The 32 byte `extended_data` array deliberately leaves room for
further `MAV_PARAM_EXTENDED_TYPE` values, for example 64-bit
integers, doubles or short strings, without further message changes.
The NaN `param_value` fallback applies uniformly to all extended
encodings, including non-numeric ones such as strings. Defining those
encodings is out of scope for this RFC; this document only
establishes the container and the int32 encoding.

## Reference implementation

  * ArduPilot: sends extended int32 for values that don't fit a
    float on MAVLink2 channels, accepts extended PARAM_SET, and has a
    user option (`MAV_OPTIONS` bit 1) to disable extended sending and
    the capability bit for compatibility with ground stations that
    mis-handle unknown parameter types.
  * pymavlink: `decode_param_value()` helper, capability tracking and
    `param_set_send()` support.
  * MAVProxy: transparent lossless `param set`/`param show` for int32
    parameters, gated on the capability bit.

# Alternatives

  * **Byte-wise transport in the float field**
    (`MAV_PARAM_TYPE_UNION_INT32`, the predecessor of this RFC):
    rejected because integer values with NaN bit patterns are
    corrupted by signalling-NaN quietening in common float paths, and
    working around that requires raw payload access in every
    implementation. It also cannot degrade gracefully: an old GCS sees
    a garbage float instead of a close approximation.
  * **RFC 0017 (parameter type with encoding)**: signals the encoding
    (C-cast vs byte-wise) in new PARAM_VALUE/PARAM_SET type values,
    which solves log decoding ambiguity and migration signalling but
    does not make large int32 values lossless on C-cast systems, and
    changes the meaning of `param_type` for all values rather than
    only exceptional ones.
  * **Parameter-over-MAVFTP alone**: already lossless for bulk
    download and needs no protocol change, but provides no lossless
    PARAM_SET, no lossless set acknowledgement and no lossless
    individual reads or change broadcasts, and is not implemented by
    all consumers.
  * **PARAM_EXT_* messages**: the extended parameter protocol
    (PARAM_EXT_REQUEST_READ etc.) transports values as strings and is
    a separate protocol; it is not implemented by most autopilot
    firmware or ground stations for regular parameters, and migrating
    to it is a much larger change than extending the existing
    messages.
  * **Adding a double field instead of a byte array**: a double can
    hold any int32 exactly, but not int64/uint64 should those ever be
    needed, and a typed byte array is more explicit about the exact
    wire semantics.

# Unresolved Questions

  * Whether `param_value` should carry NaN (fail loudly in
    extension-unaware consumers) or the closest float representation
    of the value (degrade gracefully, at the risk of a stale client
    silently using or writing back a rounded value). NaN is proposed
    here; the answer should be settled by testing older releases of
    the major ground stations against both variants. Code inspection
    of current releases: QGroundControl drops a PARAM_VALUE with an
    unknown param_type before ever looking at param_value (single
    parameter refresh and set-acknowledgement fail after retries;
    bulk download is unaffected as ArduPilot vehicles use the
    already-lossless MAVFTP download), so the choice does not matter
    to it; Mission Planner ignores the unknown type for ArduPilot
    vehicles and uses the float field directly, so it would display
    NaN (visible breakage) versus a silently rounded value
    (indistinguishable from today). The user-selectable option to
    disable extended sending covers both until they are updated. Note that the
    closest-float variant would also give extension-aware clients a
    usable approximation of values whose extended_type postdates
    them, which NaN cannot.
  * Whether `MAV_PARAM_EXTENDED_TYPE` values for 64-bit types should
    be defined now or when first needed.

# References

  * Parameter protocol: https://mavlink.io/en/services/parameter.html
  * Parameter encoding discussion: https://mavlink.io/en/services/parameter.html#parameter-encoding
  * Previous proposal: https://github.com/mavlink/rfcs/pull/18
