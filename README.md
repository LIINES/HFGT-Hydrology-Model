# HFGT-Hydrology-Model

Data and code for: **An Introduction to Model-Based Systems Engineering and Hetero-functional Graph Theory for Hydrological Systems of Systems** (Harris, Naderi, Ghorbanichemazkati, Little and Farid).

The repository reproduces the three illustrative simulations in the paper:

| Simulation | System | What it demonstrates |
|---|---|---|
| 1 | Lake 1 → River Segment 1 → Point 1 → River Segment 2 → Point 2 | The full workflow on the smallest system, validated against an independent continuous-time CSTR solution |
| 2 | Three lakes joined by four river segments and two points | Routing and mixing through a network |
| 3 | Simulation 2 plus three agricultural land segments | Adding a new element of the reference architecture (land) and nitrogen loading |

## Repository layout

```
0-Data/
  0-RawData/XMLs/                 Instantiated architectures (HFGT toolbox input)
  1-IntermediateData/HDF5s/       HFGT toolbox output (incidence tensors and attributes)
  1-IntermediateData/IncidenceTensors/  Incidence matrices exported by the Julia scripts
  2-FinalData/LakeConcentrations/ Figures (sim1_results, sim2_results, sim3_results; PDF and PNG)
  2-FinalData/ReferenceArchitecture/ SysML model (Magic Systems of Systems Architect, SysML v1)
1-Code/
  1-Simulation/load_simulation{1,2,3}.jl   Run one simulation end to end
  1-Simulation/0-ProcessRaw/               Read the HDF5 and build the model
  1-Simulation/1-SimulateDiscrete/         Discrete-time HFGT simulation and device models
  1-Simulation/2-SimulateDifferential/     Continuous-time CSTR solution (Simulation 1)
  2-Visualization/plot_results.jl          Figures
hfgtToolbox-v4.0.8.zip            HFGT toolbox version used for the paper (MIT license)
Project.toml, Manifest.toml       Exact Julia package versions
```

## Requirements

- **Julia 1.12.4.** All package versions are pinned in `Manifest.toml`.
- **HFGT toolbox v4.0.8** (only needed to regenerate the HDF5 files, which are already included). It requires Python ≥ 3.9 with `scipy>=1.11`, `numpy`, `sparse`, `numba`, `dicttoxml`, `xmltodict`, `bsdf` and `oct2py`, plus GNU Octave for writing HDF5. It was run with Python 3.11, SciPy 1.14.1 and Octave from Homebrew. The `.python-version` file inside the toolbox (3.7.9) is out of date.

Newer versions of the HFGT toolbox are available from the authors on request.

## Running the simulations

```bash
cd HFGT-Hydrology-Model
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # first time only
julia --project=.
```

```julia
include("1-Code/1-Simulation/load_simulation1.jl")
include("1-Code/1-Simulation/load_simulation2.jl")
include("1-Code/1-Simulation/load_simulation3.jl")
```

Each script prints its checks (Simulation 1: agreement with the CSTR solution; all: share of water reaching the outlet; Simulation 3: nitrogen mass balance) and writes its figure to `0-Data/2-FinalData/LakeConcentrations/`.

## Regenerating the HDF5 files (optional)

```bash
unzip hfgtToolbox-v4.0.8.zip -x "__MACOSX/*" -d toolbox
cd toolbox/hfgtToolbox-2025-02-12
mkdir -p 0_Input_Data/Archive
rm -f "1_Output_Data/"*Simulation*        # the archive ships with older outputs of the same names
cp ../../0-Data/0-RawData/XMLs/Lake-Land_Simulation*.xml 0_Input_Data/
for n in 1 2 3; do echo y | python src_python/PyHFGTToolbox_Analysis.py 0_Input_Data/Lake-Land_Simulation$n.xml; done
cp 1_Output_Data/myLFES-Full-Simulation*.hdf5 ../../0-Data/1-IntermediateData/HDF5s/
```

The `echo y` answers the toolbox's prompt about running outside a Git repository.

## Model inputs

All case-study data are synthetic but scaled to published values:

- **Water input:** 1083 mm/yr precipitation (NOAA NCEI 1991–2020 climate normal, Blacksburg, VA), of which 40% is taken as net water input, with seasonal multipliers 1.6, 1.1, 0.4 and 0.9 for Jan–Mar, Apr–Jun, Jul–Sep and Oct–Dec. In Simulations 1 and 2 each lake receives the net input from a contributing area 15–25 times its surface area (`netprecipDA<k>`); in Simulation 3 that area is represented explicitly by the land segments.
- **Nitrogen input (Simulation 3):** Chesapeake Bay Program Phase 6 Watershed Model edge-of-stream total-nitrogen loading rates for full-season soybeans (31.09 kg/ha/yr), other agronomic crops (19.70) and pasture (13.20), applied 15/55/15/15% by season.
- **Lakes:** 30, 40 and 50 ha; 3.0, 4.0 and 3.5 m below the outlet sill. Initial total nitrogen 1.2, 0.9 and 0.6 mg/L in Simulations 1 and 2.
- **Points:** Point 1 represents river-reach storage (5 km × 20 m); Point 2 is the receiving water downstream of the watershed outlet.
- **Resistances** give lake time constants of 20 days (60 days for lake plus land in Simulation 3), 30 days for land segments, and a 0.3 m head drop at mean flow for river reaches. **Elevations** are set so that each storage element sits at its target depth at mean flow. **Initial storages** come from a multi-year spin-up (3 years for Simulations 1 and 2, 10 years for Simulation 3) with the same time step.

The time step is 6 hours (1456 steps over 52 weeks). Daily steps are too coarse for Simulation 3, where Point 1 responds within hours.

## Known limitation of toolbox v4.0.8

For a system with exactly two buffers, toolbox v4.0.8 builds transportation columns of the incidence matrix that add to the destination without removing from the origin. Simulation 1 therefore uses three buffers (Lake 1, Point 1, Point 2); systems with three or more buffers are built correctly.

## License

See `LICENSE`. The HFGT toolbox is distributed under its own license, inside `hfgtToolbox-v4.0.8.zip`.
