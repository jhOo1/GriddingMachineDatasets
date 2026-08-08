function gapfill_section()
    return Dict{String,Any}("CHANGE_LOGS_TO_WRITE" => String[])
end

@testset "gap-filling strategies" begin
    land = Float32[1 0; 1 1]

    constant_data = Float32[NaN 2; 3 NaN]
    constant_section = gapfill_section()
    @test GriddingMachineDatasets.fill_missing_values!(
        constant_data,
        land,
        GriddingMachineDatasets.FillMethodConstant(7),
        constant_section,
    ) == 2
    @test isequal(constant_data, Float32[7 2; 3 7])
    @test length(constant_section["CHANGE_LOGS_TO_WRITE"]) == 1

    mean_data = Float32[NaN 2; 3 NaN]
    mean_section = gapfill_section()
    @test GriddingMachineDatasets.fill_missing_values!(
        mean_data,
        land,
        GriddingMachineDatasets.FillMethodMean(),
        mean_section,
    ) == 2
    @test isequal(mean_data, Float32[2.5 2; 3 2.5])

    check_data = Float32[NaN 2; 3 4]
    @test GriddingMachineDatasets.fill_missing_values!(
        copy(check_data), land, GriddingMachineDatasets.FillMethodNoLandNaN(), gapfill_section(),
    ) == -1
    @test GriddingMachineDatasets.fill_missing_values!(
        copy(check_data), land, GriddingMachineDatasets.FillMethodNoNaN(), gapfill_section(),
    ) == -2
    @test GriddingMachineDatasets.fill_missing_values!(
        copy(check_data), land, GriddingMachineDatasets.FillMethodKeepAsIs(), gapfill_section(),
    ) == 0

    integer_data = Float32[NaN 2.2; 3.8 NaN]
    @test GriddingMachineDatasets.fill_missing_values!(
        integer_data, land, GriddingMachineDatasets.FillMethodIntNaNTo1(), gapfill_section(),
    ) == -3
    @test integer_data == Float32[1 2; 4 1]

    cube = cat(Float32[NaN 2; 3 4], Float32[5 NaN; 7 8]; dims = 3)
    @test GriddingMachineDatasets.fill_missing_values!(
        cube, land, GriddingMachineDatasets.FillMethodConstant(9), gapfill_section(),
    ) == 1
    @test cube[1, 1, 1] == 9
    @test isnan(cube[1, 2, 2])
end
