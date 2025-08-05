function generate_time_series(code_word, parameters, cap_index;
                               buffer_params=nothing, incMatMatrices=nothing)
    # Ensure code_word is a string
    if !isa(code_word, AbstractString)
        code_word = string(code_word)
    end

    # Default area scaling
    buffer_area = 1.0

    # Derive buffer index from incMatPlus if available
    if !isnothing(buffer_params) && !isnothing(incMatMatrices)
        buffer_index = findfirst(x -> x == 1, incMatMatrices["incMatPlus"][:, cap_index])

        if !isnothing(buffer_index) && buffer_index <= length(buffer_params["area"])
            area_value = buffer_params["area"][buffer_index]
            buffer_area = isa(area_value, Number) ? area_value : parse(Float64, area_value)
            buffer_area /= 1000.0  # scale to m² as before
        end
    end

    # Generate time series based on code word
    if code_word == "rainfall"
        base_flow = hcat(
            30.0e-4 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            20.0e-4 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            10.0e-4 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            40.0e-4 * ones(1, Int(parameters["numOptTimeSteps"]-3/4* parameters["numOptTimeSteps"]))
        )
        return base_flow .* buffer_area

    elseif code_word == "fertilizer1"
        fertilizer_1 = hcat(
            3.0e-2 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            2.0e-1 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            1.5e-1 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            0.5e-1 * ones(1, Int(parameters["numOptTimeSteps"]-3/4* parameters["numOptTimeSteps"]))
        )
        return fertilizer_1 .* buffer_area
    
    elseif code_word == "fertilizer2"
        fertilizer_2 = hcat(
            1.5e-2 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            1.5e-1 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            2.0e-1 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            0.5e-1 * ones(1, Int(parameters["numOptTimeSteps"]-3/4* parameters["numOptTimeSteps"]))
        )
        return fertilizer_2 .* buffer_area
    
    elseif code_word == "fertilizer3"
        fertilizer_3 = hcat(
            3.0e-2 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            2.0e-1 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            2.0e-1 * ones(1, Int(parameters["numOptTimeSteps"]/4)),
            3.0e-2 * ones(1, Int(parameters["numOptTimeSteps"]-3/4* parameters["numOptTimeSteps"]))
        )
        return fertilizer_3 .* buffer_area

    else
        return zeros(1, parameters["numOptTimeSteps"])
    end
end
