local bit = require("plugin.bit")
local Helpers = require("plugin.protocol.helpers")
local CONSTANTS = require("plugin.protocol.constants.index")
local CommandBuilder = {}

-- ---------------------------------------------------------------------------
-- Pairing sequence
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_init()
    return ""
end

function CommandBuilder.cmd_get_key()
    return "SCIENER"
end

function CommandBuilder.parse_aes_key(data)
    if not data or #data < 16 then
        error(string.format("AES key response too short: %d bytes", #data))
    end
    return data:sub(1, 16)
end

function CommandBuilder.cmd_add_admin(admin, unlock)
    return Helpers.packInt32(admin) .. Helpers.packInt32(unlock) .. "SCIENER"
end
function CommandBuilder.cmd_calibrate_time()
    -- Get current date/time in YYMMDDHHmmss format (12 characters)
    local s = os.date("%y%m%d%H%M%S")
    
    -- Convert time string using your helper
    local timeBytes = Helpers.dt_to_bytes(s) -- or Helpers.dt_to_bytes_12(s)

    local payload = string.char(0, 0, 0, 0, 0, 0) 
    payload = Helpers.setBytes(payload, 1, timeBytes)
    
    return payload
end

function CommandBuilder.cmd_search_feature()
    return ""
end

function CommandBuilder.build_search_device_feature()
    return CommandBuilder.cmd_search_feature()
end

function CommandBuilder.parse_device_features(data)
    if not data or #data < 5 then
        return {}
    end
    local features_int = Helpers.unpackInt32(data, 2)
    local result = {}
    for i = 0, 31 do
        if bit.band(features_int, bit.lshift(1, i)) ~= 0 then
            table.insert(result, i)
        end
    end
    return result
end

function CommandBuilder.cmd_operate_finished()
    return ""
end

-- ---------------------------------------------------------------------------
-- Authentication & Management Extensions
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_reset_lock()
    return "SCIENER"
end

function CommandBuilder.build_reset_lock()
    return CommandBuilder.cmd_reset_lock()
end

function CommandBuilder.build_modify_admin_ps(old_admin_ps, new_admin_ps)
    return Helpers.packInt32(old_admin_ps) .. Helpers.packInt32(new_admin_ps)
end

function CommandBuilder.build_get_device_type()
    return string.char(0)
end

function CommandBuilder.parse_device_type(data)
    if not data or #data < 2 then
        return 0
    end
    return data:byte(2)
end

-- ---------------------------------------------------------------------------
-- Authentication (used for every connected operation)
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_check_admin(admin_ps)
    local payload = string.char(0,0,0,0,0,0,0,0,0,0,0)
    payload = Helpers.setBytes(payload, 1, Helpers.packInt32(admin_ps))
    payload = Helpers.setBytes(payload, 4, Helpers.packInt32(0))
    payload = Helpers.setBytes(payload, 8, Helpers.packInt32(0))
    return payload
end


function CommandBuilder.build_check_admin(admin_ps, lock_flag_pos, uid)
    admin_ps = tonumber(admin_ps) or 0
    lock_flag_pos = tonumber(lock_flag_pos) or 0
    uid = tonumber(uid) or 0

    -- Initialize an 11-byte array with zeros
    local bytes = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

    local function writeUInt32BE(tbl, val, offset0)
        local idx = offset0 + 1 -- 0-based to 1-based index
        tbl[idx]   = math.floor(val / 16777216) % 256
        tbl[idx+1] = math.floor(val / 65536) % 256
        tbl[idx+2] = math.floor(val / 256) % 256
        tbl[idx+3] = val % 256
    end

    -- Match the exact TypeScript write order and overlap
    writeUInt32BE(bytes, lock_flag_pos, 3)
    writeUInt32BE(bytes, admin_ps, 0)
    writeUInt32BE(bytes, uid, 7)

    return string.char(unpack(bytes)) -- use table.unpack if on Lua 5.3+
end

function CommandBuilder.parse_check_admin(data)
    if not data or #data < 4 then
        error("CHECK_ADMIN response too short")
    end
    return Helpers.unpackInt32(data, 1)
end

function CommandBuilder.cmd_check_random(ps_from_lock, unlock_key)
    return Helpers.packInt32(ps_from_lock + unlock_key)
end

function CommandBuilder.build_check_random(ps_from_lock, unlock_key)
    local p1 = tonumber(ps_from_lock) or 0
    local p2 = tonumber(unlock_key) or 0
    
    print("[Debug] Adding credentials - p1:", p1, "p2:", p2)
    return Helpers.packInt32(p1 + p2)
end

function CommandBuilder.cmd_check_user_time(admin_ps, unlock_key)
    local start = Helpers.dt_to_bytes("0001010000")
    local finish = Helpers.dt_to_bytes("9912312359")
    
    -- Initialize a 17-byte buffer with proper overlapping offsets matching Python
    local payload = string.char(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    payload = Helpers.setBytes(payload, 1, start)
    payload = Helpers.setBytes(payload, 6, finish)
    payload = Helpers.setBytes(payload, 10, Helpers.packInt32(admin_ps))
    payload = Helpers.setBytes(payload, 14, Helpers.packInt32(unlock_key))
    
    return payload
end

function CommandBuilder.parse_check_user_time(data)
    if not data or #data < 4 then
        error("CHECK_USER_TIME response too short")
    end
    return Helpers.unpackInt32(data, 1)
end

-- ---------------------------------------------------------------------------
-- Lock / Unlock
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_unlock(ps, key)
    return Helpers.packInt32(ps + key) .. Helpers.packInt32(os.time())
end

function CommandBuilder.parse_unlock(data)
    local result = {}
    if data and #data >= 1 then
        result.battery = data:byte(1)
    end
    return result
end

function CommandBuilder.cmd_lock(ps, key)
    return Helpers.packInt32(ps + key) .. Helpers.packInt32(os.time())
end

function CommandBuilder.parse_lock(data)
    local result = {}
    if data and #data >= 1 then
        result.battery = data:byte(1)
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Lock status
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_search_status()
    return "SCIENER"
end

function CommandBuilder.parse_search_status(data)
    if not data or #data < 2 then
        return 2 -- UNKNOWN
    end
    local raw = data:byte(2)
    if raw == 0 then
        return 0 -- LOCKED
    elseif raw == 1 then
        return 1 -- UNLOCKED
    end
    return 2 -- UNKNOWN
end

-- ---------------------------------------------------------------------------
-- Auto-lock & Sound Settings
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_get_autolock()
    return string.char(0x01)
end

function CommandBuilder.cmd_set_autolock(seconds)
    return string.char(0x02) .. Helpers.packInt16(seconds)
end

function CommandBuilder.parse_autolock(data)
    if not data or #data < 4 then
        return -1
    end
    local b1, b2 = data:byte(3, 4)
    if not b1 or not b2 then return -1 end
    return (b1 * 256) + b2
end

function CommandBuilder.build_get_lock_sound()
    return string.char(CONSTANTS.AudioManage.QUERY)
end

function CommandBuilder.build_set_lock_sound(enabled)
    return string.char(CONSTANTS.AudioManage.MODIFY, enabled and 1 or 0)
end

function CommandBuilder.parse_lock_sound(data)
    if not data or #data < 3 then
        return -1
    end
    return data:byte(3)
end

-- ---------------------------------------------------------------------------
-- Admin passcode
-- ---------------------------------------------------------------------------

function CommandBuilder.cmd_get_admin_code()
    return ""
end

function CommandBuilder.parse_admin_code(data)
    if not data then return "" end
    return data:gsub("%z", "")
end

function CommandBuilder.cmd_set_admin_code(pin)
    local encoded = tostring(pin)
    return string.char(#encoded) .. encoded
end

function CommandBuilder.build_add_passcode(pwd_type, passcode, start_date, end_date)
    start_date = start_date or "202601010000"
    end_date = end_date or "202701010000"
    
    local clean_start = start_date:gsub("%D", "")
    -- Skip the century "20" (indices 1-2) and take the 2-digit year at indices 3-4
    local s_year  = tonumber(clean_start:sub(3, 4)) or 0
    local s_month = tonumber(clean_start:sub(5, 6)) or 1
    local s_day   = tonumber(clean_start:sub(7, 8)) or 1
    local s_hour  = tonumber(clean_start:sub(9, 10)) or 0
    local s_min   = tonumber(clean_start:sub(11, 12)) or 0
    local start_b = string.char(s_year, s_month, s_day, s_hour, s_min)
    
    -- Ensure safe defaults and types
    local PWD_OPERATE_ADD = CONSTANTS.PwdOperateType.PWD_OPERATE_TYPE_ADD  
    local p_type = tonumber(pwd_type) or 1
    local code = tostring(passcode or "123456")
    local code_len = #code

    -- Build base buffer safely
    local buf = string.char(PWD_OPERATE_ADD, p_type, code_len) .. code .. start_b
    
    if p_type == CONSTANTS.KeyboardPwdType.PWD_TYPE_PERMANENT then
        buf = buf .. string.char(0, 0, 0, 0, 0)
    else
        local clean_end = end_date:gsub("%D", "")
        local e_year  = tonumber(clean_end:sub(3, 4)) or 0
        local e_month = tonumber(clean_end:sub(5, 6)) or 1
        local e_day   = tonumber(clean_end:sub(7, 8)) or 1
        local e_hour  = tonumber(clean_end:sub(9, 10)) or 0
        local e_min   = tonumber(clean_end:sub(11, 12)) or 0
        local end_b   = string.char(e_year, e_month, e_day, e_hour, e_min)
        buf = buf .. end_b
    end
    
    return buf
end

function CommandBuilder.build_update_passcode(pwd_type, old_passcode, new_passcode, start_date, end_date)
    start_date = start_date or "000101000000"
    end_date = end_date or "991231235900"
    local old_code = tostring(old_passcode)
    local new_code = tostring(new_passcode)
    local start_b = Helpers.dt_to_bytes(start_date:sub(1, 10))
    local end_b = Helpers.dt_to_bytes(end_date:sub(1, 10))
    
    return string.char(1, pwd_type, #old_code) .. old_code .. string.char(#new_code) .. new_code .. start_b .. end_b
end

function CommandBuilder.build_delete_passcode(pwd_type, passcode)
    local code = tostring(passcode)
    return string.char(3, pwd_type, #code) .. code
end

function CommandBuilder.build_clear_passcodes()
    return string.char(4)
end

function CommandBuilder.build_list_passcodes(sequence)
    sequence = sequence or 0
    return Helpers.packInt16(sequence)
end

function CommandBuilder.parse_passcodes(data)
    if not data or #data < 2 then
        return 0, {}
    end
    local total = (data:byte(1) * 256) + data:byte(2)
    if total == 0 then
        return 0, {}
    end
    if #data < 4 then
        return 0, {}
    end
    local sequence = (data:byte(3) * 256) + data:byte(4)
    local passcodes = {}
    local idx = 5
    while idx <= #data do
        local rec_len = data:byte(idx); idx = idx + 1
        if not rec_len or idx + rec_len - 1 > #data then break end
        
        local pwd_type = data:byte(idx); idx = idx + 1
        local code_len = data:byte(idx); idx = idx + 1
        local new_code = data:sub(idx, idx + code_len - 1); idx = idx + code_len
        
        local code_len2 = data:byte(idx); idx = idx + 1
        local passcode = data:sub(idx, idx + code_len2 - 1); idx = idx + code_len2
        
        local start_raw = data:sub(idx, idx + 4); idx = idx + 5
        local start_date = "20" .. Helpers.toHex(start_raw)
        
        local end_date = ""
        if pwd_type == 2 or pwd_type == 3 then
            local end_raw = data:sub(idx, idx + 4); idx = idx + 5
            end_date = "20" .. Helpers.toHex(end_raw)
        elseif pwd_type == 4 then
            idx = idx + 2
        end
        
        table.insert(passcodes, {
            type = pwd_type,
            passcode = passcode,
            new_passcode = new_code,
            start_date = start_date,
            end_date = end_date
        })
    end
    return sequence, passcodes
end

-- ---------------------------------------------------------------------------
-- IC cards
-- ---------------------------------------------------------------------------

function CommandBuilder.build_add_ic_card(card_number, start_date, end_date)
    if card_number and start_date and end_date then
        local cn = tonumber(card_number) or 0
        local card_b
        if cn > 0xFFFFFFFF then
            card_b = Helpers.packInt64(cn):sub(3, 8)
        else
            card_b = Helpers.packInt32(cn)
        end
        local date_b = Helpers.dt_to_bytes((start_date:sub(3)) .. (end_date:sub(3)))
        return string.char(2) .. card_b .. date_b
    end
    return string.char(2)
end

function CommandBuilder.build_update_ic_card(card_number, start_date, end_date)
    local cn = tonumber(card_number) or 0
    local card_b
    if cn > 0xFFFFFFFF then
        card_b = Helpers.packInt64(cn):sub(3, 8)
    else
        card_b = Helpers.packInt32(cn)
    end
    local date_b = Helpers.dt_to_bytes((start_date:sub(3)) .. (end_date:sub(3)))
    return string.char(3) .. card_b .. date_b
end

function CommandBuilder.build_delete_ic_card(card_number)
    local cn = tonumber(card_number) or 0
    if cn > 0xFFFFFFFF then
        return string.char(4) .. Helpers.packInt64(cn):sub(3, 8)
    end
    return string.char(4) .. Helpers.packInt32(cn)
end

function CommandBuilder.build_clear_ic_cards()
    return string.char(5)
end

function CommandBuilder.build_list_ic_cards(sequence)
    sequence = sequence or 0
    return string.char(6) .. Helpers.packInt16(sequence)
end

function CommandBuilder.parse_ic_card_add(data)
    if not data or #data < 3 then
        return "", 0
    end
    local status = data:byte(2)
    if status == 1 then
        local remaining = #data - 3
        local card = 0
        if remaining == 4 or (remaining == 8 and data:sub(-4) == "\xff\xff\xff\xff") then
            card = Helpers.unpackInt32(data, 4)
        else
            card = Helpers.unpackInt32(data, 4)
        end
        return tostring(card), status
    end
    return "", status
end

function CommandBuilder.parse_ic_cards(data)
    if not data or #data < 4 then
        return 0, {}
    end
    local op_type = data:byte(2)
    if op_type ~= 6 then
        return 0, {}
    end
    local sequence = (data:byte(3) * 256) + data:byte(4)
    local cards = {}
    local idx = 5
    while idx <= #data do
        local card_num = 0
        if #data == 24 then
            card_num = Helpers.unpackInt32(data, idx)
            idx = idx + 8
        else
            card_num = Helpers.unpackInt32(data, idx)
            idx = idx + 4
        end
        local start_raw = data:sub(idx, idx + 4); idx = idx + 5
        local end_raw = data:sub(idx, idx + 4); idx = idx + 5
        table.insert(cards, {
            card_number = tostring(card_num),
            start_date = "20" .. Helpers.toHex(start_raw),
            end_date = "20" .. Helpers.toHex(end_raw)
        })
    end
    return sequence, cards
end

-- ---------------------------------------------------------------------------
-- Fingerprints
-- ---------------------------------------------------------------------------

function CommandBuilder.build_add_fingerprint()
    return string.char(2)
end

function CommandBuilder.build_update_fingerprint(fp_number, start_date, end_date)
    local fp = tonumber(fp_number) or 0
    local fp_b = Helpers.packInt64(fp):sub(3, 8)
    local date_b = Helpers.dt_to_bytes((start_date:sub(3)) .. (end_date:sub(3)))
    return string.char(3) .. fp_b .. date_b
end

function CommandBuilder.build_delete_fingerprint(fp_number)
    local fp = tonumber(fp_number) or 0
    return string.char(4) .. Helpers.packInt64(fp):sub(3, 8)
end

function CommandBuilder.build_clear_fingerprints()
    return string.char(5)
end

function CommandBuilder.build_list_fingerprints(sequence)
    sequence = sequence or 0
    return string.char(7) .. Helpers.packInt16(sequence)
end

function CommandBuilder.parse_fingerprint_add(data)
    if not data or #data < 3 then
        return "", 0
    end
    local status = data:byte(2)
    if status == 1 then
        local raw = "\x00\x00" .. data:sub(4, 9)
        local fp = Helpers.unpackInt32(raw, 5)
        return tostring(fp), status
    end
    return "", status
end

function CommandBuilder.parse_fingerprints(data)
    if not data or #data < 4 then
        return 0, {}
    end
    local op_type = data:byte(2)
    if op_type ~= 7 then
        return 0, {}
    end
    local sequence = (data:byte(3) * 256) + data:byte(4)
    local fps = {}
    local idx = 5
    while idx <= #data do
        local raw = "\x00\x00" .. data:sub(idx, idx + 5); idx = idx + 6
        local fp_num = Helpers.unpackInt32(raw, 5)
        local start_raw = data:sub(idx, idx + 4); idx = idx + 5
        local end_raw = data:sub(idx, idx + 4); idx = idx + 5
        table.insert(fps, {
            fp_number = tostring(fp_num),
            start_date = "20" .. Helpers.toHex(start_raw),
            end_date = "20" .. Helpers.toHex(end_raw)
        })
    end
    return sequence, fps
end

-- ---------------------------------------------------------------------------
-- Passage mode
-- ---------------------------------------------------------------------------

function CommandBuilder.build_get_passage_mode(sequence)
    sequence = sequence or 0
    return string.char(1, sequence)
end

function CommandBuilder.build_set_passage_mode(pm_type, week_or_day, month, start_hour, end_hour)
    return string.char(
        2,
        pm_type,
        week_or_day,
        month,
        tonumber(start_hour:sub(1, 2)) or 0,
        tonumber(start_hour:sub(3, 4)) or 0,
        tonumber(end_hour:sub(1, 2)) or 0,
        tonumber(end_hour:sub(3, 4)) or 0
    )
end

function CommandBuilder.build_delete_passage_mode(pm_type, week_or_day, month, start_hour, end_hour)
    return string.char(
        3,
        pm_type,
        week_or_day,
        month,
        tonumber(start_hour:sub(1, 2)) or 0,
        tonumber(start_hour:sub(3, 4)) or 0,
        tonumber(end_hour:sub(1, 2)) or 0,
        tonumber(end_hour:sub(3, 4)) or 0
    )
end

function CommandBuilder.build_clear_passage_mode()
    return string.char(5)
end

function CommandBuilder.parse_passage_modes(data)
    if not data or #data < 3 then
        return 0, {}
    end
    local sequence = data:byte(3) or 0
    local modes = {}
    local idx = 4
    while idx + 6 <= #data do
        table.insert(modes, {
            type = data:byte(idx),
            week_or_day = data:byte(idx + 1),
            month = data:byte(idx + 2),
            start_hour = string.format("%02d%02d", data:byte(idx + 3), data:byte(idx + 4)),
            end_hour = string.format("%02d%02d", data:byte(idx + 5), data:byte(idx + 6))
        })
        idx = idx + 7
    end
    return sequence, modes
end

-- ---------------------------------------------------------------------------
-- Operation log
-- ---------------------------------------------------------------------------

function CommandBuilder.build_get_operation_log(sequence)
    sequence = sequence or 65535
    return Helpers.packInt16(sequence)
end

function CommandBuilder.parse_operation_log(data)
    if not data or #data < 4 then
        return 0, {}
    end
    local total = (data:byte(1) * 256) + data:byte(2)
    if total == 0 then
        return 0, {}
    end
    local sequence = (data:byte(3) * 256) + data:byte(4)
    local logs = {}
    local idx = 5
    while idx <= #data do
        local rec_len = data:byte(idx); idx = idx + 1
        local rec_start = idx
        if not rec_len or idx + 7 > #data then break end
        
        local rec_type = data:byte(idx); idx = idx + 1
        local year = data:byte(idx); idx = idx + 1
        local month = data:byte(idx); idx = idx + 1
        local day = data:byte(idx); idx = idx + 1
        local hour = data:byte(idx); idx = idx + 1
        local minute = data:byte(idx); idx = idx + 1
        local second = data:byte(idx); idx = idx + 1
        local battery = data:byte(idx); idx = idx + 1
        
        local operate_date = string.format("20%02d%02d%02d%02d%02d%02d", year, month, day, hour, minute, second)
        local entry = {
            record_type = rec_type,
            operate_date = operate_date,
            battery = battery
        }
        
        local remaining = rec_len - (idx - rec_start)
        if remaining > 0 and idx + remaining - 1 <= #data then
            entry.extra = Helpers.toHex(data:sub(idx, idx + remaining - 1))
            idx = idx + remaining
        end
        table.insert(logs, entry)
    end
    return sequence, logs
end

return CommandBuilder