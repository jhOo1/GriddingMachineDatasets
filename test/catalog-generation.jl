using SHA

@testset "verified local catalog generation" begin
    mktempdir() do directory
        dataset = joinpath(directory, "TEST_1X_1Y_V1.nc")
        payload = Vector{UInt8}(codeunits("synthetic-netcdf-fixture"))
        write(dataset, payload)

        entry = GriddingMachineDatasets.build_catalog_entry(
            dataset,
            ["https://example.org/TEST_1X_1Y_V1.nc", "ftp://example.org/TEST_1X_1Y_V1.nc"],
        )
        @test entry["SIZE"] == length(payload)
        @test entry["SHA256"] == bytes2hex(SHA.sha256(payload))
        @test length(entry["URL"]) == 2

        catalog_file = joinpath(directory, "Artifacts.yaml")
        artifacts = Dict(
            "TEST_1X_1Y_V1" => Dict(
                "FILE" => dataset,
                "URL" => ["https://example.org/TEST_1X_1Y_V1.nc"],
            ),
        )
        catalog = GriddingMachineDatasets.update_yaml_library!(catalog_file, artifacts)
        persisted = YAML.load_file(catalog_file)
        @test catalog["TEST_1X_1Y_V1"]["SIZE"] == length(payload)
        @test persisted["TEST_1X_1Y_V1"]["SHA256"] == bytes2hex(SHA.sha256(payload))

        @test_throws ArgumentError GriddingMachineDatasets.build_catalog_entry(
            dataset,
            String[],
        )
        @test_throws ArgumentError GriddingMachineDatasets.update_yaml_library!(
            catalog_file,
            Dict("BROKEN" => Dict("URL" => ["https://example.org/broken.nc"])),
        )
    end
end
