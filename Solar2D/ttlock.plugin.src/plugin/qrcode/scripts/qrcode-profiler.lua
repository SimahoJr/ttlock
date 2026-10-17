#!/usr/bin/env lua

package.path = package.path .. ";./scripts/?.lua"

local profiler = require("profiler")
local qrencode = require("qrencode")


profiler.start()

for _ = 1, 10 do
  qrencode.qrcode("The quick brown fox jumps over the lazy dog.")
end

profiler.stop()
-- show top 20 lines
profiler.report(20)

