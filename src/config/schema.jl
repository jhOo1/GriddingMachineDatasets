module ConfigSchema

export ConfigValidationError, standardize_dimension_order, validate_config

struct ConfigValidationError <: Exception
    errors::Vector{String}
end

function Base.showerror(io::IO, error::ConfigValidationError)
    print(io, "Invalid GriddingMachineDatasets configuration:\n - ")
    print(io, join(error.errors, "\n - "))
end

const _TOP_LEVEL_KEYS = Set(["SCHEMA_VERSION", "FILE", "FOLDER", "DATA", "STD", "GRIDDINGMACHINE"])
const _FILE_KEYS = Set(["PATTERN", "PREFIX", "NX", "MT", "YYYY", "VV"])
const _FOLDER_KEYS = Set(["ORIGINAL", "REPROCESSED"])
const _PROCESSING_KEYS = Set([
    "ABOUT", "CHANGE_LOGS", "DIMENSIONS", "FLIP_LON", "GAPFILL", "LABEL", "LIMITS",
    "REV_LAT", "REV_LON", "SCALING", "SCALING_FACTOR", "UNIT", "VERIFY_ONCE",
])
const _GRIDDINGMACHINE_KEYS = Set(["TAG", "REVISION"])
const _CANONICAL_DIMENSIONS = Dict(2 => ["lon", "lat"], 3 => ["lon", "lat", "ind"])

_is_nonempty_string(value) = value isa AbstractString && !isempty(strip(value))
_is_vector(value) = value isa AbstractVector

function _check_unknown_keys!(errors, section::AbstractDict, allowed::Set{String}, path::String)
    for key in keys(section)
        string(key) in allowed || push!(errors, "$path contains unknown field '$(key)'")
    end
end

function _require_keys!(errors, section::AbstractDict, required, path::String)
    for key in required
        haskey(section, key) || push!(errors, "$path.$key is required")
    end
end

function _validate_string_vector!(errors, section::AbstractDict, key::String, path::String)
    haskey(section, key) || return
    value = section[key]
    if !_is_vector(value) || isempty(value) || !all(_is_nonempty_string, value)
        push!(errors, "$path.$key must be a non-empty array of strings")
    end
end

function _validate_processing_section!(errors, section::AbstractDict, prefixes, path::String)
    _check_unknown_keys!(errors, section, _PROCESSING_KEYS, path)
    _require_keys!(errors, section, ["ABOUT", "CHANGE_LOGS", "GAPFILL", "LABEL", "UNIT", "VERIFY_ONCE"], path)
    _validate_string_vector!(errors, section, "LABEL", path)

    if haskey(section, "ABOUT") && !_is_nonempty_string(section["ABOUT"])
        push!(errors, "$path.ABOUT must be a non-empty string")
    end
    if haskey(section, "UNIT") && !_is_nonempty_string(section["UNIT"])
        push!(errors, "$path.UNIT must be a non-empty string")
    end
    if haskey(section, "CHANGE_LOGS")
        logs = section["CHANGE_LOGS"]
        if !_is_vector(logs) || !all(x -> x isa AbstractString, logs)
            push!(errors, "$path.CHANGE_LOGS must be an array of strings")
        end
    end
    if haskey(section, "GAPFILL") && !(section["GAPFILL"] isa Union{Number,AbstractString})
        push!(errors, "$path.GAPFILL must be a numeric fill value or a named strategy")
    end
    if haskey(section, "VERIFY_ONCE") && !(section["VERIFY_ONCE"] isa Bool)
        push!(errors, "$path.VERIFY_ONCE must be true or false")
    end
    if haskey(section, "LABEL") && _is_vector(section["LABEL"]) && _is_vector(prefixes)
        length(section["LABEL"]) == length(prefixes) ||
            push!(errors, "$path.LABEL must contain one entry for every FILE.PREFIX")
    end
    if haskey(section, "LIMITS")
        limits = section["LIMITS"]
        if !_is_vector(limits) || length(limits) != 2 || !all(x -> x isa Number, limits)
            push!(errors, "$path.LIMITS must contain exactly two numbers")
        elseif limits[1] > limits[2]
            push!(errors, "$path.LIMITS lower bound must not exceed the upper bound")
        end
    end
    if haskey(section, "SCALING")
        scaling = section["SCALING"]
        if !(scaling isa AbstractString) || lowercase(scaling) != "linear"
            push!(errors, "$path.SCALING currently supports only 'linear'")
        end
        factor = get(section, "SCALING_FACTOR", nothing)
        if !_is_vector(factor) || length(factor) != 2 || !all(x -> x isa Number, factor)
            push!(errors, "$path.SCALING_FACTOR must contain multiplier and offset")
        end
    elseif haskey(section, "SCALING_FACTOR")
        push!(errors, "$path.SCALING_FACTOR requires $path.SCALING")
    end
    for key in ("REV_LAT", "REV_LON", "FLIP_LON")
        haskey(section, key) && !(section[key] isa Bool) && push!(errors, "$path.$key must be true or false")
    end

    if haskey(section, "DIMENSIONS")
        dimensions = section["DIMENSIONS"]
        if !(dimensions isa AbstractDict)
            push!(errors, "$path.DIMENSIONS must map each source variable name to its dimension order")
        elseif haskey(section, "LABEL") && _is_vector(section["LABEL"])
            for label in unique(section["LABEL"])
                if !haskey(dimensions, label)
                    push!(errors, "$path.DIMENSIONS is missing source variable '$label'")
                    continue
                end
                dims = dimensions[label]
                if !_is_vector(dims) || !(length(dims) in (2, 3)) || !all(_is_nonempty_string, dims)
                    push!(errors, "$path.DIMENSIONS.$label must contain two or three dimension names")
                    continue
                end
                normalized = lowercase.(String.(dims))
                canonical = get(_CANONICAL_DIMENSIONS, length(normalized), String[])
                if length(unique(normalized)) != length(normalized) || Set(normalized) != Set(canonical)
                    push!(errors, "$path.DIMENSIONS.$label must be a permutation of $(canonical)")
                end
            end
        end
    end
