"""

    verify_processed_data!(filepath::String, coverage::String, limits::Vector{<:Number})
    verify_processed_data!(filepath::String, coverage::String, limits::Tuple{<:Number,<:Number})

Verify the processed data, given
- `filepath` the path to the netCDF file
- `coverage` the coverage of the data, either "both" or "land"
- `limits` the limits of the data, either a vector of two numbers or a tuple

"""
function verify_processed_data! end;

verify_processed_data!(filepath::String, coverage::String, limits::Vector{<:Number}) = verify_processed_data!(filepath, coverage, (limits[1], limits[2]));

verify_processed_data!(filepath::String, coverage::String, limits::Tuple{<:Number,<:Number}) = (
    # make sure the file exists and the coverage is valid
    @assert isfile(filepath) "File $filepath does not exist!";
    @assert coverage in ["both", "land"] "Coverage $coverage is not valid!";

    # make sure the data file contains the following variables depending on the dimension
    dims = String.(read_dimnames(filepath));
    vars = String.(read_varnames(filepath));
    @assert "lat" in dims "Dimension 'lat' not found in $(filepath)!";
    @assert "lon" in dims "Dimension 'lon' not found in $(filepath)!";
    @assert "lat" in vars "Variable 'lat' not found in $(filepath)!";
    @assert "lon" in vars "Variable 'lon' not found in $(filepath)!";
    @assert "data" in vars "Variable 'data' not found in $(filepath)!";
    if length(dims) >= 3
        @assert "ind" in dims "Dimension 'ind' not found in $(filepath)!";
    end;
    @info "All mandatory dimensions and variables are found in provided file.";

    # make sure the data is stored correctly: lon as 1st dim, lat as 2nd dim (and ind as 3rd dim if exists)
    lon_size = read_dims(filepath, "lon")[2][1];
    lat_size = read_dims(filepath, "lat")[2][1];
    dat_size = read_dims(filepath, "data")[2];
    @assert dat_size[1] == lon_size "The size of 'lon' dimension does not match the 1st dimension of 'data' variable!";
    @assert dat_size[2] == lat_size "The size of 'lat' dimension does not match the 2nd dimension of 'data' variable!";
    if length(dims) >= 3
        ind_size = read_dims(filepath, "ind")[2][1];
        @assert dat_size[3] == ind_size "The size of 'ind' dimension does not match the 3rd dimension of 'data' variable!";
    end;
    @info "The dimensions of 'data' variable match the dimensions of lon and lat.";

    # make sure the data values are within the limits
    data = read_nc(filepath, "data");
    min_val = nanmin(data);
    max_val = nanmax(data);
    @assert limits[1] <= min_val <= max_val <= limits[2] "Data values in $(filepath) are not within the limits $(limits)!";
    @info "Data values are within the limits: $(limits).";

    # make sure there is no NaN values with the coverage
    if coverage == "both"
        @assert !any(isnan, data) "Data in $(filepath) contains NaN values!";
        @info "No NaN values found in the data for both land and ocean.";
    elseif coverage == "land" && (lon_size in [360, 720, 1440])
        land_mask = regrid(read_dataset("LM_4X_1Y_V1"), lon_size ÷ 360);
        land_indx = land_mask .> 0;
        for iind in axes(data,3)
            data_plane = data[:,:,iind];
            @assert !any(isnan, data_plane[land_indx]) "Data in $(filepath) contains NaN values in land coverage!";
        end;
        @info "No NaN values found in the data for land coverage.";
    elseif coverage == "land"
        @warn "Resolution not meeting our requirements for land coverage check. Skipping...";
    end;

    return nothing
);
