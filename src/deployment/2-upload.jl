"""Build a verified catalog entry from a local dataset file.

This helper only reads the local file. Uploading and remote record management are
deliberately outside the package pipeline and must be performed explicitly.
"""
function build_catalog_entry(
        local_file::AbstractString,
        urls::AbstractVector{<:AbstractString};
        path::AbstractString = "public/v0",
    )
    isfile(local_file) || throw(ArgumentError("dataset file does not exist: $local_file"))
    isempty(urls) && throw(ArgumentError("at least one download URL is required"))
    all(url -> any(prefix -> startswith(url, prefix), ("https://", "http://", "ftp://")), urls) ||
        throw(ArgumentError("download URLs must use HTTP(S) or FTP"))

    digest = open(local_file, "r") do io
        bytes2hex(SHA.sha256(io))
    end
    return Dict{String,Any}(
        "PATH" => String(path),
        "URL" => unique(String.(urls)),
        "SIZE" => filesize(local_file),
        "SHA256" => digest,
    )
end

"""Update a local YAML catalog transactionally from local artifact specifications.

Each value in `artifacts` must contain `FILE` and `URL`; `PATH` is optional. The
function neither uploads files nor changes a remote Zenodo/GitHub record.
"""
function update_yaml_library!(
        yaml_file::AbstractString,
        artifacts::AbstractDict;
        default_path::AbstractString = "public/v0",
    )
    catalog = if isfile(yaml_file)
        loaded = YAML.load_file(yaml_file)
        loaded isa AbstractDict || throw(ArgumentError("catalog root must be a mapping"))
        Dict{String,Any}(String(key) => value for (key, value) in loaded)
    else
        Dict{String,Any}()
    end

    for (raw_tag, raw_spec) in artifacts
        tag = String(raw_tag)
        isempty(strip(tag)) && throw(ArgumentError("artifact tag must not be empty"))
        raw_spec isa AbstractDict || throw(ArgumentError("$tag specification must be a mapping"))
        haskey(raw_spec, "FILE") || throw(ArgumentError("$tag.FILE is required"))
        haskey(raw_spec, "URL") || throw(ArgumentError("$tag.URL is required"))
        path = get(raw_spec, "PATH", default_path)
        catalog[tag] = build_catalog_entry(raw_spec["FILE"], raw_spec["URL"]; path)
    end

    destination = abspath(yaml_file)
    mkpath(dirname(destination))
    temporary = tempname(dirname(destination))
    try
        YAML.write_file(temporary, Dict(key => catalog[key] for key in sort!(collect(keys(catalog)))))
        mv(temporary, destination; force = true)
    finally
        isfile(temporary) && rm(temporary; force = true)
    end
    return catalog
end
