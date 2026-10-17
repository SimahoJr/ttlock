# Solar2D BLE Plugin

Native Bluetooth Low Energy (BLE) plugin for Solar2D.

The plugin provides a Lua API for:

- BLE adapter detection
- Bluetooth state detection
- Runtime permission handling
- BLE scanning
- Device connection
- Service discovery
- Characteristic read/write
- Write without response
- Notifications / indications
- Connection and operation events

---

# Installation

Add the plugin to `build.settings`:

```lua
settings = {
    plugins = {
        ["plugin.ble"] = {
            publisherId = "it.shannonit"
        }
    },

    android = {
        usesPermissions = {
            "android.permission.BLUETOOTH",
            "android.permission.BLUETOOTH_ADMIN",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.BLUETOOTH_SCAN",
            "android.permission.BLUETOOTH_CONNECT"
        },

        minSdkVersion = 23
    }
}
```

Load the plugin:

```lua
local ble = require("plugin.ble")
```

---

# API Overview

```text
plugin.ble
│
├── init(listener)
│
├── isSupported()
├── isEnabled()
│
├── hasPermission()
├── requestPermission()
│
├── startScan()
├── stopScan()
│
├── connect(deviceId)
├── disconnect(deviceId)
│
├── discoverServices(deviceId)
│
├── read(deviceId, serviceUuid, characteristicUuid)
├── write(deviceId, serviceUuid, characteristicUuid, data)
├── writeWithoutResponse(deviceId, serviceUuid, characteristicUuid, data)
│
├── subscribe(deviceId, serviceUuid, characteristicUuid)
└── unsubscribe(deviceId, serviceUuid, characteristicUuid)
```

---

# Data Types

## Device ID

```text
string
```

On Android this is normally the Bluetooth MAC address.

Example:

```lua
local deviceId = "15:6E:16:FD:32:A6"
```

---

## UUID

```text
string
```

BLE service and characteristic UUID.

Example:

```lua
local serviceUuid =
    "00001910-0000-1000-8000-00805f9b34fb"

local characteristicUuid =
    "0000fff2-0000-1000-8000-00805f9b34fb"
```

---

## Binary Data

BLE data is represented as a Lua binary string.

Example:

```lua
local data = string.char(
    0x01,
    0x02,
    0xA0,
    0xFF,
    0x00
)
```

The Lua string can contain `0x00` and other non-printable bytes.

To display binary data as hexadecimal:

```lua
local function toHex(data)

    local result = {}

    for i = 1, #data do
        result[#result + 1] =
            string.format(
                "%02X",
                string.byte(data, i)
            )
    end

    return table.concat(result, " ")
end
```

---

# Initialization

## `ble.init(listener)`

Initializes the BLE plugin and registers the event listener.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `listener` | `function` | Yes | Function called for BLE events |

Example:

```lua
local function onBleEvent(event)

    print(
        "BLE EVENT:",
        event.name
    )

end

ble.init(onBleEvent)
```

The listener receives an event table.

General structure:

```lua
{
    name = "eventName",
    ...
}
```

The exact fields depend on the event.

---

# Adapter Status

## `ble.isSupported()`

Returns whether BLE is supported.

### Returns

```text
boolean
```

Example:

```lua
if ble.isSupported() then
    print("BLE supported")
else
    print("BLE not supported")
end
```

---

## `ble.isEnabled()`

Returns whether Bluetooth is currently enabled.

### Returns

```text
boolean
```

Example:

```lua
if ble.isEnabled() then
    print("Bluetooth enabled")
else
    print("Bluetooth disabled")
end
```

---

# Permissions

## `ble.hasPermission()`

Checks whether the required BLE permissions are available.

### Returns

```text
boolean
```

Example:

```lua
if ble.hasPermission() then
    print("BLE permission available")
end
```

---

## `ble.requestPermission()`

Requests the required BLE permissions from Android.

### Arguments

None.

Example:

```lua
ble.requestPermission()
```

Permission results are delivered through the normal BLE event system where applicable.

---

# Scanning

## `ble.startScan()`

Starts BLE device scanning.

### Arguments

None.

Example:

```lua
ble.startScan()
```

Discovered devices are reported using the `deviceFound` event.

---

## `ble.stopScan()`

Stops the current BLE scan.

### Arguments

None.

Example:

```lua
ble.stopScan()
```

Typical scan flow:

```lua
ble.startScan()

timer.performWithDelay(
    5000,
    function()
        ble.stopScan()
    end
)
```

---

# Device Discovery Event

## `deviceFound`

Generated when a BLE device is discovered.

Example:

```lua
local function onBleEvent(event)

    if event.name == "deviceFound" then

        local device = event.device

        print(
            "Name:",
            device.name
        )

        print(
            "ID:",
            device.deviceId
        )

        print(
            "RSSI:",
            device.rssi
        )

    end

end
```

