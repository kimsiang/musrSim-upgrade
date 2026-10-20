# musrSim-upgrade

Geant4-based simulation of muSR (muon spin rotation) and related muon experiments, with cosmic-ray muon generators (CRY, EcoMug) for muography studies. Built with CMake.

## Requirements

- Geant4 10.x or 11.x (tested with 11.4.3)
- ROOT 6 (tested with 6.40)
- CMake ≥ 3.16 and a C++17 compiler

## Build and run

After unzipping the file (or cloning this repository), go into the folder, then:

```bash
mkdir build
cd build
cmake ../
make -j4
cd run
mkdir data
../musrSim 101.mac
```

The macros and input tables in `run/` are copied to `build/run/` during `cmake`. Output ROOT files are written to `build/run/data/`.

Usage: `../musrSim <steering_file.mac> [output_name | idle] [random_seed_offset]`

## CRY cosmic-ray generator

`CRYExample.mac` needs the CRY data tables (`cosmics_*.data`). They are not included in this repository: copy the `data/` files from the [CRY distribution](https://nuclear.llnl.gov/simulation/) into a `cryData/` folder at the top of the repository, or point to them at run time:

```bash
export CRYDATAPATH=/path/to/cry/data
```

## Field maps

Some macros (e.g. `14510.mac`, `50121.mac`, the `LEM_*.mac` files) read tabulated field-map files that are not included here and must be supplied separately.
