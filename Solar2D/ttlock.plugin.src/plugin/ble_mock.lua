--------------------------------------------------
-- BLE MOCK (With Windows-Compatible UI & Scrollable Console)
-- Solar2D Simulator / Windows Desktop ready
--------------------------------------------------
require("lockbox.lockbox").insecure()

-- local Constants = require("protocol.constants")
local Protocol = require("protocol.protocol")
local Crypto = require("plugin.protocol.crypto")

-- Helper to convert byte string to readable hex
local function toHex(str)
    return (str:gsub(".", function(c)
        return string.format("%02X ", c:byte())
    end))
end

print("--- STARTING PACKET BUILD & ENCRYPTION TEST ---")

local proto = Protocol.new({
    group = 1,
    org = 1,
    protocol_type = 5,
    version = 3,
    scene = 1
})

local DEFAULT_AES_KEY = "1234567890123456"
local testPayload = "SCIENER"

print("Original Payload:", testPayload)
print("Using AES Key:", DEFAULT_AES_KEY)

local success, resultPacket = pcall(function()
    return proto:build_packet(0x19, testPayload, DEFAULT_AES_KEY)
end)

if success then
    print("✅ Packet build SUCCESS!")
    print("Generated Packet Length:", #resultPacket)
    print("Generated Packet HEX:  ", toHex(resultPacket))
    
    local lenByte = resultPacket:byte(12)
    print("Calculated Payload Length Byte:", string.format("0x%02X (%d)", lenByte, lenByte))
    
    if lenByte == 16 then
        print("🎉 SUCCESS: Payload was successfully encrypted into 16 bytes!")
    else
        print("❌ ERROR: Payload length byte is " .. lenByte .. " (Expected 16 / 0x10).")
    end
else
    print("❌ Packet build FAILED: " .. tostring(resultPacket))
end

print("--- TEST END ---")

local rawFrameHex = "7F 5A 05 03 09 00 01 00 01 54 AA 10 76 04 9F 30 C3 91 C2 19 F0 AD 69 3C 16 16 66 4F ED 0D 0A"

local function hexToBytes(hex)
    return (hex:gsub("%s+", ""):gsub("..", function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

local rawBytes = hexToBytes(rawFrameHex)
local encryptedPayload = rawBytes:sub(12, #rawBytes - 2)

local testKey = "1234567890123456"
local decSuccess, decrypted = pcall(function()
    return Crypto.aes_decrypt(encryptedPayload, testKey)
end)

if decSuccess then
    print("✅ Decryption SUCCESS!")
else
    print("❌ Decryption FAILED: " .. tostring(decrypted))
end

-- Compatibility Shims
if not string.pack then
    string.pack = function(fmt, val)
        if type(val) == "number" then
            local b4 = val % 256
            local b3 = math.floor(val / 256) % 256
            local b2 = math.floor(val / 65536) % 256
            local b1 = math.floor(val / 16777216) % 256
            return string.char(b1, b2, b3, b4)
        end
        return tostring(val)
    end
end

if not _G.bit then
    _G.bit = {
        bxor = function(a, b)
            local p, c = 1, 0
            while a > 0 and b > 0 do
                local ra, rb = a % 2, b % 2
                if ra ~= rb then c = c + p end
                a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
            end
            if a < b then a = b end
            while a > 0 do
                local ra = a % 2
                if ra > 0 then c = c + p end
                a, p = math.floor(a / 2), p * 2
            end
            return c
        end,
        band = function(a, b)
            local p, c = 1, 0
            while a > 0 and b > 0 do
                if (a % 2 == 1) and (b % 2 == 1) then c = c + p end
                a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
            end
            return c
        end,
        bor = function(a, b)
            local p, c = 1, 0
            while a > 0 or b > 0 do
                if (a % 2 == 1) or (b % 2 == 1) then c = c + p end
                a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
            end
            return c
        end
    }
end

if not _G.Constants then
    _G.Constants = { CRC_TABLE = {} }
    for i = 1, 256 do
        _G.Constants.CRC_TABLE[i] = (i - 1) % 256
    end
end

--------------------------------------------------
-- SCROLLABLE IN-APP UI CONSOLE (Windows Compatible)
--------------------------------------------------
local allLogs = {}
local logGroup, logText, scrollMask, logBg
local maxHistory = 100
local isDragging = false
local startY = 0
local startTextY = 0
local coms = require("plugin.protocol.command_builder")
local CommandBuilder = require("plugin.protocol.command_builder")
local x = coms.build_add_passcode(2, "222")
local helpers = require("plugin.protocol.helpers")
print("hey")
print(helpers.toHex(x))
local admin = 12345
local unlock = 12345
x = CommandBuilder.cmd_add_admin(admin, unlock)
print("hey2")
print(helpers.toHex(x))
local function updateTextDisplay()
    if not logText then return end
    logText.text = table.concat(allLogs, "\n")
    
    if not isDragging then
        local minPosY = scrollMask.height - logText.height - 10
        if minPosY > 0 then minPosY = 0 end
        logText.y = scrollMask.y + minPosY
    end
end

local function handleScrollInput(action, currentY)
    if action == "down" then
        isDragging = true
        startY = currentY
        startTextY = logText.y
    elseif action == "move" and isDragging then
        local dy = currentY - startY
        local targetY = startTextY + dy
        
        local minPosY = scrollMask.height - logText.height - 10
        if minPosY > 0 then minPosY = 0 end
        local maxPosY = scrollMask.y
        
        if targetY > maxPosY then targetY = maxPosY end
        if targetY < maxPosY + minPosY then targetY = maxPosY + minPosY end
        
        logText.y = targetY
    elseif action == "up" then
        isDragging = false
    end
end

local function onTouchLog(event)
    if event.phase == "began" then
        handleScrollInput("down", event.y)
        return true
    elseif event.phase == "moved" then
        handleScrollInput("move", event.y)
        return true
    elseif event.phase == "ended" or event.phase == "cancelled" then
        handleScrollInput("up", event.y)
        return true
    end
    return false
end

local function initUI()
    if logGroup then return end
    
    pcall(function()
        logGroup = display.newGroup()
        
        local screenW = display.contentWidth
        local screenH = display.contentHeight
        local boxW, boxH = screenW - 40, 140
        local boxX = screenW / 2
        local boxY = screenH - 90
        
        logBg = display.newRect(logGroup, boxX, boxY, boxW, boxH)
        logBg:setFillColor(0, 0, 0, 0.92)
        -- logBg.strokeWidth = 2
        -- logBg:setStrokeColor(0.2, 0.8, 0.2)
        
        scrollMask = display.newContainer(logGroup, boxW - 10, boxH - 10)
        scrollMask.x = boxX
        scrollMask.y = boxY
        
        logText = display.newText({
            text = "[BLE_MOCK] Initialized for Windows...",
            x = 0, y = 0,
            width = boxW - 20,
            font = native.systemFont,
            fontSize = 11,
            align = "left"
        })
        logText:setFillColor(0.2, 1, 0.2)
        scrollMask:insert(logText)
        
        logText.anchorX = 0
        logText.anchorY = 0
        logText.x = -scrollMask.width / 2 + 5
        logText.y = -scrollMask.height / 2 + 5
        
        logBg:addEventListener("touch", onTouchLog)
        
        -- Fallback mouse scroll support for Windows Simulator testing
        logBg:addEventListener("mouse", function(event)
            if event.isWheel then
                local scrollAmount = event.wheelDelta * 15
                startTextY = logText.y
                isDragging = true
                handleScrollInput("move", startY + (scrollAmount * -1))
                isDragging = false
                return true
            end
        end)
    end)
end

local function logMessage(msg)
    print(msg)
    if not logGroup then initUI() end
    table.insert(allLogs, msg)
    if #allLogs > maxHistory then table.remove(allLogs, 1) end
    updateTextDisplay()
end

logMessage("[BLE_MOCK] Windows-ready module loaded.")

--------------------------------------------------
-- BLE MOCK IMPLEMENTATION
--------------------------------------------------
local ble = {}
local listener = nil
local connectedDeviceId = nil
local subscribedCharacteristics = {}

local fakeDevices = {
    { id = "15:6E:16:FD:32:A6", deviceName = "TTLock Smart Lock", rssi = -42 }
}

local fakeServices = {
    {
        uuid = "00001910-0000-1000-8000-00805f9b34fb",
        type = "PRIMARY",
        characteristicCount = 2,
        characteristics = {
            { uuid = "0000fff2-0000-1000-8000-00805f9b34fb", properties = "WRITE", canWrite = true, canWriteWithoutResponse = true, canNotify = false },
            { uuid = "0000fff4-0000-1000-8000-00805f9b34fb", properties = "READ, NOTIFY", canRead = true, canNotify = true }
        }
    }
}

local function dispatch(event)
    if not listener then return end
    logMessage("[Event] -> " + tostring(event.name))
    if type(listener) == "function" then listener(event) end
end

local function findCharacteristic(serviceUuid, characteristicUuid)
    for _, service in ipairs(fakeServices) do
        if service.uuid:upper() == serviceUuid:upper() then
            for _, characteristic in ipairs(service.characteristics) do
                if characteristic.uuid:upper() == characteristicUuid:upper() then
                    return characteristic
                end
            end
        end
    end
    return nil
end

local function copyServices()
    local result = {}
    for _, service in ipairs(fakeServices) do
        local serviceCopy = { uuid = service.uuid, type = service.type, characteristicCount = service.characteristicCount, characteristics = {} }
        for _, characteristic in ipairs(service.characteristics) do
            serviceCopy.characteristics[#serviceCopy.characteristics + 1] = {
                uuid = characteristic.uuid, properties = characteristic.properties,
                canRead = characteristic.canRead, canWrite = characteristic.canWrite,
                canWriteWithoutResponse = characteristic.canWriteWithoutResponse, canNotify = characteristic.canNotify
            }
        end
        result[#result + 1] = serviceCopy
    end
    return result
end

function ble.init(callback)
    logMessage("[BLE] ble.init() called")
    initUI()
    listener = callback
    return true
end

function ble.isSupported() return true end
function ble.isEnabled() return true end
function ble.hasPermission() return true end

function ble.requestPermission()
    dispatch({ name = "permissionGranted" })
    return true
end

function ble.startScan()
    dispatch({ name = "scanStarted" })
    for index, device in ipairs(fakeDevices) do
        timer.performWithDelay(index * 350, function()
            dispatch({ name = "deviceFound", id = device.id, deviceName = device.deviceName, rssi = device.rssi })
        end)
    end
    timer.performWithDelay((#fakeDevices + 1) * 350, function()
        dispatch({ name = "scanStopped" })
    end)
    return true
end

function ble.stopScan()
    dispatch({ name = "scanStopped" })
    return true
end

function ble.connect(deviceId)
    connectedDeviceId = deviceId
    dispatch({ name = "connecting", id = deviceId })
    timer.performWithDelay(500, function()
        dispatch({ name = "connected", id = deviceId, deviceName = "Mock TTLock" })
    end)
    return true
end

function ble.disconnect(deviceId)
    deviceId = deviceId or connectedDeviceId
    timer.performWithDelay(200, function()
        dispatch({ name = "disconnected", id = deviceId })
        connectedDeviceId = nil
    end)
    return true
end

function ble.discoverServices(deviceId)
    timer.performWithDelay(400, function()
        dispatch({ name = "servicesDiscovered", id = deviceId, deviceId = deviceId, services = copyServices(), count = #fakeServices })
    end)
    return true
end

local function simulateLockResponse(deviceId, incomingData)
    local notifyServiceUuid = "00001910-0000-1000-8000-00805f9b34fb"
    local notifyCharUuid = "0000fff4-0000-1000-8000-00805f9b34fb"

    if not subscribedCharacteristics[notifyCharUuid] then return end

    local cmdByte = incomingData:byte(10) or 0x55
    local header = "\x7F\x5A\x05\x03\x01\x00\x01\x00\x01"
    local responseCmd = string.char(cmdByte)
    local appCmd = "\xAA"
    
    local payload = "\x01" .. string.rep("\xAB", 16)
    local lengthByte = string.char(#payload)
    local fakeResponseFrame = header .. responseCmd .. appCmd .. lengthByte .. payload .. "\x00\r\n"

    dispatch({
        name = "characteristicChanged",
        id = deviceId, deviceId = deviceId,
        serviceUuid = notifyServiceUuid,
        characteristicUuid = notifyCharUuid,
        data = fakeResponseFrame
    })
end

function ble.write(deviceId, serviceUuid, characteristicUuid, data)
    timer.performWithDelay(250, function()
        dispatch({ name = "characteristicWritten", id = deviceId, serviceUuid = serviceUuid, characteristicUuid = characteristicUuid, data = data })
        simulateLockResponse(deviceId, data)
    end)
    return true
end

function ble.writeWithoutResponse(deviceId, serviceUuid, characteristicUuid, data)
    timer.performWithDelay(150, function()
        dispatch({ name = "characteristicWritten", id = deviceId, serviceUuid = serviceUuid, characteristicUuid = characteristicUuid, data = data, withoutResponse = true })
        simulateLockResponse(deviceId, data)
    end)
    return true
end

function ble.subscribe(deviceId, serviceUuid, characteristicUuid)
    subscribedCharacteristics[characteristicUuid] = true
    timer.performWithDelay(300, function()
        dispatch({ name = "notificationStateChanged", id = deviceId, serviceUuid = serviceUuid, characteristicUuid = characteristicUuid, enabled = true })
    end)
    return true
end

function ble.unsubscribe(deviceId, serviceUuid, characteristicUuid)
    subscribedCharacteristics[characteristicUuid] = nil
    timer.performWithDelay(200, function()
        dispatch({ name = "notificationStateChanged", id = deviceId, serviceUuid = serviceUuid, characteristicUuid = characteristicUuid, enabled = false })
    end)
    return true
end

return ble