end

"""Validate a GriddingMachineDatasets YAML dictionary before any file or network access."""
function validate_config(config::AbstractDict)
    errors = String[]
    _check_unknown_keys!(errors, config, _TOP_LEVEL_KEYS, "config")
    _require_keys!(errors, config, ["FILE", "FOLDER", "DATA", "GRIDDINGMACHINE"], "config")

    version = get(config, "SCHEMA_VERSION", 1)
    version == 1 || push!(errors, "SCHEMA_VERSION must currently be 1")

    for key in ("FILE", "FOLDER", "DATA", "STD", "GRIDDINGMACHINE")
        haskey(config, key) && !(config[key] isa AbstractDict) && push!(errors, "config.$key must be a mapping")
    end
    isempty(errors) || throw(ConfigValidationError(errors))

    file = config["FILE"]
    _check_unknown_keys!(errors, file, _FILE_KEYS, "FILE")
    _require_keys!(errors, file, ["PATTERN", "PREFIX", "NX", "MT", "VV"], "FILE")
    _validate_string_vector!(errors, file, "PREFIX", "FILE")
    _validate_string_vector!(errors, file, "MT", "FILE")
    _validate_string_vector!(errors, file, "VV", "FILE")
    haskey(file, "PATTERN") && !_is_nonempty_string(file["PATTERN"]) && push!(errors, "FILE.PATTERN must be a non-empty string")
    if haskey(file, "NX")
        nx = file["NX"]
        (!_is_vector(nx) || isempty(nx) || !all(x -> x isa Integer && x > 0, nx)) &&
            push!(errors, "FILE.NX must be a non-empty array of positive integers")
    end
    if haskey(file, "YYYY")
        years = file["YYYY"]
        (!_is_vector(years) || isempty(years) || !all(x -> x isa Integer, years)) &&
            push!(errors, "FILE.YYYY must be a non-empty array of integers when provided")
    end

    folder = config["FOLDER"]
    _check_unknown_keys!(errors, folder, _FOLDER_KEYS, "FOLDER")
    _require_keys!(errors, folder, ["ORIGINAL", "REPROCESSED"], "FOLDER")
    for key in ("ORIGINAL", "REPROCESSED")
        haskey(folder, key) && !_is_nonempty_string(folder[key]) && push!(errors, "FOLDER.$key must be a non-empty string")
    end

    prefixes = get(file, "PREFIX", Any[])
    _validate_processing_section!(errors, config["DATA"], prefixes, "DATA")
    haskey(config, "STD") && _validate_processing_section!(errors, config["STD"], prefixes, "STD")

    gm = config["GRIDDINGMACHINE"]
    _check_unknown_keys!(errors, gm, _GRIDDINGMACHINE_KEYS, "GRIDDINGMACHINE")
    _require_keys!(errors, gm, ["TAG"], "GRIDDINGMACHINE")
    haskey(gm, "TAG") && !(gm["TAG"] isa AbstractString) && push!(errors, "GRIDDINGMACHINE.TAG must be a string")
    haskey(gm, "REVISION") && !(gm["REVISION"] isa AbstractString) && push!(errors, "GRIDDINGMACHINE.REVISION must be a string")

    isempty(errors) || throw(ConfigValidationError(errors))
    return config
end

"""Reorder a two- or three-dimensional source array to `(lon, lat[, ind])`."""
function standardize_dimension_order(data::AbstractArray, varname::AbstractString, section::AbstractDict)
    canonical = get(_CANONICAL_DIMENSIONS, ndims(data), nothing)
    isnothing(canonical) && throw(ArgumentError("Only two- and three-dimensional source variables are supported; '$varname' has $(ndims(data)) dimensions"))

    dimensions = get(section, "DIMENSIONS", nothing)
    isnothing(dimensions) && return data
    haskey(dimensions, varname) || throw(ConfigValidationError(["DIMENSIONS is missing source variable '$varname'"]))

    source = lowercase.(String.(dimensions[varname]))
    length(source) == ndims(data) || throw(ConfigValidationError(["DIMENSIONS.$varname has $(length(source)) names but the array has $(ndims(data)) dimensions"]))
    Set(source) == Set(canonical) || throw(ConfigValidationError(["DIMENSIONS.$varname must be a permutation of $(canonical)"]))

    permutation = Tuple(findfirst(==(dimension), source) for dimension in canonical)
    permutation == Tuple(1:ndims(data)) && return data
    return permutedims(data, permutation)
end

end # module ConfigSchema
