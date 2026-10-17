local bit = require("plugin.bit")
local Crypto = require("plugin.protocol.crypto") 

local Protocol = {}
Protocol.__index = Protocol

Protocol.PACKET_HEADER = string.char(0x7F, 0x5A)
Protocol.PACKET_END = string.char(0x0D, 0x0A)

Protocol.BLE_MTU = 20
Protocol.APP_COMMAND = 0xAA



Protocol.CRC_TABLE = {
      0, 94,188,226, 97, 63,221,131,194,156,126, 32,163,253, 31, 65,
    157,195, 33,127,252,162, 64, 30, 95,  1,227,189, 62, 96,130,220,
     35,125,159,193, 66, 28,254,160,225,191, 93,  3,128,222, 60, 98,
    190,224,  2, 92,223,129, 99, 61,124, 34,192,158, 29, 67,161,255,
     70, 24,250,164, 39,121,155,197,132,218, 56,102,229,187, 89,  7,
    219,133,103, 57,186,228,  6, 88, 25, 71,165,251,120, 38,196,154,
    101, 59,217,135,  4, 90,184,230,167,249, 27, 69,198,152,122, 36,
    248,166, 68, 26,153,199, 37,123, 58,100,134,216, 91,  5,231,185,
    140,210, 48,110,237,179, 81, 15, 78, 16,242,172, 47,113,147,205,
     17, 79,173,243,112, 46,204,146,211,141,111, 49,178,236, 14, 80,
    175,241, 19, 77,206,144,114, 44,109, 51,209,143, 12, 82,176,238,
     50,108,142,208, 83, 13,239,177,240,174, 76, 18,145,207, 45,115,
    202,148,118, 40,171,245, 23, 73,  8, 86,180,234,105, 55,213,139,
     87,  9,235,181, 54,104,138,212,149,203, 41,119,244,170, 72, 22,
    233,183, 85, 11,136,214, 52,106, 43,117,151,201, 74, 20,246,168,
    116, 42,200,150, 21, 75,169,247,182,232, 10, 84,215,137,107, 53,
}

function Protocol.crc8(data)
    local crc = 0
    for i = 1, #data do
        local byte = data:byte(i)
        local xorVal = bit.bxor(crc, byte)
        crc = Protocol.CRC_TABLE[(xorVal % 256) + 1] or 0
    end
    return crc
end

function Protocol.new(proto_type, version, scene, group, org)
    local self = setmetatable({}, Protocol)
    self.protocol_type = proto_type or 5
    self.version = version or 3
    self.scene = scene or 1
    self.group = group or 1
    self.org = org or 1
    return self
end

function Protocol:build_packet(cmd, payload, aes)
    payload = payload or ""

    -- Encrypt payload with AES if key and payload are present
    if aes and #payload > 0 then
        local encrypted = Crypto.aes_encrypt(payload, aes)
        payload = encrypted or payload
    end
    -- Convert group and org (16-bit integers) into big-endian bytes
    local group_hi = math.floor(self.group / 256) % 256
    local group_lo = self.group % 256
    local org_hi = math.floor(self.org / 256) % 256
    local org_lo = self.org % 256

   local header = Protocol.PACKET_HEADER .. 
                   string.char(
                       tonumber(self.protocol_type) or 5, 
                       tonumber(self.version) or 3, 
                       tonumber(self.scene) or 1
                   ) ..
                   string.char(group_hi, group_lo, org_hi, org_lo) ..
                   string.char(cmd, Protocol.APP_COMMAND, #payload)
                   
    local frame = header .. payload
    return frame .. string.char(Protocol.crc8(frame)) .. Protocol.PACKET_END
end

function Protocol.chunks(data)
    local result = {}
    for i = 1, #data, Protocol.BLE_MTU do
        table.insert(result, data:sub(i, i + Protocol.BLE_MTU - 1))
    end
    return result
end

function Protocol.parse_response(data, aes)
    -- Example safeguard inside protocol.lua before line 54
    if type(data) ~= "string" then
        print("[Protocol ERROR] Expected string for parsing, got: " .. type(data))
        return nil
    end
    
    if data:sub(1, 2) ~= Protocol.PACKET_HEADER then
        error("Bad TTLock header")
    end
    
    local cmd = data:byte(10)
    local length = data:byte(12) or 0
    local payload = data:sub(13, 12 + length)
    
    -- Decrypt payload with AES if key and payload are present
    if aes and #payload > 0 then
        payload = Crypto.aes_decrypt(payload, aes)
    end
    
    if #payload >= 2 then
        return { cmd = cmd, status = payload:byte(2), data = payload:sub(3) }
    end
    
    return { cmd = cmd, status = 0, data = "" }
end

return Protocol