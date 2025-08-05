# validate_lfes.jl
# Validate myLFES to ensure all required elements are present and are of the correct size
# Author: Megan S. Harris
# Date: February 2025

function validate_lfes(lfes_model)
    println("Validating LFES model...")
    
    parameters = lfes_model["parameters"]
    matrices = lfes_model["matrices"]
    
    errors = []  # Collect errors instead of returning early
    
    # Check required parameters
    required_params = ["simulationDuration", "deltaT", "numOptTimeSteps", "hasOperandNet", "hasDeviceModels", "tol"]
    missing_params = filter(p -> !haskey(parameters, p), required_params)
    
    if !isempty(missing_params)
        push!(errors, "Missing parameters: $(join(missing_params, ", "))")
    end
    
    # Check required matrices
    required_matrices = ["incMatPlus", "incMatMinus", "DQBconstraint", "CUMinus", "CUPlus"]
    missing_matrices = filter(m -> !haskey(matrices, m), required_matrices)
    
    if !isempty(missing_matrices)
        push!(errors, "Missing matrices: $(join(missing_matrices, ", "))")
    end
    
    # Check matrix dimensions consistency
    if haskey(matrices, "incMatPlus") && haskey(matrices, "incMatMinus")
        if size(matrices["incMatPlus"]) != size(matrices["incMatMinus"])
            push!(errors, "Inconsistent incidence matrix sizes.")
        end
    end
    
    # Check matrix types (ensure they are sparse or numerical)
    for m in required_matrices
        if haskey(matrices, m) && !(matrices[m] isa AbstractMatrix)
            push!(errors, "Matrix $m is not a valid matrix type.")
        end
    end
    
    # Check numerical parameter types
    expected_numeric_types = ["simulationDuration", "deltaT", "numOptTimeSteps", "tol"]
    for param in expected_numeric_types
        if haskey(parameters, param) && !(parameters[param] isa Number)
            push!(errors, "Parameter $param should be a number but got $(typeof(parameters[param]))")
        end
    end
    
    # Final validation result
    if isempty(errors)
        println("LFES Model validation passed!")
        return true
    else
        println(join(errors, "\n"))  # Print all errors
        return false
    end
end