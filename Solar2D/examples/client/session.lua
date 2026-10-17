local json = require("json")

local Session = {}
Session.filename = "session.json"
Session.username = ""
Session.password = ""

-- Load session data or create with empty values if missing
function Session.load()
    local path = system.pathForFile(Session.filename, system.DocumentsDirectory)
    local file = io.open(path, "r")
    
    if file then
        local contents = file:read("*a")
        io.close(file)
        
        local ok, data = pcall(json.decode, contents)
        if ok and data then
            Session.username = data.username or ""
            Session.password = data.password or ""
            print("[Session] session.json loaded.")
            return true
        end
    end
    
    Session.username = ""
    Session.password = ""
    Session.save()
    print("[Session] session.json created with empty values.")
    return true
end

-- Save current username and password to file
function Session.save()
    local path = system.pathForFile(Session.filename, system.DocumentsDirectory)
    local file = io.open(path, "w")
    
    if file then
        local data = {
            username = Session.username or "",
            password = Session.password or ""
        }
        file:write(json.encode(data))
        io.close(file)
        print("[Session] Session saved successfully.")
        return true
    end
    print("[Session] Error: Could not save session.")
    return false
end

-- Clear session credentials and update file
function Session.clear()
    Session.username = ""
    Session.password = ""
    Session.save()
    print("[Session] Session cleared.")
end

-- Automatically load on require
Session.load()

return Session