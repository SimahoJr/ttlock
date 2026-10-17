# TTLock Plugin — Current Status
This project is based on the excellent work done by [kind3r/ttlock-sdk-js](https://github.com/kind3r/ttlock-sdk-js). Most of the implementation was developed with reference to this project.

## Build and Package — Local Hosting
The following PowerShell command creates `data.tgz` and copies it to the Solar2D plugin's local app data folder.
```powershell
$dest = "$env:APPDATA\Solar2DPlugins\it.shannonit\plugin.ttlock\lua"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
tar.exe -czf "$env:TEMP\data.tgz" -C "D:\lua" plugin
Copy-Item "$env:TEMP\data.tgz" "$dest\data.tgz" -Force
```
- **Source directory:** `D:\lua`
- **Included folder:** `plugin`
- **Test file:** `main.lua`

## How to Use the Plugin
Add the following configuration to your project's `build.settings` file:
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
## Modules Included
1. **`lockbox`** — Provides data encryption and decryption utilities.
2. **`protocol`** — Contains the high-level TTLock protocol implementation.
3. **`qrcode`** — Provides functionality for generating and reading QR codes.
4. **`BTClient.lua`** — Bridges Bluetooth Low Energy (BLE) communication with TTLock and contains low-level TTLock protocol instructions.
5. **`ble_mock.lua`** — Provides mock implementations and stubs for testing in the Solar2D simulator.
6. **`ttlock.lua`** — Implements the TTLock API.

## Current Function Status

### Initialization & Configuration
1. `new`
2. `load`
3. `save`
4. `clear`

### Connection & Authentication
1. `connect`
2. `disconnect`
3. `withAuth`
4. `withAuthOld`
5. `pair`

### Lock Operations
1. `unlock`
2. `lock`
3. `reset`
4. `get_locked_status`

### Device Information & Time
1. `calibrate_time`
2. `get_device_features`
3. `get_device_info`

### Admin Code — Not Working / Needs Testing
1. `get_admin_code`
2. `set_admin_code`

### Auto-Lock & Sound
1. `get_autolock_time`
2. `set_autolock_time`
3. `get_lock_sound`
4. `set_lock_sound`

### Passage Mode — Needs Testing
1. `get_passage_mode`
2. `add_passage_mode`
3. `delete_passage_mode`
4. `clear_passage_mode`

### Passcodes
1. `get_passcodes`
2. `add_passcode`
3. `update_passcode`
4. `delete_passcode`
5. `clear_passcodes` — Known bug

### IC Cards
1. `get_ic_cards`
2. `add_ic_card`
3. `update_ic_card`
4. `delete_ic_card`
5. `clear_ic_cards`

### Operation Logs — Needs Testing
1. `get_operation_log`

## Next Steps
1. Test the functions marked as needing testing.
2. Investigate and fix the `clear_passcodes` bug.
3. Review the TTLock documentation to identify additional functions to implement.
4. Use `main.lua` to test the plugin in the Solar2D simulator and on a compatible physical device.
5. Host the plugin package on a server so it can be distributed and accessed remotely.