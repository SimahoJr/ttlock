--------------------------------------------------
-- MAIN.LUA
--------------------------------------------------

local json = require("json")
local url = require("socket.url")
local Helpers = require("plugin.protocol.helpers")
local Session = require("session")

-- Check if credentials exist on startup
if Session.username ~= "" and Session.password ~= "" then
    print("[App] User is already logged in as: " .. Session.username)
end

-- Example during login:
-- Session.username = "admin"
-- Session.password = "admin"
-- Session:save()

-- Example during logout:
-- Session:clear()
-- Show the system status bar
display.setStatusBar( display.DefaultStatusBar )
local BRIDGE_DELAY = 2

--------------------------------------------------
-- BLE / LOCK
--------------------------------------------------

local ble
local lock

if system.getInfo("environment") == "simulator" then
    ble = require("plugin.ble_mock")
else
    ble = require("plugin.ble")
    local bt_bridge = require("plugin.ttlock")
    lock = bt_bridge.new()
end

ble.init(function(event)
    print("[BLE]", event.name)
end)

if ble.hasPermission and not ble.hasPermission() then
    print("[BLE] Requesting permission")
    if ble.requestPermission then ble.requestPermission() end
end

--------------------------------------------------
-- WEBVIEW
--------------------------------------------------

local webView = native.newWebView(
    display.contentCenterX,
    display.contentCenterY,
    display.actualContentWidth,
    display.actualContentHeight
)

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function decode(value)
    if not value then return "" end
    return value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
end

local function sendToWeb(typeName, data)
    data = data or {}
    data.type = typeName

    local ok, encoded = pcall(json.encode, data)

    if not ok then
        print("[LUA->JS] JSON ERROR:", tostring(encoded))
        return false
    end

    print("[LUA->JS] Event:", typeName)
    print("[LUA->JS] Payload:", encoded)

    local targetUrl

    if system.getInfo("platformName") ~= "Android" then
        local path = system.pathForFile("webpage/index.html", system.ResourceDirectory)
        path = path:gsub("\\", "/")
        targetUrl = "file://" .. path .. "?bridge=" .. url.escape(encoded)
    else
        targetUrl = "webpage/index.html?bridge=" .. url.escape(encoded)
    end

    print("[LUA->JS] URL:", targetUrl)

    webView:request(targetUrl, system.ResourceDirectory)

    return true
end

--------------------------------------------------
-- WEBVIEW BRIDGE
--------------------------------------------------

local loginBusy = false
local secretsBusy = false
local saveSecretsBusy = false
local saveSecretsQR_Busy = false
local unlockBusy = false


