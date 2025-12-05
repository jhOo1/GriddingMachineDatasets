"""

    read_input(filepath::String, varname::String, dict::Union{Dict, OrderedDict})

Read the input data, and pre-process it according to the specifications in `dict`, given
- `filepath`: the path to the netCDF file
- `varname`: the variable name in the netCDF file
- `dict`: a dictionary containing pre-processing instructions

"""
function read_input end;

read_input(config::Union{Dict, OrderedDict}, prefix::String, nx::Int, mt::String, vv::String, yyyy::Union{Int,Nothing}; data_or_std::String = "data") = (
    @assert data_or_std in ["data", "std"] "data_or_std must be either 'data' or 'std'";

    # the index of prefix in the configuration
    if haskey(config, uppercase(data_or_std))
        dict_data = config[uppercase(data_or_std)];
        idx = findfirst(x -> x == prefix, config["FILE"]["PREFIX"]);
        return read_input(original_file(config, prefix, nx, mt, vv, yyyy), dict_data["LABEL"][idx], dict_data)
    end;

    return nothing
);

read_input(filepath::String, varname::String, dict::Union{Dict, OrderedDict}) = (
    @assert isfile(filepath) "original file $filepath not found...";

    # read the data from the netCDF file
    data = read_nc(Float32, filepath, varname);
    ndim = ndims(data);

    # clear the change logs
    dict["CHANGE_LOGS_TO_WRITE"] = deepcopy(dict["CHANGE_LOGS"]);

    # if key REV_LAT exists, reverse the latitude
    data_a = if haskey(dict, "REV_LAT") && dict["REV_LAT"]
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Latitude has been remapped from -90 to 90.");
        ndim == 2 ? data[:,end:-1:1] : data[:,end:-1:1,:]
    else
        data
    end;

    # if key REV_LON exists, reverse the longitude
    data_b = if haskey(dict, "REV_LON") && dict["REV_LON"]
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Longitude has been remapped from west to east.");
        ndim == 2 ? data_a[end:-1:1,:] : data_a[end:-1:1,:,:]
    else
        data_a
    end;

    # if key FLIP_LON exists, flip the longitude from 0 to 360 to -180 to 180
    data_c = if haskey(dict, "FLIP_LON") && dict["FLIP_LON"]
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Longitude has been remapped from 0 to 360 to -180 to 180.");
        nlon = size(data_b, 1);
        left_part = ndim == 2 ? data_b[1:nlon÷2,:] : data_b[1:nlon÷2,:,:];
        right_part = ndim == 2 ? data_b[nlon÷2+1:end,:] : data_b[nlon÷2+1:end,:,:];
        vcat(right_part, left_part)
    else
        data_b
    end;

    # if key SCALING exists, scale the data
    data_d = if haskey(dict, "SCALING") && lowercase(dict["SCALING"]) == "linear"
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Data has been scaled linearly.");
        FT = eltype(data_c);
        data_c .* FT(dict["SCALING_FACTOR"][1]) .+ FT(dict["SCALING_FACTOR"][2])
    else
        data_c
    end;

    # if key LIMITS exists, limit the data
    if haskey(dict, "LIMITS")
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Data has been limited within $(dict["LIMITS"][1]) and $(dict["LIMITS"][2]).");
        mask = data_d .< dict["LIMITS"][1] .|| data_d .> dict["LIMITS"][2];
        data_d[mask] .= NaN;
    end;

    # gapfill the data based on the setting
    gapfill = dict["GAPFILL"];
    mthd = if typeof(gapfill) <: Number
        gapfill = FillMethodConstant(gapfill);
    elseif uppercase(gapfill) == "MEAN"
        FillMethodMean();
    else
        error("Unsupported GAPFILL method: $gapfill");
    end;
    if size(data_d, 1) in [360, 720, 1440]
        land_mask = regrid(read_dataset("LM_4X_1Y_V1"), size(data_d, 1) ÷ 360);
        # land_mask = regrid(read_nc(download_artifact!("LM_4X_1Y_V1"), "data"), size(data_d, 1) ÷ 360);
        n_gapfill = fill_missing_values!(data_d, land_mask, mthd);
        @info "Gaps filled" n_gapfill;
        if n_gapfill > 0
            push!(dict["CHANGE_LOGS_TO_WRITE"], "Filled $n_gapfill missing values based on the specified gapfill method.");
        end;
    else
        @info "Resolution not meeting our requirements for gapfilling. Skipping...";
    end;

    return data_d
);
