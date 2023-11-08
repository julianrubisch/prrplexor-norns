local PRRPLEXOR = {}
local ControlSpec = require 'controlspec'
local Formatters = require 'formatters'

function round_form(param,quant,form)
  return(util.round(param,quant)..form)
end

local specs = {
  {type = "separator", name = "synthesis"},
  {id = 'amp', name = 'level', type = 'control', min = 0, max = 1, warp = 'lin', default = 0.1},
  {id = 'fb', name = 'feedback', type = 'control', min = 0, max = 10, warp = 'lin', default = 0.5},
  {id = 'attack', name = 'attack', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0.5, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {id = 'release', name = 'release', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 1, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {type = "separator", name = "modulation"},
  {id = 'panFreq', name = 'pan lfo freq', type = 'control', min = 0.001, max = 2, warp = 'exp', default = 0},
  {id = 'panAmp', name = 'pan lfo amp', type = 'control', min = 0, max = 1, warp = 'lin', default = 0},
  {id = 'fbFreq', name = 'fb lfo freq', type = 'control', min = 0.001, max = 2, warp = 'exp', default = 0},
  {id = 'fbAmp', name = 'fb lfo amp', type = 'control', min = 0, max = 1, warp = 'lin', default = 0},
  {type = "separator", name = "filter"},
  {id = 'filterFreq', name = 'filter freq', type = 'control', min = 20, max = 20000, warp = 'exp', default = 10000},
  {id = 'filterQ', name = 'filter Q', type = 'control', min = 1, max = 20, warp = 'lin', default = 1},
  {type = "separator", name = "master"},
  {id = 'pan', name = 'pan', type = 'control', min = -1, max = 1, warp = 'lin', default = 0}
}

function PRRPLEXOR.add_params()
  params:add_separator("PRRPLEXOR")
  local voices = {"all",1,2,3,4,5,6,7,8,9,10}
  
  for i = 1,#voices do
    params:add_group("voice ["..voices[i].."]",#specs) -- add a PARAMS group, eg. 'voice [all]'
    for j = 1,#specs do
      local p = specs[j]
      if p.type == 'control' then
        params:add_control(
          voices[i].."_"..p.id,
          p.name,
          ControlSpec.new(p.min, p.max, p.warp, 0, p.default),
          p.formatter
        )
      elseif p.type == 'number' then
        params:add_number(
          voices[i].."_"..p.id,
          p.name,
          p.min,
          p.max,
          p.default,
          p.formatter
        )
      elseif p.type == "option" then
        params:add_option(
          voices[i].."_"..p.id,
          p.name,
          p.options,
          p.default
        )
      elseif p.type == 'separator' then
        params:add_separator(p.name)
      end
      
      -- if the parameter type isn't a separator, then we want to assign it an action to control the engine:
      if p.type ~= 'separator' then
        params:set_action(voices[i].."_"..p.id, function(x)
          -- use the line's 'id' as the engine command, eg. engine.amp or engine.cutoff_env,
          --  and send the voice and the value:
          engine[p.id](voices[i],x) -- 
          if voices[i] == "all" then -- it's nice to echo 'all' changes back to the parameters themselves
            -- since 'all' voice corresponds to the first entry in 'voices' table,
            --   we iterate the other parameter groups as 2 through 9:
            for other_voices = 2,11 do
              -- send value changes silently, since 'all' changes all values on SuperCollider's side:
              params:set(voices[other_voices].."_"..p.id, x, true)
            end
          end
        end)
      end
      
    end
  end
  
  params:bang()
end

return PRRPLEXOR
