  * Start date: 2018-11-20
  * Contributors: Beat Küng <beat-kueng@gmx.net>
  
# Summary

This is not an RFC for a MAVLink protocol change, but rather it's something that
affects the MAVLink ecosystem. Which is why I'm still opening an RFC here.

The goal is to create a MAVLink standard testing suite that can be used to check
for MAVLink standard compliance of a system or individual components.

# Motivation

Many systems or components in the UAV space use MAVLink as communication
protocol. It is therefore important to ensure that they adhere to a common
standard to avoid communication problems and improve interoperability.

The rest of this page follows the Google doc referenced at the end.

# Goals
1. Provide a test suite that can be run against a MAVLink-enabled
   component/system to test if that component or system behaves in accordance to
   the MAVLink standard.
   The focus is on the MAVLink protocol and its microservices (as opposed to
   testing if a mission uploaded via MAVLink is executed by the vehicle as
   expected).
2. Provide a generic diagnostics tool to check the MAVLink-related health of a
   system (for example which components are active in a network).

# Testing level/components
There are different levels or components that can be tested against:
- Autopilot board without peripherals
- Autopilot with peripherals (full vehicle, and potentially a companion computer)
- MAVLink-enabled peripherals
  Examples: sensors (e.g. ADSB or FLARM), gimbals, cameras, …
  -> These can have different levels of MAVLink support. Minimally a Heartbeat
  with a sensor message. Additionally they might have parameter support or other
  advanced features.

# Tests
List of potential tests:
- Is the Heartbeat sent at 1Hz with correct sys/comp ID from all components?
- Peripherals: do they use the correct sys ID (that comes from the autopilot)?
- Test graceful handling of unknown messages
- Are wrong target sys/comp ID’s correctly discarded?
- How are different source comp ID’s handled?
- Are commands acknowledged properly?
- Request autopilot version information

- Does message forwarding work correctly? (requires multiple links)
- Test certain streamed messages (e.g. ATTITUDE or IMU@250Hz). Requires a
  working estimator or sensors

- MAVLink Signing (changing the password, sending incorrect timestamps, …)

Microservices:
- Mission/Geofence/Rally download/upload
- Test with a large survey (minimum supported mission size)
- Parameter list/set
- Camera: retrieve/change settings
- FTP list/download/upload/delete
- Log download (requires existing log(s) on the target)
- Log streaming (only on higher bandwidth links. This could interfere with mavlink-router)

For each of these: are message drops handled correctly (retransmission)?
Simulating drops can be to drop x% of the RX/TX messages in a (reproducible)
pseudo-random pattern (TODO: or should a test be more precise and specify the
exact messages to send/drop?).

Long-term the tests can be extended to run against a ground control station,
meaning the other side of the protocols would need to be implemented as well.

In General:
Each test should provide timing/latency results that can be checked against
expected values.
This will depend on the link (and for example how many
parameters a system has, in case of parameter download)

# Diagnostics
The diagnostics tools (2. goal) should include the following functionality:
- Check if MAVLink is running on a certain port (UDP/UART), including which version
- A top-like command that shows:
  - The message rates of each message that is being received (should also show
	unknown messages. Useful to check if a custom MAVLink message is being sent)
  - Data rates and error counts
  - All of this is per mavlink component, show which components are in the network
  - A shell to the autopilot

# Implementation
Very rough structure:
- There is a set of all tests (one module/class/… per test)
- There are different test targets that specify which tests to run (e.g. plain
  autopilot board)
  - A test might list all attached expected components. Then each individual
	component lists its tests. There can be generic test configurations (e.g.
	autopilot) and configurations specific to a vehicle.
  - The link connection should be specified too (e.g. telemetry) for timing
	tests
- The implementation can be based on one of the following:
  - [SDK](https://github.com/Dronecode/DronecodeSDK)
    (either using the python frontend, or native in C++)
    Pro:
    - Certain aspects are already implemented (Mission protocol)
    - Better testing level and standard conformance testing for the SDK itself
    (potential) Con:
    - Requires low-level control and thus support from the SDK:
      - Simulation of message drops (RX/TX)
      - Manipulate specific fields of messages (e.g. sys/comp ID)
	  -> Can be solved in a generic way by adding callback hooks that can
	     manipulate a message right before it’s sent/received.
    - Send/receive custom mavlink messages
    - Precise error messages & debugging possibilities (might already exist)
	- Requires the SDK to adhere exactly to the MAVLink standard (which it
	  should anyway)
	- The SDK implementation might slightly change (but still adhering to the
	  standard), and a test that passed before might fail. But this means the
	  test was not thorough enough to begin with.
	- The SDK might not be suited to test individual components as it’s designed
	  to talk to an autopilot (or a system that includes one). Also for basic
	  tests like heartbeat checking.
    -> All of the above needs to be exposed from python if python is used
  - Python + pymavlink
    Pro:
    - Independent implementation
    - Full control over what is sent and received on the lowest level
    Con:
    - All the microservices need to be implemented from scratch
	- More maintenance efforts (though once the tests exist, they should be
	  stable as the protocol evolves slowly)
    - License might be an issue
- Option to abort on first failure or run completely with a summary report
- Failed tests: output commands on how to repeat individual test
- Print detailed failure cause

# Testing Workflow

- Test preparation: set required parameters (MAV_SYS_ID), create log(s)
  -> Should be automatic, but it might be autopilot-specific (i.e. PX4)
- Then attach the vehicle/component, select the test to run and execute it
- Review the test summary/report

- In case of failures: fix them and only re-run the test(s) that failed

# Required changes for the SDK if SDK is used

- send/receive MAVLink message hooks
- Add a passive connection mode: do not send anything until told to do so, and
  just listen for incoming messages
- Check the error messages from python (must be detailed enough to debug e.g.
  mission transfer failures)
- Send/receive custom mavlink messages (already planned)
  - Ability to receive completely unknown messages (not necessarily parse it,
	but get the message ID)
  - Ability to easily add and send messages that are (not yet) officially in the
	SDK
- more?

# Unresolved Questions

- Should the implementation be based on the [SDK](https://github.com/Dronecode/DronecodeSDK),
  and if so, use the python or the C++ frontend?

# References
Main Google doc with the same content: https://docs.google.com/document/d/1zwUZ-VUmq2pmCuGn1kY6BRS48-GiSXcMO5TUfnTpqmI/edit?usp=sharing
