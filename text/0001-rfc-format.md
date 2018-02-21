  * Start date: 2018-02-21
  * Contributors: Lorenz Meier <lorenz@px4.io>, ...
  * Related issues: 
  
# Summary

The scope of this document is to design a Request-for-comments process for MAVLink for protocol additions that require a non-trivial change. The goal is to create a transparent, agreed-on process that allows the community and maintainer to make informed decisions and to capture the rationales behind these decisions in a document. This will insure quality of the design as well as later inform developers who have not been part of the original decisions of the reasons. The documents should also include further references and examples.
  
# Motivation

As the amount of micro-services in the MAVLink protocol increases the design process needs more structure to be able to accomodate all stakeholders and create the required transparency.

# Detailed Design

The RFC process should follow a simple flow:

  * The original proposer raises a pull request with a document in this format.
  * The maintainer reviews the document and notifies additional stakeholders.
  * Contributors comment on the draft or raise a separate PR. The original proposer is expected to be responsive for a period of two weeks so the document can converge and the technical discussion settle.
  * Once the discussion has converged (or if more than four weeks have passed) the RFC is either merged (and the original proposer is expected to deliver the corresponding implementation) or rejected
  * During the discussion phase there should be clear commitments towards implementing the RFC.
  * If a RFC has not been implemented with reasonable progress within 4 weeks of merging the RFC document, it should be removed entirely.

# Alternatives

The community has tried to discuss design changes on Github issues and Forums, but these threads are at time lengthy, hard to read and fragmented.

# Unresolved Questions

# References
  * IETF RFC 2026: https://tools.ietf.org/html/rfc2026
  * Rust RFC design document: https://github.com/rust-lang/rfcs/blob/master/text/0002-rfc-process.md
