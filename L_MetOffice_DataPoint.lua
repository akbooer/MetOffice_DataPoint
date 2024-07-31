module(..., package.seeall)

_G.ABOUT = {
  NAME          = "L_MetOffice_DataPoint",
  VERSION       = "2024.07.29",
  DESCRIPTION   = "WeatherApp using MetOffice data",
  AUTHOR        = "@akbooer",
  COPYRIGHT     = "(c) 2022-present AKBooer",
  DOCUMENTATION = "",
  DEBUG         = false,
  LICENSE       = [[
  Copyright 2022-present AK Booer

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]
}

-- 2022.11.04  original version
-- 2022.11.06  make child devices optional, using 'children' device attribute containing T and/or H
-- 2022.11.08  fix for data split across two day intervals 
-- 2022.11.14  change ServiceId separator to ':' from '.' (less confusing)

-- 2024.07.22  add MaxTemp and MinTemp (handled by Data Historian rules)
-- 2024.07.28  add more checks for returned data structure (including JSON global)


--[[
see:
  https://www.metoffice.gov.uk/services/data/datapoint/
  https://www.metoffice.gov.uk/services/data/datapoint/uk-observations-detailed-documentation
  https://www.metoffice.gov.uk/services/data/datapoint/uk-observations-detailed-documentation#UK%20observations%20data%20feed
  
also:
  https://groups.google.com/g/metoffice-datapoint/membership
--]]

local json    = require "openLuup.json"
local tables  = require "openLuup.servertables"     -- for standard DEV and SID definitions
local API     = require "openLuup.api"              -- new openLuup API

local luup = _G.luup
local ABOUT = _G.ABOUT

local DEV = tables.DEV

local _log = luup.log

-----

local function update_readings (p)

  local D = API[p.D]      -- this device
  local A = D.attr        -- attributes
  
  local url = "http://datapoint.metoffice.gov.uk/public/data/val/wxobs/all/json/%s?res=hourly&key=%s"

  local s, j, err = luup.inet.wget (url: format (A.station, A.key))
  if s ~= 0 then
    _log ("error polling DataPoint, return code = " .. tostring(err))
    return
  end
  
  local x, jerr = json.decode (j)
  if not x then
    _log ("error decoding JSON: " .. tostring(jerr))
    return
  end
  
  _G.JSON = j       -- 2024.07.28  save in global for debug purposes
  
  local location = x.SiteRep and x.SiteRep.DV and x.SiteRep.DV.Location
  if not location then
    _log ("error SiteRep components missing: " .. j)
    return
  end
  
  local S = D["SiteRep:DV:Location"]              -- serviceId  
  for a,b in pairs (location) do
    if a ~= "Period" then
      S[a] = b                    -- assign location variables
    end
  end

  S = D["SiteRep:Wx:Param"]              -- serviceId
  local  name = "%s (%s)"
  for _, a in pairs(x.SiteRep.Wx.Param) do
    local var = name: format (a["$"], a.units)
    S[var] = a.name
  end
  
  local P = location.Period
  local data = (P[#P] or P).Rep   -- period may contain multiple day intervals, use latest
  if not data or #data == 0 then
    _log "no data for current time interval"
    if ABOUT.DEBUG then _log (json.encode {Period = P}) end   -- diagnostic data dump
    return
  end
  
  S = D["SiteRep:DV:Location:Period:Rep"]
  local latest = data[#data]
  for var, value in pairs (latest) do
    S[var] = value
  end
  
  S.dataDate = x.SiteRep.DV.dataDate
  
  do -- update parent and child standard device variables
    D.temp.CurrentTemperature = latest.T
    D.temp.MaxTemp = latest.T               -- 2024.07.22
    D.temp.MinTemp = latest.T               -- Max/Min handled by Historian rules
    
    D.humid.CurrentLevel = latest.H
    D.generic.Pressure = latest.P
    
    if p.T then
      API[p.T].temp.CurrentTemperature = latest.T
    end
    
    if p.H then
      API[p.H].humid.CurrentLevel = latest.H
    end
  end
  
  D.hadevice.LastUpdate = os.time()
  _log ("MetOffice DataPoint: " .. x.SiteRep.DV.dataDate)
  
end

local function poll (p)
  update_readings (p)

  -- rechedule 
  API.timers "delay" {
    callback = poll, 
    delay = 10 * 60,      -- ten minutes
    parameter = p, 
    name = "DataPoint polling"}
end

function init (lul_device)
  local devNo = tonumber (lul_device)
  
  local T, H
  do -- create essential attributes if they don't exist
    local A = API[devNo].attr
    A.station = A.station or "station ID?"
    A.key = A.key or "API key?"
    A.children = A.children or "T and H"
    
    T = A.children: match "T"     -- non-nil if child to be created
    H = A.children: match "H"     -- ditto
  end
    
  local dev_t, dev_h
  do -- create children
    local children = luup.chdev.start(devNo)
    -- use non-standard device number return parameter (openLuup only) for chdev.append()
    if T then
      dev_t = luup.chdev.append (devNo, children, "MetT", "Met Temperature", '', DEV.temperature, '', '', false)
    end
    if H then
      dev_h = luup.chdev.append (devNo, children, "MetH", "Met Humidity",    '', DEV.humidity,    '', '', false)
    end
    luup.chdev.sync(devNo, children)
  end
  
  do -- delay polling startup
    API.timers "delay" {
      callback = poll, 
      delay = 10,       -- ten seconds
      parameter = {D = devNo, T = dev_t, H = dev_h}, 
      name = "DataPoint delayed startup"}
  end

  luup.set_failure (0)
  return true, "OK", "MetOffice_DataPoint"
end

-----
