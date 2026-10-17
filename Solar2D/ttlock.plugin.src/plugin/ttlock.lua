local system = system
local json = require("json")
local CommandBuilder = require("plugin.protocol.command_builder")
local CommandType = require("plugin.protocol.constants.index").CommandType

local Helpers = require("plugin.protocol.helpers")
local BTClient = require("plugin.BTClient")

local TTLock = {}
TTLock.__index = TTLock

local DEFAULT_AES_KEY = string.char(
    0x98, 0x76, 0x23, 0xE8,
    0xA9, 0x23, 0xA1, 0xBB,
    0x3D, 0x9E, 0x7D, 0x03,
    0x78, 0x12, 0x45, 0x88
)

function TTLock.new()
    local self = setmetatable({}, TTLock)
    self.client = BTClient.new()

    self.mac_address= self.client.deviceId
    self.address = ""
    self.protocol_type = 5
    self.protocol_version = 3
    self.scene = 1
    self.aes_key = DEFAULT_AES_KEY
    self.admin_ps = 0
    self.unlock_key = 0
    self.admin_passcode = ""
    
    self.battery = -1
    self.locked_status = -1
    self.auto_lock_time = -1
    return self
end

function TTLock:load()
    local path = system.pathForFile("ttlock.json", system.DocumentsDirectory)
    local file = io.open(path, "r")
    if not file then return end
    
    local contents = file:read("*a")
    io.close(file)
    
    local decoded = json.decode(contents)
    if decoded then
        self.address = decoded.address or ""
        self.protocol_type = decoded.protocol_type or 5
        self.protocol_version = decoded.protocol_version or 3
        self.scene = decoded.scene or 1
        self.admin_ps = decoded.admin_ps or 0
        self.unlock_key = decoded.unlock_key or 0
        self.admin_passcode = decoded.admin_passcode or ""
        
        if decoded.aes_key and type(decoded.aes_key) == "string" then
            self.aes_key = Helpers.fromHex(decoded.aes_key)
        end
        print("[TTLock] ✅ Config loaded successfully.")
    end
end

function TTLock:save()
    local path = system.pathForFile("ttlock.json", system.DocumentsDirectory)
    local file = io.open(path, "w")
    if file then
        local data = {
            address = self.address,
            protocol_type = self.protocol_type,
            protocol_version = self.protocol_version,
            scene = self.scene,
            aes_key = type(self.aes_key) == "string" and Helpers.toHex(self.aes_key) or nil,
            admin_ps = self.admin_ps,
            unlock_key = self.unlock_key,
            admin_passcode = self.admin_passcode
        }
        file:write(json.encode(data))
        io.close(file)
        print("[TTLock] 💾 Full credentials saved to ttlock.json.")
    end
end

function TTLock:clear(callback)
    local path = system.pathForFile("ttlock.json", system.DocumentsDirectory)
    local success = os.remove(path)
    if success then
        print("[TTLock] 🗑️ ttlock.json deleted successfully.")
        callback(true)
    else
        print("[TTLock] ⚠️ No existing ttlock.json found to delete.")
        callback(false)
    end
end

function TTLock:connect(callback)
    self.client:connect(callback)
end

function TTLock:disconnect()
    self.client:disconnect()
end

-- Centralized wrapper for actions that require connection + standard check_user_time auth
function TTLock:withAuth(callback, action)
    self.client:connect(function(connected)
        if not connected then
            if callback then callback({ status = 0, error = "Connection failed" }) end
            return
        end

        if self.admin_ps == 0 or self.unlock_key == 0 then
            self:load()
        end

        local authPayload = CommandBuilder.cmd_check_user_time(self.admin_ps, self.unlock_key)
        self.client:sendPacket(CommandType.COMM_CHECK_USER_TIME, authPayload, nil, self.aes_key, function(response)
            if not response or response.status ~= 1 or not response.data or #response.data < 4 then
                if callback then callback({ status = 0, error = "Authentication failed" }) end
            end

            local psFromLock = Helpers.unpackInt32(response.data, 1)
            action(psFromLock)
        end)
    end)
end

