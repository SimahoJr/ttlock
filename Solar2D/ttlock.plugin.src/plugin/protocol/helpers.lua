local bit = require("plugin.bit")

local Helpers = {}

-- Helper: Convert raw binary bytes to an uppercase hex string
function Helpers.toHex(str)
    if not str then return "" end
    return (str:gsub('.', function(c)
        return string.format('%02X', c:byte())
    end))
end

-- Helper: Convert a hex string back to raw binary bytes
function Helpers.fromHex(str)
    if not str then return "" end
    if #str == 16 and not str:match("^%x+$") then return str end
    local result = (str:gsub('%x%x', function(digits)
        return string.char(tonumber(digits, 16))
    end))
    return result
end

-- Helper: Split data into chunks based on BLE MTU size
function Helpers.chunks(data, mtu)
    local BLE_MTU = mtu or 20
    local t = {}
    for i = 1, #data, BLE_MTU do
        table.insert(t, data:sub(i, i + BLE_MTU - 1))
    end
    return t
end

-- Helper: Pack a 16-bit integer into 2 big-endian bytes
function Helpers.packInt16(num)
    local d = math.floor(num)
    return string.char(
        bit.band(bit.rshift(d, 8), 0xFF),
        bit.band(d, 0xFF)
    )
end

-- Helper: Pack a 32-bit integer into 4 big-endian bytes
function Helpers.packInt32(num)
    local d = math.floor(num)
    return string.char(
        bit.band(bit.rshift(d, 24), 0xFF),
        bit.band(bit.rshift(d, 16), 0xFF),
        bit.band(bit.rshift(d, 8), 0xFF),
        bit.band(d, 0xFF)
    )
end

-- Helper: Pack a 64-bit integer into 8 big-endian bytes
function Helpers.packInt64(num)
    local high = math.floor(num / 4294967296)
    local low = math.floor(num % 4294967296)
    return Helpers.packInt32(high) .. Helpers.packInt32(low)
end

-- Helper: Unpack 32-bit big-endian integer from string at index
function Helpers.unpackInt32(str, idx)
    idx = idx or 1
    local b1, b2, b3, b4 = str:byte(idx, idx + 3)
    if not b1 or not b2 or not b3 or not b4 then return 0 end
    return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
end

-- Helper: Convert a date-time string (or timestamp number) into bytes safely
function Helpers.dt_to_bytes_tm(s)
    if not s then return "" end
    -- If a number was passed instead of a string, convert it to string first
    if type(s) == "number" then
        s = tostring(s)
    end
    if type(s) ~= "string" then
        return ""
    end

    local res = {}
    for i = 1, #s, 2 do
        local chunk = s:sub(i, i + 1)
        table.insert(res, string.char(tonumber(chunk) or 0))
    end
    return table.concat(res)
end

-- Helper: Convert a date-time string into bytes
function Helpers.dt_to_bytes(s)
    if not s then return "" end

    local res = {}

    for i = 1, #s, 2 do
        local chunk = s:sub(i, i + 1)
        local byte = tonumber(chunk, 16) or 0

        table.insert(res, string.char(byte % 256))
    end

    return table.concat(res)
end

-- Helper: Replace bytes at a specific 1-based index in a string buffer (supports overlapping fields)
function Helpers.setBytes(buf, pos1Based, str)
    local prefix = buf:sub(1, pos1Based - 1)
    local suffix = buf:sub(pos1Based + #str)
    return prefix .. str .. suffix
end


function Helpers.urlEncode(str)
    if (str) then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end


-- Universal BCD/Packed Decimal encoder for TTLock timestamps
-- Works for both YYMMDDHHmm (10 chars) and YYMMDDHHmmss (12 chars)
function Helpers.encodeDate(s)
    if not s or s == "" then 
        print("[Helpers] Warning: empty date string passed to encodeDate")
        return "" 
    end
    
    s = tostring(s)
    local res = {}
    
    for i = 1, #s - 1, 2 do
        local chunk = s:sub(i, i + 1)
        local byte_val = tonumber(chunk, 16)
        if byte_val then
            table.insert(res, string.char(byte_val))
        else
            print(string.format("[Helpers] Warning: failed to parse chunk '%s' as hex", chunk))
            table.insert(res, string.char(0))
        end
    end
    
    return table.concat(res)
end

-- Backward compatibility aliases if your command builder specifically expects these names:
function Helpers.YYMMDDHHmmss(s)
    return Helpers.encodeDate(s)
end

function Helpers.YYMMDDHHmm(s)
    return Helpers.encodeDate(s)
end

return Helpers
