using NCDatasets  

# read NC variable properties and ensure that the key is of type String
function get_var_attrs(nc_file::String, var_name::String)
    ds = Dataset(nc_file, "r")
    # convert all keys to String and return pure Dict {String, Any}
    attrs = Dict{String, Any}(String(k) => v for (k, v) in ds[var_name].attrib)
    close(ds)
    return attrs
end

