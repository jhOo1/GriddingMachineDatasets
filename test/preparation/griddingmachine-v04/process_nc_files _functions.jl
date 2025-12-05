using GriddingMachine.Blender: regrid, nanmean
using GriddingMachine.Collector: download_artifact!
using NetcdfIO: append_nc!, create_nc!, read_nc, size_nc
using Statistics
using NCDatasets
include("./test/preparation/griddingmachine-v04/get_vars_attrs_tool.jl");

# -------------------------- configure paths --------------------------
# source data root directory
public_dir = "/mnt/net/emerald/GriddingMachine/public";
# output directory (saving processed files)
output_root = joinpath(homedir(), "GriddingMachine/refactored");
mkpath(output_root);  # ensure that the output directory exists

# 定义需要使用zero填充的文件名前缀列表
const ZERO_FILL_PREFIXES = ["CI", "LAI", "VCF", "BIOMASS", "GPP", "LDMC", "LE", "LNC", "LPC", "SIF", "SIL", "TD"];
const NANMEAN_FILL_PREFIXES = ["CHL", "LMA", "SLA", "VCMAX"];
const FiXED005_FILL_PREFIXES = ["CH_"];



"""
    get_fill_method(nc_filename::String) -> Symbol

根据文件名前缀获取对应的填充方法：
- :zero: 使用0填充缺失值
- :mean: 使用均值填充缺失值
- :fixed005：使用0.05填充缺失值
"""
function get_fill_method(nc_filename::String)
    # 检查文件名是否以指定前缀开头（不区分大小写）
    for prefix in ZERO_FILL_PREFIXES
        if startswith(uppercase(nc_filename), uppercase(prefix))
            return FillMethodConstant(0)
        end
    end

    for prefix in NANMEAN_FILL_PREFIXES
        if startswith(uppercase(nc_filename), uppercase(prefix))
            return FillMethodMean()
        end
    end

    for prefix in FiXED005_FILL_PREFIXES
        if startswith(uppercase(nc_filename), uppercase(prefix))
            return FillMethodConstant(0.05)
        end
    end

    return FillMethodMean()  # 默认使用均值填充
end








abstract type AbsrtactFillMethod end;

struct FillMethodMean <: AbsrtactFillMethod end;
struct FillMethodConstant <: AbsrtactFillMethod
    constant::Real
end;







"""
DOC 1
"""
function fill_missing_values! end;

fill_missing_values!(data_filled::AbstractArray, land_mask_numX::AbstractArray, mthd::FillMethodConstant) = (
    filtered_land = land_mask_numX .> 0;

    for i in axes(data_filled, 3)
        slice = data_filled[:, :, i];
        site_to_refill = isnan.(slice) .& filtered_land;
        data_filled[site_to_refill, i] .= mthd.constant;
    end;

    return nothing
);

fill_missing_values!(data_filled::AbstractArray, land_mask_numX::AbstractArray, mthd::FillMethodMean) = (
    filtered_land = land_mask_numX .> 0;

    for i in axes(data_filled, 3)
        slice = data_filled[:, :, i];
        mean_value = nanmean(slice);
        site_to_refill = isnan.(slice) .& filtered_land;
        data_filled[site_to_refill, i] .= mean_value;
    end;

    return nothing
);






"""
    generate_output_filename(nc_filename::String, target_res::Float64) -> String

生成符合规则的输出文件名：
输入: "VCF_MODIS_MOD44B_4X_1Y_2000_V1.nc", 1.0
输出: "VCF_MODIS_MOD44B_1X_1Y_2000_V1_R1.nc"
"""
function generate_output_filename(nc_filename::String, data_numX::Int)
    # 正则匹配 "数字X" 模式（如4X、2X、1X）
    res_pattern = r"(\d+)X"
    # 替换分辨率部分，并添加_R1后缀
    new_filename = replace(nc_filename, res_pattern => "$(data_numX)X")
    # 替换.nc后缀为_R1.nc（确保只替换最后一个.nc）
    new_filename = replace(new_filename, r"\.nc$" => "_R1.nc")
    return new_filename
end

"""
保存处理后的NC文件，自动根据分辨率生成文件名
"""
function save_processed_nc!(
    output_dir::String,
    nc_path::String,
    data_dims::Vector{String},
    data_filled::AbstractArray,
    data_attrs::Dict{String, Any},
    lon::Union{AbstractArray, Nothing},
    lat::Union{AbstractArray, Nothing},
    ind::Union{AbstractArray, Nothing},
    stdv::Union{AbstractArray, Nothing},
    lon_attrs::Dict{String, Any},
    lat_attrs::Dict{String, Any},
    ind_attrs::Dict{String, Any},
    std_attrs::Dict{String, Any},
    data_numX::Int,
    writeStdv::Bool=true    # 如果分辨率本来大于4，那么不管stdv
)
    nc_filename = basename(nc_path);
    # 根据源文件名以及分辨率生成新的文件名
    output_filename = generate_output_filename(nc_filename,data_numX);
    output_path = joinpath(output_dir, output_filename);

    # create NC file and append variables
    create_nc!(output_path, data_dims, [size(data_filled)...]);

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
    
    # check if stdv needs to be retained
    is_stdv_all_nan = true
    is_stdv_same_as_data = true
    if stdv !== nothing && writeStdv # only judged when stdv exists
        is_stdv_all_nan = all(isnan.(stdv))
        is_stdv_same_as_data = all(isapprox.(stdv, data_filled; atol=1e-6))
    end

    # only append stdv if valid: not all NaN and different from data
    if !is_stdv_all_nan && !is_stdv_same_as_data
        append_nc!(output_path, "std", stdv, std_attrs, data_dims);
    end

    @info "已保存处理结果：$output_path\n"
    return output_path