Typical device structure:

```lua
event.device = {
    deviceId = "15:6E:16:FD:32:A6",
    name = "BLE Device",
    rssi = -55
}
```

The available device fields depend on what Android provides.

---

# Connection

## `ble.connect(deviceId)`

Connects to a BLE device.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | BLE device identifier |

Example:

```lua
ble.connect(
    "15:6E:16:FD:32:A6"
)
```

Success:

```text
connected
```

Failure:

```text
connectionError
```

---

## `ble.disconnect(deviceId)`

Disconnects from a BLE device.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | BLE device identifier |

Example:

```lua
ble.disconnect(
    "15:6E:16:FD:32:A6"
)
```

Event:

```text
disconnected
```

---

# Connection Events

## `connected`

Generated after a successful BLE connection.

Typical event:

```lua
{
    name = "connected",
    deviceId = "15:6E:16:FD:32:A6"
}
```

---

## `disconnected`

Generated when the device disconnects.

Typical event:

```lua
{
    name = "disconnected",
    deviceId = "15:6E:16:FD:32:A6"
}
```

---

## `connectionError`

Generated when connection fails.

Typical event:

```lua
{
    name = "connectionError",
    deviceId = "15:6E:16:FD:32:A6",
    error = "Connection failed"
}
```

---

# Service Discovery

## `ble.discoverServices(deviceId)`

Discovers the GATT services and characteristics exposed by the connected device.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | Connected BLE device |

Example:

```lua
ble.discoverServices(
    deviceId
)
```

The result is delivered through:

```text
servicesDiscovered
```

or:

```text
serviceError
```

---

# `servicesDiscovered` Event

The event contains the discovered services and their characteristics.

Example structure:

```lua
{
    name = "servicesDiscovered",

    deviceId = "15:6E:16:FD:32:A6",

    count = 1,

    services = {
        {
            uuid = "00001910-0000-1000-8000-00805f9b34fb",

            type = "PRIMARY",

            characteristicCount = 2,

            characteristics = {
                {
                    uuid = "0000fff2-0000-1000-8000-00805f9b34fb",

                    properties = "WRITE",
                    propertiesValue = 8,

                    canRead = false,
                    canWrite = true,
                    canWriteWithoutResponse = false,
                    canNotify = false,
                    canIndicate = false
                }
            }
        }
    }
}
```

---

# Characteristic Properties

Each characteristic can report:

```text
BROADCAST
READ
WRITE_NO_RESPONSE
WRITE
NOTIFY
INDICATE
SIGNED_WRITE
NONE
```

Example:

```lua
if characteristic.canRead then
    print("Characteristic supports READ")
end

if characteristic.canWrite then
    print("Characteristic supports WRITE")
end

if characteristic.canWriteWithoutResponse then
    print("Characteristic supports WRITE WITHOUT RESPONSE")
end

if characteristic.canNotify then
    print("Characteristic supports NOTIFY")
end

if characteristic.canIndicate then
    print("Characteristic supports INDICATE")
end
```

---

# Service Error

## `serviceError`

Generated when service discovery fails.

Example:

```lua
if event.name == "serviceError" then

    print(
        "Service discovery error:",
        event.error
    )

end
```

---

# Read

## `ble.read(deviceId, serviceUuid, characteristicUuid)`

Reads the value of a characteristic.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | Connected BLE device |
| `serviceUuid` | `string` | Yes | GATT service UUID |
| `characteristicUuid` | `string` | Yes | Characteristic UUID |

Example:

```lua
ble.read(
    deviceId,
    serviceUuid,
    characteristicUuid
)
```

The result is delivered through:

```text
characteristicRead
```

or:

```text
readError
```

---

# `characteristicRead` Event

Example:

```lua
if event.name == "characteristicRead" then

    print(
        "Data:",
        toHex(event.data)
    )

end
```

Typical structure:

```lua
{
    name = "characteristicRead",

    deviceId = "15:6E:16:FD:32:A6",

    serviceUuid =
        "00001910-0000-1000-8000-00805f9b34fb",

    characteristicUuid =
        "0000fff2-0000-1000-8000-00805f9b34fb",

    data = "\1\2\160\255"
}
```

`data` is a binary Lua string.

---

# Read Error

## `readError`

Generated when a characteristic read fails.

Example:

```lua
if event.name == "readError" then

    print(
        "READ ERROR:",
        event.error
    )

end
```

---

# Write

## `ble.write(deviceId, serviceUuid, characteristicUuid, data)`

Writes binary data to a characteristic.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | Connected BLE device |
| `serviceUuid` | `string` | Yes | GATT service UUID |
| `characteristicUuid` | `string` | Yes | Characteristic UUID |
| `data` | `string` | Yes | Binary Lua string |

