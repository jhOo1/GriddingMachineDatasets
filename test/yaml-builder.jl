include(joinpath(@__DIR__, "..", "src", "build-yaml", "YamlBuilder.jl"))
using .YamlBuilder

payload = Dict{Symbol,Any}(
    :PATTERN => "PREFIX_NX_MT_VV.nc",
    :PREFIX => ["TEST"],
    :NX => [1],
    :MT => ["1Y"],
    :VV => ["V1"],
    :YYYY => Int[],
    :ORIGINAL => "fixture",
    :REPROCESSED => "fixture",
    :ABOUT => "Synthetic fixture",
    :CHANGE_LOGS => ["Generated for testing"],
    :LABEL => ["source"],
    :LIMITS => [-1.0, 1.0],
    :DIMENSIONS => ["lat", "lon"],
    :GAPFILL => "KEEP_AS_IS",
    :REV_LAT => false,
    :REV_LON => false,
    :FLIP_LON => false,
    :SCALING => "",
    :SCALING_FACTOR => Float64[],
    :UNIT => "1",
    :VERIFY_ONCE => true,
    :TAG => "TEST",
    :REVISION => "R1",
)

generated = build_yaml_string(payload)
parsed = YAML.load(generated)
@test validate_config(parsed) isa AbstractDict
@test parsed["SCHEMA_VERSION"] == 1
@test parsed["DATA"]["DIMENSIONS"]["source"] == ["lat", "lon"]
@test !haskey(parsed["FOLDER"], "TARBALL")
