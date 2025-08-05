# define_process_parameters.jl
# Define parameters associated with processes from HFGT toolbox output HDF5 file
# Author: Megan S. Harris
# Date: February 2025

include("extract_values.jl")

function define_process_parameters(process_keys, hdf5_file)
    process_params = Dict(key => [] for key in process_keys)
    root_path = hdf5_file["outputData"]["value"]
    
    resource_types = ["transformationResource", "independentBuffer", "transportationResource"]

    function sort_numeric_indices(keys)
        return sort(
            filter(x -> x != "dims", collect(keys)),
            by=x -> parse(Int, x[2:end])
        )
    end

    # Helper function to process values
    function process_value!(params, key, value_container)
        raw_val = if haskey(value_container, "value")
            read(value_container["value"])
        else
            read(value_container)
        end

        if raw_val isa Union{Matrix{Int8}, Vector{Int8}}
            str_value = String(vec(Char.(raw_val[:])))
            append!(params[key], extract_values([str_value], key))
        elseif raw_val isa String
            append!(params[key], extract_values([raw_val], key))
        else
            append!(params[key], extract_values(raw_val, key))
        end
    end

    # Start with process keys
    for key in process_keys
        # Iterate through resource types
        for resource_type in resource_types
            if !haskey(root_path, resource_type)
                continue
            end

            resource_type_path = root_path[resource_type]["value"]
            
            # Get all resource numbers across both process types
            resource_numbers = Set{String}()
            
            # Check transform process
            if haskey(resource_type_path, "transformProcess")
                transform_path = resource_type_path["transformProcess"]["value"]
                union!(resource_numbers, sort_numeric_indices(keys(transform_path)))
            end
            
            # Check transport process
            if haskey(resource_type_path, "transportProcess")
                transport_path = resource_type_path["transportProcess"]["value"]
                union!(resource_numbers, sort_numeric_indices(keys(transport_path)))
            end
            
            # Sort all resource numbers
            resource_numbers = sort(collect(resource_numbers))
            
            # Process each resource number
            for res_num in resource_numbers
                # First process transform process if it exists
                if haskey(resource_type_path, "transformProcess")
                    transform_path = resource_type_path["transformProcess"]["value"]
                    
                    if haskey(transform_path, res_num) && haskey(transform_path[res_num], "value")
                        process_path = transform_path[res_num]["value"]
                        
                        if haskey(process_path, key)
                            key_path = process_path[key]["value"]
                            process_numbers = sort_numeric_indices(keys(key_path))
                            
                            for proc_num in process_numbers
                                process_value!(process_params, key, key_path[proc_num])
                            end
                        end
                    end
                end

                # Then process transport process if it exists
                if haskey(resource_type_path, "transportProcess")
                    transport_path = resource_type_path["transportProcess"]["value"]
                    
                    if haskey(transport_path, res_num) && haskey(transport_path[res_num], "value")
                        process_path = transport_path[res_num]["value"]
                        
                        if haskey(process_path, key)
                            key_path = process_path[key]["value"]
                            process_numbers = sort_numeric_indices(keys(key_path))
                            
                            for proc_num in process_numbers
                                process_value!(process_params, key, key_path[proc_num])
                            end
                        end
                    end
                end
            end
        end
    end

    return process_params
end