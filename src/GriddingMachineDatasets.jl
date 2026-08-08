module GriddingMachineDatasets

using FTPClient
using HTTP
using Revise
using SHA
using YAML

using GriddingMachine.Indexer: read_dataset
using NetcdfIO: append_nc!, dimname_nc, read_nc, save_nc!, size_nc, varname_nc
using OrderedCollections: OrderedDict
using PkgUtility.ArtifactTools: read_library
using PkgUtility.MathTools: nanmax, nanmean, nanmin, regrid
using PkgUtility.PrettyDisplay: pretty_display!

export ConfigValidationError, build_catalog_entry, process_dataset!,
       standardize_dimension_order, update_yaml_library!, validate_config


# Runtime configuration must not be frozen into the package precompile cache.
GRIDDING_MACHINE_HOME = joinpath(homedir(), "GriddingMachine")

function __init__()
    global GRIDDING_MACHINE_HOME = get(
        ENV,
        "GRIDDING_MACHINE_HOME",
        joinpath(homedir(), "GriddingMachine"),
    )
    return nothing
end


# shared configuration contract
include("config/schema.jl");
using .ConfigSchema: ConfigValidationError, standardize_dimension_order, validate_config


# pipeline to process the dataset
#     0. pre-processing, used to convert other formats to netCDF
#     1. reading the netCDF file and do some basic processing
#     2. verifying the data by plotting and asking the user to verify
#     3. saving the processed data to a netCDF file
#     4. functions related to the tagging system
include("preparation/0-gapfill.jl");
# include("preparation/0-geotiff.jl");
include("preparation/1-read.jl");
include("preparation/2-verify.jl");
include("preparation/3-save.jl");
include("preparation/4-tag.jl");
include("preparation/pipeline.jl");

# pipeline to deploy the datasets
#     1. verifying the variables to make sure the data is correct
#        - not exceeding the limits
#        - no NaN values per requirement (if not processed using our pipeline above, double check anyway)
#          - land and ocean (both)
#          - land only (land)
include("deployment/1-verification.jl");
include("deployment/2-upload.jl");

# pipeline to manage the artifact library
include("library/1-verify-urls.jl");


end # module

# 执行 pipeline 处理指定 YAML 文件
#=

begin
    using GriddingMachineDatasets
    yaml_path = "/mnt/net/ormosia/group/jianghao/GitHub/GriddingMachineDatasets/yaml/community/CI_2X_1M_V3.yaml"
    GriddingMachineDatasets.process_dataset!(yaml_path)
end 

=#
