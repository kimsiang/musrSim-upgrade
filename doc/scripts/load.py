"""load.py -- a small, reusable entry point for musrSim output (tutorial, Chapter 7)."""
import uproot, awkward as ak, numpy as np

DEFAULT_BRANCHES = [
    "det_n", "det_ID", "det_edep", "det_time_start",
    "muDecayTime", "muDecayDetID",
    "muDecayPolX", "muDecayPolY", "muDecayPolZ",
    "posIniMomX", "posIniMomY", "posIniMomZ",
]


def load(path, tree="t1", branches=DEFAULT_BRANCHES):
    """Open a musrSim file and return an awkward record array."""
    return uproot.open(path)[tree].arrays(branches, library="ak")


def counter(data, det_id, field="det_edep"):
    """Flatten one per-hit field for a single detector ID."""
    return ak.flatten(data[field][data.det_ID == det_id])


if __name__ == "__main__":
    import sys
    d = load(sys.argv[1])
    print(d.type, "\n", len(d), "events")
