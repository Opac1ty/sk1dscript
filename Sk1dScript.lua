---
--- Dependencies
---

util.require_natives(1681379138, "g-uno")
local crypto = require("crypto")
local ROOT = menu.my_root()
local SHADOW_ROOT = menu.shadow_root()

---
--- Update System
---

local function update_script(body)
    local file = io.open(filesystem.scripts_dir()..SCRIPT_RELPATH, "w+")
    if file then
        file:write(body)
        file:close()
        util.yield_once()
        util.restart_script()
    end
    return util.toast("Failed to update script")
end

local function check_update()
    if async_http.have_access() then
        for _,cmd in ROOT:getChildren() do
            if string.find(cmd.menu_name, "Update") then
                return
            end
        end
        async_http.init("raw.githubusercontent.com", "/Opac1ty/sk1dscript/main/Sk1dScript.lua", function(body, headers, status)
            if status == 200 then
                if crypto.md5(body) ~= crypto.md5(soup.string.fromFile(filesystem.scripts_dir()..SCRIPT_RELPATH)) then
                    ROOT:getChildren()[1]:attachAfter(SHADOW_ROOT:action("Update Available!", {}, "Looks like a new update is available, click me to download it", function()
                        update_script(body)
                    end))
                    return true
                end
            end
        end)
        async_http.dispatch()
    else
        if not SCRIPT_SILENT_START then
            util.toast("Note: You have disabled access to internet from this script, you'll no longer get updates.")
        end
    end
end

check_update()

util.keep_running()