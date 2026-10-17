local UIButton = require("ui.button")
local UIConsole = require("ui.console")
local UIInput = require("ui.input")
local M = {}

function M.new(params)
    local group = display.newGroup()

    -- 1. Action Title
    local titleText = display.newText({
        text = params.title or "Azione",
        x = display.contentCenterX,
        y = 20,
        fontSize = 15,
        align = "center"
    })
    titleText:setFillColor(1, 1, 1)
    group:insert(titleText)

    -- 2. Status Bar
    local statusText = display.newText({
        text = "Stato: Pronto",
        x = display.contentCenterX,
        y = 42,
        fontSize = 12,
        align = "center"
    })
    statusText:setFillColor(1, 0.8, 0.2)
    group:insert(statusText)

    local function updateStatus(text, color)
        statusText.text = "Stato: " .. text
        if color then statusText:setFillColor(unpack(color)) end
    end

    -- 3. Compact Dynamic Inputs
    local inputFields = {}
    local currentY = 60

    if params.inputs and #params.inputs > 0 then
        for _, inputConfig in ipairs(params.inputs) do
            local lbl = display.newText({
                text = inputConfig.label or "Valore:",
                x = 20,
                y = currentY,
                fontSize = 11,
                align = "left"
            })
            lbl.anchorX = 0
            lbl:setFillColor(0.9, 0.9, 0.9)
            group:insert(lbl)

            currentY = currentY + 16

            local field = UIInput.new({
                x = display.contentCenterX,
                y = currentY + 11,
                width = display.contentWidth - 40,
                height = 26,
                placeholder = inputConfig.placeholder or "Inserisci valore..."
            })
            table.insert(inputFields, { key = inputConfig.key, field = field })
            group:insert(field)
            
            currentY = currentY + 34
        end
    end

    -- Collect key-value inputs
    local function getInputValues()
        local values = {}
        for _, item in ipairs(inputFields) do
            values[item.key] = item.field.text
        end
        return values
    end

    -- 4. Log Console View (Adaptive height)
    local consoleY = math.max(currentY + 5, 70)
    local consoleHeight = display.contentHeight - consoleY - 85

    local console = UIConsole.new({
        x = display.contentCenterX,
        y = consoleY + consoleHeight / 2,
        w = display.contentWidth - 30,
        h = consoleHeight
    })
    group:insert(console)

    local function log(msg)
        console:log(msg)
    end

    -- 5. Submit and Back Buttons at the bottom
    local submitBtn = UIButton.new({
        x = display.contentCenterX,
        y = display.contentHeight - 48,
        width = display.contentWidth - 40,
        height = 30,
        color = {0.2, 0.6, 0.3},
        label = "Esegui",
        onPress = function()
            native.setKeyboardFocus(nil)
            if params.actionCallback then
                params.actionCallback(
                    params.lock, 
                    log, 
                    getInputValues(), 
                    updateStatus, 
                    params.qrencode, 
                    params.showQRPopup
                )
            end
        end
    })
    group:insert(submitBtn)

    local backBtn = UIButton.new({
        x = display.contentCenterX,
        y = display.contentHeight - 16,
        width = display.contentWidth - 40,
        height = 26,
        color = {0.3, 0.3, 0.3},
        label = "Indietro",
        onPress = function()
            native.setKeyboardFocus(nil)
            if params.onBack then params.onBack() end
        end
    })
    group:insert(backBtn)

    -- Safe removeSelf overriding to prevent recursion
    local oldRemoveSelf = group.removeSelf
    function group:removeSelf()
        for _, item in ipairs(inputFields) do
            if item.field and item.field.removeSelf then
                item.field:removeSelf()
            end
        end
        oldRemoveSelf(self)
    end

    return group
end

return M