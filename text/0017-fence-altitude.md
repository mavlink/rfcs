Start date: 2025-10-08
Contributors: Tim Tuxworth
RFC PR: mavlink/rfcs#17

# Summary

Allow polygon and circle fences to include minimum and maximum altitude in a specified frame

# Motivation

With new (as at 2025) regulations coming into force for BVLOS flying in Canada, requiring Detect and Avoid capabilities, drones must be capable of flying within regulated airspaces which are typically specified as horizontal limits with altitude boundaries, and avoiding known fixed obstacles such as cell towers, buildings or electrical power lines, which have a limited specific height.

The regulations refer to [Transport Canada Standard 922](https://tc.canada.ca/en/corporate-services/acts-regulations/list-regulations/canadian-aviation-regulations-sor-96-433/standards/standard-922-rpas-safety-assurance), and in particular 922-008 Containment.

# Detailed Design

Existing messages for fence items will use existing unused parameters for minimum and maximum altitude and a single parameter for the frame.
For example:

MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION (5001)

Param (Label) | Description | Values
--- | --- | ---
1 (Vertex Count)    | Polygon vertex count. Number of vertices in the current polygon (all vertices will have the same number). | min: 3 inc: 1
2 (Inclusion Group) | Vehicle must be inside ALL inclusion zones in a single group, vehicle must be inside at least one group, must be the same for all points in each polygon | min: 0 inc: 1
3 (Min Altitude)    | Minimum altitude for the fence. | NaN for "does not apply" (all the way to the ground). Frame according to MISSION_ITEM_INT.frame by default and param4 if defined. | 
4 (Frame)           | The MAV_FRAME to use for Min Altitude (param3) if the default is not used | MAV_FRAME_GLOBAL is default frame. | 
5 (Latitude)        | Latitude | 
6 (Longitude)       | Longitude | 
7 (Max Altitude)    | Maximum altitude for the fence. Frame defined by MISSION_ITEM_INT.frame | NaN for "infinite" (or max=min=0)

For consistency, in all MAV*CMD_NAV_FENCE* messages: param 3 will be minimum altitude, param 7 will be maximum altitude. The default frame for both with be defined in MISSION_ITEM_INT.frame. If param3 and param4 have different frames then param 4 will define the frame for the minimum altitude (param 3).

# Alternatives

Create a new fence item type that records minimum altitude and maximum altitude with a different frame allowed for minimum and maximum (a real world use case). This would require each horizontal limited
fence to be matched with "altitude limit" fence items. This would be challenging for GCS to implement.

Add new values to fence items to allow for another frame type value to be added, to allow for a minimum fence to have a different frame (e.g. AGL) from the maximum altitude frame which might be AMSL.
