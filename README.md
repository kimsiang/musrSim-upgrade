# musrSim-upgrade

Geant4-based simulation of muSR (muon spin rotation) and related muon experiments, built with CMake.

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
