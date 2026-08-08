"""

    process_dataset!(yaml_file::String)

Process the entire dataset (read, verify, save), given
- `yaml_file` the path to the YAML file

"""
function process_dataset! end;

process_dataset!(yaml_file::String; verifier = verify_data!) =
    process_dataset!(validate_config(read_library(yaml_file)); verifier);

process_dataset!(config::Union{Dict, OrderedDict}; verifier = verify_data!) = (
    validate_config(config);

    # make sure the path exists
    mkpath(reprocessed_folder(config));

    # read the FILE configurations
    dict_file = config["FILE"];
    prefixs = dict_file["PREFIX"];
    nxs = dict_file["NX"];
    mts = dict_file["MT"];
    vvs = dict_file["VV"];
    yyyy = haskey(dict_file, "YYYY") ? dict_file["YYYY"] : nothing;

    # loop through the files and process each file
    for prefix in prefixs, nx in nxs, mt in mts, vv in vvs
        if isnothing(yyyy)
            process_dataset!(config, prefix, nx, mt, vv, nothing; verifier);
        else
            for year in yyyy
                process_dataset!(config, prefix, nx, mt, vv, year; verifier);
            end;
        end;
    end;

    return nothing
);

process_dataset!(config::Union{Dict, OrderedDict}, prefix::String, nx::Int, mt::String, vv::String, yyyy::Union{Int,Nothing}; verifier = verify_data!) = (
    # make sure the output file does not exist. If exists, skip the process
    output_file = reprocessed_file(config, prefix, nx, mt, vv, yyyy);

    if isfile(output_file)
        return nothing
    end;

    # show the progress
    @info "Processing file $(output_file)";

    # read the data
    data = read_input(config, prefix, nx, mt, vv, yyyy; data_or_std = "data");
    if !isnothing(data)
        if verifier(data, config["DATA"])
            save_input!(config, data, output_file; data_or_std = "data");
        else
            return error("Data verification failed, please check the data and configuration!");
        end;
    end;

    # read the std
    std = read_input(config, prefix, nx, mt, vv, yyyy; data_or_std = "std");
    if !isnothing(std)
        if verifier(std, config["STD"])
            save_input!(config, std, output_file; data_or_std = "std");
        else
            return error("STD verification failed, please check the data and configuration!");
        end;
    end;

    return nothing
);
