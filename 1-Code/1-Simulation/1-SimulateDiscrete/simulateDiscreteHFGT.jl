# simulateDiscreteHFGT.jl
# Discrete-Time HFGT Simulation (No Optimization)
# Author: Megan S. Harris
# Date: March 2025

using SparseArrays, LinearAlgebra

# Load System Parameters
include("loadDeviceModelsDiscrete.jl")

println("Starting Discrete Time Simulation...")

# Allocate Storage Arrays
QB = zeros(myLFES.numBuffers * myLFES.numOperands, myLFES.numOptTimeSteps+1)
QE = zeros(myLFES.numCapabilities, myLFES.numOptTimeSteps+1)
UEPlus = zeros(myLFES.numCapabilities, myLFES.numOptTimeSteps)
UEMinus = zeros(myLFES.numCapabilities, myLFES.numOptTimeSteps)

# Set Initial Conditions
if myLFES.hasQBinitCond == 1
    QB[:, 1] .= myLFES.QBinitCond
end
if myLFES.trackCapabilities == 1
    QE[:, 1] .= myLFES.QEinitCond
end

for k1 in 1:myLFES.numOptTimeSteps
    # println("Simulating time step $k1...")

    # Step 1: Define UE constraints from exogenous values and device models
    # Initialize UEMinus for this timestep
    UEMinus_temp = zeros(myLFES.numCapabilities)
    
    # Apply exogenous constraints if they exist
    if myLFES.hasUEMinusExoConstraint == 1
        # Check for zero diagonal elements to avoid singular matrix
        nonzero_diag = findall(x -> x != 0, diag(myLFES.DUMinus))
        
        if !isempty(nonzero_diag)
            # Only solve for non-zero diagonal elements
            UEMinus_temp[nonzero_diag] = myLFES.DUMinus[nonzero_diag, nonzero_diag] \ myLFES.CUMinus[nonzero_diag, k1]
        end
    end
    
    # Apply UEPlus exogenous constraints separately
    if myLFES.hasUEPlusExoConstraint == 1
        UEPlus_temp = zeros(myLFES.numCapabilities)
        nonzero_diag = findall(x -> x != 0, diag(myLFES.DUPlus))
        
        if !isempty(nonzero_diag)
            UEPlus_temp[nonzero_diag] = myLFES.DUPlus[nonzero_diag, nonzero_diag] \ myLFES.CUPlus[nonzero_diag, k1]
        end
        
        UEPlus[:, k1] = UEPlus_temp
    end

    # Compute volumetric flows using resistance model
    UEMinus_resistance = compute_resistance_flow(myLFES, QB[:, k1])
    
    # Merge exogenous constraints with resistance model results
    # (where exogenous constraints are defined, use them; use resistance model where there is resistance)
    if myLFES.hasDeviceModels == 1
        resistance_only = findall(x -> x != 0, diag(myLFES.hasResistance))
        
        # For capabilities with resistance constraints, add them
        UEMinus_temp[resistance_only] = UEMinus_resistance[resistance_only]
    else
        # No exogenous constraints, use resistance model for all
        UEMinus_temp = UEMinus_resistance
    end
    
    # Transport / mixing model for mass flows
    UEMinus_final = compute_transport_flow(myLFES, QB[:, k1], UEMinus_temp, k1)
    
    # Set final UEMinus values for this timestep
    UEMinus[:, k1] = UEMinus_final

    # If duration is zero, UEPlus == UEMinus 
    for psi in 1:myLFES.numCapabilities
        UEPlus[psi, (k1+myLFES.durations[psi])] = UEMinus[psi, k1]
    end

    # Step 2: Advance Buffers and Capabilities using continuity 
    QB[:, k1+1] = QB[:, k1] .+ (myLFES.incMatPlus * UEPlus[:, k1] .- myLFES.incMatMinus * UEMinus[:, k1]) * myLFES.deltaT
    # Ensure there is no negative storage
    # QB[:, k1+1]=max.(QB[:, k1+1], 0.0)

    if myLFES.trackCapabilities == 1
        QE[:, k1+1] = QE[:, k1] .- UEPlus[:, k1] * myLFES.deltaT .+ UEMinus[:, k1] * myLFES.deltaT
    end

    # Apply capacity limits 
    if myLFES.hasQBCapacityConstraint == 1
        QB[:, k1+1] = min.(QB[:, k1+1], myLFES.QBmax)
    end

    if myLFES.hasQECapacityConstraint == 1 && myLFES.trackCapabilities == 1
        QE[:, k1+1] = min.(QE[:, k1+1], myLFES.QEmax)
    end

    if myLFES.hasUEPlusCapacityConstraint == 1
        UEPlus[:, k1] = min.(UEPlus[:, k1], myLFES.UEPlusMax)
    end

    if myLFES.hasUEMinusCapacityConstraint == 1
        UEMinus[:, k1] = min.(UEMinus[:, k1], myLFES.UEMinusMax)
    end
end

for (name, array) in [("QB", QB), ("QE", QE), ("UEMinus", UEMinus), ("UEPlus", UEPlus)]
    if all(array .≥ 0.0)
        println("All values in $name are non-negative.")
    else
        println("Some values in $name are negative.")
    end
end

println("Simulation Complete!")