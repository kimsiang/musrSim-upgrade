"""make_figures.py -- regenerate the figures used in the tutorial PDF.

Run from build/run after:  ../musrSim first_sim.mac   and   ../musrSim tf_musr.mac
    python ../../doc/scripts/make_figures.py ../../doc/figures
"""
import sys, os
import uproot, awkward as ak, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

out = sys.argv[1] if len(sys.argv) > 1 else "."
NAVY, BLUE, CYAN, GREY = "#051C2C", "#2251FF", "#00A9F4", "#8A97A3"
plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 9, "axes.edgecolor": NAVY,
    "axes.labelcolor": NAVY, "xtick.color": NAVY, "ytick.color": NAVY,
    "axes.spines.top": False, "axes.spines.right": False, "legend.frameon": False,
})

# ---------- first_sim: spectrum + lifetime ----------
d = uproot.open("data/musrSim_jp000.root")["t1"].arrays(
    ["det_ID", "det_edep", "det_time_start", "muDecayTime", "muDecayDetID"], library="ak")
m = d.det_ID == 1
edep = np.asarray(ak.flatten(d.det_edep[m])); tst = np.asarray(ak.flatten(d.det_time_start[m]))
prompt = tst < 0.01                                   # hits within 10 ns of the muon's arrival
print(f"spectrum: {prompt.sum()} prompt hits (mean {edep[prompt].mean():.2f} MeV), {(~prompt).sum()} delayed hits")
fig, ax = plt.subplots(figsize=(5.2, 2.8))
ax.hist(edep[prompt], bins=120, range=(0, 15), histtype="step", color=NAVY, lw=1.1, label="prompt hits (stopping muon)")
ax.hist(edep[~prompt], bins=120, range=(0, 15), histtype="step", color=BLUE, lw=1.1, label="delayed hits (decay positron)")
ax.set_yscale("log"); ax.set_ylim(0.8, 5e4)
ax.set_xlabel("Energy deposit per hit in the slab [MeV]")
ax.set_ylabel("Hits / 0.125 MeV"); ax.legend()
fig.tight_layout(); fig.savefig(os.path.join(out, "edep_spectrum.pdf"))

t = np.asarray(d.muDecayTime)[np.asarray((d.muDecayDetID == 1) & (d.muDecayTime > 0))]
counts, edges = np.histogram(t, bins=100, range=(0, 15))
c = 0.5 * (edges[:-1] + edges[1:])
f = lambda x, N0, tau, b: N0 * np.exp(-x / tau) + b
p, cov = curve_fit(f, c, counts, p0=[counts.max(), 2.2, 1], sigma=np.sqrt(counts + 1), absolute_sigma=True)
print(f"lifetime: tau = {p[1]:.4f} +/- {np.sqrt(cov[1,1]):.4f} us from {len(t)} muons")
fig, ax = plt.subplots(figsize=(5.2, 2.8))
ax.errorbar(c, counts, yerr=np.sqrt(counts + 1), fmt="o", ms=2.2, color=BLUE, elinewidth=0.7, label="simulated (first_sim.mac)")
ax.plot(c, f(c, *p), "-", color=NAVY, lw=1, label=rf"fit: $\tau$ = {p[1]:.3f} $\pm$ {np.sqrt(cov[1,1]):.3f} $\mu$s")
ax.set_yscale("log"); ax.set_xlabel(r"Decay time [$\mu$s]"); ax.set_ylabel("Muons / 0.15 $\\mu$s"); ax.legend()
fig.tight_layout(); fig.savefig(os.path.join(out, "lifetime.pdf"))

# ---------- tf_musr: asymmetry ----------
d = uproot.open("data/musrSim_jp000_tf.root")["t1"].arrays(["det_ID", "muDecayTime", "muDecayDetID"], library="ak")
d = d[(d.muDecayDetID == 5) & (d.muDecayTime > 0)]
t = np.asarray(d.muDecayTime)
U = np.asarray(ak.any(d.det_ID == 11, axis=1)); D = np.asarray(ak.any(d.det_ID == 1, axis=1))
both = U & D; U, D = U & ~both, D & ~both
bins = np.linspace(0, 10, 201)
NU, _ = np.histogram(t[U], bins=bins); ND, _ = np.histogram(t[D], bins=bins)
c = 0.5 * (bins[:-1] + bins[1:]); tot = NU + ND; ok = tot > 20
A = (ND[ok] - NU[ok]) / tot[ok]; Ae = np.sqrt((1 - A**2) / tot[ok]); tg = c[ok]
osc = lambda x, A0, fr, ph, lam: A0 * np.exp(-lam * x) * np.sin(2 * np.pi * fr * x + ph)
p, cov = curve_fit(osc, tg, A, p0=[0.25, 1.35, 0, 0.05], sigma=Ae, absolute_sigma=True)
fr, dfr = p[1], np.sqrt(cov[1, 1])
print(f"asymmetry: A0 = {p[0]:.3f}, f = {fr:.4f} +/- {dfr:.4f} MHz, B = {fr/135.5388*1000:.3f} +/- {dfr/135.5388*1000:.3f} mT, N = {U.sum()}+{D.sum()}")
fig, ax = plt.subplots(figsize=(5.6, 2.9))
ax.errorbar(tg, A, yerr=Ae, fmt="o", ms=2, color=BLUE, elinewidth=0.6, label="simulated asymmetry")
tt = np.linspace(tg.min(), tg.max(), 1500)
ax.plot(tt, osc(tt, *p), "-", color=NAVY, lw=0.9, label=rf"fit: $f$ = {fr:.4f} $\pm$ {dfr:.4f} MHz")
ax.axhline(0, color=GREY, lw=0.5)
ax.set_xlabel(r"Decay time [$\mu$s]"); ax.set_ylabel(r"$A(t)$"); ax.legend(loc="upper center", ncol=2, bbox_to_anchor=(0.5, 1.13))
ax.set_ylim(-0.8, 0.8)
fig.tight_layout(); fig.savefig(os.path.join(out, "asymmetry.pdf"))