webView:addEventListener("urlRequest", function(event)
    local rawUrl = event.url

    print("[WEBVIEW] URL REQUEST:", rawUrl)
    -- Check if this is the initial index.html load without a bridge command
    if rawUrl:match("index.html$") or (not rawUrl:find("bridge=")) then
        print("[LUA] Initial page load detected without payload.")
        
        if Session.username == "admin" and Session.password == "admin" then
            print("[LUA] Valid admin session found. Skipping to unlock screen.")
            timer.performWithDelay(100, function()
                sendToWeb("save_secrets_save_success", {
                message = "Secrets saved successfully"
            })
            end)
        end
        return true
    end

    local rawCommand, encodedPayload = rawUrl:match("[?&]bridge=([^&]+)&payload=(.*)$")

    if not rawCommand then return false end

    local command = decode(rawCommand)
    local payloadJson = decode(encodedPayload)
    local payload = {}

    if payloadJson ~= "" and payloadJson ~= "empty" then
        local ok, decodedPayload = pcall(json.decode, payloadJson)

        if not ok then
            print("[LUA] Invalid JSON payload:", payloadJson)
            return true
        end

        payload = decodedPayload or {}
    end

    print("[LUA] COMMAND:", command)
    print("[LUA] PAYLOAD:", payloadJson)

    --------------------------------------------------
    -- LOGIN
    --------------------------------------------------

    if command == "login" then
        if loginBusy then return true end

        loginBusy = true

        timer.performWithDelay(BRIDGE_DELAY, function()
            print("[LUA] Login success")
            
            Session.save()
            sendToWeb("auth_success", {
                passwordExpiry = "29d 23h 45m"
            })

            loginBusy = false
        end)

    --------------------------------------------------
    -- GET SECRETS
    --------------------------------------------------

    elseif command == "get_secrets" then
        if secretsBusy then return true end

        secretsBusy = true

        if lock then
            local ok, err = pcall(function() lock:load() end)
            if not ok then print("[LOCK] load() error:", err) end
        end

        timer.performWithDelay(BRIDGE_DELAY, function()
            local lockId = 1048576
            local lockMac = "15:6E:16:FD:32:A6"
            local key = "bcbf5375606fc0007a0428368b260a20"
            local adminPassword = 123456
            local unlockKey = 123456
            local lockVersion = 3
            local battery = 100
            local aptName = "Carrubi"
            local stanzaName = "St.1"

            if lock then
                if lock.ps ~= nil then lockId = lock.ps end
                if lock.client and lock.client.deviceId then lockMac = lock.client.deviceId end
                if lock.aes_key then key = Helpers.toHex(lock.aes_key) end
                if lock.admin_ps ~= nil then adminPassword = lock.admin_ps end
                if lock.unlock_key ~= nil then unlockKey = lock.unlock_key end
                if lock.protocol_version ~= nil then lockVersion = lock.protocol_version end
                if lock.battery ~= nil then battery = lock.battery end
                if lock.apt_name then aptName = lock.apt_name end
                if lock.stanza_name then stanzaName = lock.stanza_name end
            end

            print("[LOCK] lockId:", lockId)
            print("[LOCK] lockMac:", lockMac)
            print("[LOCK] protocol:", lockVersion)

            sendToWeb("secrets_result", {
                lockId = lockId,
                lockMac = lockMac,
                key = key,
                adminPassword = adminPassword,
                unlockKey = unlockKey,
                lockVersion = lockVersion,
                battery = battery,
                aptName = aptName,
                stanzaName = stanzaName,
                passwordExpiry = "9d 23h 45m"
            })

            secretsBusy = false
        end)

    --------------------------------------------------
    -- SAVE SECRETS
    --------------------------------------------------

    elseif command == "save_secrets" then
        if saveSecretsBusy then return true end

        saveSecretsBusy = true

        if lock and payload then
            local ok, err = pcall(function()
                lock:load()
                lock.client.deviceId = payload.lockMac or ""
                lock.aes_key = Helpers.fromHex(payload.key or "")
                lock.admin_ps = payload.adminPassword or 123456
                lock.unlock_key = payload.unlockKey or 123456
                lock.protocol_version = payload.lockVersion or 3
                lock.apt_name = payload.aptName or "Carrubi"
                lock.stanza_name = payload.stanzaName or "St.1"
                lock:save()
            end)

            if not ok then
                print("[LOCK] save() error:", err)
                saveSecretsBusy = false

                sendToWeb("save_secrets_error", {
                    message = "Failed to save lock configuration."
                })

                return true
            end
        end

        timer.performWithDelay(BRIDGE_DELAY, function()
            print("[LUA] Secrets saved successfully")

            sendToWeb("save_secrets_save_success", {
                message = "Secrets saved successfully"
            })

            saveSecretsBusy = false
        end)

    --------------------------------------------------
    -- UNLOCK
    --------------------------------------------------

    elseif command == "unlock" then
        if unlockBusy then return true end

        unlockBusy = true

        print("[LUA] =================================")
        print("[LUA] UNLOCK COMMAND RECEIVED")
        print("[LUA] =================================")

        if system.getInfo("environment") == "simulator" then
            print("[LUA] Simulator mode - fake unlock")

            timer.performWithDelay(BRIDGE_DELAY, function()
                sendToWeb("unlock_result", {
                    action = "unlock",
                    processing = true,
                    success = false,
                    unlockDuration = 0,
                    userPassword = "1232",
                    battery = 0,
                    message = "PROCESSING"
                })

                unlockBusy = false
            end)

            return true
        end

        if not lock then
            print("[LUA] ERROR: Lock object is nil")

            sendToWeb("unlock_result", {
                action = "unlock",
                success = false,
                unlockDuration = 0,
                battery = 0,
                message = "LOCK NOT INITIALIZED"
            })

            unlockBusy = false
            return true
        end

        sendToWeb("unlock_result", {
            action = "unlock",
            processing = true,
            success = false,
            message = "PROCESSING"
        })

        print("[LUA] Requesting auto-lock time...")

        -- Helper function to execute unlock once configurations are ready
        local function executeUnlock()
            lock:unlock(function(unlockResult)
                print("[LUA] Unlock response:", unlockResult and json.encode(unlockResult) or "nil")

                local success = unlockResult ~= nil and unlockResult.status == 1
                local duration = tonumber(lock.auto_lock_time) or 0

                print("[LUA] Unlock success:", tostring(success))
                print("[LUA] Unlock duration:", tostring(duration))

                sendToWeb("unlock_result", {
                    action = "unlock",
                    success = success,
                    unlockDuration = duration,
                    battery = lock.battery or 100,
                    passwordExpiry = lock.password_expiry or "",
                    aptName = lock.apt_name or "Carrubi",
                    stanzaName = lock.stanza_name or "St.1",
                    userPassword = lock.user_password or "",
                    message = success and "ACCESS ACTIVE" or "UNLOCK FAILED"
                })

                unlockBusy = false
                pcall(function() lock:save() end)
            end)
        end

        -- Step 1: Get auto lock time first
        lock:get_autolock_time(function(autoLockResult)
            lock.auto_lock_time = tonumber(string.match(tostring(autoLockResult or ""), "%d+")) or 0
            print("[LUA] Auto-lock response:", autoLockResult and json.encode(autoLockResult) or "nil")

            -- Step 2: Check passcode
            if not lock.user_password or lock.user_password == "" then
                local passcode = ""
                for i = 1, 4 do
                    passcode = passcode .. math.random(1, 7)
                end
                
                lock:add_passcode(1, passcode, "202001010000", "000000000000", function(result)
                    print("[LUA] Passcode response:", result and json.encode(result) or "nil")
                    lock.user_password = passcode
                    lock:save()
                    executeUnlock()
                end)
            else
                executeUnlock()
            end
        end)
    --------------------------------------------------
    -- LOGOUT
    --------------------------------------------------

    elseif command == "logout" then
        print("[LUA] Logout")
        -- Example during logout:
        Session:clear()
        sendToWeb("logout_success", {})

    --------------------------------------------------
    -- QRCODE
    --------------------------------------------------

    elseif command == "qrcode" then
        print("[LUA] qrcode command received")
        if saveSecretsQR_Busy then return true end

        saveSecretsQR_Busy = true

        -- payload comes as a JSON string from the webview bridge, so decode it first
        -- local decodedPayload = json.decode(payload or "{}")
        -- The QR code string is stored inside decodedPayload.code as a JSON string
        local innerCodeStr = payload.code or "{}"
        local lockData = json.decode(innerCodeStr)
        
        if lock and lockData then
            local ok, err = pcall(function()
                lock:load()
                lock.client.deviceId = lockData.lockMac or ""
                lock.aes_key = Helpers.fromHex(lockData.key or "")
                lock.password_expiry = lockData.passwordExpiry or ""
                
                -- Force conversion to numbers to prevent string type mismatches
                lock.admin_ps = tonumber(lockData.adminPassword) or 123456
                lock.unlock_key = tonumber(lockData.unlockKey) or 123456
                lock.lock_id = tonumber(lockData.lockId) or 0
                
                lock.apt_name = lockData.aptName or "Carrubi"
                lock.stanza_name = lockData.stanzaName or "St.1"
                lock:save()
                
                Session.username = "admin"
                Session.password = "admin"
                Session:save()
            end)

            if not ok then
                print("[LOCK] save() error:", err)
                saveSecretsQR_Busy = false

                sendToWeb("save_secrets_error", {
                    message = "Failed to save lock configuration."
                })

                return true
            end
        end

        timer.performWithDelay(BRIDGE_DELAY, function()
            print("[LUA] Secrets saved successfully via QR Code")

            sendToWeb("save_secrets_save_success", {
                message = "Secrets saved successfully"
            })

            saveSecretsQR_Busy = false
        end)

    --------------------------------------------------
    -- UNKNOWN COMMAND
    --------------------------------------------------

    else
        print("[LUA] Unknown command:", command)
    end

    return true
end)

--------------------------------------------------
-- START
--------------------------------------------------

webView:request("webpage/index.html", system.ResourceDirectory)

