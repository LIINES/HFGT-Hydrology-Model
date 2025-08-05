# extract_coo_matrix.jl
# Extract COO matrix from HFGT toolbox output HDF5 file
# Author: Megan S. Harris
# Date: February 2025

using HDF5, SparseArrays

function extract_coo_matrix(hdf5_file_path::String)
    h5open(hdf5_file_path, "r") do f
        return Dict(
            "MRho2Pos" => (
                coords = read(f["outputData/value/analytics/value/MRho2Pos/value/coords"])["value"],  # Extract array
                values = read(f["outputData/value/analytics/value/MRho2Pos/value/data"])["value"],    # Extract array
                shape = Tuple(Int.(read(f["outputData/value/analytics/value/MRho2Pos/value/myShape"])["value"])) # Ensure integers
            ),
            "MRho2Neg" => (
                coords = read(f["outputData/value/analytics/value/MRho2Neg/value/coords"])["value"],  # Extract array
                values = read(f["outputData/value/analytics/value/MRho2Neg/value/data"])["value"],    # Extract array
                shape = Tuple(Int.(read(f["outputData/value/analytics/value/MRho2Neg/value/myShape"])["value"])) # Ensure integers
            )
        )
    end
end

function coo_to_sparse(coo_matrix)
    coords = coo_matrix.coords  # Extract coordinate matrix
    values = coo_matrix.values  # Extract values
    shape = coo_matrix.shape  # Ensure it's a tuple of integers

    # Ensure `rows` and `cols` are 1D vectors
    rows, cols = vec(coords[1, :]), vec(coords[2, :])

    return sparse(rows .+ 1, cols .+ 1, vec(values), shape...)  # Convert to SparseMatrixCSC
end