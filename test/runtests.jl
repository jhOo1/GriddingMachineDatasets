using Test
using YAML

include(joinpath(@__DIR__, "..", "src", "config", "schema.jl"))
using .ConfigSchema

@testset "GriddingMachineDatasets configuration" begin
    include("schema.jl")
    include("dimension-order.jl")
    include("yaml-builder.jl")
end

if lowercase(get(ENV, "GMD_RUN_INTEGRATION_TESTS", "false")) == "true"
    @testset "Package integration" begin
        include("package-load.jl")
        include("catalog-generation.jl")
        include("pipeline-integration.jl")
        include("gapfill.jl")
    end
end
