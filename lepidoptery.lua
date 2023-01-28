-- Lepidoptery
-- @sixolet
--
-- Your sonic butterfly collection.
--
-- Lepidoptery requires a Grid
-- and some way of inputting
-- sound into Norns.
--
-- Make some sounds. Use the
-- grid to pin down the sound
-- at any given moment. Your
-- butterflies are well-
-- organized, of course. Each
-- row has a particular color,
-- with the higher frequencies
-- toward the top of the grid,
-- and the lower toward the
-- bottom, and each column has
-- a particular shape, going
-- from long butterflies on
-- the left to very short
-- butterflies on the right.
-- The butterflies in the
-- middle are a bit more
-- fluttery.
-- 
-- As you are the
-- lepidopterist, you can
-- reorganize your butterfly
-- collection in the params,
-- deciding exactly what color
-- each row should be, or
-- exactly what shape each
-- column. should be.
--
-- If you do not have a grid
-- you can use a MIDI keyboard.
-- Columns 2 through 14 are
-- mapped to the 12 notes
-- and rows are mapped to
-- octaves 1 through 8.
--
-- K2 allows removing 
-- butterflies.
--
-- K3 + a butterfly + empty
-- allows copying the pattern
-- to a different shape and
-- color.
--
-- K3 + a butterfly + E3
-- adjusts the volume of 
-- the butterfly.


engine.name = "ButterflyCollection"

local deque = require('lib/container/deque')

g = grid.connect()

local LENGTH = 2;

local clearing = false
local selecting = false
local recording = false
local selected = nil
local todo = deque.new()
local next_todo = deque.new()

local function n(s, i)
    return "butterfly_" .. s .. "_" .. i
end

function adjust_butterfly(i)
    local playing = params:get(n("playing", i))

    if playing < 1 then return end

    local memory = params:get(n("memory", i))
    local flutter = params:get(n("flutter", i))
    local amp = params:get(n("amp", i))
    local attack = params:get(n("attack", i))
    --local release = params:get(n("release", i))
    local size = memory / flutter
    local variation = memory - size
    local pan = params:get(n("pan", i))
    engine.fly(i - 1, size, amp, attack, variation, pan)
end

function adjust_filters(i)
    local low = params:get("lowpass_" .. i)
    local low_q = params:get("low_q_" .. i)
    local high = params:get("highpass_" .. i)
    local high_q = params:get("high_q_" .. i)
    engine.filter(i - 1, low, low_q, high, high_q)
end

function key(num, z)
    if num == 1 then
        recording = z > 0
    end
    if num == 2 then
        clearing = z > 0
    end
    if num == 3 then
        selecting = z > 0
        selected = nil
    end

end

function enc(num, d)
    if num == 3 and selected ~= nil then
        params:delta(n("amp", selected), d)
    end
end

function process_midi(data)
    local d = midi.to_msg(data)
    if d.type == "note_on" or d.type == "note_off" then
        local octave = math.floor(d.note / 12)
        local note = d.note % 12
        if octave < 1 or octave > 8 then
            return
        end
        local row = 9 - octave
        local col = note + 3
        if d.type == "note_on" then
            g.key(col, row, 1)
        else
            g.key(col, row, 0)
        end
    end
end


function midi_target(x)
    midi_device[target].event = nil
    target = x
    midi_device[target].event = process_midi
end

local function toggle(loc)
    local memory = params:get(n("memory", loc))
    local flutter = params:get(n("flutter", loc))
    local size = memory / flutter
    local variation = memory - size    
    if params:get(n("playing", loc)) > 0 then
        params:set(n("playing", loc), 0)
        engine.land(loc - 1, params:get(n("release", loc)))
    elseif params:get(n("pinned", loc)) > 0 then
        params:set(n("playing", loc), 1)
        engine.fly(
            loc - 1,
            size,
            params:get(n("amp", loc)),
            params:get(n("attack", loc)),
            variation,
            params:get(n("pan", loc)))
    end
