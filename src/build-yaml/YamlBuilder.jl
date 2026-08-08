module YamlBuilder

using YAML

include(joinpath(@__DIR__, "..", "config", "schema.jl"))
using .ConfigSchema: validate_config

export build_config, build_yaml_string

function _payload(payload, key::Symbol, default = nothing)
    if hasproperty(payload, key)
        return getproperty(payload, key)
    elseif payload isa AbstractDict && haskey(payload, key)
        return payload[key]
    elseif payload isa AbstractDict && haskey(payload, String(key))
        return payload[String(key)]
    end
    return default
end

_array(value) = isnothing(value) ? Any[] : collect(value)

function build_config(payload)
    prefixes = String.(_array(_payload(payload, :PREFIX)))
    labels = String.(_array(_payload(payload, :LABEL)))

    file = Dict{String,Any}(
        "PATTERN" => String(_payload(payload, :PATTERN)),
        "PREFIX" => prefixes,
        "NX" => Int.(_array(_payload(payload, :NX))),
        "MT" => String.(_array(_payload(payload, :MT))),
        "VV" => String.(_array(_payload(payload, :VV))),
    )
    years = _array(_payload(payload, :YYYY))
    isempty(years) || (file["YYYY"] = Int.(years))

    data = Dict{String,Any}(
        "ABOUT" => String(_payload(payload, :ABOUT)),
        "CHANGE_LOGS" => String.(_array(_payload(payload, :CHANGE_LOGS))),
        "GAPFILL" => _payload(payload, :GAPFILL),
        "LABEL" => labels,
        "LIMITS" => Float64.(_array(_payload(payload, :LIMITS))),
        "REV_LAT" => Bool(_payload(payload, :REV_LAT, false)),
        "REV_LON" => Bool(_payload(payload, :REV_LON, false)),
        "FLIP_LON" => Bool(_payload(payload, :FLIP_LON, false)),
        "UNIT" => String(_payload(payload, :UNIT)),
        "VERIFY_ONCE" => Bool(_payload(payload, :VERIFY_ONCE, true)),
    )

    source_dimensions = lowercase.(String.(_array(_payload(payload, :DIMENSIONS))))
    if !isempty(source_dimensions)
        data["DIMENSIONS"] = Dict(label => copy(source_dimensions) for label in unique(labels))
    end

    scaling = _payload(payload, :SCALING, "")
    if !isnothing(scaling) && !isempty(strip(String(scaling)))
        data["SCALING"] = String(scaling)
        data["SCALING_FACTOR"] = Float64.(_array(_payload(payload, :SCALING_FACTOR)))
    end

    config = Dict{String,Any}(
        "SCHEMA_VERSION" => 1,
        "FILE" => file,
        "FOLDER" => Dict{String,Any}(
            "ORIGINAL" => String(_payload(payload, :ORIGINAL)),
            "REPROCESSED" => String(_payload(payload, :REPROCESSED)),
        ),
        "DATA" => data,
        "GRIDDINGMACHINE" => Dict{String,Any}(
            "TAG" => String(_payload(payload, :TAG)),
        ),
    )

    revision = _payload(payload, :REVISION, "")
    if !isnothing(revision) && !isempty(strip(String(revision)))
        config["GRIDDINGMACHINE"]["REVISION"] = String(revision)
    end

    return validate_config(config)
end

build_yaml_string(payload) = YAML.write(build_config(payload))

end # module
