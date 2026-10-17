--------------------------------------------------
-- MAIN.LUA - Interfaccia di test TTLock (Refactored)
--------------------------------------------------

local system = system
local json = require("json")
local qrencode = require("plugin.qrcode_api")

local MainView = require("ui.view.menu")
local ActionView = require("ui.view.action")
local QRCodeView = require("ui.view.qrcode")

display.setDefault("background", 0.05, 0.05, 0.1)

-- BLE & Lock Initialization with Permissions
local ble, bt_bridge, lock
if system.getInfo("environment") == "simulator" then
    lock = require("plugin.ble_mock")
else
    ble = require("plugin.ble")
    bt_bridge = require("plugin.BTBridge")
    lock = bt_bridge.new()
    lock:load()

    -- Ensure permissions are requested on Android devices
    if ble.hasPermission and not ble.hasPermission() then
        print("[BLE] Richiesta dei permessi...")
        if ble.requestPermission then 
            ble.requestPermission() 
        end
    end
end

-- Navigation Manager
local currentScene = nil

local function showMainView()
    if currentScene then currentScene:removeSelf() end
    currentScene = MainView.new({
        onSelectAction = function(actionConfig)
            showActionView(actionConfig)
        end,
        onOpenQRCode = function()
            showQRCodeView()
        end
    })
end

function showActionView(config)
    if currentScene then currentScene:removeSelf() end
    currentScene = ActionView.new({
        title = config.title,
        color = config.color,
        lock = lock,
        ble = ble,
        inputs = config.inputs, -- <--- CRITICAL FIX: passes inputs down to ActionView
        qrencode = qrencode,
        showQRPopup = function(text)
            showQRCodePopupOverlay(text, qrencode)
        end,
        actionCallback = config.callback,
        onBack = function()
            showMainView()
        end
    })
end

function showQRCodeView()
    if currentScene then currentScene:removeSelf() end
    currentScene = QRCodeView.new({
        qrencode = qrencode,
        onBack = function()
            showMainView()
        end
    })
end

function showQRCodePopupOverlay(codeText, qrencodeLib)
    local popupGroup = display.newGroup()

    local bgOverlay = display.newRect(
        popupGroup,
        display.contentCenterX,
        display.contentCenterY,
        display.contentWidth * 2,
        display.contentHeight * 2
    )
    bgOverlay:setFillColor(0, 0, 0, 0.85)

    local popupBg = display.newRect(
        popupGroup,
        display.contentCenterX,
        display.contentCenterY,
        280,
        320
    )
    popupBg:setFillColor(0.1, 0.1, 0.15)
    popupBg.strokeWidth = 2
    popupBg:setStrokeColor(0.3, 0.6, 0.9)

    local popupTitle = display.newText({
        parent = popupGroup,
        text = codeText,
        x = display.contentCenterX,
        y = display.contentCenterY - 120,
        fontSize = 14,
        width = 240,
        align = "center"
    })
    popupTitle:setFillColor(1, 1, 1)

    local success, result = qrencodeLib.saveQRCode(codeText, "temp_qr.png", 6)
    if success then
        local qrImage = display.newImage(popupGroup, "temp_qr.png", system.TemporaryDirectory)
        if qrImage then
            qrImage.x = display.contentCenterX
            qrImage.y = display.contentCenterY - 10
            qrImage.width = 160
            qrImage.height = 160
        end
    end

    local closeBtn = UIButton.new({
        x = display.contentCenterX,
        y = display.contentCenterY + 115,
        width = 120,
        height = 34,
        color = {0.7, 0.2, 0.2},
        label = "Chiudi",
        onPress = function()
            popupGroup:removeSelf()
        end
    })
    popupGroup:insert(closeBtn)
end

-- Initial launch on main screen
showMainView()

-- Native back button handler
Runtime:addEventListener("key", function(event)
    if event.keyName == "back" and event.phase == "up" then
        native.setKeyboardFocus(nil)
    end
end)