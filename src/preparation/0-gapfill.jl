""" Different gapfill methods """
abstract type AbstractFillMethod end;

""" Fill missing values with the mean value (nanmean) """
struct FillMethodMean <: AbstractFillMethod end;

""" Fill missing values with a constant value """
struct FillMethodConstant <: AbstractFillMethod
    constant::Real
end;

""" Check no NaN in land areas (mark gap_fill=-1 if exists) """
struct FillMethodNoLandNaN <: AbstractFillMethod end;

""" Check no NaN in any areas (mark gap_fill=-2 if exists) """
struct FillMethodNoNaN <: AbstractFillMethod end;

""" Keep data as it is (no gapfilling) """
struct FillMethodKeepAsIs <: AbstractFillMethod end;

""" Convert data to integer, land NaN becomes 1 """
struct FillMethodIntNaNTo1 <: AbstractFillMethod end;

"""
    fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::AbstractFillMethod, dict::Dict)

Gapfill/check data based on the specified method, given
- `data_in`: the data array to be filled (2D or 3D)
- `land_mask`: the land mask data (2D) (1=land, 0=ocean)
- `dict`: configuration dict (for gap_fill flag and change logs)

Return: number of NaNs detected/filled
"""
function fill_missing_values! end;
function fill_missing_values! end;

fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::FillMethodConstant, dict::Dict) = (
    filtered_land = land_mask .> 0;

    sum_gapfill = 0;
    for i in axes(data_in, 3)
        slice = data_in[:, :, i];
        site_to_refill = isnan.(slice) .& filtered_land;
        data_in[site_to_refill, i] .= mthd.constant;
        sum_gapfill += sum(site_to_refill);
    end;

    if sum_gapfill > 0
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Filled $sum_gapfill missing values to $(mthd.constant).");
    end;

    return sum_gapfill
);

fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::FillMethodMean,dict::Dict) = (
    filtered_land = land_mask .> 0;

    sum_gapfill = 0;
    for i in axes(data_in, 3)
        slice = data_in[:, :, i];
        mean_value = nanmean(slice);
        site_to_refill = isnan.(slice) .& filtered_land;
        data_in[site_to_refill, i] .= mean_value;
        sum_gapfill += sum(site_to_refill);
    end;

    if sum_gapfill > 0
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Filled $sum_gapfill missing values to nanmean.");
    end;

    return sum_gapfill
);

fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::FillMethodNoLandNaN, dict::Dict) = (
    filtered_land = land_mask .> 0;
    sum_nan = 0;
    for i in axes(data_in, 3)
        slice = data_in[:, :, i];
        land_nan = isnan.(slice) .& filtered_land;
        sum_nan += sum(land_nan);
    end;
    if sum_nan > 0
        push!(dict["CHANGE_LOGS_TO_WRITE"], "No land should be nan, but detected $sum_nan NaNs in land areas.");
    end;
    return -1;
);

fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::FillMethodNoNaN, dict::Dict) = (
    sum_nan = 0;
    for i in axes(data_in, 3)
        slice = data_in[:, :, i];
        all_nan = isnan.(slice);  
        sum_nan += sum(all_nan);
    end;
    if sum_nan > 0
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Nothing should be nan, but detected $sum_nan NaNs in total.");
    end;
    return -2;
);

fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::FillMethodKeepAsIs, dict::Dict) = (
    return 0; 
);

fill_missing_values!(data_in::AbstractArray, land_mask::AbstractArray, mthd::FillMethodIntNaNTo1, dict::Dict) = (
    sum_gapfill = 0;
    for i in axes(data_in, 3)
        slice = data_in[:, :, i];
        land_ocean_nan = isnan.(slice)
        data_in[land_ocean_nan, i] .= 1;
        sum_gapfill += sum(land_ocean_nan);
        
        # data_in[:, :, i] = convert.(Int, data_in[:, :, i]);
    end;
    data_in .= round.(Int, data_in);

    if sum_gapfill > 0
        push!(dict["CHANGE_LOGS_TO_WRITE"], "Converted data to integer, filled $sum_gapfill land NaNs with 1.");
    end;
    return -3;
);