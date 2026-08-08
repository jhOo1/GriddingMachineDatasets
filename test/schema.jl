function minimal_config()
    return Dict{String,Any}(
        "SCHEMA_VERSION" => 1,
        "FILE" => Dict{String,Any}(
            "PATTERN" => "PREFIX_NX_MT_VV.nc",
            "PREFIX" => ["TEST"],
            "NX" => [1],
            "MT" => ["1Y"],
            "VV" => ["V1"],
        ),
        "FOLDER" => Dict{String,Any}(
            "ORIGINAL" => "fixture",
            "REPROCESSED" => "fixture",
        ),
        "DATA" => Dict{String,Any}(
            "ABOUT" => "Synthetic fixture",
            "CHANGE_LOGS" => String[],
            "DIMENSIONS" => Dict("source" => ["lat", "lon"]),
            "GAPFILL" => "KEEP_AS_IS",
            "LABEL" => ["source"],
            "LIMITS" => [-1.0, 1.0],
            "REV_LAT" => false,
            "UNIT" => "1",
            "VERIFY_ONCE" => true,
        ),
        "GRIDDINGMACHINE" => Dict{String,Any}("TAG" => "TEST"),
    )
end

@test validate_config(minimal_config()) isa AbstractDict

missing_gapfill = minimal_config()
delete!(missing_gapfill["DATA"], "GAPFILL")
@test_throws ConfigValidationError validate_config(missing_gapfill)

legacy_tarball = minimal_config()
legacy_tarball["FOLDER"]["TARBALL"] = "fixture"
@test_throws ConfigValidationError validate_config(legacy_tarball)

invalid_gapfill = minimal_config()
invalid_gapfill["DATA"]["GAPFILL"] = nothing
@test_throws ConfigValidationError validate_config(invalid_gapfill)

wrong_labels = minimal_config()
push!(wrong_labels["FILE"]["PREFIX"], "OTHER")
@test_throws ConfigValidationError validate_config(wrong_labels)

@testset "all repository YAML files satisfy the schema" begin
    yaml_root = joinpath(@__DIR__, "..", "yaml")
    paths = String[]
    for (root, _, files) in walkdir(yaml_root), file in files
        endswith(file, ".yaml") && push!(paths, joinpath(root, file))
    end
    @test !isempty(paths)
    for path in sort(paths)
        @test validate_config(YAML.load_file(path)) isa AbstractDict
    end
end
