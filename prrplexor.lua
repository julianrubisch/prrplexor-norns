-- PRRPLEXOR
-- chaotic_texture_synth


engine.name = 'PRRPLEXOR'

prrplexor_setup = include 'lib/prrplexor'

local MusicUtil = require 'musicutil'
local UI = require 'ui'

local tabs = UI.Tabs.new(1, {"cluster", "chaos", "mod"})
local cluster_size = 5
local cluster_width = 1 -- octaves
local transposition = 0
local spread = 0.0
local dials

function init()
	prrplexor_setup.add_params()
	dials = {
	  cluster_size = UI.Dial.new(10, 20, 14, cluster_size, 1, 10, 1, 0, {}, "", "size"),
	  cluster_width = UI.Dial.new(10, 44, 14, cluster_width, 1, 6, 1, 0, {}, "", "width"),
	  feedback = UI.Dial.new(10, 20, 14, params:get("all_fb"), 0.0, 10.0, 0.01, 0, {}, "", "feedback"),
	  spread = UI.Dial.new(10, 44, 14, spread, 0.0, 1.0, 0.01, 0, {}, "", "spread")
	}
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
      dials["cluster_size"]:set_value(cluster_size)
    elseif tabs.index == 2 then
      params:delta("all_fb", d / 10)
      dials["feedback"]:set_value(params:get("all_fb"))
    end
  elseif n == 3 then
    if tabs.index == 1 then
      cluster_width = util.clamp(cluster_width + d, 1, 6)
      dials["cluster_width"]:set_value(cluster_width)
    elseif tabs.index == 2 then
      spread = util.clamp(spread + d / 20, 0, 1)
      dials["spread"]:set_value(spread)

      for i=1,cluster_size do
        voice_pan = util.linlin(1, cluster_size, -1. * spread, 1. * spread, i)
        params:set(i .. "_pan", voice_pan)
      end
    end
  end
  
  redraw()
end

function redraw()
  screen.clear()
  tabs:redraw()
  
  -- cluster
  if tabs.index == 1 then
    dials["cluster_size"]:redraw()
    dials["cluster_width"]:redraw()
    screen.move(17, 30)
    screen.text_center(cluster_size)
    screen.move(17, 54)
    screen.text_center(cluster_width)
  -- chaos
  elseif tabs.index == 2 then
    dials["feedback"]:redraw()
    dials["spread"]:redraw()
    screen.move(17, 30)
    screen.text_center(params:get("all_fb"))
    screen.move(17, 54)
    screen.text_center(spread)
  end
  
  screen.update()
end

function generate_cluster()
  for i=1,cluster_size do
    lower_boundary = 54 - cluster_width / 2
    upper_boundary = lower_boundary + 12 * cluster_width
    midi_note = util.clamp(util.linlin(1, cluster_size, lower_boundary, upper_boundary, i), 24, 96)

    params:set(i .. "_amp", (math.random(10) + 5) / 127)

    engine.trig(i, MusicUtil.note_num_to_freq(midi_note + transposition))
  end
end

function transpose(steps)
end
