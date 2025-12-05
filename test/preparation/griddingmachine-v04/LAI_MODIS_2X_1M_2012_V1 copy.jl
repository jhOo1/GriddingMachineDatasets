using GriddingMachine.Blender: regrid, nanmean
using GriddingMachine.Collector: download_artifact!
using NetcdfIO: append_nc!, create_nc!, read_nc, size_nc
using Statistics
using NCDatasets

arttag = "LAI_MODIS_2X_1M_2012_V1";
art_path = download_artifact!(arttag);

lon = read_nc(art_path, "lon");
lat = read_nc(art_path, "lat");
ind = read_nc(art_path, "ind");
data = read_nc(art_path, "data");
stdv = read_nc(art_path, "std");
data_filled = deepcopy(data);

# fill the missing values with mean value
# use land mask to identify missing values
land_mask = read_nc(download_artifact!("LM_4X_1Y_V1"), "data");
data_numX = Int(round(size_nc(art_path, "data")[2][1] / 360));  
land_mask_2X = regrid(land_mask, data_numX);
filtered_land = land_mask_2X .> 0;

for i in axes(data, 3)
    slice = data[:, :, i];
    site_to_refill = isnan.(slice) .& filtered_land;
    data_filled[site_to_refill,i] .= 0;
end;

data[:,:,end]
data_filled[:,:,end]


# 3. check if stdv needs to be retained
# 3.1 whether stdv is all NaN
is_stdv_all_nan = all(isnan.(stdv));
# 3.2 whether stdv is identical to original data
is_stdv_same_as_data = all(isapprox.(stdv, data; atol=1e-6));

@info "stdv校验结果：" is_stdv_all_nan is_stdv_same_as_data

# 4. save the data
new_data_folder = joinpath(homedir(), "GriddingMachine/refactored");
mkpath(new_data_folder) 
new_data_file = joinpath(new_data_folder, "LAI_MODIS_2X_1M_2012_V1_R1.nc");

# create NC file and append variables
create_nc!(new_data_file, ["lon", "lat", "ind"], [size(data)...]);
append_nc!(new_data_file, "lon", lon, lon_attrs,  ["lon"]);
append_nc!( new_data_file, "lat", lat, lat_attrs, ["lat"]);
append_nc!(new_data_file, "ind", ind, ind_attrs, ["ind"]);
append_nc!(new_data_file, "data", data_filled, data_attrs, ["lon", "lat", "ind"]);

# only append stdv if valid: not all NaN and different from data
if !is_stdv_all_nan && !is_stdv_same_as_data
    append_nc!(new_data_file, "std", stdv, std_attrs, ["lon", "lat", "ind"]);
else
    @warn "stdv全为NaN或与data完全相同，已舍弃该变量"
end


