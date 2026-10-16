# differential-solution.jl
# Continuous-time CSTR solution for Simulation 1 (Lake 1 -> Point 1 -> Point 2),
# written directly from the mass-balance, resistance and complete-mixing equations.
# Every parameter is read from the same myLFES object used by the discrete HFGT
# simulation, so the two solutions describe exactly the same system.
# Author: Megan S. Harris
# Date: October 2026

using DifferentialEquations, LinearAlgebra

ρ = 1000.0   # density of water (kg/m^3)
g = 9.81     # gravitational acceleration (m/s^2)

# Buffers: 1 = Lake 1, 2 = Point 1, 3 = Point 2 (water rows of QB)
A    = myLFES.area[1:3]           # surface areas (m^2)
z    = myLFES.elevation[1:3]      # elevations (m)
Vmin = myLFES.QBminFlow[1:3]      # volumes below which no outflow occurs (m^3)

# Resistances of the two water transport capabilities, in XML order:
# River Segment 1 (Lake 1 -> Point 1), River Segment 2 (Point 1 -> Point 2)
res_caps = findall(!iszero, diag(myLFES.hasResistance))
R1, R2   = 1 ./ diag(myLFES.reciprocalResistance)[res_caps]

# Net water input to Lake 1 for each time step (m^3/s), from the exogenous constraint
rain_cap    = findfirst(!iszero, diag(myLFES.DUMinus))
rain_series = Vector(myLFES.CUMinus[rain_cap, :])
Δt          = myLFES.deltaT
Vdot_in(t)  = rain_series[clamp(Int(floor(t / Δt)) + 1, 1, length(rain_series))]

head(V, i) = z[i] + (V - Vmin[i]) / A[i]

function cstr!(du, u, p, t)
    V1, V2, V3, m1, m2, m3 = u
    q12 = max(ρ * g / R1 * (head(V1, 1) - head(V2, 2)), 0.0)   # Lake 1 -> Point 1
    q23 = max(ρ * g / R2 * (head(V2, 2) - head(V3, 3)), 0.0)   # Point 1 -> Point 2
    n12 = m1 / V1 * q12                                         # complete mixing
    n23 = m2 / V2 * q23
    du[1] = Vdot_in(t) - q12
    du[2] = q12 - q23
    du[3] = q23
    du[4] = -n12
    du[5] = n12 - n23
    du[6] = n23
end

nb  = myLFES.numBuffers
u0  = [myLFES.QBinitCond[1:3]; myLFES.QBinitCond[nb+1:nb+3]]
tspan = (0.0, myLFES.numOptTimeSteps * Δt)
prob  = ODEProblem(cstr!, u0, tspan)
sol   = solve(prob, Tsit5(); saveat = 0:Δt:tspan[2], tstops = 0:Δt:tspan[2],
              reltol = 1e-8, abstol = 1e-6)

V_lake_sol  = sol[1, :]
V_point_sol = sol[2, :]
m_lake_sol  = sol[4, :]
conc_lake_sol = m_lake_sol ./ V_lake_sol
