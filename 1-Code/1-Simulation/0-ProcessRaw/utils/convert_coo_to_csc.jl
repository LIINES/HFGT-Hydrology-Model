# convert_coo_to_csc.jl
# Optional: convert coo matrix (HF incidence tensors) to output CSV file
# Author: Megan S. Harris
# Date: February 2025

using SparseArrays
unzip(iter) = (first.(iter), last.(iter))

function convert_coo_to_csc(coo_matrix::Any)
    # Ensure coo_matrix is in a valid format
    if isa(coo_matrix, SparseMatrixCSC)
        return coo_matrix  # Already sparse, return as-is
    elseif isa(coo_matrix, Dict)
        error("Invalid COO matrix: Expected a list of (i,j,v) tuples but got a Dict")
    elseif isa(coo_matrix, Matrix{Float64})
        return sparse(coo_matrix)  # Convert dense matrix to sparse format
    elseif !isa(coo_matrix, Vector)
        error("Invalid COO matrix: Expected a Vector of tuples or a dense matrix")
    end

    # Check if it's a list of tuples (row, col, value)
    if all(x -> isa(x, Tuple) && length(x) == 3, coo_matrix)
        rows, cols, values = unzip(coo_matrix)
        return sparse(rows, cols, values)  # Convert to SparseMatrixCSC
    end

    # If we receive a vector of numbers, assume diagonal matrix
    if all(x -> isa(x, Number), coo_matrix)
        println("Warning: Received a flat list, assuming diagonal matrix")
        return spdiagm(0 => coo_matrix)  # Convert to diagonal sparse matrix
    end

    error("Unexpected format for COO matrix: Must be a list of (row, col, value) tuples, a dense matrix, or numerical values")
end

# Convert all matrices in dictionary
function convert_all_to_csc(matrices_dict::Dict{Any, Any})
    return Dict(k => convert_coo_to_csc(v) for (k, v) in matrices_dict)
end
