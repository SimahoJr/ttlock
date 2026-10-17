local M = {}

function M.new(params)
    local btn = display.newRect(0, 0, params.width or 220, params.height or 36)
    btn:setFillColor(unpack(params.color or {0.2, 0.4, 0.8}))
    
    local txt = display.newText({
        text = params.label or "Button",
        x = 0, y = 0,
        fontSize = 14,
        font = native.systemFont
    })
    txt:setFillColor(1, 1, 1)

    local group = display.newGroup()
    group:insert(btn)
    group:insert(txt)
    
    group.x = params.x or 0
    group.y = params.y or 0

    btn:addEventListener("touch", function(event)
        if event.phase == "ended" and params.onPress then
            params.onPress()
        end
        return true
    end)

    return group
end

return M