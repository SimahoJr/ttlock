local widget = require("widget")
local M = {}

function M.new(params)
    local x = params.x or display.contentCenterX
    local y = params.y or display.contentHeight - 120
    local w = params.w or display.contentWidth - 40
    local h = params.h or 160

    local group = display.newGroup()
    
    -- Solid black background rectangle
    local bg = display.newRect(group, 0, 0, w, h)
    bg.x = x
    bg.y = y
    bg.anchorX = 0.5
    bg.anchorY = 0.5
    bg:setFillColor(0, 0, 0)
    bg.alpha = 1.0          
    
    -- ScrollView Container with explicit background hiding
    local scrollView = widget.newScrollView({
        x = x,
        y = y,
        width = w - 10,
        height = h - 10,
        scrollWidth = w - 20,
        scrollHeight = 2000,
        horizontalScrollDisabled = true,
        backgroundColor = { 0, 0, 0, 0 },
        hideBackground = true,
        isBounceEnabled = true
    })
    group:insert(scrollView)

    local textObj = display.newText({
        text = "",
        x = 5,
        y = 5,
        width = w - 30,
        font = native.systemFont,
        fontSize = 12,
        align = "left"
    })
    textObj:setFillColor(1, 1, 1)
    textObj.anchorX = 0
    textObj.anchorY = 0
    scrollView:insert(textObj)
    
    local logs = {}
    local maxHistory = 100
    
    function group:log(msg)
        print(msg)
        table.insert(logs, msg)
        if #logs > maxHistory then table.remove(logs, 1) end
        
        textObj.text = table.concat(logs, "\n")
        
        local contentHeight = math.max(textObj.height + 20, scrollView.height)
        scrollView:setScrollHeight(contentHeight)
        scrollView:scrollToPosition({
            y = scrollView.height - contentHeight,
            time = 200
        })
    end
    
    return group
end

return M