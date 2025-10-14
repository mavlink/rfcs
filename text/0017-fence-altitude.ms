Start date: 2025-10-08
Contributors: Tim Tuxworth
RFC PR: mavlink/rfcs#17

# Summary

Allow polygon and circle fences to include minimum and maximum altitude in a specified frame

# Motivation

With new (as at 2025) regulations coming into force for BVLOS flying in Canada, requiring Detect and Avoid capabilites, drones must be capable of flying within regulated airspaces
which are typically specified as horizontal limits with altitude boundaries, and avoiding known fixed obstacles such as cell towers, buidlings or electrical power lines,
which have a limited specific height.

The regulations refere to [Transport Canada Standard 922](https://tc.canada.ca/en/corporate-services/acts-regulations/list-regulations/canadian-aviation-regulations-sor-96-433/standards/standard-922-rpas-safety-assurance
), and in particular 922-008 Containment.

# Detailed Design

Existing messages for fence items will use existing unused parameters for minimum and maximum altitude and a single parameter for example:

MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION (5001)

Param (Label)	Description	Values
1 (Vertex Count)	Polygon vertex count. This is the number of vertices in the current polygon (all vertices will have the same number).	min: 3 inc: 1
2 (Inclusion Group)	Vehicle must be inside ALL inclusion zones in a single group, vehicle must be inside at least one group, must be the same for all points in each polygon	min: 0 inc: 1
3	(Minimum Altitude) Minimum altitude for the fence. NaN for "does not apply", aka all the way to the ground. Frame according to param 7
4	(Maximum Altitude) Maximum altitude for the fence. NaN for "infinite". 
5 (Latitude)	Latitude	
6 (Longitude)	Longitude	
7	(Frame)     The MAV_FRAME to use for both minimum and maximum altitudes. Applies to both.

For consistencey, in all related MAV_CMD_NAV_FENCE_POLYGON and CIRCLE messages. param 3 will be minimum altitude, param 4 will be maximum altitude and param 7 will be frame.

Accomodating different frames for minimum and maximum altitudes will be accomodated by using vertically overlapping fences each with their own min/max alt frames. 
By including these overlapping fences in the same fence group, a composite airspace can be described using different altitude frames.

# Alternatives

Create a new fence item type that records minimum altitude and maximum altitde with a different frame allowed for minimum and maximum (a real world use case). This would require each horizontal limited 
fence to be matched with "altitude limit" fence items. This would be challenging for GCS to implement.

Add new values to fence items to allow for another frame type value to be added, to allow for a minimum fence to have a differnt frame (e.g. AGL) from the maximum altitude frame which might be AMSL.
