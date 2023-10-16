-- PRRPLEXOR
-- chaotic_texture_synth


engine.name = 'PRRPLEXOR'

prrplexor_setup = include 'lib/prrplexor'

local MusicUtil = require 'musicutil'
local UI = require 'ui'

local tabs = UI.Tabs.new(1, {"cluster", "chaos"})
local cluster_size = 5
local cluster_width = 1 -- octaves

local pages_widget = UI.Pages.new(1, 2)

function init()
	prrplexor_setup.add_params()
	redraw()
end

function key(n, z)
  if n == 2 then
    generate_cluster()
  elseif n == 3 then
    engine.free_all_notes()
  end
end

function enc(n, d)
  if n == 1 then
    tabs:set_index_delta(d, false)
  elseif n == 2 then
    if tabs.index == 1 then
      cluster_size = util.clamp(cluster_size + d, 1, 10)
    elseif tabs.index == 2 then
      params:delta("all_fb", d / 10)
    end
  elseif n == 3 then
    if tabs.index == 1 then
      cluster_width = util.clamp(cluster_width + d, 1, 6)
    end
  end
  
  redraw()
end

function redraw()
  screen.clear()
  tabs:redraw()
  
  -- footer
  -- cluster
  if tabs.index == 1 then
    screen.move(10, 64)
    screen.text("size : " .. string.format("%2i", cluster_size))
    screen.move(118, 64)
    screen.text_right("width : " .. string.format("%2i", cluster_width))
  elseif tabs.index == 2 then
    screen.move(10, 64)
    screen.text("feedback : " .. string.format("%.2f", params:get("all_fb")))
    screen.move(118, 64)
    screen.text_right("width : " .. string.format("%2i", cluster_size))
  end
  
  screen.update()
end

function generate_cluster()
  for i=1,cluster_size do
    lower_boundary = 54 - cluster_width / 2
    upper_boundary = lower_boundary + 12 * cluster_width
    midi_note = util.clamp(util.linlin(1, cluster_size, lower_boundary, upper_boundary, i), 24, 96)
    
    params:set(i .. "_amp", (math.random(10) + 5) / 127)
    engine.trig(i, MusicUtil.note_num_to_freq(midi_note))
  end
end
