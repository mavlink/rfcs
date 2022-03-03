  * Start date: 2021-03-03
  * Contributors: HamishWillee <hamishwillee@gmail.com>, AndrewTridgell
  * Related issues: 
    - Protocol bits: https://github.com/mavlink/mavlink/pull/1799#issuecomment-1047329524

# Summary

This RFC proposes a modification to the parameter protocol that makes parameter value encoding explict in the parameter itself, and allows a GCS to signal the encoding so that a flight stack can configure itself to send the right types if supported.

This will allow:
- Reliable decoding of parameter messages from partial logs
- Flight stack to know that the types it is using are supported by the GCS.
  This eases migration from C-style parameter encoding to byte-wise encoding.
  
The changes can be used in parallel with the protocol bits that indicate support for bytewise/c style encoding (if you don't want to take these changes, a GCS would still be able to work with the flight stack).


# Motivation

This provides a path for C-casting based flight stacks and GCS to migrate to supporting bytewise encoding.
At the moment that is hard because a vehicle would have to make the change "all in one go" and all client GCS it works with would need to be using protocol bits to determine the encoding used.

With this change the migration can be done in parts, allowing GCS times to adjust.

This also allows us to know precisely the encoding used from the parameter, without having to check any protocol bits.


### Background

The MAVLink [Parameter Protocol](https://mavlink.io/en/services/parameter.html) provides a mechanism for getting and setting the values of flight-stack specific parameters.

Parameter values are encoded in the `PARAM_SET.param_value` and `PARAM_VALUE.param_value` fields, which are both IEE754 single-precision, 4 byte, floating point values.
The `param_type` ([MAV_PARAM_TYPE](../messages/common.md#MAV_PARAM_TYPE)) is used to indicate the actual type of the data, so that it can be decoded by the recipient.
Supported types are: 8, 16, 32 and 64-bit signed and unsigned integers, and 32 and 64-bit floating point numbers.

For historical reasons two encoding approaches are supported:
- **Byte-wise encoding:** The parameter's bytes are copied directly into the bytes used for the field. 
  A 32-bit integer is sent as 32 bits of data.
- **C-style cast:** The parameter value is converted to a `float`.
  This may result in some loss of precision as a `float` can represent an integer with up to 24 bits of pecision.

A component should support only one type, and indicate that type by setting the `MAV_PROTOCOL_CAPABILITY_PARAM_ENCODE_BYTEWISE` (byte-wise encoding) or `MAV_PROTOCOL_CAPABILITY_PARAM_ENCODE_C_CAST` (C-style encoding) protocol bits in `AUTOPILOT_VERSION.capabilities`.
A GCS may support both types and use the type that is indicated by the target component.

Byte wise encoding is recommended as it allows very large integers to be exchanged (e.g. 1E7 scaled integers can be useful for encoding some types of data, but lose precision if cast directly to floats).

The above approach allows a GCS to determine the parameter type and encoding, and from that extract the value.

This RFC proposes a parallel approach where both the parameter data type _and_ its encoding are represented in the `param_type` field.
This allows a GCS (or other system) to be able to decode a particular parameter type without access to any other information. 
This in turn means that parameters can be decoded from a partial log. 
What it also means is that it provides a migration path for an autopilot from one encoding to the other, because the switch does not have to be done in one release and can be staggered as needed.


# Detailed Design

The design has two parts:
- New enum values in [MAV_PARAM_TYPE](https://mavlink.io/en/messages/common.html#MAV_PARAM_TYPE) that include the parameter type and encoding.
  These allow the GCS to decode each param based on its type.
- [`PARAM_REQUEST_READ`](https://mavlink.io/en/messages/common.html#PARAM_REQUEST_READ) and [`PARAM_REQUEST_LIST`](https://mavlink.io/en/messages/common.html#PARAM_REQUEST_LIST) are extended with an 32 bit bitmask indicating which which `MAV_PARAM_TYPE` flags that the GCS/requester understands.
  The flight stack would cache this response and use the appropriate type for each parameter.
  This allows the flight stack to send only types supported by the corresponding GCS.


## New Enum types

We would add new [MAV_PARAM_TYPE](https://mavlink.io/en/messages/common.html#MAV_PARAM_TYPE) values corresponding to each of the existing types, but including 
the encoding.
A recipient can therefore determine the type and encoding from the message, without having to query any other source.

The proposed pattern for the 10 new "cast" and 10 new "bytewise" flags is: `MAV_PARAM_TYPE_[BYTEWISE|CAST]_[UINT8|INT8|UINT16|INT16|UINT32|INT32|UINT64|INT64|REAL32|REAL64]`.
So for example, to send 32-bit integers you could use `MAV_PARAM_TYPE_INT32`, `MAV_PARAM_TYPE_BYTEWISE_INT32`, or `MAV_PARAM_TYPE_CAST_INT32` (by preference you would send using `MAV_PARAM_TYPE_BYTEWISE_INT32` if this was understood by the GCS.

Question? 
- I am not sure if we need all these?
  I imagine the goal is to move to using `MAV_PARAM_TYPE_BYTEWISE` for all types.
  If you were moving from the existing types to one with encoding in it, when would you ever use the cast type?


## GCS Support

A flight stack can't know if it is talking to a recent GCS that understands the new flags (either all of them, or just the subset it supports).
As a result, if a flight stack sends out the new types, an old GCS will not be able to interpret them. 
This is a problem because it means that a GCS that could understand the old parameters will not understand the new ones. 
This problem cannot be fixed by protocol bits, and is in particular difficult when multiple GCS are based off a common source that might take some releases to get into sync.

The proposed soluton is that a bitmask extension field be added to `PARAM_REQUEST_READ` and `PARAM_REQUEST_LIST` which flags which of the new data types the requestor understands.
The flight stack then configures itself to send the BYTEWISE encoded value of the appropriate type if supported, and otherwise a supported fallback type. 

With the current proposed set of items the flag would have to be a 32-bit bitmask - there will be 10 x 3 parameters.

Flags would be `MAV_PARAM_TYPE_SUPPORTED` values like `MAV_PARAM_TYPE_SUPPORTED_INT32`, `MAV_PARAM_TYPE_SUPPORTED_CAST_INT32`, `MAV_PARAM_TYPE_SUPPORTED_BYTEWISE_INT32`


Notes:
- In future this set may be extended with additional flight modes and component specific modes.
- The "return home" and "safe recovery" modes both serve the same function: getting the vehicle to a safe location in the event of a failsafe or for landing.
  They are separated because from the user perspective the behaviour is quite different and the GCS needs to be able to present that behaviour differently.
  - The existance of these as separate modes means that the autopilot must have separate custom modes for these if we don't publish the standard mode independently. 

## Protocol bits

The two protocol bits `MAV_PROTOCOL_CAPABILITY_PARAM_ENCODE_BYTEWISE` and `MAV_PROTOCOL_CAPABILITY_PARAM_ENCODE_C_CAST` will have to be updated to state that they only apply to the type flags that do not include encoding.

Question 
- what is the discoverability mechanism for parameter protocol?
  Right now you should set one of the above bits, and a GCS can use that to determine support.
  But in future if we all moved to using these new flags, how would we do it?


## Deprecation Path

TBD. 

This update complicates the protocol.
- It adds new enum bits - where there are 10 there may now be 30.
  It is not as obvious which should be selected.
- It adds mechanism to query supported types, which are used in parallel with the protocol bits.
  - We want to make it clear which you should use and when.

What is the envisaged end point? I'd like it to be simple.


# Alternatives

- Do nothing.
  - A GCS will be able to decode messages if it reads the protocol bit (once that is set)
  - Over time a big-bang migration to bytewise encoding would be possible if GCS update to using the protocol bits for identity.
    - I have my doubts this could be reliably managed. Whereas if ground stations start receiving these odd new enums I think they will adjust.
- ?

# Unresolved Questions

- [ ] Do we need C-style encoding enums?
- [ ] What does the end point look like? i.e. the end protocol is more complicated.
- [ ] Are there other alternatives to aid in migration
- [ ] Is there any reason for PX4 to update to the new types?
- [ ] Confirm the desired end point is everyone using bytewise encoding for everything.


# References

- None