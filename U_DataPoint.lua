-- Custom device panel and control for MetOffice_DataPoint device type
-- ...but note that the filename is just "U_DataPoint.lua"

local xml = require "openLuup.xml"
local api = require "openLuup.api"

local json = require "openLuup.json"

local h = xml.createHTMLDocument ()    -- for factory methods
local span = h.span
local div = h.div
local br = h.br()
local p = h.p

return {
  panel = function(devNo)
    local D = api[devNo]
    local S = D["SiteRep.DV.Location.Period.Rep"]
    local dataDate = S.dataDate or "--/--/--"
    local T = S.T or '?'
    local H = S.H or '?'

    return div {
        span {class="w3-large w3-text-dark-gray", T, "°, ", H, '%', br, ''},
        div {class = "w3-tiny w3-display-bottomright", dataDate}
      }
  end,
 
  control = function() 
    return [[
      <div>
        <a  href="https://www.metoffice.gov.uk/services/data/datapoint/about" target="_blank">About Met Office DataPoint</a>
      </div>]]
    end,
 
}
