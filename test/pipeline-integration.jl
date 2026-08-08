using NetcdfIO

@testset "synthetic NetCDF pipeline" begin
    mktempdir() do directory
        original_home = GriddingMachineDatasets.GRIDDING_MACHINE_HOME
        try
            GriddingMachineDatasets.GRIDDING_MACHINE_HOME = directory
            original_dir = joinpath(directory, "original", "case-input")
            mkpath(original_dir)
            source_file = joinpath(original_dir, "SRC_2X_1Y_V1.nc")
            source = Float32[
                11 12 13 14
                21 22 23 24
            ]
            NetcdfIO.save_nc!(source_file, "source", source, Dict{String,Any}("about" => "fixture"))

            config = Dict{String,Any}(
                "SCHEMA_VERSION" => 1,
                "FILE" => Dict(
                    "PATTERN" => "PREFIX_NX_X_MT_VV.nc",
                    "PREFIX" => ["SRC"],
                    "NX" => [2],
                    "MT" => ["1Y"],
                    "VV" => ["V1"],
                ),
                "FOLDER" => Dict("ORIGINAL" => "case-input", "REPROCESSED" => "case-output"),
                "DATA" => Dict(
                    "ABOUT" => "synthetic data",
                    "CHANGE_LOGS" => String[],
                    "DIMENSIONS" => Dict("source" => ["lat", "lon"]),
                    "FLIP_LON" => true,
                    "GAPFILL" => "KEEP_AS_IS",
                    "LABEL" => ["source"],
                    "LIMITS" => [23, 49],
                    "REV_LAT" => true,
                    "SCALING" => "linear",
                    "SCALING_FACTOR" => [2, 1],
                    "UNIT" => "1",
                    "VERIFY_ONCE" => false,
                ),
                "GRIDDINGMACHINE" => Dict("TAG" => "TEST"),
            )
            yaml_file = joinpath(directory, "fixture.yaml")
            YAML.write_file(yaml_file, config)

            expected = permutedims(source, (2, 1))[:, end:-1:1]
            expected = vcat(expected[3:4, :], expected[1:2, :]) .* 2 .+ 1
            expected[expected .< 23 .|| expected .> 49] .= NaN
            reviews = Ref(0)
            verifier = (data, section) -> begin
                reviews[] += 1
                isequal(data, expected)
            end
            GriddingMachineDatasets.process_dataset!(yaml_file; verifier)

            output_file = joinpath(directory, "reprocessed", "case-output", "TEST_SRC_2X_1Y_V1.nc")
            @test isfile(output_file)
            @test isequal(NetcdfIO.read_nc(Float32, output_file, "data"), expected)
            @test reviews[] == 1

            GriddingMachineDatasets.process_dataset!(yaml_file; verifier)
            @test reviews[] == 1

            source_3d = reshape(Float32.(1:16), 2, 2, 4)
            source_file_3d = joinpath(original_dir, "CUBE_2X_1M_V1.nc")
            NetcdfIO.save_nc!(source_file_3d, "cube", source_3d, Dict{String,Any}("about" => "3-D fixture"))
            config_3d = deepcopy(config)
            config_3d["FILE"]["PREFIX"] = ["CUBE"]
            config_3d["FILE"]["MT"] = ["1M"]
            config_3d["DATA"] = Dict(
                "ABOUT" => "synthetic cube",
                "CHANGE_LOGS" => String[],
                "DIMENSIONS" => Dict("cube" => ["ind", "lat", "lon"]),
                "GAPFILL" => "KEEP_AS_IS",
                "LABEL" => ["cube"],
                "UNIT" => "1",
                "VERIFY_ONCE" => false,
            )
            config_3d["GRIDDINGMACHINE"]["TAG"] = "TEST3"
            yaml_file_3d = joinpath(directory, "fixture-3d.yaml")
            YAML.write_file(yaml_file_3d, config_3d)
            expected_3d = permutedims(source_3d, (3, 2, 1))
            reviews_3d = Ref(0)
            verifier_3d = (data, section) -> begin
                reviews_3d[] += 1
                data == expected_3d
            end
            GriddingMachineDatasets.process_dataset!(yaml_file_3d; verifier = verifier_3d)
            output_file_3d = joinpath(directory, "reprocessed", "case-output", "TEST3_CUBE_2X_1M_V1.nc")
            @test isfile(output_file_3d)
            @test NetcdfIO.read_nc(Float32, output_file_3d, "data") == expected_3d
            @test reviews_3d[] == 1
        finally
            GriddingMachineDatasets.GRIDDING_MACHINE_HOME = original_home
        end
    end
end
