source_2d = reshape(collect(1:6), 2, 3)
section_2d = Dict{String,Any}("DIMENSIONS" => Dict("v" => ["lat", "lon"]))
@test standardize_dimension_order(source_2d, "v", section_2d) == permutedims(source_2d, (2, 1))
@test size(standardize_dimension_order(source_2d, "v", section_2d)) == (3, 2)

source_3d = reshape(collect(1:12), 2, 2, 3)
section_3d = Dict{String,Any}("DIMENSIONS" => Dict("v" => ["ind", "lat", "lon"]))
@test standardize_dimension_order(source_3d, "v", section_3d) == permutedims(source_3d, (3, 2, 1))
@test size(standardize_dimension_order(source_3d, "v", section_3d)) == (3, 2, 2)

canonical = Dict{String,Any}("DIMENSIONS" => Dict("v" => ["lon", "lat"]))
@test standardize_dimension_order(source_2d, "v", canonical) === source_2d

wrong = Dict{String,Any}("DIMENSIONS" => Dict("v" => ["x", "y"]))
@test_throws ConfigValidationError standardize_dimension_order(source_2d, "v", wrong)
@test_throws ArgumentError standardize_dimension_order(zeros(2, 2, 2, 2), "v", Dict{String,Any}())
