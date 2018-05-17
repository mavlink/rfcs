  * Start date: 2018-05-17
  * Contributors: Nuno Marques <nuno.marques@dronesolutions.io>
  * Related issues: To update

# Summary

Create a standard in order to identify a covariance matrix as "unknown".

# Motivation

ROS uses a set of specifications for setting a covariance matrix as unknown. For example:
  * [sensor_msgs/MagneticField.msg](http://docs.ros.org/jade/api/sensor_msgs/html/msg/MagneticField.html): sets all the
  values to zero.
  * [sensor_msgs/Imu.msg](http://docs.ros.org/api/sensor_msgs/html/msg/Imu.html): sets the first value to `-1`.

Having a standard to identify a covariance matrix as unknown is useful when:
  * The data being sent does not have associated covariance values, even though it is being propagated on a message with
  covariance fields;
  * If the consumer is aware that the covariance matrix is unkown, is not going to use it.

# Detailed Design

For all MAVLink messages having an array as a row major represetation of a full covariance matrix or URT of a cross-covariance
matrix, it is proposed to set the first value of the array to `NaN` to identify the covariance matrix (or URT) as unknown.

# Alternatives

Set the first value of the array as `-1` or init the matrix with zeros. This last approach has a problem because a
covariance matrix can have zero-valued cells, meaning that the values are valid. Also, the values of the diagonal
represent the variances, and a variance of zero means that the random variable is constant, so no deviation on the data
between observations.

# Unresolved Questions

# References
  * A good reference for understanding covariances, from the UoM, USA: http://users.stat.umn.edu/~helwig/notes/datamat-Notes.pdf
