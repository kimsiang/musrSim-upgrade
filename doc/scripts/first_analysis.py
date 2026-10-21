"""first_analysis.py -- energy spectrum and muon lifetime from first_sim.mac (tutorial, Chapter 7).

Usage:  python first_analysis.py [data/musrSim_jp000.root]
"""
import sys
import uproot, awkward as ak, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

path = sys.argv[1] if len(sys.argv) > 1 else "data/musrSim_jp000.root"
t = uproot.open(path)["t1"]                        # the tree is always called t1
print(t.num_entries, "events,", len(t.keys()), "branches")
data = t.arrays(["det_n", "det_ID", "det_edep", "det_time_start",
                 "muDecayTime", "muDecayDetID"], library="ak")

# ---- (1) energy spectra: mask on det_ID first, then flatten ----
all_edep = ak.flatten(data.det_edep)
mask = data.det_ID == 1                            # the slab has volumeID 1
edep_slab = ak.flatten(data.det_edep[mask])

fig, ax = plt.subplots(figsize=(6, 4))
ax.hist(np.asarray(all_edep), bins=100, range=(0, 15), histtype="step", label="all hits")
ax.hist(np.asarray(edep_slab), bins=100, range=(0, 15), histtype="step", ls="--", label="det_ID == 1")
ax.set_xlabel("Energy deposit [MeV]")
ax.set_ylabel("Hits / bin")
ax.legend()
fig.tight_layout()
fig.savefig("edep_spectrum.png", dpi=150)

# ---- (2) muon lifetime: event-level scalar, cut the sentinel ----
t_us = np.asarray(data.muDecayTime)
good = np.asarray((data.muDecayDetID == 1) & (data.muDecayTime > 0))
t_us = t_us[good]

counts, edges = np.histogram(t_us, bins=100, range=(0, 15))
centres = 0.5 * (edges[:-1] + edges[1:])

def decay(t, N0, tau, bkg):
    return N0 * np.exp(-t / tau) + bkg

popt, pcov = curve_fit(decay, centres, counts, p0=[counts.max(), 2.2, 1.0],
                       sigma=np.sqrt(counts + 1), absolute_sigma=True)
tau, dtau = popt[1], np.sqrt(pcov[1, 1])
print(f"tau = {tau:.4f} +/- {dtau:.4f} us   (PDG: 2.1970 us)")

fig, ax = plt.subplots(figsize=(6, 4))
ax.errorbar(centres, counts, yerr=np.sqrt(counts + 1), fmt=".", label="simulated")
ax.plot(centres, decay(centres, *popt), "-", label=rf"fit $\tau$ = {tau:.3f} $\mu$s")
ax.set_yscale("log")
ax.set_xlabel(r"Decay time [$\mu$s]")
ax.set_ylabel("Muons / bin")
ax.legend()
fig.tight_layout()
fig.savefig("lifetime.png", dpi=150)
