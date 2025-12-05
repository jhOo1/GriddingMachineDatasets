using GriddingMachine.Blender: regrid, nanmean
using GriddingMachine.Collector: download_artifact!
using NetcdfIO: append_nc!, create_nc!, read_nc, size_nc
using Statistics
include("./test/preparation/griddingmachine-v04/get_vars_attrs_tool.jl");

# e90ae3629fb1af041d707e2607f38a227d5a6fe9
# 1. read raw data+extract attributes
arttag = "VCF_MODIS_MOD44B_2X_1Y_2000_V1"
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

# 2. fill the data missing values with mean value
valid_data = data_filled[.!isnan.(data_filled)]  
global_mean = isempty(valid_data) ? 0.0 : mean(valid_data)
data_filled[isnan.(data_filled)] .= global_mean 

# use land mask to identify missing values
land_mask = read_nc(download_artifact!("LM_4X_1Y_V1"), "data");
data_numX = size_nc(art_path, "data")[2][1] / 360;

if (data_numX > 4) {
    data_filled = regrid(data_filled,4);
} else {
    # TODO:这里若不是1X，还需要再创建一个1X的文件，可以把下面的操作抽象出来一个函数，这样ifelse直接调函数即可
    # 比如process_numX(data_numX,land_mask_numX,data_filled)
    land_mask_numX = regrid(land_mask, data_numX);

}

filtered_land = land_mask_numX .> 0;

for i in axes(data, 3)
    slice = data[:, :, i];
    mean_value = nanmean(slice);
    site_to_refill = isnan.(slice) .& filtered_land;
    data_filled[site_to_refill,i] .= mean_value;
end;

# copy a nanmean


# 3. check if stdv needs to be retained
# 3.1 whether stdv is all NaN
is_stdv_all_nan = all(isnan.(stdv));
# 3.2 whether stdv is identical to original data
is_stdv_same_as_data = all(isapprox.(stdv, data; atol=1e-6))

@info "stdv校验结果：" is_stdv_all_nan is_stdv_same_as_data

# 4. save the data
new_data_folder = joinpath(homedir(), "GriddingMachine/refactored");
mkpath(new_data_folder)
# TODO:这里X前面根据data_numX变化 
new_data_file = joinpath(new_data_folder, "VCF_MODIS_MOD44B_" + string(data_numX) + "X_1Y_2000_V1_R1.nc");

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