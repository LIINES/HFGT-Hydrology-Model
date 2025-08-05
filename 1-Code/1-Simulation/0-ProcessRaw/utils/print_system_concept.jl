# print_system_concept.jl
# Optional: print system concept from HFGT toolbox output HDF5 file
# Author: Megan S. Harris
# Date: February 2025

function print_system_concept(hdf5_file)
    base_path = "/outputData/value/systemConcept/value/name/value"

    if !haskey(hdf5_file, base_path)
        println("Path not found: $base_path")
        return
    end

    base_group = hdf5_file[base_path]

    # Get sorted keys, ignoring "dims"
    sorted_keys = sort(
        filter(x -> x != "dims", keys(base_group)), 
        by = x -> tryparse(Int, x[2:end])
    )

    println("\n Extracted Names from: $base_path")
    
    # Iterate over sorted keys and print extracted values
    for key in sorted_keys
        raw_value = read(base_group[key]["value"])

        if raw_value isa Matrix{Int8} || raw_value isa Vector{Int8}
            string_value = String(vec(Char.(raw_value[:])))
            println("$key -> \"$string_value\"")
        else
            println("Unexpected format for key $key: $(typeof(raw_value))")
        end
    end
end