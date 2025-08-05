# construct_matrices.jl
# Construct sparse matrices from HDF5 data
# Author: Megan S. Harris
# Date: February 2025

using SparseArrays
using LinearAlgebra  # Ensure diagm() is available

function construct_matrices(parameters, buffer_params, process_params, method_equations, coo_matrices)
    println("Constructing LFES matrices...")
    matrices = Dict()

    # Helper function to extract numerical values safely
    function extract_numeric_value(dict, key, default=0.0)
        return haskey(dict, key) && isa(dict[key], Number) ? dict[key] : default
    end

    # println("Available keys in process_params: ", keys(process_params))

    # Extract COO matrices for incidence matrices
    matrices["incMatPlus"] = convert(SparseMatrixCSC, coo_matrices["incMatPlus"])
    matrices["incMatMinus"] = convert(SparseMatrixCSC, coo_matrices["incMatMinus"])

    # Ensure buffer constraints exist before using them
    matrices["DQBconstraint"] = buffer_params["hasQBCapacityConstraint"] !== nothing ?
        diagm(convert(Vector{Float64}, extract_numeric_value(buffer_params, "hasQBCapacityConstraint", []))) :
        spzeros(0, 0)

    # Extract and convert numerical values safely
    matrices["QBinitCond"] = extract_numeric_value(buffer_params, "QBinitCond", [])
    matrices["QEinitCond"] = extract_numeric_value(process_params, "QEinitCond", 0.0)  # Fix for missing QEinitCond
    matrices["QBfinalCond"] = extract_numeric_value(buffer_params, "QBfinalCond", [])
    matrices["QEfinalCond"] = extract_numeric_value(process_params, "QEfinalCond", 0.0)  # Fix for missing QEfinalCond
    matrices["costCoeffQB"] = extract_numeric_value(buffer_params, "costCoeffQB", [])
    matrices["costCoeffQE"] = extract_numeric_value(process_params, "costCoeffQE", 0.0)  # Fix for missing costCoeffQE

    # Construct Flow Constraint Matrices safely
    matrices["CUMinus"] = vcat(
        extract_numeric_value(method_equations["transformProcess"], "CUMinus", []),
        haskey(method_equations, "transportProcess") ? extract_numeric_value(method_equations["transportProcess"], "CUMinus", []) : []
    )
    matrices["CUPlus"] = vcat(
        extract_numeric_value(method_equations["transformProcess"], "CUPlus", []),
        haskey(method_equations, "transportProcess") ? extract_numeric_value(method_equations["transportProcess"], "CUPlus", []) : []
    )

    return matrices
end