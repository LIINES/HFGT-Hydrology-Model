# plot_results.jl
# Publication figures for the three illustrative simulations.
# Every figure shares (A) lake water depth and (B) lake total nitrogen;
# Simulation 3 adds (C) nitrogen stored on the land segments.
# Author: Megan S. Harris
# Date: October 2026

using StatsPlots   # re-exports Plots

# One fixed color and marker per lake in every figure (validated categorical palette;
# markers give a second, color-independent encoding). Land i uses Lake i's color.
LAKE_COLORS  = ["#2a78d6", "#eb6834", "#1baf7a"]
LAKE_MARKERS = [:circle, :rect, :diamond]
DEPTH_LIMS   = (2.5, 6.0)          # same depth axis in all figures
INK          = "#3d3d3a"

function base_panel(title, ylabel)
    p = plot(; title = title, titlelocation = :left, titlefontsize = 10,
             xlabel = "Time (weeks)", ylabel = ylabel, xlims = (0, 52),
             xticks = 0:13:52, guidefontsize = 9, tickfontsize = 8,
             legendfontsize = 7, legend = :topright, foreground_color_legend = nothing,
             background_color_legend = nothing, grid = true, gridalpha = 0.15,
             framestyle = :axes, foreground_color_axis = INK, foreground_color_text = INK)
    # Light shading on Apr-Jun and Oct-Dec marks the seasonal input blocks
    for (a, b) in ((13.0, 26.0), (39.0, 52.0))
        vspan!(p, [a, b]; color = :gray, alpha = 0.08, linewidth = 0, label = false)
    end
    return p
end

# Index of one sample per week (t is in weeks)
weekly(t) = 1:max(1, round(Int, 1 / (t[2] - t[1]))):length(t)

# Series drawn as a line, with a marker once a week for identity
function series!(p, t, y; color, marker, label)
    plot!(p, t, y; color = color, linewidth = 2, label = false)
    wk = weekly(t)
    scatter!(p, t[wk], y[wk]; color = color, marker = marker, markersize = 4,
             markerstrokecolor = :white, markerstrokewidth = 0.5, label = label)
end

function save_figure(p, path)
    savefig(p, path * ".pdf")
    savefig(p, path * ".png")
    println("Saved ", path, ".pdf/.png")
end

"""Simulation 1: Lake 1 depth and TN, discrete HFGT vs continuous CSTR."""
function plot_simulation1(t, depth_hfgt, depth_cstr, tn_hfgt, tn_cstr, path)
    c = LAKE_COLORS[1]
    pA = base_panel("(A) Lake 1 water depth", "Depth (m)")
    plot!(pA; ylims = DEPTH_LIMS)
    plot!(pA, t, depth_cstr; color = INK, linewidth = 1.5, label = "CSTR (continuous)")
    wk = weekly(t)
    scatter!(pA, t[wk], depth_hfgt[wk]; color = c, marker = :circle, markersize = 4,
             markerstrokecolor = :white, markerstrokewidth = 0.5, label = "HFGT (discrete)")
    pB = base_panel("(B) Lake 1 total nitrogen", "TN (mg/L)")
    plot!(pB; ylims = (0, 1.25 * maximum(tn_cstr)))       # from zero, with room for the legend
    plot!(pB, t, tn_cstr; color = INK, linewidth = 1.5, label = "CSTR (continuous)")
    scatter!(pB, t[wk], tn_hfgt[wk]; color = c, marker = :circle, markersize = 4,
             markerstrokecolor = :white, markerstrokewidth = 0.5, label = "HFGT (discrete)")
    p = plot(pA, pB; layout = (1, 2), size = (900, 340), left_margin = 6Plots.mm,
             bottom_margin = 5Plots.mm)
    save_figure(p, path)
    return p
end

"""Simulations 2 and 3: lake depth and TN for Lakes 1-3, plus (Simulation 3) land N storage."""
function plot_network(t, lake_depth, lake_tn, path; land_n_kg_ha = nothing,
                      land_labels = ["Land 1", "Land 2", "Land 3"])
    pA = base_panel("(A) Lake water depth", "Depth (m)")
    plot!(pA; ylims = DEPTH_LIMS)
    pB = base_panel("(B) Lake total nitrogen", "TN (mg/L)")
    for i in 1:3
        series!(pA, t, lake_depth[i, :]; color = LAKE_COLORS[i], marker = LAKE_MARKERS[i], label = "Lake $i")
        series!(pB, t, lake_tn[i, :];    color = LAKE_COLORS[i], marker = LAKE_MARKERS[i], label = "Lake $i")
    end
    plot!(pB; ylims = (0, 1.25 * maximum(lake_tn)))       # from zero, with room for the legend
    panels = Any[pA, pB]
    if !isnothing(land_n_kg_ha)
        pC = base_panel("(C) Nitrogen stored on land", "Stored N (kg/ha)")
        for i in 1:3
            series!(pC, t, land_n_kg_ha[i, :]; color = LAKE_COLORS[i], marker = LAKE_MARKERS[i],
                    label = land_labels[i])
        end
        plot!(pC; ylims = (0, 1.3 * maximum(land_n_kg_ha)))
        push!(panels, pC)
    end
    n = length(panels)
    p = plot(panels...; layout = (1, n), size = (450 * n, 340), left_margin = 6Plots.mm,
             bottom_margin = 5Plots.mm)
    save_figure(p, path)
    return p
end
