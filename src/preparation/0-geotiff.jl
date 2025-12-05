#=
using ArchGDAL
#=
"""

    read_geotiff(filepath::String, band::Int)

Reads a geotiff file and returns the data of the specified band, given
- `filepath` the path to the geotiff file
- `band` the band to read

"""
function read_geotiff end;

read_geotiff(filepath::String, band::Int) = (
    dset = ArchGDAL.read(filepath);
    data = ArchGDAL.getband(dset, band);

    return data[:,:]
);
=#
