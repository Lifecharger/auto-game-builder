"""Counter-zoom stabiliser for short generated clips (Grok i2v "camera pushes in").

Estimates the apparent camera motion (scale + translation) of every frame against frame 0 from
BACKGROUND features, smooths it over time, then crops/rescales every frame so the camera looks
locked. The output framing is the tightest one (the maximum-zoom frame, mapped back into every
other frame), same aspect ratio as the source, written at source resolution.

How the motion is measured
  * ORB features (AKAZE fallback) on each consecutive pair, with the subject roughly masked out
    (face detector -> body column below it; without a face, a central column), robust RANSAC
    similarity fit, then a least-squares scale+translation refit on the inliers (no rotation).
  * The chained transform is refined directly against frame 0 (warp frame i into frame-0
    coordinates, fit the residual) so chaining drift does not build up.
  * log(scale), tx, ty are Gaussian-smoothed over time.

A subject who walks toward the camera grows while the background does not: the background scale
stays ~1.0 but the face grows. `measure` prints both so such clips can be told apart; the
counter-zoom cannot fix them. Nor can it fix a camera that dollies/orbits with strong parallax
(foreground and far background move differently): judge the fixed clip by eye (QA sheet).

Usage
  python counter_zoom.py measure <in.mp4> [--face-model yunet.onnx] [--json out.json]
  python counter_zoom.py fix <in.mp4> <out.mp4> [--face-model yunet.onnx] [--sigma 3]
                         [--min-height 720] [--crf 16] [--json out.json]

Face model: optional OpenCV YuNet .onnx (face_detection_yunet). Without it the Haar cascade that
ships with OpenCV is used. Needs opencv-python, numpy and ffmpeg on PATH.
"""
import argparse
import json
import math
import os
import subprocess
import sys

import cv2
import numpy as np

# ----------------------------------------------------------------------------------- video io