Example:

```lua
local data = string.char(
    0x01,
    0x02,
    0xA0,
    0xFF
)

ble.write(
    deviceId,
    serviceUuid,
    characteristicUuid,
    data
)
```

Success:

```text
characteristicWritten
```

Failure:

```text
writeError
```

---

# Write Without Response

## `ble.writeWithoutResponse(deviceId, serviceUuid, characteristicUuid, data)`

Writes binary data using the BLE Write Without Response operation.

This is useful for protocols that require:

```text
WRITE_NO_RESPONSE
```

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | Connected BLE device |
| `serviceUuid` | `string` | Yes | GATT service UUID |
| `characteristicUuid` | `string` | Yes | Characteristic UUID |
| `data` | `string` | Yes | Binary Lua string |

Example:

```lua
local packet =
    string.char(
        0x7F,
        0x5A,
        0x01,
        0x02
    )

ble.writeWithoutResponse(
    deviceId,
    serviceUuid,
    characteristicUuid,
    packet
)
```

---

# Write Events

## `characteristicWritten`

Generated after a characteristic write succeeds.

Example:

```lua
if event.name == "characteristicWritten" then

    print("WRITE OK")

end
```

---

## `writeError`

Generated when a write fails.

Example:

```lua
if event.name == "writeError" then

    print(
        "WRITE ERROR:",
        event.error
    )

end
```

---

# Notifications

## `ble.subscribe(deviceId, serviceUuid, characteristicUuid)`

Enables notifications or indications for a characteristic.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | Connected BLE device |
| `serviceUuid` | `string` | Yes | GATT service UUID |
| `characteristicUuid` | `string` | Yes | Notification characteristic UUID |

Example:

```lua
ble.subscribe(
    deviceId,
    serviceUuid,
    characteristicUuid
)
```

The plugin enables the appropriate GATT notification mechanism.

---

## `ble.unsubscribe(deviceId, serviceUuid, characteristicUuid)`

Disables notifications or indications.

### Arguments

| Argument | Type | Required | Description |
|---|---|---:|---|
| `deviceId` | `string` | Yes | Connected BLE device |
| `serviceUuid` | `string` | Yes | GATT service UUID |
| `characteristicUuid` | `string` | Yes | Notification characteristic UUID |

Example:

```lua
ble.unsubscribe(
    deviceId,
    serviceUuid,
    characteristicUuid
)
```

---

# Notification Events

## `notificationStateChanged`

Generated when the notification subscription state changes.

Example:

```lua
if event.name == "notificationStateChanged" then

    print(
        "Notification state changed"
    )

end
```

---

## `characteristicChanged`

Generated when a subscribed characteristic sends data.

Example:

```lua
if event.name == "characteristicChanged" then

    print(
        "NOTIFICATION:",
        toHex(event.data)
    )

end
```

Typical event:

```lua
{
    name = "characteristicChanged",

    deviceId = "15:6E:16:FD:32:A6",

    serviceUuid =
        "00001910-0000-1000-8000-00805f9b34fb",

    characteristicUuid =
        "0000fff4-0000-1000-8000-00805f9b34fb",

    data = "\170\1\16\32\48"
}
```

---

# Notification Error

## `notificationError`

Generated when subscribing, unsubscribing, or configuring notifications fails.

Example:

```lua
if event.name == "notificationError" then

    print(
        "NOTIFICATION ERROR:",
        event.error
    )

end
```

---

# Generic Error

## `error`

Generic plugin error.

Example:

```lua
if event.name == "error" then

    print(
        "BLE ERROR:",
        event.error
    )

end
```

---

# Complete Event List

The plugin currently exposes these event names:

| Event | Purpose |
|---|---|
| `deviceFound` | BLE device discovered |
| `connected` | Device connected |
| `disconnected` | Device disconnected |
| `connectionError` | Connection failed |
| `servicesDiscovered` | GATT services discovered |
| `serviceError` | Service discovery failed |
| `characteristicRead` | Characteristic read completed |
| `readError` | Characteristic read failed |
| `characteristicWritten` | Characteristic write completed |
| `writeError` | Characteristic write failed |
| `characteristicChanged` | Notification/indication received |
| `notificationStateChanged` | Notification state changed |
| `notificationError` | Notification operation failed |
| `scanError` | BLE scan failed |
| `error` | Generic BLE error |

---

# Complete Example

