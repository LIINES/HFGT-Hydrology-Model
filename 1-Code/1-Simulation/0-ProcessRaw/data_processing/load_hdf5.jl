# load_hdf5.jl
# Load and open HDF5 file output from the HFGT toolbox
# Author: Megan S. Harris
# Date: February 2025

using HDF5

function load_hdf5(file_path)
    println("Loading HDF5 file: $file_path")
    file = h5open(file_path, "r")  # Open HDF5 file in read mode
    
    # Navigate to analytics matrices
    analytics_path = file["outputData"]["value"]["analytics"]["value"]
    matrix_names = collect(keys(analytics_path))

    # println("Available Matrices: ", matrix_names)
    
    return file, matrix_names
end