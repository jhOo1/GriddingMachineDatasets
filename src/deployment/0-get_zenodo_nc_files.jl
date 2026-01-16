using Downloads, Gumbo, Cascadia

"""
    get_zenodo_nc_urls(zenodo_record_url::String) -> Vector{String}

Extract the complete download URLs of all .nc files from the Zenodo record page
"""
using Downloads, Gumbo, Cascadia

function get_zenodo_nc_urls(zenodo_record_url::String)
    # 1. download the HTML file from Zenodo and then decode it
    temp_html = Downloads.download(zenodo_record_url)
    html_content = read(temp_html, String)
    rm(temp_html; force=true)
    doc = parsehtml(html_content)

    # 2. match the<link>tag (the actual carrier of the .nc file)
    # Core: match<link>with type=application/x-netcdf and href containing/files/
    selector = Selector(raw"link[type='application/x-netcdf'][href*='/files/']")
    nc_links = eachmatch(selector, doc.root)

    # 3. extract the href and concatenate the complete download URL
    nc_urls = String[]
    for link in nc_links
        href = getattr(link, "href")
        push!(nc_urls, href)
    end
    # deduplication
    unique!(nc_urls) 

    @info "Found $(length(nc_urls)) .nc file links"
    return nc_urls
end

