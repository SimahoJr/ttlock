-- ui/input.lua
local M = {}

function M.new(params)
    local field = native.newTextField(params.x or display.contentCenterX, params.y or 50, params.width or 200, params.height or 32)
    field.inputType = params.inputType or "default"
    field.placeholder = params.placeholder or "Enter text..."
    return field
end

return M