end

function process_single_resolution(
    nc_path::String,
    output_dir::String,
    data_numX::Int,
    data_filled::AbstractArray,
    land_mask_numX::AbstractArray,
    vars_in_file::Set{String},
    data_dims::Vector{String},
    lon::Union{AbstractArray, Nothing},
    lat::Union{AbstractArray, Nothing},
    ind::Union{AbstractArray, Nothing},
    stdv::Union{AbstractArray, Nothing},
    lon_attrs::Dict{String, Any},
    lat_attrs::Dict{String, Any},
    ind_attrs::Dict{String, Any},
    data_attrs::Dict{String, Any},
    std_attrs::Dict{String, Any},
    writeStdv::Bool=true    # 如果分辨率本来大于4，那么不管stdv
)
    try
        # 1. 根据不同的文件调用不同的填充方法填充缺失值
        nc_filename = basename(nc_path);
        fill_missing_values!(data_filled, land_mask_numX, get_fill_method(nc_filename));

        # 3. 保存处理后的NC文件
        save_processed_nc!(
            output_dir, nc_path, data_dims, data_filled, data_attrs,
            lon, lat, ind, stdv,
            lon_attrs, lat_attrs, ind_attrs, std_attrs,
            data_numX,
            writeStdv
        );

    catch e
        rethrow(e)
    end
end





function func_process_file(nc_path::String, output_dir::String)
    try
        # 1. open the file and check whether the variables exist uniformly && obtain the dimension order of data
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


        # 4. set resolution
        land_mask = read_nc(download_artifact!("LM_4X_1Y_V1"), "data");
        data_numX = size_nc(nc_path, "data")[2][1] ÷ 360;

        if data_numX > 4
            # 此时data分辨率过大，则data_filled 设置为4X
            data_filled = regrid(data, 4);
            land_mask_numX = land_mask;
            # 生成相应分度的经纬度数组
            # 180° 和 -180° 是同一个经度
            lon_filled = collect(-180.0 + (1/8):0.25: 180);  # 4分度经度：1440个点（360/0.25）
            lat_filled = collect(-90.0 + (1/8):0.25: 90);    # 4分度纬度：720个点（180/0.25）
            # 处理单个分辨率生成文件
            process_single_resolution(
                nc_path, output_dir, 4 ,data_filled, land_mask_numX, vars_in_file,data_dims,
                lon_filled, lat_filled, ind, stdv,
                lon_attrs, lat_attrs, ind_attrs, data_attrs, std_attrs,
                false # 此时不管stdv
            );
        else
            # 此时分辨率小，则land_mask设置为data_numX、1X分别生成文件
            data_filled = deepcopy(data);
            land_mask_numX = regrid(land_mask, data_numX);
            process_single_resolution(
                nc_path, output_dir, data_numX, data_filled, land_mask_numX, vars_in_file,data_dims,
                lon, lat, ind, stdv,
                lon_attrs, lat_attrs, ind_attrs, data_attrs, std_attrs,
                true
            );
        end

        if data_numX % 2 == 0 && data_numX > 2
            land_mask_numX = regrid(land_mask, 2);
            data_filled = regrid(data, 2);
            stdv_filled = regrid(stdv, 2);
            lon_filled = collect(-180.0 + (1 / 4):0.5: 180);  # 1分度经度：360个点（360/1）
            lat_filled = collect(-90.0 + (1 / 4):0.5: 90);    # 1分度纬度：180个点（180/1）
            process_single_resolution(
                nc_path, output_dir, 2, data_filled, land_mask_numX, vars_in_file,data_dims,
                lon_filled, lat_filled, ind, stdv_filled,
                lon_attrs, lat_attrs, ind_attrs, data_attrs, std_attrs,
                true
            );
        end

        if data_numX > 1
            land_mask_numX = regrid(land_mask, 1);
            data_filled = regrid(data, 1);
            stdv_filled = regrid(stdv, 1);
            lon_filled = collect(-180.0 + (1 / 2):1.0: 180);  # 1分度经度：360个点（360/1）
            lat_filled = collect(-90.0 + (1 / 2):1.0: 90);    # 1分度纬度：180个点（180/1）
            process_single_resolution(
                nc_path, output_dir, 1, data_filled, land_mask_numX, vars_in_file,data_dims,
                lon_filled, lat_filled, ind, stdv_filled,
                lon_attrs, lat_attrs, ind_attrs, data_attrs, std_attrs,
                true
            );
        end

    catch e
        rethrow(e)
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
            func_process_file(nc_path, output_root);
            processed_count += 1
        else
            @warn "子文件夹 $subdir 中未找到nc文件，跳过\n"
        end
    end
end