-- Dedicated wrapper for older-protocol locks using CHECK_ADMIN + CHECK_RANDOM
function TTLock:withAuthOld(callback, action)
    self.client:connect(function(connected)
        if not connected then
            if callback then callback({ status = 0, error = "Connection failed" }) end
            return
        end
        print("[TTLock] Connected to device. Proceeding with authentication...")
        if self.admin_ps == 0 or self.unlock_key == 0 then
            self:load()
        end
        -- print("[TTLock] Starting authentication sequence with CHECK_ADMIN and CHECK_RANDOM...")
        -- Ensure proper formatting/padding of admin_ps if required by your CommandBuilder
        local adminPayload = CommandBuilder.build_check_admin(tonumber(self.admin_ps))
        
        self.client:sendPacket(CommandType.COMM_CHECK_ADMIN, adminPayload, nil, self.aes_key, function(adminResp)
            -- if not adminResp or adminResp.status ~= 0 or not adminResp.data then
            --     if callback then callback({ status = 1, error = "Authentication may have failed (CHECK_ADMIN)" }) end
            -- end
            -- print("[TTLock] CHECK_ADMIN response received. Proceeding to CHECK_RANDOM...")
            -- Safely grab whatever bytes are available up to the 4th index
            local b1, b2, b3, b4 = adminResp.data:byte(1, 4)
            local ps_from_lock = 0

            if b1 and b2 and b3 and b4 then
                -- Full 32-bit (4-byte) big-endian unpack
                ps_from_lock = (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
            elseif b1 and not b2 then
                -- Old-school 1-byte fallback
                ps_from_lock = b1
            elseif b1 and b2 then
                -- 2-byte fallback (just in case)
                ps_from_lock = (b1 * 256) + b2
            end

            -- print("[TTLock] ps_from_lock obtained:", ps_from_lock)
            -- Step 2: CHECK_RANDOM (using ps_from_lock instead of admin_ps)
            local randomPayload = CommandBuilder.build_check_random(ps_from_lock, self.unlock_key)
            -- print("[TTLock] Sending CHECK_RANDOM with ps_from_lock:", ps_from_lock, "and unlock_key:", self.unlock_key)
            self.client:sendPacket(CommandType.COMM_CHECK_RANDOM, randomPayload, nil, self.aes_key, function(randomResp)
                if not randomResp or randomResp.status ~= 1 then
                    print("[TTLock] CHECK_RANDOM failed.")
                    if callback then callback({ status = 0, error = "Authentication failed (CHECK_RANDOM)" }) end
                end
                -- print("[TTLock] CHECK_RANDOM successful.")
                -- Pass control back to the action callback once authorized, passing ps_from_lock
                local success, err = pcall(function()
                    action(ps_from_lock)
                end)

                if not success and callback then
                    callback({ status = 0, error = "Action execution error: " .. tostring(err) })
                end
            end)
        end)
    end)
end

-- Generic paginated fetcher for Passcodes, IC Cards, and Fingerprints
function TTLock:fetchPaginatedList(command, parseFunc, callback)
    self:withAuthOld(callback, function(psFromLock)
        local all_items = {}
        local sequence = 0
        
        local function fetchNext()
            local cmdPayload = (command == CommandType.COMM_PWD_LIST) and CommandBuilder.build_list_passcodes(sequence)
                    or (command == CommandType.COMM_IC_MANAGE) and CommandBuilder.build_list_ic_cards(sequence)
                    or CommandBuilder.build_list_fingerprints(sequence)

            self.client:sendPacket(command, cmdPayload, nil, self.aes_key, function(response)
                if not response or not response.data then
                    if callback then callback(all_items) end
                    return
                end
                local next_seq, items = parseFunc(response.data)
                for _, item in ipairs(items) do table.insert(all_items, item) end
                
                if next_seq == 0 or #items == 0 then
                    if callback then callback(all_items) end
                else
                    sequence = next_seq
                    fetchNext()
                end
            end)
        end
        fetchNext()
    end)
end

-- ============================================================
-- PAIRING (No Pre-Existing Auth Required)
-- ============================================================
function TTLock:pair(callback)
    print("[TTLock] Starting pairing sequence...")
    self.client:connect(function(connected)
        if not connected then
            print("[TTLock] Error: Connection failed")
            if callback then callback(false, "Connection failed") end
            return
        end

        local hasFinished = false
        local pairingTimeout = timer.performWithDelay(15000, function()
            if not hasFinished then
                hasFinished = true
                print("[TTLock] Error: Pairing timed out")
                if callback then callback(false, "Timeout") end
            end
        end)

        -- Step 1: Initialise
        self.client:sendPacket(CommandType.COMM_INITIALIZATION, CommandBuilder.cmd_init(), nil, DEFAULT_AES_KEY, function(initResp)
            if hasFinished then return end

            -- Step 2: Get AES key
            self.client:sendPacket(CommandType.COMM_GET_AES_KEY, CommandBuilder.cmd_get_key(), DEFAULT_AES_KEY, nil, function(keyResp)
                if hasFinished then return end

                if not keyResp or not keyResp.data or #keyResp.data < 16 then
                    hasFinished = true
                    timer.cancel(pairingTimeout)
                    if callback then callback(false, "Invalid AES key response") end
                    return
                end

                self.aes_key = keyResp.data:sub(1, 16)

                -- Step 3: Register admin credentials (randomized 6-digit values)
                math.randomseed(os.time())
                self.admin_ps = math.random(100000, 999999)
                self.unlock_key = math.random(100000, 999999)
                
                local addPayload = CommandBuilder.cmd_add_admin(self.admin_ps, self.unlock_key)

                self.client:sendPacket(CommandType.COMM_ADD_ADMIN, addPayload, nil, self.aes_key, function(addResp)
                    if hasFinished then return end

                    -- Step 4: Calibrate clock (Best-effort / Non-blocking)
                    self.client:sendPacket(CommandType.COMM_TIME_CALIBRATE, CommandBuilder.cmd_calibrate_time(), nil, self.aes_key, function(timeResp)
                        if hasFinished then return end
                        
                        -- Step 5: Query features
                        self.client:sendPacket(CommandType.COMM_SEARCHE_DEVICE_FEATURE, CommandBuilder.build_search_device_feature(), nil, self.aes_key, function(featResp)
                            if hasFinished then return end

                            local features = {}
                            if featResp and featResp.data then
                                features = CommandBuilder.parse_device_features(featResp.data) or {}
                                for index, value in ipairs(features) do
                                    print(string.format("[TTLock] Feature %d: %s", index, tostring(value)))
                                end
                            end

                            local function proceedToFinish()
                                self.client:sendPacket(CommandType.COMM_GET_ALARM_ERRCORD_OR_OPERATION_FINISHED, CommandBuilder.cmd_operate_finished(), nil, self.aes_key, function(finResp)
                                    if hasFinished then return end

                                    hasFinished = true
                                    timer.cancel(pairingTimeout)
                                    self:save()

                                    local credentials = {
                                        aes_key        = Helpers.toHex(self.aes_key),
                                        admin_ps       = self.admin_ps,
                                        unlock_key     = self.unlock_key,
                                    }

                                    -- Print out the final credentials
                                    print("--- Final Credentials ---")
                                    print("Admin PS:", credentials.admin_ps)
                                    print("Unlock Key:", credentials.unlock_key)
                                    print("AES Key:", credentials.aes_key)

                                    if callback then callback(true, credentials) end
                                end)
                            end
                            proceedToFinish()
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- ============================================================
-- UNLOCK / LOCK / STATUS / TIME / DEVICE INFO / RESET
-- ============================================================

function TTLock:unlock(callback)
    self:withAuth(callback, function(psFromLock)
        local payload = CommandBuilder.cmd_unlock(psFromLock, self.unlock_key)
        self.client:sendPacket(CommandType.COMM_UNLOCK, payload, nil, self.aes_key, function(response)
            if response and response.data and #response.data > 0 then
                self.battery = response.data:byte(1)
            end
            if callback then callback(response) end
        end)
    end)
end

function TTLock:lock(callback)
    self:withAuth(callback, function(psFromLock)
        local payload = CommandBuilder.cmd_lock(psFromLock, self.unlock_key)
        self.client:sendPacket(CommandType.COMM_FUNCTION_LOCK, payload, nil, self.aes_key, function(response)
            if response and response.data and #response.data > 0 then
                self.battery = response.data:byte(1)
            end
            if callback then callback(response) end
        end)
    end)
end

function TTLock:reset(callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_reset_lock()
        self.client:sendPacket(CommandType.COMM_RESET_LOCK, payload, nil, self.aes_key, function(response)
            if response and response.status == 1 then
                self.aes_key = 0
                self.admin_passcode = 0
                self.admin_ps = 0
                self.unlock_key = 0
                self:save()
            end
            if callback then callback(response) end
        end)
    end)
end

function TTLock:get_locked_status(callback)
    self:withAuth(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_SEARCH_BICYCLE_STATUS, CommandBuilder.cmd_search_status(), nil, self.aes_key, function(response)
            if response and response.status == 1 and response.data then
                self.locked_status = CommandBuilder.parse_search_status(response.data)
            end
            if callback then callback(self.locked_status) end
        end)
    end)
end

function TTLock:calibrate_time(callback)
    self:withAuthOld(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_TIME_CALIBRATE, CommandBuilder.cmd_calibrate_time(), nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:get_device_features(callback)
    self:withAuth(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_SEARCHE_DEVICE_FEATURE, CommandBuilder.build_search_device_feature(), nil, self.aes_key, function(response)
            local features = response and response.data and CommandBuilder.parse_device_features(response.data) or {}
            if callback then callback(features) end
        end)
    end)
end

function TTLock:get_device_info(callback)
    self:withAuth(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_READ_DEVICE_INFO, CommandBuilder.build_get_device_type(), nil, self.aes_key, function(response)
            local devType = response and response.data and CommandBuilder.parse_device_type(response.data) or 0
            if callback then callback(response) end
        end)
    end)
end

function TTLock:get_admin_code(callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.cmd_get_admin_code()
        self.client:sendPacket(CommandType.COMM_GET_ADMIN_CODE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:set_admin_code(new_passcode, callback)
    self:withAuthOld(callback, function(psFromLock)
        if not new_passcode then
            new_passcode = tostring(math.random(1000000, 9999999))
        end
        local payload = CommandBuilder.cmd_set_admin_code(new_passcode)
        self.client:sendPacket(CommandType.COMM_SET_ADMIN_KEYBOARD_PWD, payload, nil, self.aes_key, function(response)
            if response and response.status == 1 then
                self.admin_passcode = new_passcode
                self:save()
            end
            if callback then callback(response) end
        end)
    end)
end

-- ============================================================
-- AUTO-LOCK & SOUND SETTINGS
-- ============================================================

function TTLock:get_autolock_time(callback)
    -- TODO: check the feature first
    self:withAuthOld(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_AUTO_LOCK_MANAGE, CommandBuilder.cmd_get_autolock(), nil, self.aes_key, function(response)
            if response and response.data then
                self.auto_lock_time = CommandBuilder.parse_autolock(response.data)
            end
            if callback then callback(self.auto_lock_time) end
        end)
    end)
end

function TTLock:set_autolock_time(seconds, callback)
    -- TODO: check the feature first
    self:withAuthOld(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_AUTO_LOCK_MANAGE, CommandBuilder.cmd_set_autolock(seconds), nil, self.aes_key, function(response)
            if response and response.status == 1 then
                self.auto_lock_time = seconds
            end
            if callback then callback(response) end
        end)
    end)
end

function TTLock:get_lock_sound(callback)
    -- TODO: check the feature first
    self:withAuthOld(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_AUDIO_MANAGE, CommandBuilder.build_get_lock_sound(), nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:set_lock_sound(enabled, callback)
    -- TODO: check the feature first
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_set_lock_sound(enabled)
        print("[TTLock] Setting lock sound with payload:", Helpers.toHex(payload))
        self.client:sendPacket(CommandType.COMM_AUDIO_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

-- ============================================================
-- PASSAGE MODE
-- ============================================================

function TTLock:get_passage_mode(callback)
    self:withAuthOld(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_CONFIGURE_PASSAGE_MODE, CommandBuilder.build_get_passage_mode(), nil, self.aes_key, function(response)
            local sequence, modes = 0, {}
            if response and response.data then
                sequence, modes = CommandBuilder.parse_passage_modes(response.data)
            end
            if callback then callback(modes) end
        end)
    end)
end

function TTLock:add_passage_mode(pm_type, week_or_day, month, start_hour, end_hour, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_set_passage_mode(pm_type, week_or_day, month, start_hour, end_hour)
        self.client:sendPacket(CommandType.COMM_CONFIGURE_PASSAGE_MODE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:delete_passage_mode(pm_type, week_or_day, month, start_hour, end_hour, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_delete_passage_mode(pm_type, week_or_day, month, start_hour, end_hour)
        self.client:sendPacket(CommandType.COMM_CONFIGURE_PASSAGE_MODE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:clear_passage_mode(callback)
    self:withAuthOld(callback, function(psFromLock)
        self.client:sendPacket(CommandType.COMM_CONFIGURE_PASSAGE_MODE, CommandBuilder.build_clear_passage_mode(), nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

-- ============================================================
-- PIN CODES / PASSCODES
-- ============================================================

function TTLock:get_passcodes(callback)
    self:fetchPaginatedList(CommandType.COMM_PWD_LIST, CommandBuilder.parse_passcodes, callback)
end

function TTLock:add_passcode(pwd_type, passcode, start_date, end_date, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_add_passcode(pwd_type, passcode, start_date, end_date)
        print("[TTLock] Adding passcode with payload:", Helpers.toHex(payload))
        self.client:sendPacket(CommandType.COMM_MANAGE_KEYBOARD_PASSWORD, payload, self.aes_key, nil,  function(response)
            local sequence, modes = 0, {}
            if callback then callback(response) end
        end)
    end)
end

function TTLock:update_passcode(old_passcode, new_passcode, pwd_type, start_date, end_date, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_update_passcode(pwd_type, old_passcode, new_passcode, start_date, end_date)
        self.client:sendPacket(CommandType.COMM_MANAGE_KEYBOARD_PASSWORD, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:delete_passcode(passcode, pwd_type, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_delete_passcode(pwd_type, passcode)
        self.client:sendPacket(CommandType.COMM_MANAGE_KEYBOARD_PASSWORD, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:clear_passcodes(callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_clear_passcodes()
        self.client:sendPacket(CommandType.COMM_MANAGE_KEYBOARD_PASSWORD, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

-- ============================================================
-- IC CARDS
-- ============================================================

function TTLock:get_ic_cards(callback)
    self:fetchPaginatedList(CommandType.COMM_IC_MANAGE, CommandBuilder.parse_ic_cards, callback)
end

function TTLock:add_ic_card(start_date, end_date, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_add_ic_card(nil, start_date, end_date)
        self.client:sendPacket(CommandType.COMM_IC_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:update_ic_card(card_number, start_date, end_date, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_update_ic_card(card_number, start_date, end_date)
        self.client:sendPacket(CommandType.COMM_IC_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:delete_ic_card(card_number, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_delete_ic_card(card_number)
        self.client:sendPacket(CommandType.COMM_IC_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:clear_ic_cards(callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_clear_ic_cards()
        self.client:sendPacket(CommandType.COMM_IC_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

-- ============================================================
-- FINGERPRINTS
-- ============================================================

function TTLock:get_fingerprints(callback)
    self:fetchPaginatedList(CommandType.COMM_FR_MANAGE, CommandBuilder.parse_fingerprints, callback)
end

function TTLock:add_fingerprint(start_date, end_date, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_add_fingerprint()
        self.client:sendPacket(CommandType.COMM_FR_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:update_fingerprint(fp_number, start_date, end_date, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_update_fingerprint(fp_number, start_date, end_date)
        self.client:sendPacket(CommandType.COMM_FR_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:delete_fingerprint(fp_number, callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_delete_fingerprint(fp_number)
        self.client:sendPacket(CommandType.COMM_FR_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

function TTLock:clear_fingerprints(callback)
    self:withAuthOld(callback, function(psFromLock)
        local payload = CommandBuilder.build_clear_fingerprints()
        self.client:sendPacket(CommandType.COMM_FR_MANAGE, payload, nil, self.aes_key, function(response)
            if callback then callback(response) end
        end)
    end)
end

-- ============================================================
-- OPERATION LOG
-- ============================================================

function TTLock:get_operation_log(callback)
    self:withAuthOld(callback, function(psFromLock)
        local all_logs = {}
        local sequence = 65535

        local function fetchNextLogs()
            local payload = CommandBuilder.build_get_operation_log(sequence)
            self.client:sendPacket(CommandType.COMM_GET_OPERATE_LOG, payload, nil, self.aes_key, function(response)
                if not response or not response.data then
                    if callback then callback(all_logs) end
                    return
                end
                
                local next_seq, logs = CommandBuilder.parse_operation_log(response.data)
                for _, log in ipairs(logs) do table.insert(all_logs, log) end

                if next_seq == 0 or #logs == 0 then
                    if callback then callback(all_logs) end
                else
                    sequence = next_seq
                    fetchNextLogs()
                end
            end)
        end
        fetchNextLogs()
    end)
end

return TTLock