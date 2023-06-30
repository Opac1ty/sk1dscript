---
--- Dependencies
---

util.require_natives(1681379138, "g-uno")
local crypto = require("crypto")
local version_crc
local vars = {}
local ROOT = menu.my_root()
local SHADOW_ROOT = menu.shadow_root()

---
--- Some (useful) functions
---

local function table_nand(t1, t2)
    local t3 = {}
    for i,v in t1 do
        for j,w in t2 do
            if v == w then continue 2 end
        end
        t3[i] = v
    end
    return t3
end

local function is_sk1d_user(pid)
    if players.exists(pid) then
        for _,cmd in menu.player_root(pid):getChildren() do
            if string.find(lang.get_localised(cmd.menu_name), "Classification") then
                for _,class in cmd:getChildren() do
                    if string.find(lang.get_localised(class.menu_name), "Sk1d User") then
                        return class
                    end
                end
                break
            end
        end
    end
    return false
end

local function get_toast_settings(var_name)
    return vars[var_name.."_toast"] ? vars[var_name.."_toast"] : TOAST_DEFAULT
end

---
--- Update System
---

local function get_version_hash()
    if not version_crc then
        local file = io.open(filesystem.scripts_dir()..SCRIPT_RELPATH, "r")
        version_crc = crypto.crc32(file:read("a*"))
        file:close()
    end
    return version_crc
end

local function update_script(body)
    local file = io.open(filesystem.scripts_dir()..SCRIPT_RELPATH, "w+")
    if file then
        file:write(body)
        file:close()
        util.yield_once()
        util.restart_script()
        return util.toast("Updated script to the latest version")
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
                local file = io.open(filesystem.scripts_dir()..SCRIPT_RELPATH, "r")
                if crypto.crc32(body) ~= get_version_hash() then
                    ROOT:getChildren()[1]:attachAfter(SHADOW_ROOT:action("Update Available!", {}, "Looks like a new update is available, click me to download it", function()
                        update_script(body)
                    end))
                end
                file:close()
            end
        end)
        async_http.dispatch()
    else
        if not SCRIPT_SILENT_START then
            util.toast("Note: You have disabled access to internet from this script, you'll no longer get updates.")
        end
    end
end

---
--- Online
---

local ONLINE = ROOT:list("Online")
local ALL_PLAYERS = ONLINE:list("All Players")

ONLINE:toggle("Sk1d User Identification", {}, "Tells you if any other player has this identification enabled (this feature uses script events)", function(state)
    vars["identification"] = state
    util.create_tick_handler(function()
        for i=0,GET_NUMBER_OF_EVENTS(1)-1 do
            if GET_EVENT_AT_INDEX(1, i) == 174 then
                local event = memory.alloc()
                GET_EVENT_DATA(1, i, event, 4)
                if memory.read_int(event) == util.joaat("Sk1dUser") then
                    local pid = memory.read_int(event + 8)
                    if not is_sk1d_user(pid) then
                        players.add_detection(pid, "Sk1d User", get_toast_settings("detection"))
                    end
                end
            end
        end
        return vars["identification"]
    end)
    util.trigger_script_event(util.get_session_players_bitflag(), {util.joaat("Sk1dUser"), players.user()})
end)

---
--- Settings
---

local SETTINGS = ROOT:list("Settings")
local CREDITS = SETTINGS:list("Credits")
local TOAST_SETTINGS = SETTINGS:list("Toast Settings")

local credits = {
    {"Stand", "Providing the mod menu you're using to run this script"..(menu.get_edition() < 3 ? " (consider upgrading)." : "."), "https://std.gg/"},
    {"NativeDB", "Providing informations on every natives used in this script.", "https://nativedb.dotindustries.dev/"},
    {"GTAV Decompiled Scripts", "Providing decompiled GTA V scripts to help with reverse engineering (too many forks running over github).", "https://github.com/Primexz/GTAV-Decompiled-Scripts"},
    {"You...", "Thanks for using the script."}
}

