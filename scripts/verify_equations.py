#!/usr/bin/env python
"""Recover the state equations a circuit actually implements, by regression.

Give it a waveform dump (AnadigmDesigner2 CSV, a scope capture, anything with
time in the first column) and it fits, for every channel,

    dV/dt  =  a few terms from a candidate dictionary

built from all channels: constant, linear, |x|, x^2 and pair products.

Three details matter more than the fitting method:

  * the switched-capacitor output carries a clock-rate ripple, so the channels
    are smoothed before differentiating. Skip this and the derivative is
    dominated by switching artefacts and no coefficient makes sense;
  * if you already know the structure, pass --design: the named terms then
    define the model and the fit is a plain least squares on exactly those
    terms. This is far more reliable than any sparse selection when two
    regressors nearly cancel, which happens whenever an equation contains
    "u - x" and u tracks x;
  * without --design the tool falls back to orthogonal matching pursuit, which
    is fine for discovery but less accurate.

This is the check that matters. A circuit can look chaotic and still implement
the wrong system - verify the equations before believing any dynamics.

Usage
    python verify_equations.py wave.csv
    python verify_equations.py wave.csv --names Vx,Vy,Vz,Vu --skip-ms 8

    # assert against a design. Terms are in the SAME units as the data, i.e.
    # AFTER --scale is applied, and a bare number is a constant term.
    python verify_equations.py wave.csv --names Vx,Vy,Vz,Vu --scale 20 \
        --skip-ms 8 --smooth 21 \
        --design "0.04*Vy" "0.04*Vu-0.04*Vx+0.04*VyVz" \
                 "0.2-0.04*abs(Vy)-0.008*Vz" "0.04*VyVz"

Exit status is 0 when every requested design coefficient is recovered within
--tol (default 20 %).
"""
import argparse
import itertools
import re
import sys

import numpy as np


def load_csv(path):
    raw = np.loadtxt(path, delimiter=",", skiprows=1)
    t = raw[:, 0]
    if t.max() < 1.0:            # AD2 writes seconds
        t = t * 1e6              # -> microseconds
    return t, raw[:, 1:]


def smooth(V, width):
    if width is None or width <= 1:
        return V
    k = np.ones(width) / float(width)
    out = np.column_stack([np.convolve(V[:, j], k, mode="same") for j in range(V.shape[1])])
    return out[width:-width, :]          # drop the contaminated edges


def candidate_terms(V, names):
    cols = [np.ones(len(V))]
    labels = ["1"]
    for i, n in enumerate(names):
        cols.append(V[:, i]);          labels.append(n)
        cols.append(np.abs(V[:, i]));  labels.append("abs(" + n + ")")
        cols.append(V[:, i] ** 2);     labels.append(n + "^2")
    for i, j in itertools.combinations(range(len(names)), 2):
        cols.append(V[:, i] * V[:, j]); labels.append(names[i] + names[j])
    return np.column_stack(cols), labels


def omp(A, target, max_terms):
    """Orthogonal matching pursuit: pick terms greedily, refit each round."""
    An = A / (np.linalg.norm(A, axis=0) + 1e-30)
    chosen = []
    residual = target - target.mean()
    for _ in range(max_terms):
        corr = np.abs(An.T @ residual)
        for c in chosen:
            corr[c] = -1.0
        j = int(np.argmax(corr))
        if corr[j] <= 0:
            break
        chosen.append(j)
        coef, *_ = np.linalg.lstsq(A[:, chosen], target, rcond=None)
        residual = target - A[:, chosen] @ coef
        if np.linalg.norm(residual) < 1e-9 * (np.linalg.norm(target) + 1e-30):
            break
    coef, *_ = np.linalg.lstsq(A[:, chosen], target, rcond=None)
    return chosen, coef


