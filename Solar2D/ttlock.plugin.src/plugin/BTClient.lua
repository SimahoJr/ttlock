local system = system
local ble = (system.getInfo("environment") == "simulator") and require("plugin.ble_mock") or require("plugin.ble")
local Protocol = require("plugin.protocol.protocol")
local Helpers = require("plugin.protocol.helpers")

local BTClient = {}
BTClient.__index = BTClient

local LOCK_MAC = "15:6E:16:FD:32:A6"
local SERVICE_UUID = "00001910-0000-1000-8000-00805f9b34fb"
local WRITE_UUID = "0000fff2-0000-1000-8000-00805f9b34fb"
local NOTIFY_UUID = "0000fff4-0000-1000-8000-00805f9b34fb"

BTClient.PACKET_HEADER = string.char(0x7F, 0x5A)
BTClient.PACKET_END = string.char(0x0D, 0x0A)

BTClient.BLE_MTU = 20
BTClient.APP_COMMAND = 0xAA


function BTClient.new()
    local self = setmetatable({}, BTClient)
    self.deviceId = LOCK_MAC
    self.rx_buffer = ""
    self.responseQueue = {}
    self.pendingRequest = nil
    self.isConnected = false
    self.proto = Protocol.new(5, 3, 1, 1, 1)
    return self
end



function BTClient:connect(onConnected)
    print("[BTClient] Connecting to BLE device...")
    
    local function bleListener(event)
        if event.name == "connected" then
            print("[BTClient] Connected, discovering services...")
            ble.discoverServices(self.deviceId)
            
        elseif event.name == "servicesDiscovered" then
            print("[BTClient] Services discovered. Subscribing to notifications...")
            ble.subscribe(self.deviceId, SERVICE_UUID, NOTIFY_UUID)
            
            timer.performWithDelay(1000, function()
                self.isConnected = true
                if onConnected then onConnected(true) end
            end)
            
        elseif event.name == "disconnected" then
            print("[BTClient] Device disconnected.")
            self.isConnected = false
            
        elseif event.name == "connectionError" or event.name == "serviceError" then
            print("[BTClient] Connection error:", event.error)
            self.isConnected = false
            if onConnected then onConnected(false) end
            
        elseif event.name == "characteristicChanged" then
            self:handleNotification(event.data)
        end
    end

    ble.init(bleListener)
    ble.connect(self.deviceId)
end

function BTClient:disconnect()
    ble.disconnect(self.deviceId)
    self.isConnected = false
end

function BTClient:handleNotification(data)
    self.rx_buffer = self.rx_buffer .. data

    while true do
        local endIndex = self.rx_buffer:find(BTClient.PACKET_END, 1, true)
        if not endIndex then break end

        local frameLength = endIndex + #BTClient.PACKET_END - 1
        local frame = self.rx_buffer:sub(1, frameLength)
        self.rx_buffer = self.rx_buffer:sub(frameLength + 1)

        table.insert(self.responseQueue, frame)
        self:processQueue()
    end
end

function BTClient:processQueue()
    if self.isProcessing or #self.responseQueue == 0 then return end

    self.isProcessing = true
    local responseFrame = table.remove(self.responseQueue, 1)

    if type(responseFrame) ~= "string" then
        self.isProcessing = false
        return
    end

    if self.pendingRequest and self.pendingRequest.callback then
        local req = self.pendingRequest
        self.pendingRequest = nil

        local success, parsed = pcall(function()
            return Protocol.parse_response(responseFrame, req.aes)
        end)
        
        if success then
            pcall(function() req.callback(parsed) end)
        else
            print("[BTClient ERROR] Parse response failed: " .. tostring(parsed))
        end
    end

    timer.performWithDelay(100, function()
        self.isProcessing = false
        if #self.responseQueue > 0 then self:processQueue() end
    end)
end

function BTClient:sendPacket(cmd, payload, overrideAesKey, aes_key, callback)
    payload = payload or ""
    local aes = overrideAesKey or aes_key
    local packet = self.proto:build_packet(cmd, payload, aes)
    -- print(Helpers.toHex(packet))
    -- print("[BTClient TX] Sending cmd: 0x" .. string.format("%02X", cmd) .. " | Length: " .. #packet)

    self.pendingRequest = { aes = aes, callback = callback }

    local chunksList = Helpers.chunks(packet)
    local index = 1

    local function sendNext()
        if index > #chunksList then return end
        local chunk = chunksList[index]

        if ble.writeWithoutResponse then
            ble.writeWithoutResponse(self.deviceId, SERVICE_UUID, WRITE_UUID, chunk)
        else
            ble.write(self.deviceId, SERVICE_UUID, WRITE_UUID, chunk)
        end

        index = index + 1
        timer.performWithDelay(200, sendNext)
    end
    sendNext()
end

return BTClient