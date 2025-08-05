# load_simulation2.jl
# Run Code for Simulation 2: System with 3 Lakes
# Author: Megan S. Harris
# Date: May 2025

using HDF5, SparseArrays, XLSX

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
include("../2-Visualization/plot_timeseries.jl")

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
file_path = "0-Data/1-IntermediateData/HDF5s/myLFES-Full-Simulation 2-Default-Base-2.hdf5"
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
    "simulationDuration" => 31449600, # 52 weeks (s)
    "deltaT" => 604800, # one week (s)
    "numOptTimeSteps" => 52,
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

# ========================
# CONFIGURATION OPTIONS
# ========================
should_print_system_concept = false  # Set this to `true` or `false` when needed
should_save_incidence_matrices = true  # Set this to `true` or `false` when needed
incidence_matrices_filename = "0-Data/0-RawData/IncidenceTensors/simulation3_incidence_matrices.xlsx"  # Change this to specify a different filename

if should_print_system_concept
    print_system_concept(hdf5_file)
end

if should_save_incidence_matrices
    save_incidence_matrices_to_excel(
        incMatMatrices["incMatPlus"], 
        incMatMatrices["incMatMinus"], 
        incidence_matrices_filename
    )
end

include("../1-SimulateDiscrete/simulateDiscreteHFGT.jl")
time = 0:1:myLFES.numOptTimeSteps # in weeks
water_buffers = QB[1:myLFES.numBuffers,:]
nitrogen_buffers = QB[(myLFES.numBuffers+1):2*myLFES.numBuffers,:]
concentration_buffers = nitrogen_buffers./water_buffers
lake_concentrations = concentration_buffers[1:3,:]

names_buffers = ["Lake 1","Lake 2","Lake 3",
                "Point 1", "Point 2"]
names_lakes = ["Lake 1", "Lake 2", "Lake 3"]
concentration_plot = plot_buffer_timeseries(lake_concentrations, time, names_lakes,
                                "Time (weeks)",
                                 "Concentration (mg/L)",
                                 "Simulation 2: Lake Concentration Over Time",
                                 "0-Data/2-FinalData/LakeConcentrations/sim2_lakeconc",
                                 colors=["#4363d8", "#3cb44b","#f58231"],
                                markers=[:circle,:square,:diamond])
display(concentration_plot)