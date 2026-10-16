# generate_time_series.jl
# Exogenous water and nitrogen inputs for the illustrative simulations
# Author: Megan S. Harris
# Date: October 2026
#
# All inputs are synthetic but scaled to published regional values:
#   * Precipitation: 1083 mm/yr, the NOAA NCEI 1991-2020 climate normal for
#     Blacksburg, VA.
#   * Net water input (water yield): 40% of precipitation, i.e. the share not
#     returned to the atmosphere by evapotranspiration in the humid eastern US
#     (Sanford & Selnick, 2013, JAWRA 49(1):217-230).
#     Seasonal multipliers (Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec) represent the
#     wetter winter-spring and drier summer-fall pattern; they average to 1.
#   * Nitrogen: Chesapeake Bay Program Phase 6 Watershed Model average
#     edge-of-stream total-nitrogen loading rates by land use (CAST
#     documentation, Section 2 "Average Loads", 2018), applied mostly in spring.
#
# Code words (set as CUMinus in the XML input files):
#   "netprecip"        net water input over the buffer's own surface area
#   "netprecipDA<k>"   net water input over a contributing area k times the
#                      buffer's surface area (e.g. "netprecipDA20")
#   "fert_<landuse>"   nitrogen input at the CAST loading rate for <landuse>
#
# Units: water m^3/s, nitrogen g/s (so stored N/V is in g/m^3 = mg/L).

const PRECIP_MM_PER_YR = 1083.0
const NET_FRACTION     = 0.40
const WATER_SEASON     = [1.60, 1.10, 0.40, 0.90]   # mean = 1
const N_SEASON         = [0.15, 0.55, 0.15, 0.15]   # sums to 1 (spring application)
const CAST_TN_KG_HA_YR = Dict(                       # edge-of-stream TN, kg/ha/yr
    "soybeans"       => 31.09,   # Full Season Soybeans
    "otheragronomic" => 19.70,   # Other Agronomic Crops
    "pasture"        => 13.20,   # Pasture
)

# Repeat four seasonal values over the simulation horizon
function seasonal_series(season_values, parameters)
    n = Int(parameters["numOptTimeSteps"])
    q = n ÷ 4
    s = vcat([fill(v, q) for v in season_values]...)
    return reshape(vcat(s, fill(season_values[end], n - length(s))), 1, n)
end

function generate_time_series(code_word, parameters, cap_index;
                               buffer_params=nothing, incMatMatrices=nothing)
    code_word = lowercase(string(code_word))   # the toolbox stores code words in lowercase

    # Surface area (m^2) of the buffer that receives this capability's input
    buffer_area = 0.0
    if !isnothing(buffer_params) && !isnothing(incMatMatrices)
        buffer_index = findfirst(x -> x == 1, incMatMatrices["incMatPlus"][:, cap_index])
        if !isnothing(buffer_index) && buffer_index <= length(buffer_params["area"])
            a = buffer_params["area"][buffer_index]
            buffer_area = isa(a, Number) ? Float64(a) : parse(Float64, a)
        end
    end

    seconds_per_year = 365.0 * 86400.0
    mean_net_rate = PRECIP_MM_PER_YR * NET_FRACTION / 1000.0 / seconds_per_year   # m/s

    if startswith(code_word, "netprecip")
        ratio = code_word == "netprecip" ? 1.0 : parse(Float64, replace(code_word, "netprecipda" => ""))
        return seasonal_series(WATER_SEASON, parameters) .* (mean_net_rate * buffer_area * ratio)

    elseif startswith(code_word, "fert_")
        landuse = replace(code_word, "fert_" => "")
        annual_g = CAST_TN_KG_HA_YR[landuse] * (buffer_area / 1.0e4) * 1000.0
        season_seconds = (parameters["numOptTimeSteps"] ÷ 4) * parameters["deltaT"]
        return seasonal_series(N_SEASON, parameters) .* (annual_g / season_seconds)

    else
        return zeros(1, Int(parameters["numOptTimeSteps"]))
    end
end
