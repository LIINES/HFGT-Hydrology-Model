# extract_values.jl
# Extract values of text and numerical type from HFGT toolbox output HDF5 file
# Author: Megan S. Harris
# Date: February 2025

function extract_values(param_input, key)
    values = []
    
    # Special case: if input is a 2-element vector of zeros, just return 0
    if param_input isa Vector && length(param_input) == 2 && all(x -> x == 0, param_input)
        return [0.0]
    end
    
    # Handle different input types
    if param_input isa Dict
        # Original dictionary handling logic
        for (index, entry) in param_input
            if index == "dims"  # Skip dimension info
                continue
            end
            
            if haskey(entry, "value")
                raw_value = entry["value"]
                try
                    # Special case: 2-element vector of zeros
                    if raw_value isa Vector && length(raw_value) == 2 && all(x -> x == 0, raw_value)
                        push!(values, 0.0)
                    else
                        process_value!(values, raw_value)
                    end
                catch
                    push!(values, 0.0)  # Return 0.0 instead of NaN on failure
                end
            else
                push!(values, 0.0)  # If key is missing, return 0.0
            end
        end
    elseif param_input isa Vector || param_input isa Matrix
        # Handle vector/matrix input
        for val in param_input
            try
                # Special case: 2-element vector of zeros
                if val isa Vector && length(val) == 2 && all(x -> x == 0, val)
                    push!(values, 0.0)
                else
                    process_value!(values, val)
                end
            catch
                push!(values, 0.0)
            end
        end
    else
        # Handle single value input
        try
            process_value!(values, param_input)
        catch
            push!(values, 0.0)
        end
    end
    
    return values
end

# Helper function to process individual values
function process_value!(values, raw_value)
    if raw_value isa Matrix{Int8} || raw_value isa Vector{Int8}
        # Handle ASCII-encoded strings
        str_value = String(vec(Char.(raw_value[:])))  # Convert ASCII matrix to string
        str_value = lowercase(strip(str_value))  # Normalize string
        
        # Convert boolean-like strings to numeric values
        if str_value == "true"
            push!(values, 1.0)
        elseif str_value == "false"
            push!(values, 0.0)
        else
            push!(values, str_value)  # Store as a string
        end
    elseif raw_value isa Number
        push!(values, Float64(raw_value))  # Convert numbers directly
    elseif raw_value isa Vector || raw_value isa Matrix
        # Special case: handle 2-element vector of zeros
        if raw_value isa Vector && length(raw_value) == 2 && all(x -> x == 0, raw_value)
            push!(values, 0.0)
        # Handle list-like numerical values
        elseif isempty(raw_value)
            push!(values, 0.0)  # Return zero if the list is empty
        else
            push!(values, Float64(raw_value[1]))  # Take the first element
        end
    elseif raw_value isa String
        # Handle string input
        str_value = lowercase(strip(raw_value))
        if str_value == "true"
            push!(values, 1.0)
        elseif str_value == "false"
            push!(values, 0.0)
        else
            push!(values, str_value)
        end
    else
        throw(ArgumentError("Unsupported value type: $(typeof(raw_value))"))
    end
end