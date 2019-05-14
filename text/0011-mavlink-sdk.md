  * Start date: 2019-05-10
  * Contributors: Beat Kueng <beat-kueng@gmx.net>, Lorenz Meier <lorenz@px4.io>, Julian Oes <julian@oes.ch>, Tom Pittenger, Ramón Hernán Roche Quintana <mrpollo@gmail.com>, Jonas Vautherin <jonas.vautherin@gmail.com>, Stone White <bys_1123@163.com>, Hamish Willee <hamishwillee@gmail.com>

# Summary

The proposition here is to rename the "DronecodeSDK" to "MAVSDK" and move it into the MAVLink organization.

# Motivation

The DronecodeSDK is a high-level API to MAVLink in different languages (currently C++, Swift, Python and Java), a lower-level MAVLink implementation in C++, and the corresponding "glue" between them. As such, it is very closely related to MAVLink.

However, the "Dronecode" branding of it has been seen to create confusion that the new name would solve by making it clear that:
  * ... the Dronecode Foundation and the SDK are two different things.
  * ... the SDK is a MAVLink implementation not limited to Dronecode, but open to any project based on MAVLink.

# Detailed Design

The proposition goes as follows:

  * The "DronecodeSDK" gets renamed to "MAVSDK"
  * All the subprojects of the SDK (API definition, C++ mavlink implementation, gRPC server, language bindings) move to the MAVLink organization
  * The SDK is committed to staying open to different MAVLink-based platforms, by:
    * Staying generic to "MAVLink common" (while allowing plugins for specific features/dialects).
    * Maintaining tests making sure that changes don't break the supported platforms.
    * Maintaining a CI infrastructure running those tests.
  * Contributions to the SDK should come with adequate automated testing to the same quality level as standard plugins.
  * Contributions do not necessarily need to support all flight stacks to be merged, as long as they do not break existing test suites.
  * The contributor must commit to maintain the code. If not maintained, the code might be removed.
  * The people with maintenance rights is the superset of the current MAVLink and SDK teams.

# Relation to other MAVLink implementations

The SDK architecture makes it theoretically compatible with different implementations, as long as the API is maintained. This means that even though the SDK comes with a C++ mavlink implementation, one could possibly integrate e.g. rust-mavlink or, say, a pure python implementation.

MAVSDK is _an_ official SDK, in that it is supported and maintained within the MAVLink organization but without the implication that it is the only or necessarily best stack for every flight stack.
