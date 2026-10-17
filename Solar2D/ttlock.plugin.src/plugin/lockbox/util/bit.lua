
local Bit = {}

local MOD = 4294967296
local HALF = 2147483648

local function normalize(n)
    return n % MOD
end

local function bitop(a, b, mode)
    a, b = normalize(a), normalize(b)
    local result, place = 0, 1

    for _ = 1, 32 do
        local x, y = a % 2, b % 2
        local keep

        if mode == "and" then
            keep = x == 1 and y == 1
        elseif mode == "or" then
            keep = x == 1 or y == 1
        else
            keep = x ~= y
        end

        if keep then result = result + place end

        a = (a - x) / 2
        b = (b - y) / 2
        place = place * 2
    end

    return result
end

function Bit.band(a, b, ...)
    local result = bitop(a, b, "and")
    for i = 1, select("#", ...) do
        result = bitop(result, select(i, ...), "and")
    end
    return result
end

function Bit.bor(a, b, ...)
    local result = bitop(a, b, "or")
    for i = 1, select("#", ...) do
        result = bitop(result, select(i, ...), "or")
    end
    return result
end

function Bit.bxor(a, b, ...)
    local result = bitop(a, b, "xor")
    for i = 1, select("#", ...) do
        result = bitop(result, select(i, ...), "xor")
    end
    return result
end

function Bit.bnot(a)
    return MOD - 1 - normalize(a)
end

function Bit.lshift(a, n)
    n = n % 32
    return normalize(normalize(a) * (2 ^ n))
end

function Bit.rshift(a, n)
    n = n % 32
    return math.floor(normalize(a) / (2 ^ n))
end

function Bit.arshift(a, n)
    n = n % 32
    a = normalize(a)
    if a >= HALF then
        return normalize(math.floor(a / (2 ^ n)) + (MOD - 2 ^ (32 - n)))
    end
    return math.floor(a / (2 ^ n))
end

function Bit.rol(a, n)
    n = n % 32
    if n == 0 then return normalize(a) end
    return normalize(Bit.lshift(a, n) + Bit.rshift(a, 32 - n))
end

function Bit.ror(a, n)
    n = n % 32
    if n == 0 then return normalize(a) end
    return normalize(Bit.rshift(a, n) + Bit.lshift(a, 32 - n))
end

Bit.lrotate = Bit.rol
Bit.rrotate = Bit.ror

return Bit
