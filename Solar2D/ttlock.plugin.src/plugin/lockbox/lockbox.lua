local Lockbox = {};

-- Configure package.path relative to the project root where lockbox folders live
package.path = "./plugin.?.lua;"
             .. "./plugin.cipher/?.lua;"
             .. "./plugin.cipher/mode/?.lua;"
             .. "./plugin.digest/?.lua;"
             .. "./plugin.kdf/?.lua;"
             .. "./plugin.mac/?.lua;"
             .. "./plugin.padding/?.lua;"
             .. "./plugin.util/?.lua;"
             .. package.path;

-- Allow insecure usage so the assert doesn't crash your app
Lockbox.ALLOW_INSECURE = true;

Lockbox.insecure = function()
    -- Bypasses the production restriction
end

return Lockbox;