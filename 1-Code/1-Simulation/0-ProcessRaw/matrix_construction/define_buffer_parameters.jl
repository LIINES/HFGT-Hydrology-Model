# define_buffer_parameters.jl
# Define parameters associated with buffers from HFGT toolbox output HDF5 file
# Author: Megan S. Harris
# Date: February 2025

function define_buffer_parameters(buffer_keys, num_operands, hdf5_file)
    buffer_params = Dict()
    root_path = hdf5_file["outputData"]["value"]

    function process_resource_path(resource_path, base_key, operand)
        key = "$(base_key)_$operand"
        if !haskey(resource_path, key)
            return Float64[]
        end

        value_dict = read(resource_path[key]["value"])
        indices = sort([parse(Int, k[2:end]) for k in keys(value_dict) if k != "dims"])
        
        values = []
        for i in indices
            idx = "_$i"
            if haskey(value_dict, idx)
                temp_dict = Dict{String,Any}()
                temp_dict[idx] = value_dict[idx]
                temp_dict["dims"] = value_dict["dims"]
                
                val = extract_values(temp_dict, key)
                append!(values, val)
            end
        end
        
        return values
    end

    trans_resource_path = haskey(root_path, "transformationResource") ? 
        root_path["transformationResource"]["value"] : Dict()

    ind_buffer_path = haskey(root_path, "independentBuffer") ? 
        root_path["independentBuffer"]["value"] : Dict()

    for base_key in buffer_keys
        all_values = []
        for operand in 1:num_operands
            val_trans = process_resource_path(trans_resource_path, base_key, operand)
            val_ind = process_resource_path(ind_buffer_path, base_key, operand)
            append!(all_values, vcat(val_trans, val_ind))
        end
        buffer_params[base_key] = all_values
    end

    return buffer_params
end