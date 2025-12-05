# this script is meant to regrid the ERA5 datasets to different spatial resolutions
using Dates: month, now, year
using NetcdfIO: NCDataset, read_nc, save_nc!, size_nc, varname_nc
using PkgUtility.MathTools: nanmean, regrid
using PkgUtility.PrettyDisplay: pretty_display!
using ProgressMeter: @showprogress

include("0-config.jl");


# 1. function to regrid ERA5 data for a given year and resolution
function regrid_ERA5!(yyyy::Int, nx::Int, varlabel::String, varname::String)
    file_in = raw_version_file_path(varlabel, yyyy);
    file_out = old_version_file_path(varlabel, yyyy, nx);

    # if file exists already, skip
    if isfile(file_out)
        return pretty_display!("Regridded file already exists for $(yyyy) and $(varlabel), skipping...", "tinfo_mid");
    end;

    # if original file does not exist, skip
    if !isfile(file_in)
        return error("Original file does not exist for $(yyyy) and $(varlabel)...");
    end;

    # define an empty 3d array to store the regridded data
    pretty_display!("Creating an empty array for the regridded data ...", "tinfo_mid");
    sizes = size_nc(file_in, varname)[end];
    nlon = sizes[1];
    nlat = sizes[2] - 1;
    nind = sizes[3];
    matx = zeros(Float32, nlon, nlat);
    mati = deepcopy(matx);
    regridded = zeros(Float32, (360nx, 180nx, nind));
    regridded .= Float32(NaN);

    # process the file per slice
    #     - read in the data slice
    #     - add one column to the longitude to add that of 360
    #     - take the nanmean to the center of a grid box (4 corners)
    #     - shift the longitude from (0, 360) to (-180, 180)
    #     - regrid the data to the new resolution
    pretty_display!("Reading and regridding $(varname) per time slice...", "tinfo_mid");
    dset = NCDataset(file_in, "r");
    @showprogress for ind in 1:sizes[3]
        _mat = replace(read_nc(dset, varname, ind), missing=>Float32(NaN));
        mat_ = [_mat; _mat[1:1,:]];
        for i in axes(matx,1), j in axes(matx,2)
            matx[i,j] = nanmean(mat_[i:i+1,j:j+1])
        end;
        mati[1:nlon÷2,:] = matx[nlon÷2+1:end,:];
        mati[nlon÷2+1:end,:] = matx[1:nlon÷2,:];
        regridded[:,:,ind] .= regrid(mati, nx);
    end;
    close(dset);

    # save the regridded dataset
    pretty_display!("Saving regridded dataset to $(file_out)...", "tinfo_mid");
    attr = Dict{String,Any}(varname => varlabel, "unit" => "Same as $(file_in)");
    save_nc!(file_out, varname, regridded, attr);

    # set the variables to nothing to clean the memory
    regridded = nothing;

    return nothing;
end;


# 2. loop through the years and regrid the data
for yyyy in EARLIEST_YEAR:LATEST_YEAR
    pretty_display!("Regridding ERA5 data for year $(yyyy)...", "tinfo_pre");
    regrid_ERA5!.(yyyy, 1, ERA5_SL_HOURLY_SELECTION, ERA5_SL_HOURLY_LAYERS);
    pretty_display!("Finished regridding all the datasets for year $(yyyy)!", "tinfo_end");
    println();
end;
