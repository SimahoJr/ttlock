
-- plugin/bel.lua
-- BLE mock plugin for Solar2D simulator testing.
-- Implements the API used by BTClient.

local M = {}

local listener
local connected = false
local subscribed = false
local initialized = false

local deviceId
local services = {}
local writes = {}
local responseHandler

local DEFAULT_DEVICE = "15:6E:16:FD:32:A6"

local SERVICE_UUID =
    "00001910-0000-1000-8000-00805f9b34fb"

local WRITE_UUID =
    "0000fff2-0000-1000-8000-00805f9b34fb"

local NOTIFY_UUID =
    "0000fff4-0000-1000-8000-00805f9b34fb"

local function emit(event)
    if listener then
        event = event or {}
        pcall(listener, event)
    end
end

local function delay(ms, callback)
    if timer and timer.performWithDelay then
        timer.performWithDelay(ms, callback)
    else
        callback()
    end
end

local function normalizeUUID(uuid)
    if type(uuid) ~= "string" then
        return ""
    end
    return string.lower(uuid)
end

function M.init(callback)
    listener = callback
    initialized = true
    connected = false
    subscribed = false
    writes = {}

    print("[BLE MOCK] Initialized")
end

function M.connect(id)
    deviceId = id or DEFAULT_DEVICE

    if not initialized then
        print("[BLE MOCK] Warning: init() was not called")
    end

    print("[BLE MOCK] Connecting to " .. tostring(deviceId))

    delay(250, function()
        connected = true

        emit({
            name = "connected",
            device = deviceId,
            address = deviceId,
        })
    end)
end

function M.disconnect(id)
    print("[BLE MOCK] Disconnecting " .. tostring(id or deviceId))

    delay(50, function()
        local wasConnected = connected

        connected = false
        subscribed = false

        if wasConnected then
            emit({
                name = "disconnected",
                device = deviceId,
            })
        end
    end)
end

function M.discoverServices(id)
    if not connected then
        emit({
            name = "serviceError",
            error = "Mock device is not connected",
        })
        return
    end

    print("[BLE MOCK] Discovering services")

    delay(200, function()
        services = {
            SERVICE_UUID,
        }

        emit({
            name = "servicesDiscovered",
            device = deviceId,
            services = services,
        })
    end)
end

function M.subscribe(id, serviceUUID, characteristicUUID)
    if not connected then
        emit({
            name = "serviceError",
            error = "Cannot subscribe: not connected",
        })
        return
    end

    if normalizeUUID(serviceUUID) ~= normalizeUUID(SERVICE_UUID) then
        emit({
            name = "serviceError",
            error = "Unknown mock service UUID",
        })
        return
    end

    if normalizeUUID(characteristicUUID) ~= normalizeUUID(NOTIFY_UUID) then
        emit({
            name = "serviceError",
            error = "Unknown mock notification characteristic UUID",
        })
        return
    end

    subscribed = true

    print("[BLE MOCK] Subscribed to notifications")
end

local function emitNotification(data, delayMs)
    if type(data) ~= "string" then
        error("Notification data must be a string")
    end

    delay(delayMs or 0, function()
        if connected and subscribed then
            emit({
                name = "characteristicChanged",
                device = deviceId,
                service = SERVICE_UUID,
                characteristic = NOTIFY_UUID,
                data = data,
            })
        end
    end)
end

function M.write(id, serviceUUID, characteristicUUID, data)
    if not connected then
        print("[BLE MOCK] Write rejected: not connected")
        return false
    end

    if normalizeUUID(serviceUUID) ~= normalizeUUID(SERVICE_UUID) then
        print("[BLE MOCK] Write rejected: invalid service UUID")
        return false
    end

    if normalizeUUID(characteristicUUID) ~= normalizeUUID(WRITE_UUID) then
        print("[BLE MOCK] Write rejected: invalid write UUID")
        return false
    end

    if type(data) ~= "string" then
        print("[BLE MOCK] Write rejected: data must be a string")
        return false
    end

    writes[#writes + 1] = {
        device = id or deviceId,
        service = serviceUUID,
        characteristic = characteristicUUID,
        data = data,
        time = os.time(),
    }

    print(string.format(
        "[BLE MOCK] Write #%d: %d bytes",
        #writes,
        #data
    ))

    if responseHandler then
        local ok, response = pcall(responseHandler, data, #writes)

        if not ok then
            print("[BLE MOCK] Response handler error: " ..
                tostring(response))
        elseif type(response) == "string" then
            emitNotification(response, 100)
        elseif type(response) == "table" then
            for _, item in ipairs(response) do
                if type(item) == "string" then
                    emitNotification(item, 100)
                end
            end
        end
    end

    return true
end

function M.writeWithoutResponse(id, serviceUUID, characteristicUUID, data)
    return M.write(id, serviceUUID, characteristicUUID, data)
end

-- Test utilities ------------------------------------------------------------

function M.setResponseHandler(callback)
    assert(callback == nil or type(callback) == "function",
        "response handler must be a function or nil")

    responseHandler = callback
end

function M.emitNotification(data, delayMs)
    emitNotification(data, delayMs)
end

function M.getWrites()
    local result = {}

    for i, write in ipairs(writes) do
        result[i] = write
    end

    return result
end

function M.clearWrites()
    writes = {}
end

function M.isConnected()
    return connected
end

function M.isSubscribed()
    return subscribed
end

function M.reset()
    connected = false
    subscribed = false
    initialized = false
    listener = nil
    deviceId = nil
    services = {}
    writes = {}
    responseHandler = nil

    print("[BLE MOCK] Reset")
end

-- Export mock metadata for test assertions.
M.DEFAULT_DEVICE = DEFAULT_DEVICE
M.SERVICE_UUID = SERVICE_UUID
M.WRITE_UUID = WRITE_UUID
M.NOTIFY_UUID = NOTIFY_UUID

return M