end

function add_event(butterfly, b)
    if b == nil then
        b = clock.get_beats() % params:get("pattern_beats")
    end
    local event = {
        index = butterfly,
        time = b,
    }
    function event:f()
        local loc = self.index
        if params:get(n("pinned", self.index)) > 0 then
            toggle(loc)
        end
    end
    next_todo:push_back(event)
end

function init()
    for i = 1, 128 do
        (function(i)
            params:add_group(n("butterfly_", i), "butterfly " .. i, 8)
            params:add_binary(n("pinned", i), "pinned", 'toggle', 0)
            params:add_binary(n("playing", i), "playing", 'toggle', 0)
            params:add_control(n("memory", i), "memory", controlspec.new(0.05, 2, 'exp', 0, 1, 's'))
            params:add_control(n("flutter", i), "flutter", controlspec.new(1, 10, 'lin', 0, 2))
            params:add_control(n("amp", i), "amp", controlspec.new(0, 1, 'lin', 0, 0.1));
            params:add_control(n("attack", i), "attack", controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
            params:add_control(n("release", i), "release", controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
            params:add_control(n("pan", i), "pan", controlspec.BIPOLAR)

            params:set_action(n("memory", i), function() adjust_butterfly(i) end)
            params:set_action(n("flutter", i), function() adjust_butterfly(i) end)
            params:set_action(n("amp", i), function() adjust_butterfly(i) end)
            params:set_action(n("pan", i), function() adjust_butterfly(i) end)

            params:hide(n("butterfly_", i))
        end)(i)
    end
    -- Row params
    params:add_separator("colors", "Colors")
    local filterspecs = {}
    -- highpass
    table.insert(filterspecs, {
        high = 3000,
        high_q = 1,
        low = 19000,
        low_q = 1,
    })
    -- highish transparent bandpass
    table.insert(filterspecs, {
        high = 1500,
        high_q = 1,
        low = 4000,
        low_q = 1,
    })
    -- highish resonant bandpass
    table.insert(filterspecs, {
        high = 1000,
        high_q = 6,
        low = 3000,
        low_q = 6,
    })
    -- midish transparent bandpass
    table.insert(filterspecs, {
        high = 300,
        high_q = 1,
        low = 1500,
        low_q = 1,
    })
    -- midish resonant bandpass
    table.insert(filterspecs, {
        high = 200,
        high_q = 6,
        low = 1300,
        low_q = 6,
    })
    -- fully transparent
    table.insert(filterspecs, {
        high = 20,
        high_q = 1,
        low = 19000,
        low_q = 1,
    })
    -- lowpass
    table.insert(filterspecs, {
        high = 20,
        high_q = 1,
        low = 800,
        low_q = 1,
    })
    -- resonant lowpass
    table.insert(filterspecs, {
        high = 20,
        high_q = 1,
        low = 500,
        low_q = 6,
    })
    for i = 1, 8 do
        (function(i)
            local spec = filterspecs[i]
            params:add_group("row " .. i, "row " .. i, 4)
            params:add_control("highpass_" .. i, "highpass",
                controlspec.new(20, 19000, 'exp', 0, spec.high, "Hz"))
            params:add_control("high_q_" .. i, "hp resonance",
                controlspec.new(1, 20, 'exp', 0, spec.high_q, ""))
            params:add_control("lowpass_" .. i, "lowpass",
                controlspec.new(20, 19000, 'exp', 0, spec.low, "Hz"))
            params:add_control("low_q_" .. i, "lp resonance",
                controlspec.new(1, 20, 'exp', 0, spec.low_q, ""))
            params:set_action("highpass_" .. i, function()
                adjust_filters(i)
            end)
            params:set_action("lowpass_" .. i, function()
                adjust_filters(i)
            end)
            params:set_action("high_q_" .. i, function()
                adjust_filters(i)
            end)
            params:set_action("low_q_" .. i, function()
                adjust_filters(i)
            end)
        end)(i)
    end
    -- Column params
    params:add_separator('shapes', 'Shapes')
    for i = 1, 16, 1 do
        params:add_group('column ' .. i, 'column ' .. i, 5)
        params:add_control('length_' .. i, 'length', controlspec.new(
            0.2,
            2,
            'exp',
            0,
            util.linexp(0, 15, 0.25, 2, 16 - i),
            's'
        ))
        params:set_action('length_' .. i, function()
            for row = 1, 8 do
                local idx = (row - 1) * 16 + i
                params:set(n('memory', idx), params:get('length_' .. i))
            end
        end)
        params:add_control('flutter_' .. i, 'flutter', controlspec.new(
            1,
            10,
            'exp',
            0,
            1 + util.linexp(0, 8, 0.1, 4, 8 - math.abs(8 - i))
        ))
        params:set_action('flutter_' .. i, function()
            for row = 1, 8 do
                local idx = (row - 1) * 16 + i
                params:set(n('flutter', idx), params:get('flutter_' .. i))
            end
        end)
        params:add_control('attack_' .. i, 'attack',
            controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
        params:set_action('attack_' .. i, function()
            for row = 1, 8 do
                local idx = (row - 1) * 16 + i
                params:set(n('attack', idx), params:get('attack_' .. i))
            end
        end)
        params:add_control('release_' .. i, 'release',
            controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
        params:set_action('release_' .. i, function()
            for row = 1, 8 do
                local idx = (row - 1) * 16 + i
                params:set(n('release', idx), params:get('release_' .. i))
            end
        end)
        params:add_control('pan_' .. i, 'pan',
            controlspec.new(-1, 1, 'lin', 0, util.linlin(1, 16, 1, -1, i), 's'))
        params:set_action('pan_' .. i, function()
            for row = 1, 8 do
                local idx = (row - 1) * 16 + i
                params:set(n('pan', idx), params:get('pan_' .. i))
            end
        end)
    end

    params:add_separator("pattern_section", "Pattern")
    params:add_text("events", "events", "")
    params:set_action("events", function()
        todo = deque.new()
        next_todo = deque.new()
        for _, item in ipairs(tab.split(params:get("events"), ',')) do
            local time, index = table.unpack(tab.split(item, ':'))
            time = tonumber(time)
            index = tonumber(index)
            add_event(index, time)
        end
    end)
    params:hide("events")
    params:add_number("pattern_beats", "wingbeats", 4, 256, 8)

    -- Make provision for saving and loading
    params.action_write = function(filename, name, number)
        local dirname = _path.audio .. norns.state.name .. "/" .. number .. "/"
        os.execute("mkdir -p " .. dirname)
        engine.saveAudio(dirname)
    end

    params.action_read = function(filename, name, number)
        local dirname = _path.audio .. norns.state.name .. "/" .. number .. "/"
        engine.loadAudio(dirname)
        for i = 1, 128 do
            if params:get(n("playing", i)) > 0 then
                params:set(n("playing", i), 0)
            end
        end
        params:lookup_param("events"):bang()
    end

    midi_device = {} -- container for connected midi devices
    midi_device_names = {}
    target = 1

    for i = 1,#midi.vports do -- query all ports
        midi_device[i] = midi.connect(i) -- connect each device
        table.insert(midi_device_names,"port "..i..": "..util.trim_string_to_width(midi_device[i].name,40)) -- register its name
    end
    params:add_separator("midi", "MIDI Input")
    params:add_option("midi target", "midi target",midi_device_names,1,false)
    params:set_action("midi target", midi_target)

    clock.run(function()
        while true do
            grid_redraw()
            clock.sleep(1 / 15)
        end
    end)
    clock.run(function()
        while true do
            redraw()
            clock.sleep(1 / 15)
        end
    end)

    -- Pattern runner
    local pattern_runner = nil
    clock.run(function()
        while true do
            clock.sync(params:get("pattern_beats"))
            local to_save = {}
            for _, event in next_todo:ipairs() do
                table.insert(to_save, string.format("%f:%i", event.time, event.index))
            end
            params:set("events", (table.concat(to_save, ',')), true)
            todo = next_todo
            next_todo = deque.new()
            if pattern_runner ~= nil then
                clock.cancel(pattern_runner)
            end
            pattern_runner = clock.run(function()
                local event = todo:peek()
                while event ~= nil do
                    local t = event.time
                    local now = clock.get_beats() % params:get("pattern_beats")
                    if t > now then
                        clock.sleep((t - now)*clock.get_beat_sec())
                        if recording and clearing then
                            -- pass
                        else
                            event:f()
                            next_todo:push_back(event)
                        end
                        todo:pop()
                    end
                    event = todo:peek()
                end
            end)
        end
    end)
    params:bang()
end

function redraw()
    screen.clear()
    local length = params:get("pattern_beats")
    local beats = clock:get_beats()
    local progress = (beats % length)/length
    screen.level(6)
    screen.aa(1)
    screen.circle(progress*127, 2, 2)
    screen.fill()
    screen.circle((progress*127 - 3) % 127, 2.5 + 0.5*math.sin(2*math.pi*(beats % 1)), 2)
    screen.fill()
    screen.circle((progress*127 - 6) % 127, 2.5 + 0.5*math.cos(2*math.pi * (beats % 1)), 2)
    screen.fill()
    for _, event in todo:ipairs() do
        screen.level(15)
        screen.pixel(127*(event.time % length)/length, 2.5)
        screen.stroke()
    end
    for _, event in next_todo:ipairs() do
        screen.level(6)
        screen.pixel(127*(event.time % length)/length, 2.5)
        screen.stroke()
    end    
    for i = 1, 128, 1 do
        screen.level(6)
        local row = math.floor((i - 1) / 16) + 1
        local col = (i - 1) % 16 + 1
        local x = col * 7 + 3
        local y = row * 7 + 3
        local playing = (params:get(n("playing", i)) > 0)
        local pinned = (params:get(n("pinned", i)) > 0)
        if playing then
            screen.level(12)
            screen.display_png(
                _path.code .. "lepidoptery/img/butterfly-" .. math.random(6) .. ".png",
                x - 3,
                y - 3)
        elseif pinned then
            screen.display_png(_path.code .. "lepidoptery/img/butterfly-0.png", x - 3, y - 3)
        else
            screen.pixel(x, y)
        end
        screen.stroke()
    end
    screen.update()
end

function g.key(x, y, z)
    local loc = (x - 1) + 16 * (y - 1) + 1
    if clearing then
        if z == 1 then
            if params:get(n("playing", loc)) then
                params:set(n("playing", loc), 0)
                engine.land(loc - 1, params:get(n("release", loc)))
            end
            params:set(n("pinned", loc), 0)
        end
    elseif selecting then
        if z == 1 and selected == nil then
            selected = loc
        elseif z == 1 and params:get(n("pinned", loc)) == 0 then
            engine.copy(selected - 1, loc - 1)
            params:set(n("pinned", loc), 1)
        elseif z == 0 and loc == selected then
            selected = nil
        end
    else
        if z == 1 then
            if params:get(n("pinned", loc)) > 0 then
                toggle(loc)
                if recording then
                    add_event(loc)
                end
            else
                engine.capture(loc - 1);
                params:set(n("pinned", loc), 1)
                clock.run(function()
                    toggle(loc)
                end)
            end
        end
    end
end

function grid_redraw()
    g:all(0)
    for i = 1, 128 do
        local row = math.floor((i - 1) / 16) + 1
        local col = (i - 1) % 16 + 1
        g:led(
            col,
            row,
            4 * params:get(n("pinned", i)) + 8 * params:get(n("playing", i)))
    end
    g:refresh()
end
