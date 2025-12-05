using GriddingMachine.Collector: download_artifact!
using NetcdfIO: append_nc!, create_nc!, read_nc
using Statistics
using NCDatasets
include("./test/preparation/griddingmachine-v04/get_vars_attrs_tool.jl");

# -------------------------- configure paths --------------------------
# source data root directory
public_dir = "/mnt/net/emerald/GriddingMachine/public";
# output directory (saving processed files)
output_root = joinpath(homedir(), "GriddingMachine/refactored");
mkpath(output_root);  # ensure that the output directory exists


# -------------------------- single file processing function --------------------------
function process_nc_file(nc_path::String, output_dir::String)
    try
        # 1. extract file name (used to generate output file name)
        nc_filename = basename(nc_path);  
        output_filename = replace(nc_filename, ".nc" => "_R1.nc"); 
        output_path = joinpath(output_dir, output_filename);
        
        # open the file and check whether the variables exist uniformly && obtain the dimension order of data
        ds = Dataset(nc_path, "r");
        vars_in_file = Set(keys(ds));  
        data_dims = collect(NCDatasets.dimnames(ds["data"]));  # Collect() converts it to Vector {String}
        close(ds);

        # 2. extract all attributes
        lon_attrs = ("lon" in vars_in_file) ? get_var_attrs(nc_path, "lon") : Dict{String, Any}();
        lat_attrs = ("lat" in vars_in_file) ? get_var_attrs(nc_path, "lat") : Dict{String, Any}();
        ind_attrs = ("ind" in vars_in_file) ? get_var_attrs(nc_path, "ind") : Dict{String, Any}();
        data_attrs = ("data" in vars_in_file) ? get_var_attrs(nc_path, "data") : Dict{String, Any}();
        std_attrs = ("std" in vars_in_file) ? get_var_attrs(nc_path, "std") : Dict{String, Any}();
        
        # 3. read raw data
        lon = ("lon" in vars_in_file) ? read_nc(nc_path, "lon") : nothing;
        lat = ("lat" in vars_in_file) ? read_nc(nc_path, "lat") : nothing;
        ind = ("ind" in vars_in_file) ? read_nc(nc_path, "ind") : nothing;
        stdv = ("std" in vars_in_file) ? read_nc(nc_path, "std") : nothing;
        data = read_nc(nc_path, "data")

        data_filled = deepcopy(data);

        # 4. fill the data missing values with mean value
        valid_data = data_filled[.!isnan.(data_filled)];
        global_mean = isempty(valid_data) ? 0.0 : mean(valid_data);
        data_filled[isnan.(data_filled)] .= global_mean;

        # 5. use land mask to identify missing values
        land_mask = read_nc(download_artifact!("LM_4X_1Y_V1"), "data");
        

        # copy a nanmean
        

        # 6. check if stdv needs to be retained
        is_stdv_all_nan = true
        is_stdv_same_as_data = true
        if stdv !== nothing  # only judged when stdv exists
            is_stdv_all_nan = all(isnan.(stdv))
            is_stdv_same_as_data = all(isapprox.(stdv, data; atol=1e-6))
            @info "stdv校验结果：" is_stdv_all_nan is_stdv_same_as_data
        else
            @info "文件 $nc_filename 中无 'std' 变量，跳过std处理"
        end
        

        # 8. create NC file and append variables
        create_nc!(output_path, data_dims, [size(data)...]);

        if lon !== nothing
            append_nc!(output_path, "lon", lon, lon_attrs, ["lon"]);
        end
        if lat !== nothing
            append_nc!(output_path, "lat", lat, lat_attrs, ["lat"]);
        end
        if ind !== nothing
            append_nc!(output_path, "ind", ind, ind_attrs, ["ind"]);
        end
        append_nc!(output_path, "data", data_filled, data_attrs, data_dims);

        # only append stdv if valid: not all NaN and different from data
        if !is_stdv_all_nan && !is_stdv_same_as_data 
            append_nc!(output_path, "std", stdv, std_attrs, data_dims);
        else
            @warn "舍弃 $nc_filename 的 std 变量"
        end

        @info "已保存处理结果：$output_path\n"

    catch e
        @error "处理文件 $nc_path 时出错" exception=e
    end
end


processed_count = 0  # Counter: records the number of processed files
max_files = 5        # maximum processing quantity

# traverse all subfolders under public
for subdir in readdir(public_dir; join=true)
    if processed_count >= max_files
        @info "已处理 $max_files 个文件，停止批处理"
        break
    end

    if isdir(subdir)  
        # search for. nc files in subfolders
        nc_files = filter(f -> endswith(f, ".nc"), readdir(subdir; join=true));
        if !isempty(nc_files)
            nc_path = nc_files[1]; 
            process_nc_file(nc_path, output_root);  
            processed_count += 1
        else
            @warn "子文件夹 $subdir 中未找到nc文件，跳过\n"
        end
    end
end
