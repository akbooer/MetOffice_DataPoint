-- Custom device panel and control for MetOffice_DataPoint device type
-- ...but note that the filename is just "U_DataPoint.lua"

local xml = require "openLuup.xml"
local api = require "openLuup.api"

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
    return 
      div {
        div {class="w3-gray w3-round-large",
          h.img {alt="Met Office logo", width=400, src="https://www.metoffice.gov.uk/binaries/content/gallery/metofficegovuk/images/about-us/website/mo_master_for_dark_backg_rbg.png", }
        },
        div {class = "w3-panel w3-margin-left",
          p {h.a {href="https://www.metoffice.gov.uk/services/data/datapoint/about", target="_blank", "About Met Office DataPoint"}},
          p {h.a {href="https://www.metoffice.gov.uk/services/data/datapoint/datapoint-documentation", target="_blank", "DataPoint Documentation"}}},    
      }
    end,
 
}
