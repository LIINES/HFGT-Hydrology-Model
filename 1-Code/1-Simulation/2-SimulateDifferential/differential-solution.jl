# differential-solution.jl
# Differential Solution for Simulation 1
# Author: Megan S. Harris
# Date: July 2025

using DifferentialEquations

# Constants
ρ = 1000.0                    # Density of water (kg/m³)
g = 9.81                      # Gravitational acceleration (m/s²)
R = 1e6                       # Flow resistance (s*m²/kg)
A_lake = myLFES.area[1]       # Surface area of lake (m²)
A_point = myLFES.area[2]      # Surface area of outflow point (m²)
z_lake = myLFES.elevation[1]  # Elevation of lake (m)
z_point = myLFES.elevation[2] # Elevation of downstream point (m)

# Time setup
weeks = 0:1:52
tspan = (0.0, 52*7*24*3600.0)  # seconds in 52 weeks

# Rainfall (from generate_time_series)
rainfall_series = vcat(
    fill(30e-4, Int(parameters["numOptTimeSteps"]/4)),
    fill(20e-4, Int(parameters["numOptTimeSteps"]/4)),
    fill(10e-4, Int(parameters["numOptTimeSteps"]/4)),
    fill(40e-4, Int(parameters["numOptTimeSteps"]/4)))
  # m³/s per week

function Vdot_in_exo(t)
    week = Int(floor(t / (7*24*3600))) + 1  # convert time to 1-based week index
    rainfall = if week < 1
        rainfall_series[1]
    elseif week > length(rainfall_series)
        rainfall_series[end]
    else
        rainfall_series[week]
    end
    return rainfall * A_lake/1000  # convert depth rate (m/s) to volume rate (m³/s)
end

# Differential equation system
function lake_and_point_dynamics!(du, u, p, t)
    V_lake, m_lake, V_point, m_point = u

    # Inflows and outflows
    Vdot_in = Vdot_in_exo(t)

    # Hydraulic head differential
    Vdot_out = ρ * g / R * ((V_lake / A_lake) - (V_point / A_point) + z_lake - z_point)

    # Mass outflow
    mdot_out = (m_lake / V_lake) * Vdot_out

    # Lake dynamics
    du[1] = Vdot_in - Vdot_out       # dV_lake/dt
    du[2] = -mdot_out                # dm_lake/dt

    # Point dynamics
    du[3] = Vdot_out                 # dV_point/dt
    du[4] = mdot_out                 # dm_point/dt
end


# Initial conditions
V_lake0 = myLFES.QBinitCond[1]
m_lake0 = myLFES.QBinitCond[myLFES.numBuffers + 1]

V_point0 = myLFES.QBinitCond[2]
m_point0 = myLFES.QBinitCond[myLFES.numBuffers + 2]

u0 = [V_lake0, m_lake0, V_point0, m_point0]

# Solve
prob = ODEProblem(lake_and_point_dynamics!, u0, tspan)
sol = solve(prob, Tsit5(), saveat=7*24*3600.0 .* weeks)

# Extract and compute concentrations
V_lake_sol = sol[1, :]
m_lake_sol = sol[2, :]
V_point_sol = sol[3, :]
m_point_sol = sol[4, :]

conc_lake_sol = m_lake_sol ./ V_lake_sol
conc_point_sol = m_point_sol ./ V_point_sol