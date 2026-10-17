local qrencode = require("plugin.qrcode.qrencode")
local M = {}

function M.saveQRCode(text, filename, moduleSize)
    filename = filename or "qrcode.png"
    moduleSize = moduleSize or 8

    local ok, matrix = qrencode.qrcode(text)

    if not ok then
        return false, matrix
    end

    local size = #matrix
    local quietZone = 4
    local totalSize = (size + quietZone * 2) * moduleSize

    local group = display.newGroup()
    group.x = -totalSize
    group.y = -totalSize

    local background = display.newRect(
        group,
        totalSize / 2,
        totalSize / 2,
        totalSize,
        totalSize
    )
    background:setFillColor(1, 1, 1)

    for x = 1, size do
        for y = 1, #matrix[x] do
            if matrix[x][y] > 0 then
                local pixel = display.newRect(
                    group,
                    (y - 1 + quietZone) * moduleSize
                        + moduleSize / 2,
                    (x - 1 + quietZone) * moduleSize
                        + moduleSize / 2,
                    moduleSize,
                    moduleSize
                )
                pixel:setFillColor(0, 0, 0)
            end
        end
    end

    display.save(group, {
        filename = filename,
        baseDir = system.DocumentsDirectory,
        captureOffscreenArea = true,
        backgroundColor = { 1, 1, 1, 1 }
    })

    display.remove(group)

    return true, system.pathForFile(
        filename,
        system.DocumentsDirectory
    )
end

return M
