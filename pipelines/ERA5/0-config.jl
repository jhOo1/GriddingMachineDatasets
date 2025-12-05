using Dates: month, now, year


# 1. define the raw, old, and new version folder paths
RAW_DAT_FOLDER = joinpath(homedir(), "DATASERVER/model/ERA5/SingleLevels/Hourly/original");
OLD_VER_FOLDER = joinpath(homedir(), "DATASERVER/model/ERA5/SingleLevels/Hourly/reprocessed");
NEW_VER_FOLDER = joinpath(homedir(), "DATASERVER/model/ERA5/SingleLevels/Hourly/GriddingMachine");
@assert isdir(RAW_DAT_FOLDER) "Raw data folder does not exist: $RAW_DAT_FOLDER";
@assert isdir(OLD_VER_FOLDER) "Old data folder does not exist: $OLD_VER_FOLDER";
@assert isdir(NEW_VER_FOLDER) "New data folder does not exist: $NEW_VER_FOLDER";


# 2. function to generate the path to the raw, original file and old version file
#    e.g., 10m_v_component_of_wind_SL_2018.nc
#          10m_v_component_of_wind_SL_2018_1X.nc
#          WIND_ERA5_1X_1H_2019_V1.nc
raw_version_file_path(varlabel::String, year::Int             ) = "$(RAW_DAT_FOLDER)/$(varlabel)_SL_$(year).nc";
old_version_file_path(varlabel::String, year::Int, nx::Int = 1) = "$(OLD_VER_FOLDER)/$(varlabel)_SL_$(year)_$(nx)X.nc";
new_version_file_path(taglabel::String, year::Int, nx::Int = 1) = "$(NEW_VER_FOLDER)/$(taglabel)_$(nx)X_1H_$(year)_V1.nc";


# 3. process the data one by one variable
ERA5_SL_HOURLY_SELECTION = [
    "10m_u_component_of_wind",
    "10m_v_component_of_wind",
    "2m_dewpoint_temperature",
    "2m_temperature",
    "mean_surface_direct_short_wave_radiation_flux",
    "mean_surface_downward_long_wave_radiation_flux",
    "mean_surface_downward_short_wave_radiation_flux",
    "mean_surface_downward_uv_radiation_flux",
    "surface_pressure",
    "total_precipitation"
];
ERA5_SL_HOURLY_LAYERS = [
    "u10", "v10", "d2m", "t2m",
    "msdrswrf", "msdwlwrf", "msdwswrf", "msdwuvrf",
    "sp", "tp"
];
EARLIEST_YEAR = 1980;
LATEST_YEAR = year(now()) - (month(now()) < 4);