def read_frames(path):
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        raise SystemExit("cannot open %s" % path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    frames = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        frames.append(f)
    cap.release()
    if len(frames) < 2:
        raise SystemExit("%s: fewer than 2 frames" % path)
    return frames, fps


def write_video(frames, fps, out, src, crf):
    h, w = frames[0].shape[:2]
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    cmd = ["ffmpeg", "-y", "-v", "error",
           "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", "%dx%d" % (w, h), "-r", "%g" % fps, "-i", "-",
           "-i", src, "-map", "0:v:0", "-map", "1:a:0?", "-c:a", "copy",
           "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p",
           "-movflags", "+faststart", out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for f in frames:
        p.stdin.write(np.ascontiguousarray(f).tobytes())
    p.stdin.close()
    if p.wait() != 0:
        raise SystemExit("ffmpeg failed writing %s" % out)


# ------------------------------------------------------------------------------ face detector


class Faces:
    def __init__(self, model=None):
        self.yunet = None
        if model:
            if not os.path.isfile(model):
                raise SystemExit("face model not found: %s" % model)
            self.yunet = cv2.FaceDetectorYN.create(model, "", (320, 320), 0.6, 0.3, 5000)
        else:
            self.haar = cv2.CascadeClassifier(os.path.join(cv2.data.haarcascades,
                                                           "haarcascade_frontalface_default.xml"))

    def largest(self, img):
        """(x, y, w, h) of the largest face or None."""
        h, w = img.shape[:2]
        if self.yunet is not None:
            self.yunet.setInputSize((w, h))
            _, det = self.yunet.detect(img)
            if det is None or not len(det):
                return None
            d = max(det, key=lambda r: r[2] * r[3])
            return tuple(float(v) for v in d[:4])
        g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        det = self.haar.detectMultiScale(g, 1.1, 5, minSize=(max(24, w // 25),) * 2)
        if not len(det):
            return None
        d = max(det, key=lambda r: r[2] * r[3])
        return tuple(float(v) for v in d)


# ---------------------------------------------------------------------------- motion estimate


def subject_mask(img, face):
    """255 = usable background, 0 = the (rough) subject."""
    # widest body column that still leaves >= 30 % of the frame as background; in close-ups
    # the column narrows down to the head only and RANSAC rejects the rest of her
    h, w = img.shape[:2]
    if face:
        x, y, fw, fh = face
        cx = x + fw / 2
        top = max(0, int(y - fh * 0.6))
        for mult in (1.6, 1.1, 0.75, None):
            m = np.full((h, w), 255, np.uint8)
            if mult is None:
                cv2.rectangle(m, (int(x - fw * 0.25), top), (int(x + fw * 1.25), int(y + fh * 1.3)), 0, -1)
            else:
                half = fw * mult
                cv2.rectangle(m, (int(cx - half), top), (int(cx + half), h), 0, -1)
            if (m > 0).mean() >= 0.3:
                break
        return m
    m = np.full((h, w), 255, np.uint8)
    cv2.rectangle(m, (int(w * 0.3), int(h * 0.1)), (int(w * 0.7), h), 0, -1)
    return m


class Matcher:
    def __init__(self):
        # ORB first; AKAZE (binary) or SIFT as fallback, whichever this OpenCV build ships
        self.dets = [(cv2.ORB_create(3000, 1.2, 8, 15), cv2.NORM_HAMMING)]
        if hasattr(cv2, "AKAZE_create"):
            self.dets.append((cv2.AKAZE_create(), cv2.NORM_HAMMING))
        elif hasattr(cv2, "SIFT_create"):
            self.dets.append((cv2.SIFT_create(3000), cv2.NORM_L2))

    def pairs(self, a, b, ma, mb):
        """Matched point arrays (pts in a, pts in b)."""
        for det, norm in self.dets:
            self.bf = cv2.BFMatcher(norm)
            ka, da = det.detectAndCompute(a, ma)
            kb, db = det.detectAndCompute(b, mb)
            if da is None or db is None or len(ka) < 12 or len(kb) < 12:
                continue
            good = []
            for m in self.bf.knnMatch(da, db, k=2):
                if len(m) == 2 and m[0].distance < 0.75 * m[1].distance:
                    good.append(m[0])
            if len(good) >= 12:
                pa = np.float32([ka[g.queryIdx].pt for g in good])
                pb = np.float32([kb[g.trainIdx].pt for g in good])
                return pa, pb
        return None, None


def fit_st(src, dst):
    """Robust dst = s*src + t. Returns (s, tx, ty, inliers) or None."""
    if src is None or len(src) < 12:
        return None
    M, inl = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=2.5,
                                         maxIters=4000, confidence=0.995)
    if M is None:
        return None
    inl = inl.ravel().astype(bool)
    if inl.sum() < 10:
        return None
    p, q = src[inl].astype(np.float64), dst[inl].astype(np.float64)
    pm, qm = p.mean(0), q.mean(0)
    den = ((p - pm) ** 2).sum()
    if den <= 1e-6:
        return None
    s = float(((p - pm) * (q - qm)).sum() / den)
    t = qm - s * pm
    return s, float(t[0]), float(t[1]), int(inl.sum())


_CLAHE = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))


def gray(img, scale):
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    if scale != 1.0:
        g = cv2.resize(g, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    return _CLAHE.apply(g)     # lifts texture in dark club/night scenes


def lk_pairs(a, b, ma):
    """Shi-Tomasi corners in a (background mask) tracked into b with forward-backward check."""
    pa = cv2.goodFeaturesToTrack(a, 1200, 0.003, 6, mask=ma)
    if pa is None or len(pa) < 12:
        return None, None
    lk = dict(winSize=(21, 21), maxLevel=4,
              criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 30, 0.01))
    pb, st, _ = cv2.calcOpticalFlowPyrLK(a, b, pa, None, **lk)
    pr, st2, _ = cv2.calcOpticalFlowPyrLK(b, a, pb, None, **lk)
    ok = (st.ravel() == 1) & (st2.ravel() == 1) & (np.linalg.norm((pa - pr).reshape(-1, 2), axis=1) < 0.7)
    if ok.sum() < 12:
        return None, None
    return pa.reshape(-1, 2)[ok], pb.reshape(-1, 2)[ok]


def estimate(frames, faces, sigma):
    """Per frame i: (S_i, Tx_i, Ty_i) with p0 = S_i * p_i + T_i (frame-i pixel -> frame-0 pixel)."""
    h, w = frames[0].shape[:2]
    ds = 540.0 / max(h, w) if max(h, w) > 540 else 1.0     # work at ~540 px for speed
    mt = Matcher()
    n = len(frames)
    g = [gray(f, ds) for f in frames]
    face_boxes = [faces.largest(f) for f in frames]
    masks = []
    for f, fb in zip(frames, face_boxes):
        m = subject_mask(f, fb)
        masks.append(cv2.resize(m, (g[0].shape[1], g[0].shape[0]), interpolation=cv2.INTER_NEAREST))
    # consecutive steps (frame i -> frame i-1): LK tracks first, ORB/SIFT matches as fallback;
    # a step that still fails is interpolated from its neighbours (never forced to identity)
    steps = np.full((n, 3), np.nan)
    steps[0] = (1.0, 0.0, 0.0)
    fails = 0
    for i in range(1, n):
        la, lb = lk_pairs(g[i], g[i - 1], masks[i])
        oa, ob = mt.pairs(g[i], g[i - 1], masks[i], masks[i - 1])
        sa = [p for p in (la, oa) if p is not None]
        sb = [p for p in (lb, ob) if p is not None]
        r = fit_st(np.vstack(sa), np.vstack(sb)) if sa else None     # one RANSAC over both sets
        if r is None or not 0.8 < r[0] < 1.25:
            fails += 1
            continue
        steps[i] = (r[0], r[1] / ds, r[2] / ds)
    for c in range(3):
        bad = np.isnan(steps[:, c])
        if bad.any():
            idx = np.arange(n)
            steps[bad, c] = np.interp(idx[bad], idx[~bad], steps[~bad, c])
    # kill single-step spikes (a hand sweeping through the background): 5-tap running median
    med = np.array([np.median(steps[max(1, i - 2):i + 3], axis=0) for i in range(n)])
    dev = np.abs(steps - med)
    spike = (dev[:, 0] > 0.006) | (np.hypot(dev[:, 1], dev[:, 2]) > 2.5)
    spike[0] = False
    steps[spike] = med[spike]
    S, T = [1.0], [(0.0, 0.0)]
    for i in range(1, n):
        s, tx, ty = steps[i]
        Sp, (Tx, Ty) = S[-1], T[-1]
        S.append(Sp * s)
        T.append((Sp * tx + Tx, Sp * ty + Ty))
    # drift refinement: warp frame i into frame-0 space with the chained estimate, fit residual
    refined = 0
    for i in range(1, n):
        Si, (Tx, Ty) = S[i], T[i]
        A = np.float32([[Si * 1.0, 0, Tx * ds], [0, Si * 1.0, Ty * ds]])
        wi = cv2.warpAffine(g[i], A, (g[0].shape[1], g[0].shape[0]), flags=cv2.INTER_LINEAR)
        mi = cv2.warpAffine(masks[i], A, (g[0].shape[1], g[0].shape[0]), flags=cv2.INTER_NEAREST)
        pa, pb = mt.pairs(wi, g[0], mi, masks[0])
        r = fit_st(pa, pb)
        if r is None or abs(r[0] - 1) > 0.15:
            continue
        s, tx, ty = r[0], r[1] / ds, r[2] / ds                     # p0 = s*(Si p + T) + t
        S[i] = s * Si
        T[i] = (s * Tx + tx, s * Ty + ty)
        refined += 1
    S = np.array(S)
    T = np.array(T)
    if sigma > 0:
        S = np.exp(smooth(np.log(S), sigma))
        T = np.stack([smooth(T[:, 0], sigma), smooth(T[:, 1], sigma)], 1)
    return S, T, face_boxes, {"pair_failures": fails, "refined": refined}


def smooth(x, sigma):
    r = int(math.ceil(sigma * 3))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    xp = np.pad(x, r, mode="edge")
    return np.convolve(xp, k, mode="valid")


# -------------------------------------------------------------------------------- crop logic


def tight_crop(S, T, w, h):
    """Largest w:h rect in frame-0 coordinates that is visible in EVERY frame."""
    x0 = max(T[:, 0].max(), 0.0)
    y0 = max(T[:, 1].max(), 0.0)
    x1 = min((T[:, 0] + S * w).min(), float(w))
    y1 = min((T[:, 1] + S * h).min(), float(h))
    iw, ih = x1 - x0, y1 - y0
    if iw <= 0 or ih <= 0:
        raise SystemExit("no common area across frames")
    cw = min(iw, ih * w / h)
    ch = cw * h / w
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return cx - cw / 2, cy - ch / 2, cw, ch


def render(frames, S, T, crop, out_w, out_h):
    cx, cy, cw, ch = crop
    k = cw / out_w
    out = []
    for f, s, (tx, ty) in zip(frames, S, T):
        # output (u,v) -> frame0 (cx + k u, cy + k v) -> frame i ((c - T) / s)
        M = np.float64([[k / s, 0, (cx - tx) / s], [0, k / s, (cy - ty) / s]])
        out.append(cv2.warpAffine(f, M, (out_w, out_h), flags=cv2.INTER_LANCZOS4 | cv2.WARP_INVERSE_MAP,
                                  borderMode=cv2.BORDER_REPLICATE))
    return out


def face_growth(face_boxes, n_ref=6):
    hs = [b[3] for b in face_boxes if b]
    if len(hs) < n_ref + 2:
        return None
    ref = float(np.median(hs[:n_ref]))
    return float(max(hs) / ref) if ref > 0 else None


def summarise(S, T, faces_src, crop, w, h, stats):
    zoom = 1.0 / S                                       # apparent zoom of frame i vs frame 0
    imax = int(np.argmax(zoom))
    cx, cy, cw, ch = crop
    fg = face_growth(faces_src)
    bg = float(zoom.max())
    f0 = next((b for b in faces_src[:6] if b), None)
    head_in = None
    if f0:
        x, y, fw, fh = f0
        head_in = bool(x >= cx and x + fw <= cx + cw and y - 0.35 * fh >= cy and y + fh <= cy + ch)
    info = {
        "frames": len(S), "max_zoom": round(bg, 3), "max_zoom_frame": imax,
        "final_zoom": round(float(zoom[-1]), 3),
        "max_shift_px": round(float(np.abs(T).max()), 1),
        "crop_frame0": [round(v, 1) for v in (cx, cy, cw, ch)],
        "crop_keeps_height": round(ch / h, 3),
        "face_growth_src": round(fg, 3) if fg else None,
        "head_in_crop_frame0": head_in, **stats,
    }
    # subject grows much more than the background -> she walks in, counter-zoom cannot fix it
    info["subject_walks_in"] = bool(fg and fg / bg > 1.25)
    return info


def cmd_measure(a):
    frames, fps = read_frames(a.input)
    h, w = frames[0].shape[:2]
    faces = Faces(a.face_model)
    S, T, fb, st = estimate(frames, faces, a.sigma)
    crop = tight_crop(S, T, w, h)
    info = summarise(S, T, fb, crop, w, h, st)
    info.update({"input": a.input, "size": [w, h], "fps": fps})
    report(info, a.json)
    return info


def cmd_fix(a):
    frames, fps = read_frames(a.input)
    h, w = frames[0].shape[:2]
    faces = Faces(a.face_model)
    S, T, fb, st = estimate(frames, faces, a.sigma)
    crop = tight_crop(S, T, w, h)
    info = summarise(S, T, fb, crop, w, h, st)
    out_h = max(h, a.min_height)
    out_h -= out_h % 2
    out_w = int(round(out_h * w / h / 2)) * 2
    fixed = render(frames, S, T, crop, out_w, out_h)
    # residual check on the fixed clip: background scale should now be ~1, head never cut
    S2, T2, fb2, _ = estimate(fixed, faces, 0)
    tops = [b[1] for b in fb2 if b]
    info.update({
        "input": a.input, "output": a.output, "size": [w, h], "out_size": [out_w, out_h], "fps": fps,
        "residual_max_zoom": round(float((1 / S2).max()), 3), "residual_min_zoom": round(float((1 / S2).min()), 3),
        "residual_max_shift_px": round(float(np.abs(T2).max()), 1),
        "face_found_frames": "%d/%d" % (len(tops), len(fixed)),
        "min_head_top_px": round(min(tops), 1) if tops else None,
        "face_growth_fixed": round(face_growth(fb2), 3) if face_growth(fb2) else None,
    })
    write_video(fixed, fps, a.output, a.input, a.crf)
    report(info, a.json)
    return info


def report(info, path):
    print("max scale (apparent zoom) %.3fx at frame %d, end %.3fx; crop keeps %.0f%% of frame height; "
          "head inside crop: %s; subject walks in: %s"
          % (info["max_zoom"], info["max_zoom_frame"], info["final_zoom"], 100 * info["crop_keeps_height"],
             info["head_in_crop_frame0"], info["subject_walks_in"]))
    ok = info["head_in_crop_frame0"] and not info["subject_walks_in"] and info["crop_keeps_height"] >= 0.5
    print("full intended framing kept: %s" % ("YES" if ok else "NO (check by eye)"))
    print(json.dumps(info))
    if path:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("measure", "fix"):
        p = sub.add_parser(name)
        p.add_argument("input")
        if name == "fix":
            p.add_argument("output")
            p.add_argument("--min-height", type=int, default=720)
            p.add_argument("--crf", type=int, default=16)
        p.add_argument("--face-model", default=None, help="optional YuNet .onnx")
        p.add_argument("--sigma", type=float, default=3.0, help="temporal smoothing (frames)")
        p.add_argument("--json", default=None, help="write the result as JSON here")
    a = ap.parse_args()
    (cmd_measure if a.cmd == "measure" else cmd_fix)(a)


if __name__ == "__main__":
    sys.exit(main())
