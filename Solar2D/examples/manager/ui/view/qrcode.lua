local widget = require("widget")
local UIButton = require("ui.button")
local lfs = require("lfs")
local M = {}

function M.new(params)
    local qrencode = params.qrencode
    local group = display.newGroup()

    local titleText = display.newText({
        text = "Codici QR Salvati",
        x = display.contentCenterX,
        y = 30,
        fontSize = 18,
        align = "center"
    })
    titleText:setFillColor(1, 1, 1)
    group:insert(titleText)

    local scrollW = display.contentWidth - 40
    local scrollView = widget.newScrollView({
        x = display.contentCenterX,
        y = 180,
        width = display.contentWidth - 25,
        height = display.contentHeight - 240,
        scrollWidth = scrollW,
        scrollHeight = 600,
        horizontalScrollDisabled = true,
        backgroundColor = { 0, 0, 0, 0 },
        hideBackground = true,
        isBounceEnabled = false
    })
    group:insert(scrollView)

    local function showQRPopup(filename)
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
            text = filename,
            x = display.contentCenterX,
            y = display.contentCenterY - 120,
            fontSize = 11,
            width = 240,
            align = "center"
        })
        popupTitle:setFillColor(1, 1, 1)

        local qrImage = display.newImage(popupGroup, filename, system.DocumentsDirectory)
        if qrImage then
            qrImage.x = display.contentCenterX
            qrImage.y = display.contentCenterY - 10
            qrImage.width = 160
            qrImage.height = 160
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

    local qrFiles = {}
    local path = system.pathForFile("", system.DocumentsDirectory)
    if path then
        for file in lfs.dir(path) do
            if file:match("%.png$") then
                table.insert(qrFiles, file)
            end
        end
    end

    local yOffset = 25
    if #qrFiles == 0 then
        local emptyText = display.newText({
            parent = scrollView,
            text = "Nessun QR code salvato.",
            x = scrollW / 2,
            y = yOffset,
            fontSize = 14,
            align = "center"
        })
        emptyText:setFillColor(0.7, 0.7, 0.7)
    else
        for _, filename in ipairs(qrFiles) do
            local btn = UIButton.new({
                x = scrollW / 2,
                y = yOffset,
                width = scrollW - 10,
                height = 36,
                color = {0.2, 0.4, 0.6},
                label = filename,
                onPress = function()
                    showQRPopup(filename)
                end
            })
            scrollView:insert(btn)
            yOffset = yOffset + 44
        end
    end

    local backBtn = UIButton.new({
        x = display.contentCenterX,
        y = display.contentHeight - 35,
        width = display.contentWidth - 40,
        height = 38,
        color = {0.3, 0.3, 0.3},
        label = "Indietro",
        onPress = function()
            if params.onBack then params.onBack() end
        end
    })
    group:insert(backBtn)

    return group
end

return M