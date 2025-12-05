using PkgUtility.ArtifactTools: read_library, save_library!

# https://zenodo.org/records/15622412/files/Artifacts.yaml
old_db_file = "../../Artifacts-v0.yaml";
new_db_file = "../../Artifacts.yaml";

old_database = sort(isfile(old_db_file) ? read_library(old_db_file) : Dict{String,Any}());
new_database = sort(isfile(new_db_file) ? read_library(new_db_file) : Dict{String,Any}());

for (k,item) in old_database
    if k in keys(new_database)
        continue;
    end;

    @info "Processing artifact key: $(k)...";
    new_item = Dict{String,Any}(
        "PATH" => "public/v0",
        "URL"  => ["ftp://114.214.212.145/GriddingMachine/public/v0/$(k).nc"],
    );
    new_database[k] = new_item;
end;

save_library!("../../Artifacts.yaml", sort(new_database));

#=
# The code below copies the v0 data file from the old server to the new server
dirs = readdir("/mnt/net/emerald/GriddingMachine/public");
for d in dirs
    dpath = joinpath("/mnt/net/emerald/GriddingMachine/public", d);
    fpath = joinpath("/mnt/net/emerald/GriddingMachine/public", d, "GRIDDINGMACHINE");
    if isfile(fpath)
        for f in readdir(dpath)
            if endswith(f, ".nc")
                srcpath = joinpath(dpath, f);
                tarpath = joinpath(homedir(), "GriddingMachine/public/v0", f);
                @info "Copying file from" srcpath tarpath;
                cp(srcpath, tarpath);
            end;
        end;
    end;
end;
=#
