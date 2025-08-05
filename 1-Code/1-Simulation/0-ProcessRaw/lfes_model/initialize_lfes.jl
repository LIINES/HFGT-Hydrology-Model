# initialize_lfes.jl
# Initialize LFES data structure and save data as required type to myLFES
# Author: Megan S. Harris
# Date: February 2025

using SparseArrays

struct LFES
    verboseMode::Int64
    numOperands::Int64
    numResources::Int64
    numBuffers::Int64
    numProcesses::Int64
    numCapabilities::Int64
    numOptTimeSteps::Int64
    deltaT::Int64
    tol::Float64

    incMatPlus::SparseMatrixCSC{Int64, Int64}
    incMatMinus::SparseMatrixCSC{Int64, Int64}
    DQBconstraint::SparseMatrixCSC{Int64, Int64}
    QBinitCond::Vector{Int64}
    QEinitCond::Vector{Int64}
    QBfinalCond::Vector{Int64}
    QEfinalCond::Vector{Int64}
    costCoeffQB::Vector{Int64}
    costCoeffQE::Vector{Int64}
    durations::Vector{Int64}
    QBmax::Vector{Int64}
    QEmax::Vector{Int64}
    UEMinusMax::Vector{Int64}
    UEPlusMax::Vector{Int64}
    DUMinus::SparseMatrixCSC{Int64, Int64}
    DUPlus::SparseMatrixCSC{Int64, Int64}
    CUMinus::SparseMatrixCSC{Float64, Int64}
    CUPlus::SparseMatrixCSC{Float64, Int64}

    trackCapabilities::Int64
    hasOperandNet::Int64
    hasQBinitCond::Int64
    hasQEinitCond::Int64
    hasQBfinalCond::Int64
    hasQEfinalCond::Int64
    hasQBCapacityConstraint::Int64
    hasQECapacityConstraint::Int64
    hasUEMinusCapacityConstraint::Int64
    hasUEPlusCapacityConstraint::Int64
    hasUEMinusExoConstraint::Int64
    hasUEPlusExoConstraint::Int64
    hasDeviceModels::Int64

    reciprocalResistance::SparseMatrixCSC{Float64, Int64}
    hasResistance::SparseMatrixCSC{Int64, Int64}
    elevation::Vector{Float64}
    QBminFlow::Vector{Float64}
    area::Vector{Float64}
end

# **Safe Conversion Functions**
function safe_int_conversion(vec)
    if isempty(vec)
        return [0]  # Default to zero for empty lists
    elseif vec isa AbstractVector
        return [x isa AbstractString ? parse(Int64, x) : Int64(x) for x in vec]
    else
        error("❌ Expected vector, received: $(typeof(vec))")
    end
end

function safe_float_conversion(vec)
    if isempty(vec)
        return [0.0]  # Default to zero for empty lists
    elseif vec isa AbstractVector
        return [x isa AbstractString ? parse(Float64, x) : Float64(x) for x in vec]
    else
        error("❌ Expected vector, received: $(typeof(vec))")
    end
end

# Convert booleans or binary values (1 if any nonzero value, else 0)
binary_indicator(vec) = Int64(any(!iszero, vec))

function initialize_lfes(parameters, incMatMatrices, buffer_params, process_params)
    return LFES(
        Int64(parameters["verboseMode"] == "true"),
        Int64(parameters["numOperands"]),
        Int64(parameters["numResources"]),
        Int64(parameters["numBuffers"]),
        Int64(parameters["numProcesses"]),
        Int64(parameters["numCapabilities"]),
        Int64(parameters["numOptTimeSteps"]),
        Int64(parameters["deltaT"]),
        Float64(parameters["tol"]),

        SparseMatrixCSC{Int64, Int64}(round.(Int, incMatMatrices["incMatPlus"])),
        SparseMatrixCSC{Int64, Int64}(round.(Int, incMatMatrices["incMatMinus"])),

        sparse(diagm(Int.(buffer_params["hasQBCapacityConstraint"] .== "true" .|| buffer_params["hasQBCapacityConstraint"] .== 1))),
        safe_int_conversion(buffer_params["QBinitCond"]),
        safe_int_conversion(process_params["QEinitCond"]),
        safe_int_conversion(buffer_params["QBfinalCond"]),
        safe_int_conversion(process_params["QEfinalCond"]),
        safe_int_conversion(buffer_params["costCoeffQB"]),
        safe_int_conversion(process_params["costCoeffQE"]),
        safe_int_conversion(process_params["duration"]),
        safe_int_conversion(buffer_params["QBmax"]),
        safe_int_conversion(process_params["QEmax"]),

        safe_int_conversion(process_params["UEMinusMax"]),
        safe_int_conversion(process_params["UEPlusMax"]),
        sparse(diagm(Int.(process_params["hasUEMinusExoConstraint"] .== "true" .|| process_params["hasUEMinusExoConstraint"] .== 1))),
        sparse(diagm(Int.(process_params["hasUEPlusExoConstraint"] .== "true" .|| process_params["hasUEPlusExoConstraint"] .== 1))),

        sparse(vcat(process_params["CUMinus"]...)),
        sparse(vcat(process_params["CUPlus"]...)),

        Int64(parameters["trackCapabilities"]),
        Int64(parameters["hasOperandNet"]),
        binary_indicator(buffer_params["hasQBinitCond"]),
        binary_indicator(process_params["hasQEinitCond"]),
        binary_indicator(buffer_params["hasQBfinalCond"]),
        binary_indicator(process_params["hasQEfinalCond"]),
        binary_indicator(buffer_params["hasQBCapacityConstraint"]),
        binary_indicator(process_params["hasQECapacityConstraint"]),
        binary_indicator(process_params["hasUEMinusCapacityConstraint"]),
        binary_indicator(process_params["hasUEPlusCapacityConstraint"]),
        binary_indicator(process_params["hasUEMinusExoConstraint"]),
        binary_indicator(process_params["hasUEPlusExoConstraint"]),
        Int64(parameters["hasDeviceModels"]),

        sparse(diagm([res != 0.0 ? 1.0 / res : 0.0 for res in safe_float_conversion(process_params["resistance"])])),
        sparse(diagm(Int.(process_params["hasResistance"] .== "true" .|| process_params["hasResistance"] .== 1))),
        safe_float_conversion(buffer_params["elevation"]),
        safe_float_conversion(buffer_params["QBminFlow"]),
        safe_float_conversion(buffer_params["area"])
    )
end