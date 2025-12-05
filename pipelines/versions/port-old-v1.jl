using PkgUtility.ArtifactTools: read_library, save_library!

# https://zenodo.org/records/17731834/files/Artifacts.yaml
old_db_file = "../../Artifacts-v1.yaml";
new_db_file = "../../Artifacts.yaml";

old_database = isfile(old_db_file) ? read_library(old_db_file) : Dict{String,Any}();
new_database = isfile(new_db_file) ? read_library(new_db_file) : Dict{String,Any}();

for (k,item) in old_database
    if k in keys(new_database)
        continue;
    end;

    @info "Processing artifact key: $(k)...";
    new_item = Dict{String,Any}(
        "PATH" => occursin("old", item["PATH"]) ? "public/v0" : item["PATH"],
        "URL"  => ["ftp://114.214.212.145/GriddingMachine/$(item["PATH"])/$(k).nc", item["URL"]],
    );
    new_database[k] = new_item;
end;

save_library!("../../Artifacts.yaml", sort(new_database));
