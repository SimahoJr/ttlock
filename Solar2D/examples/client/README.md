# TTLock WebView Client

This is a client-facing Solar2D WebView UI built around the TTLock Lua layer.

## Files

- `main.lua` — native/WebView bridge and TTLock operations
- `www/index.html` — application structure
- `www/style.css` — visual design 
- `www/app.js` — authentication, lock switch, RSSI/distance UI

## Expected backend endpoints

### POST /api/auth/register

Request:

```json
{
  "username": "alice",
  "password": "secret"
}
```

### POST /api/auth/login

Request:

```json
{
  "username": "alice",
  "password": "secret"
}
```

Suggested response:

```json
{
  "token": "SESSION_OR_JWT",
  "user": {
    "id": 123,
    "username": "alice"
  },
  "lockData": {
    "lockId": "TTLOCK_ID",
    "lockName": "Front Door",
    "expiresAt": "2026-10-04T18:30:00Z"
  }
}
```

The returned `lockData` is deliberately kept as an opaque object on the client. You can extend it later with the TTLock identifiers/keys needed by your native `BTBridge`.

## RSSI / distance

Your backend can provide a calibrated RSSI-to-distance model. The WebView accepts:

```json
{
  "type": "rssi",
  "rssi": -58,
  "distanceMeters": 1.7
}
```

The UI maps proximity continuously:

- close -> green
- medium -> yellow
- far -> red

For development, `app.js` has a simple RSSI fallback. For production, use your calibrated distance result.

## Important integration point

The exact RSSI event exposed by your BLE/TTLock implementation is not present in the supplied `main.lua`, so `updateRSSI(rssi)` is intentionally an integration point.

The existing TTLock calls are preserved:

- `lock:unlock(...)`
- `lock:lock(...)`
- `lock:pair(...)`
- `lock:load()`

The client UI only exposes lock/unlock to the authenticated user. The broader diagnostic/admin operations from your original test interface are intentionally not exposed here.

## Solar2D note

The WebView-to-Lua bridge uses a custom `ttlock://` URL scheme. Lua intercepts the navigation and handles the command. This avoids exposing arbitrary native Lua functions directly to JavaScript.

Replace:

```lua
local API_BASE = "https://YOUR-BACKEND.example.com/api"
```

with your backend URL.

For production, the backend should authorize every lock operation. Do not rely on the WebView's hidden UI or a client-provided token alone to establish authorization.
