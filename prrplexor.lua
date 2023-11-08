-- PRRPLEXOR
-- chaotic_texture_synth


engine.name = 'PRRPLEXOR'

prrplexor_setup = include 'lib/prrplexor'

local MusicUtil = require 'musicutil'
local UI = require 'ui'
local Graph = require 'graph'
local FilterGraph = require 'filtergraph'

local tabs = UI.Tabs.new(1, {"cluster", "chaos", "mod", "filter"})
-- TODO refactor into params
local cluster_size = 5
local cluster_width = 1 -- octaves
local transposition = 0
local spread = 0.0
local pan_mod = 0.0 -- a composite param for amp and freq
local fb_mod = 0.0 -- a composite param for amp and freq
local dials
local flatness = 0.0
local amplitude = {0.0, 0.0}
local wave_freq = 2

function init()
	prrplexor_setup.add_params()
	dials = {
	  cluster_size = UI.Dial.new(10, 12, 18, cluster_size, 1, 10, 1, 0, {}, "", "size"),
	  cluster_width = UI.Dial.new(10, 40, 18, cluster_width, 1, 6, 1, 0, {}, "", "width"),
	  feedback = UI.Dial.new(10, 12, 18, params:get("all_fb"), 0.0, 10.0, 0.1, 0, {}, "", "feedback"),
	  spread = UI.Dial.new(10, 40, 18, spread, 0.0, 1.0, 0.01, 0, {}, "", "spread"),
	  fb_mod = UI.Dial.new(10, 12, 18, fb_mod, 0.0, 1.0, 0.01, 0, {}, "", "feedback"),
	  pan_mod = UI.Dial.new(10, 40, 18, pan_mod, 0.0, 1.0, 0.01, 0, {}, "", "spread"),
	  filter_freq = UI.Dial.new(10, 12, 18, params:get("all_filterFreq"), 20, 20000, 1, 0, {}, "", "freq"),
	  filter_q = UI.Dial.new(10, 40, 18, params:get("all_filterQ"), 1, 20, 0.1, 0, {}, "", "Q")
	}

	spec_flat_tracker = poll.set("specFlatness")
  spec_flat_tracker.callback = function(flat)
    flatness = flat
    screen_dirty = true
  end
  spec_flat_tracker:start()

  amplitude_tracker_l = poll.set("amp_out_l")
  amplitude_tracker_l.callback = function(amp)
    amplitude[1] = amp
    screen_dirty = true
  end
  amplitude_tracker_l:start()
  
  amplitude_tracker_r = poll.set("amp_out_r")
  amplitude_tracker_r.callback = function(amp)
    amplitude[2] = amp
    screen_dirty = true
  end
  amplitude_tracker_r:start()

  screen_timer = clock.run(
    function()
      while true do
        clock.sleep(1/10)
        if screen_dirty then
          flatness_graph_l:update_functions()
          flatness_graph_r:update_functions()
          redraw()
          screen_dirty = false
        end
      end
    end
  )

  init_graphs()

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
      params:delta("all_fb", d / 2)
      dials["feedback"]:set_value(params:get("all_fb"))
    elseif tabs.index == 3 then
      fb_mod = util.clamp(fb_mod + d / 10, 0., 1.)
      dials["fb_mod"]:set_value(fb_mod)
      
      fb_amp_range = params:get_range("all_fbAmp")
      fb_freq_range = params:get_range("all_fbFreq")
      params:set("all_fbAmp", util.linlin(0., 1., fb_amp_range[1], fb_amp_range[2], fb_mod))
      params:set("all_fbFreq", util.linlin(0., 1., fb_freq_range[1], fb_freq_range[2], fb_mod))
    elseif tabs.index == 4 then
      params:delta("all_filterFreq", d)
      dials["filter_freq"]:set_value(params:get("all_filterFreq"))
      filter_graph:edit("lowpass", 12, params:get("all_filterFreq"), params:get("all_filterQ")/20)
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
    elseif tabs.index == 3 then
      pan_mod = util.clamp(pan_mod + d / 10, 0., 1.)
      dials["pan_mod"]:set_value(pan_mod)
      
      pan_amp_range = params:get_range("all_panAmp")
      pan_freq_range = params:get_range("all_panFreq")
      params:set("all_panAmp", util.linlin(0., 1., pan_amp_range[1], pan_amp_range[2], pan_mod))
      params:set("all_panFreq", util.linlin(0., 1., pan_freq_range[1], pan_freq_range[2], pan_mod))
    elseif tabs.index == 4 then
      params:delta("all_filterQ", d)
      dials["filter_q"]:set_value(params:get("all_filterQ"))
      filter_graph:edit("lowpass", 12, params:get("all_filterFreq"), params:get("all_filterQ")/20)
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
    screen.move(19, 24)
    screen.text_center(cluster_size)
    screen.move(19, 52)
    screen.text_center(cluster_width)
  -- chaos
  elseif tabs.index == 2 then
    dials["feedback"]:redraw()
    dials["spread"]:redraw()
    screen.move(19, 24)
    screen.text_center(params:get("all_fb"))
    screen.move(19, 52)
    screen.text_center(spread)
  -- mod
  elseif tabs.index == 3 then
    dials["pan_mod"]:redraw()
    dials["fb_mod"]:redraw()
    screen.move(19, 24)
    screen.text_center(fb_mod)
    screen.move(19, 52)
    screen.text_center(pan_mod)
  -- filter
  elseif tabs.index == 4 then
    dials["filter_freq"]:redraw()
    dials["filter_q"]:redraw()
    screen.move(19, 24)
    screen.text_center(params:get("all_filterFreq"))
    screen.move(19, 52)
    screen.text_center(params:get("all_filterQ"))
  end

  -- graphs
  if tabs.index == 4 then
    filter_graph:redraw()
  else 
    flatness_graph_l:redraw()
    flatness_graph_r:redraw()
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

function init_graphs()
  flatness_graph_l = Graph.new(0, 2, "lin", -0.5, 0.5, "lin", "point", false, false)
  flatness_graph_l:set_position_and_size(44, 18, 70, 20)

  local wave_func_l = function(x)
    local wave_shape = flatness / 5.

    local sine = math.sin(x * wave_freq * math.pi)
    local noise = math.random() * 2. - 1.
    return (sine * (1 - wave_shape) + noise * wave_shape) * amplitude[1]
  end
  -- Set sample_quality to 3 (high)
  flatness_graph_l:add_function(wave_func_l, 3)
  
  flatness_graph_r = Graph.new(0, 2, "lin", -0.5, 0.5, "lin", "point", false, false)
  flatness_graph_r:set_position_and_size(44, 44, 70, 20)

  local wave_func_r = function(x)
    local wave_shape = flatness / 5.

    local sine = math.sin(x * wave_freq * math.pi)
    local noise = math.random() * 2. - 1.
    return (sine * (1 - wave_shape) + noise * wave_shape) * amplitude[2]
  end
  -- Set sample_quality to 3 (high)
  flatness_graph_r:add_function(wave_func_r, 3)
  
  filter_graph = FilterGraph.new()
  filter_graph:set_position_and_size(44, 18, 70, 40)
end
