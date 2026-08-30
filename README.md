# GriddingMachineDatasets

GriddingMachineDatasets contains the data-production workflow used to convert heterogeneous source products into the standardized NetCDF products consumed by GriddingMachine.jl.

The manuscript code freeze is available at:

- branch: `paper-release`
- tag: `griddingmachine-datasets-paper-2026-v1`
- commit: `b2d25b0544dca462168c7421d2c40dbbba652bce`

## Production contract

The paper-release workflow separates source-specific information from shared processing logic through a versioned YAML schema.

The current contract includes:

- `SCHEMA_VERSION = 1`;
- file and folder definitions;
- source variable names and units;
- explicit source-dimension semantics through `DIMENSIONS`;
- latitude/longitude orientation changes;
- numerical scaling and valid ranges;
- configurable Gapfill policies;
- standardized output metadata and GriddingMachine labels.

The configuration builder and the production pipeline use the same validation schema so that generated configurations and executable configurations follow the same field semantics.

## Standardization workflow

At a high level, a dataset contribution follows:

1. prepare or adapt the source files;
2. describe source structure and transformations in YAML;
3. validate the configuration;
4. run the shared production pipeline;
5. check dimensions, coordinates, numerical ranges, missing values, and output metadata;
6. publish the standardized NetCDF;
7. build or update the GriddingMachine catalog entry.

Source-specific preprocessing is still appropriate for irregular grids, regional projections, or source structures that cannot be represented by the shared regular-grid contract alone.

## Minimal Julia example

```julia
using GriddingMachineDatasets

cfg = load_and_validate_config("dataset.yml")
process_dataset!(cfg)
```

See the repository tests and versioned contribution materials for concrete 2-D and 3-D examples.

## Dimension mapping

The paper-release branch supports explicit source-dimension mapping. For example, a source variable stored as

```text
(lat, lon)
```

or

```text
(ind, lat, lon)
```

can be mapped to the GriddingMachine standard order

```text
(lon, lat)
(lon, lat, ind)
```

before the remaining coordinate and numerical transformations are applied.

## Catalog integrity metadata

`build_catalog_entry` can compute file size and SHA-256 from an authoritative standardized file when registering a new catalog entry. These fields support strict integrity verification in the corresponding GriddingMachine.jl acquisition path.

This does **not** mean that every historical GriddingMachine catalog entry has already been migrated to size/SHA-256 metadata or to multiple mirrors. The manuscript limits strict-integrity and multi-mirror conclusions to the entries and experiments that carry the corresponding metadata and mirror configuration.

## Tests relevant to the manuscript

The paper-release test suite includes deterministic checks for:

- configuration schema validation;
- 2-D and 3-D dimension ordering;
- Gapfill behavior;
- YAML-builder/schema agreement;
- synthetic NetCDF pipeline integration;
- output structure and metadata.

These tests complement the real-data experiments archived in the GriddingMachine research-materials repository.

## Related repositories

- GriddingMachine.jl: https://github.com/CliMA/GriddingMachine.jl
- manuscript and reproducibility materials: https://github.com/jhOo1/GriddingMachine_Reaserach
- Emerald paper interface snapshot: https://github.com/jhOo1/Emerald-paper

## Scope

GriddingMachineDatasets is a production workflow for selected global regular-grid products used by GriddingMachine. It is not intended to replace general geospatial reprojection, cloud-native data-cube, or repository infrastructure.
