# Dispersion Payload Protocol

- Start date: 2025-02-18
- Contributors: Wesley Murray <murraywj97@gmail.com>, ...
- Related issues: N/A

## Summary

The scope of this document is to define a message definition set and protocol for interacting with a dispersion payload to ensure effective control as well as compliance and efficacy reporting. The goal is to create an agreed-on standard for what data is necessary and how it should be used so that there can be more transparency in the UAV crop protection space.

## Motivation

There is an increasing demand for using UAVs to deliver chemicals in agriculture for crop protection. This most commonly happens in the form of sprayers or spreaders. Sprayers are typically for liquid payloads and spreaders for granular solids. This has resulted in many indepent solutions to the problem, all using their own version of a black box. This often leaves aerial applicators unable to provide transparency into their service from a regulatory compliance side of things or for customer satisfaction in a situation where very hazardous chemical are frequently applied. This should not be the case.

From the technical side of things, the concept of operations around agricultural applications provide the opportunity to push the techical envelope without a safety risk to people. Thus, expanding MAVLink support into the space will inherently increase adoption of MAVLink which will help validate other aspects of the standard in an unstructured enviornment. So putting a little investment in agriculture specific solutions IMO has out sized benefits.

## Detailed Design

### Background

For those not familiar with aerial application in Agriculture, I strongly recommend using the [Aerial Applicator's Manual](https://www.epa.gov/system/files/documents/2023-11/national-aerial-applicator-manual-2014.pdf). Specifically Chapter 4.

I used the [MAVLink Gimbal Protocol](https://mavlink.io/en/services/gimbal_v2.html) as my template. I must admit, I do not like the concept of splitting the manager and device. I think it over complicates the protocol but I still followed the pattern since there is context I am likely missing. In this PR you will see a proposal that is the device only, but adding on the manager layer is pretty trivial. That being said, I would like to see strong justification for the addition of a manager before I will agree to add it in during the implementation.

### Test Cases

A procotol can be very difficult to analyze in isolation so I started by creating the following set of test cases. These test cases are effectively situations and workflows the protocol must support to provide any value. I then used the proposed protocol to accomplish said test cases. This is an excellent review point for industry specific individuals who might not have a technical background. For those with a technical background this is still a useful starting point because it provides context.

[x] user needs to manually rinse out the system and must be able to control via some sort of interface (physical or digital)
[x] user might need to stop spray mid flight for an emergency without the autopilot being able to override
[x] payload gets overfilled during servicing
[x] payload is not full enough when trying to take off
[x] clogged nozzle during flight
[x] motor (spray pump, or spreader motor) failure during flight
[x] spray system leaks
[x] autopilot control of spray system
[x] aircraft exceeds speed at which the device can keep up
[x] device is turned on before aircraft is at minimum speed
[x] dynamically adjust deposition rate based on aircraft speed
[x] get payload information for planning (ie lead in/out distances, spray leg length, etc)

- Swath width will be configured during planning so OOS

[x] data for compliance and efficancy reporting can be extracted

- Factors that cannot be known by the dispersion device is OOS and can be collected in other parts of the system (ie wind, chemical being applied, etc)

[x] payload is at target fill and ready to go
[x] spot spraying. This happens at the planning level. This protocol supports setting flow rate at specific locations which is enough for spot spraying.
[x] communication buses might be lossy so protocol must handle failure detection.
[x] ability to construct a synchronized timestamp across mavlink nodes to account for latency in commands when generating reports
[x] multiple dispersion devices are connected to the autopilot and need independent control
[x] a single dispersion device has multiple nozzles that require independent nozzle control
[x] the user can adjust droplet size on the ground station during a mission to account for changing wind conditions
[x] a dispersion device could correct flow rate for individual nozzles during turning
[x] a dispersion device can reduce overspray when intersecting an existing not perpendicular spray line by individually turning off one nozzle at a time
[x] protocol supports nozzle count of largest existing sprayer with some additional room for expansion

### Implementation

After reviewing other submissions, I think I might have gone too far down this path but I wanted something complete to get reviewed by industry relevant people in my network before submitting here to the MAVLink community. I created a messages.md file with the full set of message definitions and a microservice.md file detailing how the protocol should work that is submitted with this PR. I have a couple of versions: one with a manager and one without. I used the one without because it is less complex and conveys the same concept.

Every enum that is not a bitmask uses the zero value as a default UNKNOWN value. This, in my experience, results in more robust systems since it is very common to initialize values to zero in the background. Developers can miss this and if zero is a common valid value, the issue often wont surface until late run time. By having a default value that is useless, systems will almost immediately surface an error.

This protocol should at a minimum support the capability of existing systems and then project into the future a little bit to be a timely, durable, and valuable solution. So, this protocol is designed to support a system with multiple dispersion devices and multiple subcomponents on that device. For the sake of this design, we consider a dispersion device to be a system containing one chemical mix and the infrastructure to deliver that to a field. The dipsersion device must have one gateway compute node that is responsible for communicating over a MAVLink interface. In the most simple form, a disperison device could be a microprocessor, tank, esc, motor, and spreader wheel that needs rate assigned at specific GPS locations but it can take on a more complex form factor for large ground based spray systems. These might have multiple feeder tanks with n number of subcomponents allowing independent control of subcomponent droplet size and flow rate to support many powerful features such as spot spraying and turn compenstation.

### Questions

1. ~~This is a combined protocol for spraying and spreading since there are many common elements. Should this be split up?~~
1. ~~For any kind of effective reporting, not only do the messages needs to be defined but there should also be a degree of standardization on how that information gets logged so utilities can interact with it. Making logging suggestions seemed out of scope here but is there anything I should add to nudge people in the right direction?~~
1. ~~Is a dispersion manager needed? I genuinely believe the source should not matter. Anything should be able to send a request and it get processed in the order it is received. The only time any prioritization should occur is manual triggers vs automated. No this could be handled through a manager but it is pretty easy implement with just the deivce using the MANUAL vs AUTO request type. I also expect there to be multiple possible viable sources for manual on/off live at any given moment. All should be immediately respected. I feel like the overhead with a manager only allowign two control sources could make this over complicated.~~
1. Am I missing any critical workflows or test cases? Ie Debug level motor controller and motor information (deemed out of scope, should be a separate protocol for general motor controller and motor information)
1. should we encourage using something like the parameter protocol rather than a command message for configuration?

### Tentative Decisions

1. the combined protocol makes sense with the addition of an enum indicating type in the relevant messages
1. dispersion payloads will be implemented as standalone MAVLink devices
1. a logging infrastructure is proposed
1. a dispersion manager will not be used
1. eliminate request message in favor of mav command infrastructure

## Alternatives

1. Do nothing. Solutions are already evolving organically. While the problem will be solved, it is subject to the issues documented in the motivation section.
1. Create documentation on how to use the generic payload messaging infrastructure to accomplish this goal. (I think this will lose a lot of critical information)

## References

- ISOBUS (HSI) Agriculture Comm Standards: https://www.aef-online.org/about-us/activities/high-speed-isobus.html
- Pix4D Spot Spraying Article: https://www.pix4d.com/blog/variable-rate-application-wheat-field/
- Aerial Applicator's Manual: https://www.epa.gov/system/files/documents/2023-11/national-aerial-applicator-manual-2014.pdf
- MAVLink Gimbal Protocol: https://mavlink.io/en/services/gimbal_v2.html
- XAG P150: https://www.xa.com/en/p150
- DJI Agras T40: https://www.dji.com/t40
- Hylio: https://www.hyl.io/
- Rotor: https://rotor.ai/
- Guardian Agriculture: https://guardian.ag/
- PYKA: https://www.flypyka.com/
- TeeJet Dynajet: https://www.teejet.com/precision-farming/application-control-and-monitoring/dynajet
- TeeJet Precision Ag Products: https://www.farmco.com/price%20lists/teejet/2024%2009-01%20teejet%20precision%20picture%20price.pdf
- CPNozzles Accuflow: https://www.cpnozzles.com/products/accu-flo-nozzles/

## TODO

1. um (micron) should be added as an allowed xml unit
