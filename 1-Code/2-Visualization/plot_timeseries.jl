# plot_timeseries.jl
# Function to plot time series results from HFNMCF results
# Author: Megan S. Harris
# Date: February 2025

 StatsPlots
using DataFrames

function plot_buffer_timeseries(variable::AbstractArray, t::AbstractVector,
                               names::Vector{String},
                               xlabel::AbstractString,
                               ylabel::AbstractString,
                               title::AbstractString,
                               save_path=nothing;
                               colors=nothing,
                               markers=nothing)
    # Handle both matrix (multiple buffers) and vector (single buffer) cases
    if ndims(variable) == 1
        # Vector case (single buffer)
        num_buffers = 1
        num_steps = length(variable)
        # Reshape to a 1×n matrix for consistent processing
        variable_mat = reshape(variable, 1, num_steps)
    else
        # Matrix case (multiple buffers)
        num_buffers, num_steps = size(variable)
        variable_mat = variable
    end

    # Default names if none provided
    if isnothing(names)
        names = ["Buffer $i" for i in 1:num_buffers]
    end

    # Default colors - use a diverse color palette
    if isnothing(colors)
        default_colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray, :olive, :cyan]
        colors = default_colors[1:min(num_buffers, length(default_colors))]
        # If more buffers than default colors, cycle through them
        if num_buffers > length(default_colors)
            colors = [default_colors[((i-1) % length(default_colors)) + 1] for i in 1:num_buffers]
        end
    end

    # Default markers - use a variety of marker shapes
    if isnothing(markers)
        default_markers = [:circle, :square, :diamond, :utriangle, :dtriangle, :star5, :hexagon, :cross, :xcross, :star4]
        markers = default_markers[1:min(num_buffers, length(default_markers))]
        # If more buffers than default markers, cycle through them
        if num_buffers > length(default_markers)
            markers = [default_markers[((i-1) % length(default_markers)) + 1] for i in 1:num_buffers]
        end
    end

    # Create a long-format DataFrame
    rows = []
    for i in 1:num_buffers
        for j in 1:num_steps
            push!(rows, (time = t[j], value = variable_mat[i, j], name = names[i]))
        end
    end
    df = DataFrame(rows)

    # Plot each series separately for better control over colors and markers
    p = plot(xlabel = xlabel, ylabel = ylabel, title = title, legend = :bottomright,
             size = (800, 350), margin = 1Plots.mm, bottommargin = 3Plots.mm,
             leftmargin = 3Plots.mm, titlefontsize = 12, guidefontsize = 10,
             legendfontsize = 8)
    
    for i in 1:num_buffers
        series_data = filter(row -> row.name == names[i], df)
        plot!(p, series_data.time, series_data.value,
              color = colors[i],
              marker = markers[i],
              linewidth = 1.5,
              markersize = 3,
              markerstrokewidth = 0,
              label = names[i])
    end

    # Save the plot if a path is provided
    if !isnothing(save_path)
        # Save as PDF
        savefig(p, save_path * ".pdf")
        
        # Save as PNG
        savefig(p, save_path * ".png")
    end
    return p
end