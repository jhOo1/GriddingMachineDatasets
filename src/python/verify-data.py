#
# This script is meant to verify the orientation of the dataset
#
import os
import sys

import matplotlib.pyplot as PLT
import matplotlib.animation as ANI

# Allow a caller to supply netCDF4/cftime without overriding the NumPy used by
# the installed Matplotlib build. Appending is deliberate: system packages win.
extra_packages = os.environ.get("GMD_PYTHON_PACKAGES")
if extra_packages:
    sys.path.append(extra_packages)

import netCDF4 as NC


def plane_lat_lon(data, dimensions, frame=None):
    """Return one 2-D plane ordered as (lat, lon) for imshow."""
    dims = list(dimensions)
    if "lon" not in dims or "lat" not in dims:
        raise ValueError("The plotted variable must contain lon and lat dimensions")
    if frame is not None:
        if "ind" not in dims:
            raise ValueError("A 3-D variable must contain an ind dimension")
        ind_axis = dims.index("ind")
        data = data.take(frame, axis=ind_axis)
        dims.pop(ind_axis)
    if len(dims) != 2:
        raise ValueError("Only 2-D (lon,lat) and 3-D (lon,lat,ind) variables are supported")
    return data.transpose(dims.index("lat"), dims.index("lon"))


# 1. if file name not provided, print error message and exit
if len(sys.argv) == 1:
    print("    PythonVisualization: Please provide the file name!")
    sys.exit(1)


# 2. if file name provided, make sure the file exists
fname = sys.argv[1]
print("    PythonVisualization: File name is: ", fname)
if not os.path.exists(fname):
    print("    PythonVisualization: File", fname, "does not exist!")
    sys.exit(1)


# 3. make sure the data name is provided
if len(sys.argv) == 2:
    print("    PythonVisualization: Please provide the data name!")
    sys.exit(1)
label = sys.argv[2]
print("    PythonVisualization: Data name is: ", label)


# 4. read the optional input for vmin and vmax
vmin = None
vmax = None
if len(sys.argv) == 5:
    vmin = float(sys.argv[3])
    vmax = float(sys.argv[4])
    print("    PythonVisualization: vmin is: ", vmin)
    print("    PythonVisualization: vmax is: ", vmax)


# 5. read the data using Netcdf4
dset = NC.Dataset(fname)
variable = dset.variables[label]
data = variable[:]
dimensions = variable.dimensions
dset.close()
if "lon" not in dimensions or "lat" not in dimensions:
    print("    PythonVisualization: Variable dimensions must include lon and lat:", dimensions)
    sys.exit(1)
lon_size = data.shape[dimensions.index("lon")]
lat_size = data.shape[dimensions.index("lat")]
lon_step = max(1, int(round(lon_size / 360)))
lat_step = max(1, int(round(lat_size / 180)))
output_dir = os.path.dirname(os.path.abspath(fname))


# 6. print the shape of the data
print("    PythonVisualization: Data shape is: ", data.shape)
if len(data.shape) == 2:
    print("    PythonVisualization: 2D PNG will be plotted as is!")
    PLT.figure(1, figsize=(13,6), dpi=300)
    plane = plane_lat_lon(data, dimensions)[::lat_step, ::lon_step]
    if vmin is not None and vmax is not None:
        cm = PLT.imshow(plane, origin="lower", extent=(-180, 180, -90, 90),
                        aspect="auto", vmin=vmin, vmax=vmax)
    else:
        cm = PLT.imshow(plane, origin="lower", extent=(-180, 180, -90, 90),
                        aspect="auto")
    PLT.xlabel("Longitude (degrees east)")
    PLT.ylabel("Latitude (degrees north)")
    PLT.colorbar(cm)
    output_path = os.path.join(output_dir, "orientation.png")
    PLT.savefig(output_path)
    PLT.close()
    print("    PythonVisualization: Orientation image saved as", output_path)
elif len(data.shape) == 3:
    def animate(i):
        PLT.clf()
        plane = plane_lat_lon(data, dimensions, i)[::lat_step, ::lon_step]
        if vmin is not None and vmax is not None:
            cm = PLT.imshow(plane, origin="lower", extent=(-180, 180, -90, 90),
                            aspect="auto", vmin=vmin, vmax=vmax)
        else:
            cm = PLT.imshow(plane, origin="lower", extent=(-180, 180, -90, 90),
                            aspect="auto")
        PLT.xlabel("Longitude (degrees east)")
        PLT.ylabel("Latitude (degrees north)")
        PLT.colorbar(cm)
        PLT.title("Frame: " + str(i))
        return cm
    print("    PythonVisualization: 3D GIF will be plotted!")
    fig = PLT.figure(1, figsize=(13,6), dpi=300)
    anim = ANI.FuncAnimation(fig, animate,
                             frames=data.shape[dimensions.index("ind")], interval=200)
    writer = ANI.PillowWriter(fps=1)
    output_path = os.path.join(output_dir, "orientation.gif")
    anim.save(output_path, writer=writer)
    PLT.close()
    print("    PythonVisualization: Orientation image saved as", output_path)
else:
    print("    PythonVisualization: Data shape is not supported!")
    sys.exit(1)
