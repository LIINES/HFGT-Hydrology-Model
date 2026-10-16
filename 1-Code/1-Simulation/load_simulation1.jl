# load_simulation1.jl
# Run Code for Simulation 1: System with 1 Lake
# Author: Megan S. Harris
# Date: May 2025

using HDF5, SparseArrays, XLSX, LinearAlgebra

# Repository root, so the script runs from any working directory
const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

# Include all necessary modules
include("0-ProcessRaw/data_processing/load_hdf5.jl")
include("0-ProcessRaw/exogenous_flows/generate_time_series.jl")
include("0-ProcessRaw/matrix_construction/extract_coo_matrix.jl")
include("0-ProcessRaw/matrix_construction/define_buffer_parameters.jl")
include("0-ProcessRaw/matrix_construction/define_process_parameters.jl")
include("0-ProcessRaw/lfes_model/construct_matrices.jl")
include("0-ProcessRaw/lfes_model/initialize_lfes.jl")
include("0-ProcessRaw/utils/convert_coo_to_csc.jl")
include("0-ProcessRaw/utils/validate_lfes.jl")
include("0-ProcessRaw/utils/print_system_concept.jl")
include("../2-Visualization/plot_results.jl")

# Function to save incidence matrices to Excel
function save_incidence_matrices_to_excel(incMatPlus, incMatMinus, file_name)
    # Convert sparse matrices to full
    incMatPlus_full = Matrix(incMatPlus)
    incMatMinus_full = Matrix(incMatMinus)
    # Calculate the combined incidence matrix (incMatPlus - incMatMinus)
    incMat_full = incMatPlus_full - incMatMinus_full
    
    # Create a new Excel file
    XLSX.openxlsx(file_name, mode="w") do xf
        # Add sheets for each matrix
        sheet_incMat = XLSX.addsheet!(xf, "incMat")
        sheet_incMatPlus = XLSX.addsheet!(xf, "incMatPlus")
        sheet_incMatMinus = XLSX.addsheet!(xf, "incMatMinus")
        
        # Write matrices to respective sheets
        rows, cols = size(incMat_full)
        
        # Write incMat sheet
        for r in 1:rows
            for c in 1:cols
                sheet_incMat[XLSX.CellRef(r, c)] = incMat_full[r, c]
            end
        end
        
        # Write incMatPlus sheet
        for r in 1:rows
            for c in 1:cols
                sheet_incMatPlus[XLSX.CellRef(r, c)] = incMatPlus_full[r, c]
            end
        end
        
        # Write incMatMinus sheet
        for r in 1:rows
            for c in 1:cols
                sheet_incMatMinus[XLSX.CellRef(r, c)] = incMatMinus_full[r, c]
            end
        end
    end
    
    println("Incidence matrices saved to $file_name")
end

# Load HDF5 file
# file_path = "myLFES-Full-Three Lake Land System Both Operands Test-Default-Base-2.hdf5"
file_path = joinpath(REPO_ROOT, "0-Data/1-IntermediateData/HDF5s/myLFES-Full-Simulation 1-Default-Base-2.hdf5")
hdf5_file, _ = load_hdf5(file_path)

# Extract system parameters (manually defined)
parameters = Dict(
    "verboseMode" => String(vec(Char.(read(hdf5_file["outputData/value/verboseMode/value/_0/value"])))),
    "numOperands" => read(hdf5_file["outputData/value/operand/value/number"])["value"],
    "numResources" => read(hdf5_file["outputData/value/physicalResource/value/number"])["value"],
    "numBuffers" => read(hdf5_file["outputData/value/buffer/value/number"])["value"],
    "numProcesses" => read(hdf5_file["outputData/value/systemProcess/value/number"])["value"],
    "numCapabilities" => length(keys(read(hdf5_file["/outputData/value/systemConcept/value/name/value"])))-1,  
    "trackCapabilities" => 1,             
    "simulationDuration" => 31449600, # 364 days = 52 weeks (s)
    "deltaT" => 21600, # six hours (s); see README on time-step choice
    "numOptTimeSteps" => 1456,   # 52 weeks of 6-hour steps
    "hasOperandNet" => 0,
    "hasDeviceModels" => 1,
    "tol" => 0.001
)

# Define variables to extract from personalized XML file
buffer_keys = [
    "hasQBinitCond", "hasQBfinalCond", "hasQBCapacityConstraint", 
    "QBinitCond", "QBfinalCond", "QBmax", "costCoeffQB", "QBminFlow",
    "area", "elevation"
]
process_keys = [
    "hasResistance", "hasUEMinusExoConstraint", "hasUEPlusExoConstraint",
    "hasUEMinusCapacityConstraint", "hasUEPlusCapacityConstraint",
    "hasQEinitCond", "hasQEfinalCond", "hasQECapacityConstraint",
    "UEMinusMax", "UEPlusMax", "resistance", "QEinitCond",
    "QEfinalCond", "QEmax", "costCoeffQE", "duration",
    "CUMinus", "CUPlus"
]

