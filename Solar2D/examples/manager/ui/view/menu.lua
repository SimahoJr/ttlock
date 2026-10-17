local system = system
local widget = require("widget")
local UIButton = require("ui.button")
local helpers = require("plugin.protocol.helpers")
local json = require("json")
local M = {}

function M.new(params)
    local group = display.newGroup()

    -- Fixed Header Title
    local titleText = display.newText({
        text = "TTLock - Menu Principale",
        x = display.contentCenterX,
        y = 45,
        fontSize = 18,
        align = "center"
    })
    titleText:setFillColor(1, 1, 1)
    group:insert(titleText)

    -- Scrollable area positioned safely below the title
    local viewWidth = display.contentWidth - 30
    local scrollView = widget.newScrollView({
        x = display.contentCenterX,
        y = 285,
        width = viewWidth,
        height = display.contentHeight - 65,
        scrollWidth = viewWidth,
        scrollHeight = 1450,
        horizontalScrollDisabled = true,
        backgroundColor = { 0, 0, 0, 0 },
        hideBackground = true,
        isBounceEnabled = false
    })
    group:insert(scrollView)

    local yOffset = 20
    local function addMenuBtn(label, color, callback)
        local btn = UIButton.new({
            x = viewWidth / 2,
            y = yOffset,
            width = viewWidth - 25,
            height = 36,
            color = color,
            label = label,
            onPress = function()
                native.setKeyboardFocus(nil)
                if callback then callback() end
            end
        })
        scrollView:insert(btn)
        yOffset = yOffset + 44
    end

    addMenuBtn("Mostra QR Code", {0.8, 0.4, 0.1}, function()
        if params.onOpenQRCode then params.onOpenQRCode() end
    end)

    local actions = {
        { 
            title = "Cancella dati serratura", 
            color = {0.1, 0.6, 0.2}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                log("[Azione] Cancellazione dei dati...")
                lock:clear(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Connetti", 
            color = {0.2, 0.4, 0.8}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                log("[Azione] Associazione...")
                updateStatus("Associazione...", {1, 0.8, 0.2})
                lock:pair(function(success, err)
                    if success then
                        log("[Successo] Associato!")
                        updateStatus("Associato e pronto", {0.3, 1, 0.3})
                    else
                        log("[Errore]: " .. tostring(err))
                        updateStatus("Fallito", {1, 0.3, 0.3})
                    end
                end)
            end
        },
        { 
            title = "Sblocca serratura", 
            color = {0.1, 0.6, 0.2}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                log("[Azione] Sblocco...")
                lock:unlock(function(res) log("[Risultato]: " .. json.encode(res or {}) .. " | Batteria: " .. tostring(lock.battery) .. "%") end)
            end
        },
        { 
            title = "Blocca serratura", 
            color = {0.6, 0.2, 0.2}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                log("[Azione] Blocco...")
                lock:lock(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Sincronizza orologio", 
            color = {0.5, 0.3, 0.6}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:calibrate_time(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Leggi stato serratura", 
            color = {0.3, 0.5, 0.5}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_locked_status(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Leggi funzioni dispositivo", 
            color = {0.3, 0.5, 0.5}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_device_features(function(features) log("[Risultato]: " .. json.encode(features or {})) end)
            end
        },
        { 
            title = "Leggi info dispositivo", 
            color = {0.3, 0.5, 0.5}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_device_info(function(devType) log("[Risultato]: " .. tostring(devType)) end)
            end
        },
        { 
            title = "Leggi tempo chiusura automatica", 
            color = {0.3, 0.5, 0.5}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_autolock_time(function(seconds) log("[Risultato]: " .. tostring(seconds)) end)
            end
        },
        { 
            title = "Imposta chiusura automatica", 
            color = {0.3, 0.5, 0.5}, 
            inputs = {
                { key = "seconds", label = "Secondi:", placeholder = "Es. 10" }
            }, 
            callback = function(lock, log, inputs, updateStatus)
                local seconds = tonumber(inputs.seconds)
                if not seconds or seconds < 1 then
                    log("[Errore] Inserisci un numero valido di secondi.")
                    return
                end
                lock:set_autolock_time(seconds, function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Leggi suono serratura", 
            color = {0.4, 0.4, 0.5}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_lock_sound(function(soundStatus) log("[Risultato]: " .. tostring(soundStatus)) end)
            end
        },
        { 
            title = "Imposta suono serratura", 
            color = {0.4, 0.4, 0.5}, 
            inputs = {
                { key = "sound", label = "Stato (1/0 o on/off):", placeholder = "1" }
            }, 
            callback = function(lock, log, inputs, updateStatus)
                local input = string.lower(tostring(inputs.sound))
                local enable = (input == "1" or input == "true" or input == "on")
                lock:set_lock_sound(enable, function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Leggi modalità passaggio", 
            color = {0.4, 0.5, 0.3}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_passage_mode(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Cancella modalità passaggio", 
            color = {0.7, 0.3, 0.3}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:clear_passage_mode(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Elenca codici di accesso", 
            color = {0.7, 0.5, 0.1}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_passcodes(function(codes) log("[Risultato] Codici: " .. json.encode(codes or {})) end)
            end
        },
        { 
            title = "Aggiungi codice di accesso", 
            color = {0.7, 0.5, 0.1}, 
            inputs = {
                { key = "Name", label = "Nome:", placeholder = "Carrubi St.1" },
                { key = "code", label = "Codice (4-9 cifre):", placeholder = "123456" },
                { key = "type", label = "Tipo (1=Perm):", placeholder = "1" },
                { key = "startDate", label = "Inizio (YYYYMMDDHHMM):", placeholder = "202601010000" },
                { key = "endDate", label = "Fine (YYYYMMDDHHMM):", placeholder = "000000000000" }
            }, 
            callback = function(lock, log, inputs, updateStatus, qrencode, showQRPopup)
                local code = inputs.code
                local passcodeType = tonumber(inputs.type) or 1
                local startDate = (inputs.startDate and inputs.startDate ~= "") and inputs.startDate or "202601010000"
                local endDate = (inputs.endDate and inputs.endDate ~= "") and inputs.endDate or "000000000000"
                local Name = (inputs.Name and inputs.Name ~= "") and inputs.Name or "Carrubi Stanza 1"

                if not code or not code:match("^%d+$") or #code < 4 or #code > 9 then
                    log("[Errore] Il codice deve contenere da 4 a 9 cifre numeriche.")
                    return
                end

                lock:add_passcode(passcodeType, code, startDate, endDate, function(res)
                    log("[Risultato]: " .. json.encode(res or {}))

                    if res and res.status == 1 then
                        local secrets = {
                            lockId = 12343,
                            lockMac = lock.mac_address,
                            key = helpers.toHex(lock.aes_key),
                            adminPassword = lock.admin_ps,
                            unlockKey = lock.unlock_key,
                            lockVersion = lock.protocol_version,
                            battery = -1,
                            aptName = "Carrubi",
                            stanzaName = "St. 1",
                            passwordExpiry = endDate
                        }
                        local safeName = string.gsub(tostring(Name or "lock"), "[^%w]", "_")
                        local timestamp = os.date("%y%m%d_%H%M%S")
                        -- local filename = "qr_" .. tostring(code or "unknown") .. "_" .. safeName .. "_" .. timestamp .. ".png"
                        local filename = "qr_" .. tostring(code or "unknown") .. "_" .. safeName .. "_" .. ".png"
                        local qrPayload = json.encode(secrets)
                        local encodedData = helpers.urlEncode(qrPayload)
                        -- This is the exact string encoded into the QR code graphic
                        local qrContent = "client://passcode?data=" .. encodedData
                        -- print("[QR Content Check]: " .. qrContent)
                        if qrencode and qrencode.saveQRCode then
                            -- qrencode.saveQRCode(json.encode(qrContent), filename, 8)
                            qrencode.saveQRCode(qrPayload, filename, 8)
                        end

                        -- if showQRPopup then
                        --     showQRPopup(Name)
                        -- end
                    end
                end)
            end
        },
        { 
            title = "Elimina codice di accesso", 
            color = {0.8, 0.3, 0.1}, 
            inputs = {
                { key = "code", label = "Codice da eliminare:", placeholder = "123456" },
                { key = "type", label = "Tipo codice:", placeholder = "1" }
            }, 
            callback = function(lock, log, inputs, updateStatus)
                local code = inputs.code
                local passcodeType = tonumber(inputs.type) or 1
                
                lock:delete_passcode(code, passcodeType, function(res) 
                    log("[Risultato]: " .. json.encode(res or {})) 
                    
                    -- Check if deletion was successful
                    if res and res.status == 1 then
                        local safeName = string.gsub(tostring(inputs.Name or "lock"), "[^%w]", "_")
                        local prefix = "qr_" .. tostring(code) .. "_" .. safeName
                        
                        -- Use LuaFileSystem to find and remove the matching QR file
                        local lfs = require("lfs")
                        local docDir = system.pathForFile("", system.DocumentsDirectory)
                        
                        for file in lfs.dir(docDir) do
                            -- Check if the filename starts with our target prefix and ends with .png
                            if string.sub(file, 1, string.len(prefix)) == prefix and string.match(file, "%.png$") then
                                local filePath = system.pathForFile(file, system.DocumentsDirectory)
                                os.remove(filePath)
                                log("[QR Cleanup] Removed file: " .. file)
                            end
                        end
                    end
                end)
            end
        },
        { 
            title = "Elimina tutti i codici", 
            color = {0.8, 0.2, 0.2}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:clear_passcodes(function(res) 
                    log("[Risultato]: " + json.encode(res or {})) 
                    
                    if res and res.status == 1 then
                        local lfs = require("lfs")
                        local docDir = system.pathForFile("", system.DocumentsDirectory)
                        
                        for file in lfs.dir(docDir) do
                            -- Match any file starting with qr_ and ending with .png
                            if string.sub(file, 1, 3) == "qr_" and string.match(file, "%.png$") then
                                local filePath = system.pathForFile(file, system.DocumentsDirectory)
                                os.remove(filePath)
                                log("[QR Cleanup] Removed file: " + file)
                            end
                        end
                    end
                end)
            end
        },
        { 
            title = "Elenca tessere RFID", 
            color = {0.2, 0.6, 0.6}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_ic_cards(function(cards) log("[Risultato]: " .. json.encode(cards or {})) end)
            end
        },
        { 
            title = "Aggiungi tessera RFID", 
            color = {0.2, 0.6, 0.6}, 
            inputs = {
                { key = "startDate", label = "Inizio (opzionale):", placeholder = "202001010000" },
                { key = "endDate", label = "Fine (opzionale):", placeholder = "000000000000" }
            }, 
            callback = function(lock, log, inputs, updateStatus)
                local startDate = (inputs.startDate ~= "") and inputs.startDate or nil
                local endDate = (inputs.endDate ~= "") and inputs.endDate or nil
                log("[Azione] Avvicina la tessera RFID...")
                lock:add_ic_card(startDate, endDate, function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Elimina tessere RFID", 
            color = {0.8, 0.2, 0.2}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:clear_ic_cards(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Leggi registro operazioni", 
            color = {0.5, 0.5, 0.5}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:get_operation_log(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Ripristina serratura", 
            color = {0.9, 0.1, 0.1}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:reset(function(res) log("[Risultato]: " .. json.encode(res or {})) end)
            end
        },
        { 
            title = "Disconnetti", 
            color = {0.5, 0.2, 0.2}, 
            inputs = nil, 
            callback = function(lock, log, inputs, updateStatus)
                lock:disconnect()
                log("[Azione] Disconnesso.")
                updateStatus("Disconnesso", {1, 0.3, 0.3})
            end
        }
    }

    for _, act in ipairs(actions) do
        addMenuBtn(act.title, act.color, function()
            if params.onSelectAction then
                params.onSelectAction(act)
            end
        end)
    end

    return group
end

return M