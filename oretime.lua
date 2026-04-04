addon.name      = 'oretime';
addon.author    = 'Waldron';
addon.version   = '1.0';
addon.desc      = 'Alerts when the moon phase is right for digging elemental ore.';
addon.commands  = {'/oretime'};

require('common');
local chat = require('chat');

-- Moon percent range for ore digging
local MOON_MIN = 7;
local MOON_MAX = 21;

-- 1 Vana'diel day = 57.6 real minutes = 0.96 real hours
local VANA_DAY_REAL_HOURS = 57.6 / 60;

-- Track the last Vana'diel day to detect day changes
local last_day = 0;

-- Memory pointer for Vana'diel time
local vana_pointer = nil;

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function is_logged_in()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    return player ~= nil and player:GetLoginStatus() == 2;
end

local function get_vana_timestamp()
    if (vana_pointer == nil) then
        vana_pointer = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0x34, 0);
    end
    if (vana_pointer == 0) then
        return 0;
    end
    local ptr = ashita.memory.read_uint32(vana_pointer);
    local raw = ashita.memory.read_uint32(ptr + 0x0C);
    return (raw + 92514960) * 25;
end

local function get_vana_total_days()
    return math.floor(get_vana_timestamp() / 86400);
end

local function moon_percent_for_day(total_days)
    local mphase = (total_days + 26) % 84;
    local mpercent = ((42 - mphase) * 100) / 42;
    if (mpercent < 0) then
        mpercent = math.abs(mpercent);
    end
    return math.floor(mpercent + 0.5);
end

local function get_vana_day_fraction()
    local ts = get_vana_timestamp();
    local day_seconds = ts % 86400;
    return day_seconds / 86400;
end

local function format_real_time(hours)
    if (hours < 1) then
        return string.format('%d min', math.floor(hours * 60 + 0.5));
    end
    return string.format('%.1f hrs', hours);
end

local function check_moon()
    local total_days = get_vana_total_days();
    local moon_pct = moon_percent_for_day(total_days);
    local in_range = moon_pct >= MOON_MIN and moon_pct <= MOON_MAX;
    local fraction = get_vana_day_fraction();

    if (in_range) then
        -- Count days remaining in the window (including rest of today)
        local days_left = 0;
        for i = 1, 84 do
            local future_pct = moon_percent_for_day(total_days + i);
            if (future_pct < MOON_MIN or future_pct > MOON_MAX) then
                days_left = i;
                break;
            end
        end
        local real_hours = (days_left - fraction) * VANA_DAY_REAL_HOURS;
        print(chat.header(addon.name)
            :append(chat.success('Time to dig for ore! '))
            :append(chat.message('Moon: ' .. tostring(moon_pct) .. '% | '
                .. days_left .. ' days left (~' .. format_real_time(real_hours) .. ' real)')));
    else
        -- Count days until the window opens
        local days_until = 0;
        for i = 1, 84 do
            local future_pct = moon_percent_for_day(total_days + i);
            if (future_pct >= MOON_MIN and future_pct <= MOON_MAX) then
                days_until = i;
                break;
            end
        end
        local real_hours = (days_until - fraction) * VANA_DAY_REAL_HOURS;
        print(chat.header(addon.name)
            :append(chat.message('Moon: ' .. tostring(moon_pct) .. '% (need ' .. MOON_MIN .. '-' .. MOON_MAX .. '%) | '
                .. days_until .. ' days away (~' .. format_real_time(real_hours) .. ' real)')));
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

-- On login / zone-in, check the moon
ashita.events.register('packet_in', 'oretime_packet_in_cb', function (e)
    if (e.id == 0x000A) then
        -- Delay slightly so the game state is ready
        ashita.tasks.once(2, function ()
            last_day = get_vana_total_days();
            check_moon();
        end);
    end
end);

-- Poll every frame for day changes
ashita.events.register('d3d_present', 'oretime_present_cb', function ()
    if (not is_logged_in()) then
        return;
    end

    local current_day = get_vana_total_days();
    if (last_day == 0) then
        last_day = current_day;
        return;
    end

    if (current_day ~= last_day) then
        last_day = current_day;
        check_moon();
    end
end);

-- Chat commands
ashita.events.register('command', 'oretime_command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/oretime')) then
        return;
    end
    e.blocked = true;

    if (#args >= 2 and args[2]:any('check')) then
        check_moon();
        return;
    end

    -- Default: show status
    check_moon();
end);

-- Load message
ashita.events.register('load', 'oretime_load_cb', function ()
    print(chat.header(addon.name):append(chat.message('Loaded. Use /oretime to check moon status.')));
end);

-- Unload message
ashita.events.register('unload', 'oretime_unload_cb', function ()
    print(chat.header(addon.name):append(chat.message('Unloaded.')));
end);