```lua
local ble = require("plugin.ble")

local function toHex(data)

    if not data then
        return ""
    end

    local result = {}

    for i = 1, #data do

        result[#result + 1] =
            string.format(
                "%02X",
                string.byte(data, i)
            )

    end

    return table.concat(
        result,
        " "
    )
end


local function onBleEvent(event)

    if not event then
        return
    end

    print(
        "[BLE]",
        event.name
    )


    if event.name == "deviceFound" then

        local device =
            event.device

        print(
            "Device:",
            device.name
        )

        print(
            "ID:",
            device.deviceId
        )

        print(
            "RSSI:",
            device.rssi
        )


    elseif event.name == "connected" then

        print(
            "Connected:",
            event.deviceId
        )

        ble.discoverServices(
            event.deviceId
        )


    elseif event.name == "servicesDiscovered" then

        for i = 1, #event.services do

            local service =
                event.services[i]

            print(
                "SERVICE:",
                service.uuid
            )

            for j = 1,
                #(service.characteristics or {}) do

                local characteristic =
                    service.characteristics[j]

                print(
                    "CHARACTERISTIC:",
                    characteristic.uuid
                )

                print(
                    "PROPERTIES:",
                    characteristic.properties
                )

            end

        end


    elseif event.name == "characteristicRead" then

        print(
            "READ:",
            toHex(event.data)
        )


    elseif event.name == "characteristicChanged" then

        print(
            "NOTIFICATION:",
            toHex(event.data)
        )


    elseif event.name == "characteristicWritten" then

        print(
            "WRITE OK"
        )


    elseif event.name == "disconnected" then

        print(
            "Disconnected:",
            event.deviceId
        )


    elseif event.name == "error" or
           event.name == "connectionError" or
           event.name == "serviceError" or
           event.name == "readError" or
           event.name == "writeError" or
           event.name == "notificationError" or
           event.name == "scanError" then

        print(
            "ERROR:",
            event.error
        )

    end
end


ble.init(
    onBleEvent
)


if not ble.isSupported() then

    print("BLE is not supported")
    return

end


if not ble.isEnabled() then

    print("Bluetooth is disabled")
    return

end


if not ble.hasPermission() then

    ble.requestPermission()
    return

end


ble.startScan()
```

---

# Recommended BLE Operation Sequence

For normal GATT communication, use this sequence:

```text
1. require("plugin.ble")
        ↓
2. ble.init(listener)
        ↓
3. Check isSupported()
        ↓
4. Check isEnabled()
        ↓
5. Check/request permission
        ↓
6. ble.startScan()
        ↓
7. deviceFound
        ↓
8. ble.stopScan()
        ↓
9. ble.connect(deviceId)
        ↓
10. connected
        ↓
11. ble.discoverServices(deviceId)
        ↓
12. servicesDiscovered
        ↓
13. Read / Write / Subscribe
        ↓
14. characteristicRead /
    characteristicWritten /
    characteristicChanged
        ↓
15. ble.disconnect(deviceId)
```

---

# Important Rules

## Always discover services first

Do not attempt to read or write using an arbitrary service/characteristic UUID before discovering the GATT database.

```lua
ble.connect(deviceId)
```

then:

```lua
ble.discoverServices(deviceId)
```

then use the UUIDs returned by:

```text
servicesDiscovered
```

---

## Binary data is not hexadecimal text

This:

```lua
string.char(
    0x01,
    0x02,
    0xA0,
    0xFF
)
```

is four bytes.

This:

```lua
"01 02 A0 FF"
```

is text and represents many more bytes.

Use binary Lua strings when communicating with BLE devices.

---

# TTLock Example

The generic plugin can be used for a TTLock device without knowing anything about the TTLock protocol.

Example UUIDs:

```lua
local SERVICE_UUID =
    "00001910-0000-1000-8000-00805f9b34fb"

local WRITE_UUID =
    "0000fff2-0000-1000-8000-00805f9b34fb"

local NOTIFY_UUID =
    "0000fff4-0000-1000-8000-00805f9b34fb"
```

After connecting:

```lua
ble.discoverServices(deviceId)
```

Then subscribe:

```lua
ble.subscribe(
    deviceId,
    SERVICE_UUID,
    NOTIFY_UUID
)
```

And write a binary protocol packet:

```lua
ble.writeWithoutResponse(
    deviceId,
    SERVICE_UUID,
    WRITE_UUID,
    packet
)
```

Incoming TTLock notifications arrive through:

```lua
event.name == "characteristicChanged"
```

with:

```lua
event.data
```

containing the raw binary packet.

---

# Architecture

The plugin is intentionally protocol-independent.

```text
Solar2D Lua
     │
     ▼
plugin.ble
     │
     ▼
LuaLoader.java
     │
     ▼
BleManager.java
     │
     ▼
Android BluetoothGatt
     │
     ▼
BLE Device
```

Application-specific protocols should be implemented above the generic BLE plugin.

For example:

```text
plugin.ble
     │
     ├── Generic BLE Explorer
     │
     ├── TTLock protocol
     │
     ├── Sensor protocol
     │
     └── Custom BLE device protocol
```