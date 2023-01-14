engine.name = "ButterflyCollection"

g = grid.connect()

local LENGTH = 2;

local clearing = false
local selecting = false
local selected = nil

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

function init()
    for i = 1, 128 do
        (function(i)
            params:add_group(n("butterfly_", i), "butterfly " .. i, 7)
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
    for i=1,16,1 do
        params:add_group('column '..i, 'column '..i, 5)
        params:add_control('length_'..i, 'length', controlspec.new(
            0.2,
            2,
            'exp',
            0,
            util.linexp(0, 15, 0.25, 2, 16 - i),
            's'
        ))
        params:set_action('length_'..i, function()
            for row=1,8 do
                local idx = (row-1)*16 + i
                params:set(n('memory', idx), params:get('length_'..i))
            end
        end)
        params:add_control('flutter_'..i, 'flutter', controlspec.new(
            1,
            10,
            'exp',
            0,
            1+util.linexp(0, 8, 0.1, 4, 8-math.abs(8 - i))
        ))
        params:set_action('flutter_'..i, function()
            for row=1,8 do
                local idx = (row-1)*16 + i
                params:set(n('flutter', idx), params:get('flutter_'..i))
            end
        end)
        params:add_control('attack_'..i, 'attack', 
            controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
        params:set_action('attack_'..i, function()
            for row=1,8 do
                local idx = (row-1)*16 + i
                params:set(n('attack', idx), params:get('attack_'..i))
            end
        end)
        params:add_control('release_'..i, 'release', 
            controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
        params:set_action('release_'..i, function()
            for row=1,8 do
                local idx = (row-1)*16 + i
                params:set(n('release', idx), params:get('release_'..i))
            end
        end)
        params:add_control('pan_'..i, 'pan', 
            controlspec.new(-1, 1, 'lin', 0, util.linlin(1,16,1, -1, i), 's'))
        params:set_action('pan_'..i, function()
            for row=1,8 do
                local idx = (row-1)*16 + i
                params:set(n('pan', idx), params:get('pan_'..i))
            end
        end)
    end

    -- Make provision for saving and loading
    params.action_write = function(filename,name,number)
        local dirname = _path.audio .. norns.state.name .. "/"..number.."/"
        os.execute("mkdir -p "..dirname)
        engine.saveAudio(dirname)
    end

    params.action_read = function(filename, name, number)
        local dirname = _path.audio .. norns.state.name .. "/"..number.."/"
        engine.loadAudio(dirname)
        for i=1,128 do
            if params:get(n("playing", i)) > 0 then
                params:set(n("playing", i), 0)
            end
        end
    end


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
    params:bang()
end

function redraw()
    screen.clear()
    for i = 1, 128, 1 do
        screen.level(6)
        local row = math.floor((i - 1) / 16) + 1
        local col = (i - 1) % 16 + 1
        local x = col * 7
        local y = row * 7
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
            else
                engine.capture(loc - 1);
                params:set(n("pinned", loc), 1)
                clock.run(function()
                    clock.sleep(0.1)
                    params:set(n("playing", loc), 1)
                    engine.fly(
                        loc - 1,
                        size,
                        params:get(n("amp", loc)),
                        params:get(n("attack", loc)),
                        variation,
                        params:get(n("pan", loc)))
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
