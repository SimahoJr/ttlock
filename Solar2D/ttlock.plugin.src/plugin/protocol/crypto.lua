local bit = require("plugin.bit")
local Lockbox = require("plugin.lockbox.lockbox")
local Array = require("plugin.lockbox.util.array")
local Stream = require("plugin.lockbox.util.stream")
local CBCMode = require("plugin.lockbox.cipher.mode.cbc")
local PKCS7Padding = require("plugin.lockbox.padding.pkcs7")
local AES128Cipher = require("plugin.lockbox.cipher.aes128")

local Crypto = {}

local function stringToBytes(str)
    str = tostring(str or "")
    local bytes = {}
    for i = 1, #str do
        bytes[i] = str:byte(i)
    end
    return bytes
end

local function bytesToString(bytes)
    if type(bytes) == "string" then return bytes end
    if not bytes then return "" end
    
    local t = {}
    local size = (type(bytes.size) == "function" and bytes.size()) or #bytes
    
    for i = 1, size do
        local val = bytes[i] or (type(bytes.get) == "function" and bytes.get(i))
        if val then
            t[#t + 1] = string.char(val)
        end
    end
    return table.concat(t)
end

function Crypto.aes_encrypt(data, key)
    data = tostring(data or "")
    key = tostring(key or "")

    local keyBytes = stringToBytes(key)
    local dataBytes = stringToBytes(data)

    local success, result = pcall(function()
        local cipher = CBCMode.Cipher()
            .setKey(keyBytes)
            .setBlockCipher(AES128Cipher)
            .setPadding(PKCS7Padding)

        -- Match the lockbox test vector pattern: init -> update(IV/Key) -> update(Data) -> finish -> asBytes
        local rawBytes = cipher.init()
            .update(Stream.fromArray(keyBytes)) -- Key serves as IV in TTLock protocol
            .update(Stream.fromArray(dataBytes))
            .finish()
            .asBytes()

        return bytesToString(rawBytes)
    end)

    if not success then
        print("[Crypto] ❌ Encryption error: " .. tostring(result))
        return ""
    end

    return result
end

function Crypto.aes_decrypt(data, key)
    data = tostring(data or "")
    key = tostring(key or "")

    local keyBytes = stringToBytes(key)
    local dataBytes = stringToBytes(data)

    local success, result = pcall(function()
        local decipher = CBCMode.Decipher()
            .setKey(keyBytes)
            .setBlockCipher(AES128Cipher)
            .setPadding(PKCS7Padding)

        local rawBytes = decipher.init()
            .update(Stream.fromArray(keyBytes)) -- Key serves as IV
            .update(Stream.fromArray(dataBytes))
            .finish()
            .asBytes()

        return bytesToString(rawBytes)
    end)

    if not success then
        print("[Crypto] ❌ Decryption error: " .. tostring(result))
        return ""
    end

    return result
end

return Crypto