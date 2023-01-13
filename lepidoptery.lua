engine.name = "ButterflyCollection"

g = grid.connect()

local function n(s, i)
    return "butterfly_"..s.."_"..i
end

function init()
    print("adding params")
    for i=1,128 do
        params:add_binary(n("pinned", i), "pinned", 'toggle', 0)
        params:add_binary(n("playing", i), "playing", 'toggle', 0)
        params:add_control(n("size", i), "size", controlspec.new(0.05, 2, 'exp', 0, 1, 's'))
        params:add_control(n("amp", i), "amp", controlspec.new(0, 1, 'lin', 0, 0.3));
        params:add_control(n("attack", i), "attack", controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
        params:add_control(n("release", i), "release", controlspec.new(0.1, 10, 'exp', 0, 2, 's'))
    end
    print("added paraams")
    clock.run(function()
        while true do
            grid_redraw()
            clock.sleep(1/15)
        end
    end)
    clock.run(function()
        while true do
            redraw()
            clock.sleep(1/15)
        end
    end)
end

function redraw()
    screen.clear()
    for i=1,128,1 do
        screen.level(6)
        local row = math.floor((i-1)/16) + 1
        local col = (i-1)%16 + 1
        local x = col*7
        local y = row*7
        local playing = (params:get(n("playing", i)) > 0)
        local pinned = (params:get(n("pinned", i)) > 0)
        if playing then
            screen.level(12)
            screen.display_png(
                _path.code.."lepidoptery/img/butterfly-"..math.random(6)..".png",
                x-3,
                y-3)
        elseif pinned then
            screen.display_png(_path.code.."lepidoptery/img/butterfly-0.png", x-3, y-3)
        else
            screen.pixel(x, y)
        end
        screen.stroke()
    end
    screen.update()
end

function g.key(x, y, z)
    if z == 1 then
        local loc = (x-1) + 16*(y-1) + 1
        if params:get(n("playing", loc)) > 0 then
            params:set(n("playing", loc), 0)
            engine.land(loc-1, params:get(n("release", loc)))
        elseif params:get(n("pinned", loc)) > 0 then
            params:set(n("playing", loc), 1)
            engine.fly(
                loc-1, 
                params:get(n("size", loc)), 
                params:get(n("amp", loc)),
                params:get(n("attack", loc)))
        else
            engine.capture(loc-1);
            params:set(n("pinned", loc), 1)
            clock.run(function()
                clock.sleep(0.1)
                params:set(n("playing", loc), 1)
                engine.fly(
                    loc-1, 
                    params:get(n("size", loc)), 
                    params:get(n("amp", loc)),
                    params:get(n("attack", loc)))                
            end)
        end
    end
end

function grid_redraw()
    g:all(0)
    for i=1,128 do
        local row = math.floor((i-1)/16) + 1
        local col = (i-1)%16 + 1
        g:led(
            col, 
            row, 
            4*params:get(n("pinned", i)) + 8*params:get(n("playing", i)))
    end
    g:refresh()
end