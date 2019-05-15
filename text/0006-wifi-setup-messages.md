 * Start date: 2018-05-7
 * Contributors: Vladimir Provalov <vladimir.provalov@emlid.com>, Alexey Bulatov <alexey.bulatov@emlid.com>
 * Related PR: [wifi-setup mavlink](https://github.com/mavlink/mavlink/pull/900)

# Summary

This document describes the new messages for Wi-Fi setup through mavlink protocol.
With these messages GCS can switch Wi-Fi between two modes (Client/AP), save/delete
networks to/from vehicle and requests current status of Wi-Fi.

# Motivation

Some of vehicles can connect to a ground station via Wi-Fi. It follows that the vehicle can be in two modes: Access Point (AP) - vehicle is connected to GCS directly (GCS is client of vehicle's access point), Client - vehicle is connected to another access point (for example, your home network) and communicates with GCS using it.
On start, vehicle is in AP mode. We need some instrument:

* for switching vehicle's Wi-Fi between modes,
* for requesting current Wi-Fi status (Current Wi-Fi mode and SSID of current network or SSID of vehicle's AP)
* for saving/removing networks to/from a vehicle, to which vehicle can connect.
* for getting list of saved/scanned networks

> Note: saved network - is a network which was added to vehicle using `WIFI_NETWORK_ADD` or manually (through SSH). Scanned network - is a network which was scanned by vehicle's Wi-Fi adapter.

Switching between modes is useful for users. For example, they can add a local AP (with access to the internet) and connect their vehicles to it, ssh, and install needed packages.

For these reasons, we want to add new messages to the mavlink protocol for setting up Wi-Fi via GCS.

> Note: Following messages come as additional functionality to existing `WIFI_CONFIG_AP` message.

# Detailed Design

## Messages naming

All messages which is related to Wi-Fi start with `WIFI_object`
All commands which is related to Wi-Fi start with `MAV_CMD_action_WIFI_objects`

## Communication

### Enums

* `WIFI_SECURITY_TYPE` defines a set of Wi-Fi security types:
  * `WIFI_SECURITY_TYPE_OPEN`
  * `WIFI_SECURITY_TYPE_WEP`
  * `WIFI_SECURITY_TYPE_WPA`
  * `WIFI_SECURITY_TYPE_WPA2`

* `WIFI_STATE` def
* ines current Wi-Fi state:
  * `WIFI_STATE_UNDEFINED`
  * `WIFI_STATE_AP` - Access point mode
  * `WIFI_STATE_CLIENT` - Client mode

### Wi-Fi Ack

Wi-Fi ACK sends by vehicle as a response to GCS wifi messages (not commands).

* `WIFI_ACK`, contains:
  * `WIFI_*` message id
  * Result: 0 - success, 1 - network already exists (on add), 2 - network is not exist (on delete or connect), 3 - already in AP, 4 - unknown error (may be described in `STATUS_TEXT`)

### Request Wi-Fi status

#### Messages

* `MAV_CMD_GET_WIFI_STATUS`
* `WIFI_STATUS`, contains:
  * current state (see `WIFI_STATE`)
  * SSID (If current state is `WIFI_STATE_AP` - SSID of vehicle's AP, else if current state is `WIFI_STATE_CLIENT` - SSID of AP, to which vehicle is connected, otherwise - undefined)

#### Description

GCS requests Wi-Fi status using `MAV_CMD_GET_WIFI_STATUS` and waits for `WIFI_STATUS` message.

### Request saved/scanned Wi-Fi networks list

#### Messages

* `MAV_CMD_GET_WIFI_NETWORKS_COUNT`, contains:
  * Networks type (Saved or Scanned)
* `WIFI_NETWORKS_COUNT`, contains:
  * Number of networks
  * Networks type (Saved or Scanned)
* `MAV_CMD_GET_WIFI_NETWORKS_INFO`, contains:
  * Networks type (Saved or Scanned)
* `WIFI_NETWORK_INFO`, contains:
  * SSID of network
  * Security type (See `WIFI_SECURITY_TYPE`)
  * Network type (Saved scanned)

#### Description

First of all, GCS requests number of saved/scanned Wi-Fi networks using `MAV_CMD_GET_WIFI_NETWORKS_COUNT`. When GCS receives `WIFI_NETWORKS_COUNT`, it requests needed networks using `MAV_CMD_GET_WIFI_NETWORKS_INFO` and receives nth `WIFI_NETWORKS_INFO` from vehicle (losses can be detected using number of networks).

### Add/delete network to/from vehicle

#### Messages

* `WIFI_NETWORK_ADD`
  * SSID of network
  * Security type (see `WIFI_SECURITY_TYPE`)
  * password
* `WIFI_NETWORK_DELETE`
  * SSID of network, which we want to delete

#### Description

GCS sends `WIFI_NETWORK_ADD`/`WIFI_NETWORK_DELETE` for adding/deleting network to/from vehicle, and waits for `WIFI_ACK`.

### Switching between AP and Client

#### Messages

* `MAV_CMD_WIFI_START_AP`
* `WIFI_NETWORK_CONNECT`
  * SSID of network, to which we want to connect (network should be already saved using `WIFI_NETWORK_ADD`)

#### Description

* For switching vehicle to AP GCS sends `MAV_CMD_WIFI_START_AP` to a vehicle and waits for `WIFI_ACK` (Possible results: 0 - success, 3 - already in AP, 4 - unknown Error)

* For switching vehicle to Client mode GCS sends `WIFI_NETWORK_CONNECT` with SSID of network as parameter and waits for `WIFI_ACK` (Possible results: 0 - success, 2 - network doesn't exist, 4 - unknown error)

> Note: after each switching, GCS should reconnect to a vehicle (using new IP) and, when connection is established, request for `WIFI_STATUS`.

# References

* [Documentation with GUI screenshots](https://docs.emlid.com/edge/qgc/wifi-setup/)