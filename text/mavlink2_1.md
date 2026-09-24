  * Start date: 2022-10-12
  * Contributors: Andrew Tridgell

# Summary

Rough proposal for MAVLink 2.1

# Motivation

Key features wanted:

 * support for more than 256 system IDs
 * support for checking CRCs in routers that don't have all xml
 * better target_system/target_component support
 * maximum compatibility with existing mavlink2 systems

# Detailed Design

The design takes advantage of the incompat_flags and compat_flags
fields in the MAVLink2 header.

New incompat_flags flags would be:

 * MAVLINK_IFLAG_SYSID16 : system ID in header is 16 bits wide
 * MAVLINK_IFLAG_TARGETTED : header has target_system and target_component appended
 * MAVLINK_IFLAG_SPLIT_CRC : 16 bit crc is as described below

New compat_flags flags would be:

 * MAVLINK_FLAG_21_CAPABLE : sender is capable of handling MAVLink 2.1

Note that for the SYSID16 and TARGETTED flags the sender should only
use the flag if is it needed. So if the systemID in the message is
<=255 then the flag should not be set and the existing 8 bit field
should be used. For the TARGETTED bit this should only be used if the
target systemID is >255 (needing 16 bits) or if the message that needs
targetting doesn't have a target_system or target_component field.

Following these rules maximises compatibility with existing MAVLink2
capable systems.

Note that when SYSID16 flag is set then the target_system would be 16
bits when TARGETTED is set.

For messages with existing target_system/target_component fields, if
the TARGETTED bit is set then the existing fields are ignored by the
recipient. The sender should set the old fields to zero.

The 16 bit size of the expanded systemID could perhaps be 32 bits,
allowing for an IPv4 address to be used, which could be useful for
many use cases. The target audience is drone light shows which often
use WiFi.

## Split CRC

The idea of the split CRC is to address a concern from people making
MAVLink routing tools that they can't CRC new messages that they
didn't have the XML for at the time they built the router firmware.

The solution is to do what we should have done for MAVLink 1.0, which
is to make 8 bits of the 16 bit CRC depend on the structural seed, and
8 bits not depend on the seed.
