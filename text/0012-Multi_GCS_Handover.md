  * Start date: 2023-03-06
  * Contributors: Konrad Rudin <konrad@auterion.com>, Thomas Debrunner <thomas.debrunner@auterion.com>
  * Related issues: 
  
# Summary

Proposal to add a new microservice to MAVLink to handle control for multiple GCS connections and to provide a mechanism to hand over the control between multiple GCSs. 
  
# Motivation

It is common that multiple GCS can connect to a AV, where one is able to control the AV, one in control of the payload and the others are observers and can see the state as well as the payload streams. In this scenario, it has to be defined, which GCS is in control. Further, a mechanism has to be provided, which enables an observer to request a handover control from the current controller.

# Detailed Design

In order to to allow the multiple GCS scenario the communication protocol must add the following capabilities:
  * A mesage for a GCS to request the control.
  * A corresponding Ack message defining the status of the request.
  * A handoff request from the system to request the handoff from the current control GCS, together with a respond message.
  * A corresponding Control Status messaage periodically sending which GCS is in control of which subsystem.
  * A release control message for the control GCS to be able to release the control
A more detailed view of the outline can be seen in the PR in https://github.com/mavlink/mavlink/pull/1954

# Alternatives

# Unresolved Questions

# References

