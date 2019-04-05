  * Start date: 2019-04-05
  * Contributors: Beat Küng <beat-kueng@gmx.net>
  
# Summary

MAVLink currently does not provide a mechanism to let one component inform
others about sporadic events or state changes with certain delivery. The most
prominent case is for an autopilot to inform a user via GCS about state changes
(e.g. switching into a failsafe mode). This has traditionally been solved by
sending string text messages that are then displayed directly.
However this has several shortcomings:
- The message could be lost, there is no retransmission
- Translation is not possible (or at least very impractical)
- Limited text length, no URLs
- Not suited for automated analysis, or consumption by other components
- Increased flash size requirements for an autopilot binary

The following document serves as a draft for a generic new events interface:
https://docs.google.com/document/d/18qdDgfML97lItom09MJhngYnFzAm1zFdmlCKG7TaBpg/edit

