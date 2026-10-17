# TTLock BLE Plugin for Solar2D

Lua API for integrating TTLock Bluetooth Low Energy (BLE) locks into Solar2D applications.

## Installation

1. Extract `it.shannonit.zip` into your Solar2D plugins directory:
   ` %APPDATA%\Solar2DPlugins`

2. Extract `plugin.zip` into the Solar2D Simulator plugins directory to enable simulator support.

3. Restart Solar2D.

## Configuration

Add the required plugins and Android permissions to your project's `build.settings`:

```lua
settings = {
    plugins = {
        ["plugin.ble"] = {
            publisherId = "it.shannonit",
        },
        ["plugin.ttlock"] = {
            publisherId = "it.shannonit",
        },
        ["plugin.bit"] = {
            publisherId = "com.coronalabs",
        },
    },

    android = {
        usesPermissions = {
            "android.permission.BLUETOOTH",
            "android.permission.BLUETOOTH_ADMIN",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.BLUETOOTH_SCAN",
            "android.permission.BLUETOOTH_CONNECT",
        },
        minSdkVersion = 23,
    },
}
```

## Examples

- **Manager:** `example/manager`
- **Client:** `example/client`

Run these projects to explore the API and its usage.

## Source Code

- **BLE plugin:** `ble.plugin.src`
- **TTLock plugin:** `ttlock.plugin.src`

See each source directory for its documentation.

## Testing

Simulator support is limited to development and simulated behavior. Test actual BLE communication with a compatible physical device.

For simulator errors, add the necessary exceptions or implement stubs for unsupported functionality.