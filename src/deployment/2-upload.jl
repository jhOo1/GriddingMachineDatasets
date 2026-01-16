"""

    verify_uploads!(doi_url::String)

Verify the uploaded datasets to make sure a dict could be parsed from the website, given
- `doi_url` the DOI or url of the uploaded datasets

"""
function update_yaml_library! end;

yaml_file = "/mnt/net/ormosia/group/jianghao/GitHub/GriddingMachineDatasets/Artifacts.yaml";
ftp_base = "ftp://114.214.212.145/GriddingMachine/public/GM1-GM2-R1/"
path = "public/v0";

update_yaml_library!(doi_url::String = "https://zenodo.org/records/17732092") = (
    web_response = HTTP.get(doi_url; require_ssl_verification = false);

    # 1. if the response is not 200, raise an error
    if web_response.status != 200
        error("Faild to access the uploader datasets at $(doi_url)!");
        return nothing
    end;
    
    # 2. obtain the URL address of the NC files
    nc_urls = get_zenodo_nc_urls(zenodo_record_url);
    if isempty(nc_urls)
        error("no .nc files found");
    end;

    # 3. read existing YAML files
    yaml_data = isfile(yaml_file) ? read_library(yaml_file) : Dict{String,Any}();

    # 4. traverse .nc links and update YAML data
    for zenodo_url in nc_urls
        # 4.1 extract Key (file name, remove .nc suffix)
        # "https://zenodo.org/records/17732092/files/CHL_2X_7D_V1.nc"
        file_name = split(zenodo_url, "/")[end];
        art_key = replace(file_name, ".nc" => "");
        
        # 4.2 generate FTP address (concatenate base+Key+ .nc)
        ftp_url = joinpath(ftp_base, "$art_key.nc");  
        
        # 4.3 logic for handling the existence/non existence of keys
        if haskey(yaml_data, art_key)
            # key already exists: Verify if URL needs to be appended
            existing_urls = get(yaml_data[art_key], "URL", []);
            
            # check if Zenodo URL already exists
            if !(zenodo_url in existing_urls)
                push!(existing_urls, zenodo_url);                 
                push!(existing_urls, ftp_url);  
                yaml_data[art_key]["URL"] = existing_urls;
            end;
        else
            # key is not found: create a new entry
            new_item = Dict{String,Any}(
                "PATH" => path,
                "URL"  => [ftp_url, zenodo_url] 
            );
            yaml_data[art_key] = new_item;

        end;
    end;

    # 5. write updated data to YAML file
    save_library!(yaml_file, sort(yaml_data));
    @info "Successfully updated YAML library: $yaml_file";

    
    # TODO: 这里添加 FTP 上传逻辑，新文件上传到 FTP 服务器
    # upload_to_ftp(ftp_url, zenodo_url)
    
    return web_response;
);

# Example usage
update_yaml_library!();