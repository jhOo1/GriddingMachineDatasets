using GriddingMachine.Blender: regrid, nanmean
using GriddingMachine.Collector: download_artifact!
using NetcdfIO: append_nc!, create_nc!, read_nc, size_nc
using Statistics
using NCDatasets
include("./test/preparation/griddingmachine-v04/get_vars_attrs_tool.jl");

# dcd1a9324a8ce952281affa613674896534bdace
# 1. read raw data+extract attributes
arttag = "LAI_MODIS_20X_8D_2014_V1";
art_path = download_artifact!(arttag);

# 1.1 extract all attributes
lon_attrs = get_var_attrs(art_path, "lon");
lat_attrs = get_var_attrs(art_path, "lat");
ind_attrs = get_var_attrs(art_path, "ind");
data_attrs = get_var_attrs(art_path, "data");
std_attrs = get_var_attrs(art_path, "std");

# 1.2 read raw data
lon = read_nc(art_path, "lon");
lat = read_nc(art_path, "lat");
ind = read_nc(art_path, "ind");
data = read_nc(art_path, "data");
stdv = read_nc(art_path, "std");
data_filled = deepcopy(data);


# use land mask to identify missing values
land_mask = read_nc(download_artifact!("LM_4X_1Y_V1"), "data");

filtered_land = land_mask .> 0;
data_filled = regrid(data_filled, 4);
lon_filled = collect(-180.0 + (data_numX / 2):0.25: 180);  # 4分度经度：1440个点（360/0.25）
lat_filled = collect(-90.0 + (data_numX / 2):0.25: 90);

for i in axes(data_filled, 3)
    slice = data_filled[:, :, i];
    site_to_refill = isnan.(slice) .& filtered_land;
    data_filled[site_to_refill, i] .= 0;
end
data[:,:,end]
data_filled[:,:,end]


# 4. save the data
new_data_folder = joinpath(homedir(), "GriddingMachine/refactored");
mkpath(new_data_folder) 
new_data_file = joinpath(new_data_folder, "LAI_MODIS_4X_8D_2014_V1_R1.nc");

# create NC file and append variables
create_nc!(new_data_file, ["lon", "lat", "ind"], [size(data_filled)...]);
append_nc!(new_data_file, "lon", lon_filled, lon_attrs,  ["lon"]);
append_nc!( new_data_file, "lat", lat_filled, lat_attrs, ["lat"]);
append_nc!(new_data_file, "ind", ind, ind_attrs, ["ind"]);
append_nc!(new_data_file, "data", data_filled, data_attrs, ["lon", "lat", "ind"]);

