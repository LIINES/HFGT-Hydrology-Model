# loadDeviceModelsDiscrete.jl
# Discrete-Time Device Models for HFGT Simulation
# Author: Megan S. Harris
# Date: May 2025

function compute_resistance_flow(myLFES, QB_resistance)
    ρ = 1000.0        # kg/m³
    g = 9.81          # m/s²
    headToPressure = ρ * g

    inverseAverageArea = Diagonal([a ≈ 0 ? 0.0 : 1.0 / a for a in myLFES.area])
    netIncT = -transpose(myLFES.incMatPlus - myLFES.incMatMinus)

    pressureHead = myLFES.elevation .+ inverseAverageArea * (QB_resistance .- myLFES.QBminFlow)

    UEMinus_resistance = myLFES.hasResistance * (
        myLFES.reciprocalResistance * (
            netIncT * (headToPressure .* pressureHead)
        )
    )
    UEMinus_resistance = max.(UEMinus_resistance, 0.0) # No flow backwards

    return UEMinus_resistance
end

function compute_transport_flow(myLFES, QB_mixing, UEMinus_volumetric, timestep)
    # Note: This function should use UEMinus_volumetric (from resistance model)
    # to calculate mass flows of nitrogen
    
    UEMinus_mixing = copy(UEMinus_volumetric)  # Start with the volumetric flows

    # Recompute net incidence matrix
    netIncMat = myLFES.incMatPlus - myLFES.incMatMinus
    
    # Track paired capabilities for debug output
    found_pairs = 0
    
    for cap_i in 1:myLFES.numCapabilities-1
        for cap_j in (cap_i+1):myLFES.numCapabilities
            # Find extraction and injection buffers
            i_extract = findfirst(x -> x < 0, netIncMat[:, cap_i])
            j_extract = findfirst(x -> x < 0, netIncMat[:, cap_j])
            i_inject = findfirst(x -> x > 0, netIncMat[:, cap_i])
            j_inject = findfirst(x -> x > 0, netIncMat[:, cap_j])

            if isnothing(i_extract) || isnothing(j_extract) || isnothing(i_inject) || isnothing(j_inject)
                continue
            end

            # Confirm they form a water-nitrogen transport pair
            is_paired = (
                (i_extract <= myLFES.numBuffers && j_extract == i_extract + myLFES.numBuffers) ||
                (j_extract <= myLFES.numBuffers && i_extract == j_extract + myLFES.numBuffers)
            )

            if !is_paired
                continue
            end
            
            found_pairs += 1
            
            # Debug output for paired capabilities
            if timestep == 1
                println("\nFound water-nitrogen pair #$found_pairs:")
                # println("  Capabilities: cap_i=$cap_i, cap_j=$cap_j")
                # println("  Extract buffers: i_extract=$i_extract, j_extract=$j_extract")
                # println("  Inject buffers: i_inject=$i_inject, j_inject=$j_inject")
            end

            # Assign buffer/cap indices for clarity
            if i_extract <= myLFES.numBuffers
                water_cap, nitrogen_cap = cap_i, cap_j
                water_idx, nitrogen_idx = i_extract, j_extract
            else
                water_cap, nitrogen_cap = cap_j, cap_i
                water_idx, nitrogen_idx = j_extract, i_extract
            end
            
            if timestep == 1
                println("  Water capability: U[$water_cap], Nitrogen capability: U[$nitrogen_cap]")
                println("  Water buffer: QB[$water_idx], Nitrogen buffer: QB[$nitrogen_idx]")
            end

            # Mixing relationship: QB[nitrogen] * U[water] == QB[water] * U[nitrogen]
            U_water = UEMinus_volumetric[water_cap]
            
            # if timestep == 1
            #     println("  Water flow U[$water_cap] = $U_water")
            #     println("  Water buffer quantity QB[$water_idx] = $(QB_mixing[water_idx])")
            #     println("  Nitrogen buffer quantity QB[$nitrogen_idx] = $(QB_mixing[nitrogen_idx])")
            # end
            
            # Only update nitrogen flow if water flow exists and water buffer has content
            if U_water > 0 && QB_mixing[water_idx] > 1e-6
                U_nitrogen = U_water * QB_mixing[nitrogen_idx] / QB_mixing[water_idx]
                UEMinus_mixing[nitrogen_cap] = U_nitrogen
                
                if timestep == 1
                    println("  EQUATION: U[$nitrogen_cap] = U[$water_cap] * QB[$nitrogen_idx] / QB[$water_idx]")
                end
            else
                # No water flow or empty water buffer means no nitrogen flow
                UEMinus_mixing[nitrogen_cap] = 0.0
                
                if timestep == 1
                    if U_water <= 0
                        println("  SKIPPED: Water flow U[$water_cap] <= 0 ($U_water)")
                    end
                    if QB_mixing[water_idx] <= 1e-6
                        println("  SKIPPED: Water buffer QB[$water_idx] too low ($(QB_mixing[water_idx]))")
                    end
                    println("  RESULT: U[$nitrogen_cap] = 0 (no transport occurs)")
                end
            end
        end
    end
    if timestep == 1
        if found_pairs == 0
            println("WARNING: No water-nitrogen pairs found in the system!")
        end
    end
    return UEMinus_mixing
end