def fit_channel(t, V, names, k, max_terms, forced=None):
    d = np.gradient(V[:, k], t)
    A, labels = candidate_terms(V, names)
    if forced:
        chosen = []
        for lab in forced:
            if lab in labels:
                chosen.append(labels.index(lab))
            else:
                print("  WARNING: term '%s' is not in the dictionary - skipped" % lab)
        if not chosen:
            return [], float("nan")
        coef, *_ = np.linalg.lstsq(A[:, chosen], d, rcond=None)
    else:
        chosen, coef = omp(A, d, max_terms)
    pairs = sorted(zip([labels[c] for c in chosen], coef), key=lambda kv: -abs(kv[1]))
    pred = A[:, chosen] @ coef
    r2 = 1.0 - ((d - pred) ** 2).sum() / (((d - d.mean()) ** 2).sum() + 1e-30)
    return pairs, r2


def parse_design(spec):
    """'0.04*Vu-0.04*Vx+0.04*VyVz' -> [(0.04,'Vu'), (-0.04,'Vx'), (0.04,'VyVz')].

    A bare number is a constant term and gets the label '1', which is how the
    candidate dictionary names the constant regressor.
    """
    out = []
    for term in re.findall(r'[+-]?[^+-]+', spec.replace(' ', '')):
        if not term:
            continue
        if '*' in term:
            c, lab = term.split('*', 1)
            c = 1.0 if c in ('', '+') else (-1.0 if c == '-' else float(c))
            out.append((c, lab))
        else:
            out.append((float(term), '1'))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--names", default=None, help="comma separated channel names")
    ap.add_argument("--skip-ms", type=float, default=0.0,
                    help="drop this much of the start (startup transient)")
    ap.add_argument("--scale", type=float, default=1.0,
                    help="multiply the channels, e.g. the voltage scaling S")
    ap.add_argument("--smooth", type=int, default=21,
                    help="moving-average width before differentiating (0 = off)")
    ap.add_argument("--max-terms", type=int, default=4,
                    help="terms per equation when --design is not given")
    ap.add_argument("--design", nargs="*", default=[],
                    help="expected equation per channel, in the SAME units as the data")
    ap.add_argument("--tol", type=float, default=0.20)
    a = ap.parse_args()

    t, V = load_csv(a.csv)
    if a.skip_ms > 0:
        m = t >= t[0] + a.skip_ms * 1000.0
        t, V = t[m], V[m]
    W = a.smooth
    if W and W > 1 and len(t) > 4 * W:
        V = smooth(V, W)
        t = t[W:-W]
    t = t - t[0]
    V = V * a.scale
    names = a.names.split(",") if a.names else ["V%d" % (i + 1) for i in range(V.shape[1])]
    print("file      :", a.csv)
    print("samples   : %d   t = %.1f .. %.1f us   dt = %.4f us   smooth = %d"
          % (len(t), t[0], t[-1], t[1] - t[0], a.smooth))
    print("channels  :", ", ".join(names), "  (scale %.3g applied)" % a.scale)
    print()

    forced = None
    if a.design:
        if len(a.design) == len(names):
            forced = [[lab for _, lab in parse_design(s)] for s in a.design]
            print("model     : terms taken from --design (least squares on those terms)")
        else:
            print("WARNING   : --design needs one string per channel; falling back to pursuit")
        print()

    recovered = {}
    for k, n in enumerate(names):
        pairs, r2 = fit_channel(t, V, names, k, a.max_terms,
                                forced[k] if forced else None)
        recovered[n] = dict(pairs)
        print("d%s/dt =  %s      (R2 = %.4f)"
              % (n, " ".join("%+.4f*%s" % (c, lab) for lab, c in pairs), r2))
    print()

    if a.design and forced:
        ok = True
        for spec, chan in zip(a.design, names):
            got = recovered[chan]
            for coef, term in parse_design(spec):
                have = got.get(term, 0.0)
                good = abs(have - coef) <= a.tol * abs(coef) if coef else abs(have) < 1e-12
                print("  %-3s %-9s want %+.4f  got %+.4f   %s"
                      % (chan, term, coef, have, "ok" if good else "MISMATCH"))
                ok = ok and good
        print()
        print("VERDICT:", "equations recovered as designed" if ok else "MISMATCH")
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