for _,credit in credits do
    if #credit == 2 then
        CREDITS:action(credit[1], {}, credit[2], function() end)
    elseif #credit > 2 then
        CREDITS:hyperlink(credit[1], credit[3], credit[2])
    end
end

TOAST_SETTINGS:list_select("Detection", {}, "Changes the way it notifies you when someone receives a new detection", 
    {
        [TOAST_DEFAULT] = {"Default"},
        [TOAST_LOGGER] = {"Logger (Console & Log File)"}, 
        [TOAST_ALL] = {"All (Default, Console & Log File)"},
        [TOAST_ABOVE_MAP] = {"Above Map"},
        [TOAST_CONSOLE] = {"Console"},
        [TOAST_FILE] = {"Log File"},
        [TOAST_WEB] = {"Web"},
        [TOAST_CHAT] = {"Chat"},
        [TOAST_CHAT_TEAM] = {"Chat Team"}
    },
    TOAST_DEFAULT, function(value)
    vars["detection_toast"] = value
end)

SETTINGS:readonly("Version CRC", get_version_hash())

---
--- Players Features
---

local player_features = {
    ["Utils"] = {
        {
            menu.action,
            {"Mark as Sk1d User", {}, "Marks player as Sk1d User", function(pid)
                if not is_sk1d_user(pid) then
                    players.add_detection(pid, "Sk1d User", get_toast_settings("detection"))
                else
                    util.toast("Player is already marked as Sk1d User")
                end
            end}
        },
        {
            menu.action,
            {"Unmark as Sk1d User", {}, "Unmarks player as Sk1d User", function(pid)
                local class = is_sk1d_user(pid)
                if class then
                    class:trigger()
                else
                    util.toast("Player is not a Sk1d User")
                end
            end}
        }
    }
}

local function init_player_features(_ROOT, pid) -- Needs a lot of improvements but working atm
    local last_list = _ROOT
    local function recursive_check(_tbl)
        for id,value in _tbl do
            if type(id) == "string" then
                last_list = last_list:list(id)
            end
            if type(id) == "number" and type(value) == "table" then
                if value[1] then
                    if type(value[1]) == "function" then
                        local new_value = {{},{}}
                            for i,v in value[2] do
                                new_value[2][i] = v
                                if type(v) ~= "function" then continue end
                                if pid then
                                    new_value[2][i] = function()
                                        v(pid)
                                    end
                                    continue
                                end
                                new_value[2][i] = function()
                                    local player_list = players.list_except((vars["exclude_self"] or false), (vars["exclude_friends"] or false), (vars["exclude_crew"] or false), (vars["exclude_org"] or false))
                                    for _,_pid in (vars["exclude_strangers"]) ? table_nand(player_list, players.list(false, false, true)) : player_list do
                                        v(_pid)
                                    end
                                end
                            end
                        value[1](last_list, table.unpack(new_value[2])) 
                    end
                end
            end
            if type(value) == "table"  then
                recursive_check(value)
            end
        end
    end
    recursive_check(player_features)
end

--- Excludes

local EXCLUDES = ALL_PLAYERS:list("Excludes")

EXCLUDES:toggle("Exclude Self", {}, "", function(state)
    vars["exclude_self"] = state
end)

EXCLUDES:toggle("Exclude Friends", {}, "", function(state)
    vars["exclude_friends"] = state
end)

EXCLUDES:toggle("Exclude Crew Members", {}, "", function(state)
    vars["exclude_crew"] = state
end)

EXCLUDES:toggle("Exclude Organisation Members", {}, "", function(state)
    vars["exclude_org"] = state
end)

EXCLUDES:toggle("Exclude Strangers", {}, "", function(state)
    vars["exclude_strangers"] = state
end)

init_player_features(ALL_PLAYERS)

---
--- Threads and shits
---

players.add_command_hook(function(pid, PLAYER_ROOT)
    PLAYER_ROOT:divider(SCRIPT_NAME)
    init_player_features(PLAYER_ROOT, pid)
    if vars["identification"] then
        util.trigger_script_event(1 << pid, {util.joaat("Sk1dUser"), players.user()})
    end
end)

check_update()
util.keep_running()