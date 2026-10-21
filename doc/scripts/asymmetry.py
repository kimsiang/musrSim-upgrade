"""asymmetry.py -- from a musrSim ROOT file to a Larmor frequency (tutorial, Chapter 9).

Usage:  python asymmetry.py [data/musrSim_jp000_tf.root]
"""
import sys
import uproot, awkward as ak, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

path = sys.argv[1] if len(sys.argv) > 1 else "data/musrSim_jp000_tf.root"
d = uproot.open(path)["t1"].arrays(
    ["det_ID", "muDecayTime", "muDecayDetID"], library="ak")

# keep muons that stopped and decayed in the sample (volumeID 5); cut sentinels
sel = (d.muDecayDetID == 5) & (d.muDecayTime > 0)
d = d[sel]
t = np.asarray(d.muDecayTime)                      # microseconds

# per event: did the up (+y) or down (-y) counter register a hit?
hitU = np.asarray(ak.any(d.det_ID == 11, axis=1))
hitD = np.asarray(ak.any(d.det_ID == 1, axis=1))
both = hitU & hitD                                 # ambiguous: drop
hitU, hitD = hitU & ~both, hitD & ~both

bins = np.linspace(0, 10, 201)
NU, _ = np.histogram(t[hitU], bins=bins)
ND, _ = np.histogram(t[hitD], bins=bins)
centre = 0.5 * (bins[:-1] + bins[1:])

tot = NU + ND
ok = tot > 20                                      # ignore starved bins at late time
A = (ND[ok] - NU[ok]) / tot[ok]                    # the lifetime cancels in the ratio
Aerr = np.sqrt((1 - A**2) / tot[ok])
tg = centre[ok]

def osc(t, A0, f, phi, lam):                       # damped precession
    return A0 * np.exp(-lam * t) * np.sin(2 * np.pi * f * t + phi)

popt, pcov = curve_fit(osc, tg, A, p0=[0.25, 1.35, 0.0, 0.05],
                       sigma=Aerr, absolute_sigma=True)
f_fit, df = popt[1], np.sqrt(pcov[1, 1])
GAMMA = 135.5388                                   # gamma_mu / 2pi in MHz/T
B_fit = f_fit / GAMMA * 1000                       # mT
print(f"events used: {hitU.sum()} (U) + {hitD.sum()} (D)")
print(f"A0 = {popt[0]:.3f} +/- {np.sqrt(pcov[0, 0]):.3f}")
print(f"f  = {f_fit:.4f} +/- {df:.4f} MHz  ->  B = {B_fit:.3f} +/- {df / GAMMA * 1000:.3f} mT (set: 10.000 mT)")

fig, ax = plt.subplots(figsize=(6.5, 4))
ax.errorbar(tg, A, yerr=Aerr, fmt=".", ms=3, label="simulated asymmetry")
tt = np.linspace(tg.min(), tg.max(), 1000)
ax.plot(tt, osc(tt, *popt), "-", label=rf"fit: $f$ = {f_fit:.3f} MHz")
ax.set_xlabel(r"Decay time [$\mu$s]")
ax.set_ylabel(r"Asymmetry $A(t)$")
ax.legend()
fig.tight_layout()
fig.savefig("asymmetry.png", dpi=150)
