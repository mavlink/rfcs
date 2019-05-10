  * Start date: 2019-05-10
  * Contributors: Beat Kueng <beat-kueng@gmx.net>, Lorenz Meier <lorenz@px4.io>, Julian Oes <julian@oes.ch>, Jonas Vautherin <jonas.vautherin@gmail.com>

# Summary

The proposition here is to rename the "DronecodeSDK" to "MAVLink SDK" and move it into the MAVLink organization.

# Motivation

The DronecodeSDK is a high-level API to MAVLink in different languages (currently C++, Swift, Python and Java), a lower-level MAVLink implementation in C++, and the corresponding "glue" between them. As such, it is very closely related to MAVLink.

However, the "Dronecode" branding of it has been seen to create confusion that the new name would solve by making it clear that:
  * ... the Dronecode Foundation and the SDK are two different things.
  * ... the SDK is a MAVLink implementation not limited to Dronecode, but open to any project based on MAVLink.

# Detailed Design

The proposition goes as follows:

  * The "DronecodeSDK" gets renamed to "MAVLink SDK"
  * All the subprojects of the SDK (API definition, C++ mavlink implementation, gRPC server, language bindings) move to the MAVLink organization
  * The SDK commits to staying open to different MAVLink-based platforms, by:
    * Staying generic to "MAVLink common" (while allowing plugins for specific features)
    * Maintaining tests making sure that changes don't break the supported platforms
    * Maintaining a CI infrastructure running those tests

# Relation to other MAVLink implementations

The SDK architecture makes it theoretically compatible with different implementations, as long as the API is maintained. This means that even though the SDK comes with a C++ mavlink implementation, one could possibly integrate e.g. rust-mavlink or, say, a pure python implementation.

# Unresolved Questions

  * Naming of the different subprojects: how should e.g. DronecodeSDK-Swift be named? MAVLinkSDK-Swift? MAVLink-API-Swift?
  * Namespace/prefix in the implementation: "mvl::"? "mvlsdk::"?
  * SDK logo: should it be the MAVLink logo, or should it be a new logo specific to the "MAVLink SDK" project?
