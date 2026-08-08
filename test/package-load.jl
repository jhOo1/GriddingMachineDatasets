using GriddingMachineDatasets

@test GriddingMachineDatasets.GRIDDING_MACHINE_HOME == get(
    ENV,
    "GRIDDING_MACHINE_HOME",
    joinpath(homedir(), "GriddingMachine"),
)
@test GriddingMachineDatasets.validate_config(minimal_config()) isa AbstractDict