# Extract buffer parameters
println("Extracting buffer parameters...")
buffer_params = define_buffer_parameters(buffer_keys, Int8(parameters["numOperands"]), hdf5_file)

# Extract process parameters
println("Extracting process parameters...")
process_params = define_process_parameters(process_keys, hdf5_file)

# Extract COO matrices (Incidence Matrices)
println("Extracting HF Incidence Tensors...")
coo_matrices = extract_coo_matrix(file_path)
incMatMatrices = Dict(
    "incMatPlus" => coo_to_sparse(coo_matrices["MRho2Pos"]),
    "incMatMinus" => coo_to_sparse(coo_matrices["MRho2Neg"])
)

# Replace `CUMinus` and `CUPlus` values if they are strings
# println("Defining exogenous flows...")
# for key in ["CUMinus", "CUPlus"]
#     if haskey(process_params, key)
#         process_params[key] = [generate_time_series(value, parameters["deltaT"], parameters["numOptTimeSteps"]) for value in process_params[key]]
#     end
# end
println("Defining exogenous flows...")
for key in ["CUMinus", "CUPlus"]
    if haskey(process_params, key)
        process_params[key] = [
            generate_time_series(code_word, parameters, cap_index;
                                 buffer_params=buffer_params, incMatMatrices=incMatMatrices)
            for (cap_index, code_word) in enumerate(process_params[key])
        ]
    end
end

# Initialize LFES model
println("Building LFES model...")
myLFES = initialize_lfes(parameters, incMatMatrices, buffer_params, process_params)

println("LFES Model Ready!")

# Simulation 1 has three buffers (Lake 1, Point 1, Point 2). An HDF5 built from the
# earlier two-buffer XML has only two, and its transport columns are wrong.
myLFES.numBuffers == 3 || error("The Simulation 1 HDF5 has $(myLFES.numBuffers) buffers; expected 3. " *
    "Regenerate it from 0-Data/0-RawData/XMLs/Lake-Land_Simulation1.xml with the HFGT toolbox.")

# ========================
# CONFIGURATION OPTIONS
# ========================
should_print_system_concept = false  # Set this to `true` or `false` when needed
should_save_incidence_matrices = true  # Set this to `true` or `false` when needed
incidence_matrices_filename = joinpath(REPO_ROOT, "0-Data/1-IntermediateData/IncidenceTensors/simulation1_incidence_matrices.xlsx")  # Change this to specify a different filename

if should_print_system_concept
    print_system_concept(hdf5_file)
end

if should_save_incidence_matrices
    mkpath(dirname(incidence_matrices_filename))
    save_incidence_matrices_to_excel(
        incMatMatrices["incMatPlus"], 
        incMatMatrices["incMatMinus"], 
        incidence_matrices_filename
    )
end

include("1-SimulateDiscrete/simulateDiscreteHFGT.jl")
include("2-SimulateDifferential/differential-solution.jl")
time = collect(0:myLFES.numOptTimeSteps) .* (myLFES.deltaT / 604800) # in weeks
water_buffers = QB[1:myLFES.numBuffers,:]
nitrogen_buffers = QB[(myLFES.numBuffers+1):2*myLFES.numBuffers,:]
concentration_buffers = nitrogen_buffers./water_buffers
lake_concentrations = concentration_buffers[1,:]

hfgt_conc = reshape(lake_concentrations, 1, :)
diff_conc = reshape(conc_lake_sol, 1, :)
combined_conc = vcat(hfgt_conc, diff_conc)

# Agreement between the discrete HFGT and continuous CSTR solutions
rel_diff = abs.(lake_concentrations .- conc_lake_sol) ./ conc_lake_sol
println("Lake 1 TN, HFGT vs CSTR: max relative difference = ", round(100 * maximum(rel_diff), digits=2), " %")
println("Lake 1 TN, HFGT vs CSTR: RMSE = ", round(sqrt(sum((lake_concentrations .- conc_lake_sol).^2) / length(conc_lake_sol)), sigdigits=3), " mg/L")
outflow_share = (QB[3, end] - QB[3, 1]) / sum(myLFES.CUMinus[findfirst(!iszero, diag(myLFES.DUMinus)), :] .* myLFES.deltaT)
println("Water delivered to Point 2 / net water input = ", round(outflow_share, digits=3))

# Water depth in Lake 1 (total depth = volume / surface area)
depth_hfgt = QB[1, :] ./ myLFES.area[1]
depth_cstr = V_lake_sol ./ myLFES.area[1]
println("Lake 1 depth, HFGT vs CSTR: max absolute difference = ",
        round(maximum(abs.(depth_hfgt .- depth_cstr)) * 100, digits=2), " cm")

fig1 = plot_simulation1(time, depth_hfgt, depth_cstr, lake_concentrations, conc_lake_sol,
                        joinpath(REPO_ROOT, "0-Data/2-FinalData/LakeConcentrations/sim1_results"))
display(fig1)
