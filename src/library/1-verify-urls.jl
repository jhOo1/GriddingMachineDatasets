""" Function to verify the accessibility of URLs in the artifact library """
function verify_urls! end;

verify_urls!() = (
    database = sort(read_library("../../Artifacts.yaml"));

    # make a list of unique server addresses and accessibility pings
    server_adds = String[];
    server_pings = Float64[];
    for (_, item) in database
        urls = item["URL"];
        for url in urls
            serveradd = replace(match(r"://([^/]+)/", url).captures[1], r":.*" => "");
            if !(serveradd in server_adds)
                push!(server_adds, serveradd);
                push!(server_pings, ip_address_ping(serveradd));
            end;
        end;
    end;
    pretty_display!("The pings for the servers are as follows:", "tinfo_pre");
    for i in eachindex(server_adds)
        pretty_display!("    $(server_adds[i]): $(server_pings[i]) ms", "tinfo_mid");
    end;
    pretty_display!("", "tinfo_end");

    # loop through the database and verify each URL
    warns = String[];
    pretty_display!("Verifying URLs in the artifact library...", "tinfo_pre");
    count = length(database);
    idx = 1;
    for (k, db_item) in database
        pretty_display!("Verifying $(idx)/$(count) artifact: $(k)...", "tinfo_mid");
        item_warns = verify_urls!(db_item, server_adds, server_pings);
        append!(warns, item_warns);
        idx += 1;
        if idx > 10
            break;
        end;
        sleep(5);
    end;

    # write the summary of warnings
    if length(warns) > 0
        pretty_display!("$(length(warns)) URLs are inaccessible or files do not exist on server:", "tinfo_end");
        sort!(warns);
        open("../../invalid-url.log", "w") do io
            for warn in warns
                println(io, warn);
            end;
        end;
    else
        pretty_display!("All URLs in the artifact library are accessible.", "tinfo_end");
    end;

    return nothing
);

verify_urls!(db_item::Dict) = (
    # make a list of unique server addresses and accessibility pings
    server_adds = String[];
    server_pings = Float64[];
    urls = db_item["URL"];
    for url in urls
        serveradd = replace(match(r"://([^/]+)/", url).captures[1], r":.*" => "");
        if !(serveradd in server_adds)
            push!(server_adds, serveradd);
            push!(server_pings, ip_address_ping(serveradd));
        end;
    end;
    pretty_display!("The pings for the servers are as follows:", "tinfo_pre");
    for i in eachindex(server_adds)
        pretty_display!("    $(server_adds[i]): $(server_pings[i]) ms", "tinfo_mid");
    end;
    pretty_display!("", "tinfo_end");

    return verify_urls!(db_item, server_adds, server_pings)
);

verify_urls!(db_item::Dict, serveradds::Vector{String}, serverpings::Vector{Float64}) = (
    urls = db_item["URL"];
    warns = String[];
    for url in urls
        iserver = findfirst(x -> occursin(x, url), serveradds);
        if serverpings[iserver] == Inf
            push!(warns, "URL inaccessible: $(url)");
            continue;
        end;
        url_valid = occursin("ftp://", url) ? ftp_url_accessible(url) : http_url_accessible(url);
        if !url_valid
            push!(warns, "File does not exist on server: $(url)");
        end;
    end;

    return warns
);


function ip_address_ping(ipadd::String)
    return try
        pinginfo = read(`ping -c 1 -W 2 $(ipadd)`, String);
        # isolate time= ms from the printinfo
        parse(Float64, match(r"time=(\d+\.?\d*) ms", pinginfo)[1])
    catch e
        @warn "Ping failed for IP address: $(ipadd)";
        Inf
    end;
end;

function ftp_url_accessible(ftp_url::String)
    ftpaddess = match(r"ftp://([^/]+)/", ftp_url).captures[1];
    ftpclient = nothing;

    filepath = replace(ftp_url, r"ftp://[^/]+/" => "");
    dirpath = dirname(filepath);
    filename = basename(filepath);
    return try
        ftpclient = FTPClient.FTP("ftp://$(ftpaddess)");
        cd(ftpclient, dirpath);
        filelist = readdir(ftpclient);
        filename in filelist
    catch e
        false
    finally
        # Ensure connection is closed
        if !isnothing(ftpclient)
            close(ftpclient)
        end;
    end;
end;

function http_url_accessible(http_url::String)
    return try
        response = HTTP.get(http_url; require_ssl_verification = false);
        response.status == 200
    catch e
        false
    end;
end;
