"""Synthesizes the game's sound effects into audio/sfx/*.wav (no samples, no
dependencies). Layered oscillators, filtered noise, FM bells, plucked strings
and a small reverb, so they sound like toys rather than beeps.
Run: python3 tools/make_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "sfx")
random.seed(7)


# --- building blocks ----------------------------------------------------------------

def n_of(dur):
    return int(dur * RATE)


def silence(dur):
    return [0.0] * n_of(dur)


def env_ad(n, attack=0.003, decay_pow=2.0, hold=0.0):
    a = max(1, int(attack * RATE))
    h = int(hold * RATE)
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i < a + h:
            out.append(1.0)
        else:
            t = (i - a - h) / max(1, n - a - h)
            out.append((1.0 - t) ** decay_pow)
    return out


def exp_env(n, tau):
    return [math.exp(-i / (tau * RATE)) for i in range(n)]


def osc(dur, freq, shape="sine", phase=0.0):
    """freq: number or function of t (seconds)."""
    n = n_of(dur)
    out = []
    ph = phase
    for i in range(n):
        f = freq(i / RATE) if callable(freq) else freq
        ph += f / RATE
        x = ph % 1.0
        if shape == "sine":
            out.append(math.sin(2 * math.pi * x))
        elif shape == "tri":
            out.append(4 * abs(x - 0.5) - 1)
        elif shape == "saw":
            out.append(2 * x - 1)
    return out


def fm_bell(dur, freq, ratio=3.5, index=2.5, tau=0.5):
    """Two-operator FM bell with a decaying index."""
    n = n_of(dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / tau)
        mod = math.sin(2 * math.pi * freq * ratio * t) * index * math.exp(-t / (tau * 0.4))
        out.append(math.sin(2 * math.pi * freq * t + mod) * env)
    return out


def noise(dur):
    return [random.uniform(-1, 1) for _ in range(n_of(dur))]


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be a function of t."""
    out = []
    y = 0.0
    for i, v in enumerate(x):
        c = cutoff(i / RATE) if callable(cutoff) else cutoff
        a = 1 - math.exp(-2 * math.pi * c / RATE)
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, center, q=2.0):
    """State-variable band pass; center may be a function of t."""
    out = []
    low = band = 0.0
    for i, v in enumerate(x):
        c = center(i / RATE) if callable(center) else center
        f = 2 * math.sin(math.pi * min(c, RATE / 6) / RATE)
        low += f * band
        high = v - low - band / q
        band += f * high
        out.append(band)
    return out


def pluck(dur, freq, damp=0.996, bright=0.5):
    """Karplus-Strong plucked string."""
    period = max(2, int(RATE / freq))
    buf = [random.uniform(-1, 1) for _ in range(period)]
    buf = lowpass(buf, 2000 + 8000 * bright)
    out = []
    idx = 0
    for _ in range(n_of(dur)):
        v = buf[idx]
        nxt = buf[(idx + 1) % period]
        buf[idx] = damp * 0.5 * (v + nxt)
        out.append(v)
        idx = (idx + 1) % period
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def gain(a, g):
    return [x * g for x in a]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def at(track, start):
    return [0.0] * n_of(start) + track


def reverb(x, wet=0.25, size=1.0, tail=0.8):
    """Small Schroeder reverb (4 combs + 2 allpasses)."""
    extra = n_of(tail)
    dry = x + [0.0] * extra
    combs = [int(d * size) for d in (1557, 1617, 1491, 1422)]
    out = [0.0] * len(dry)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        fb = 0.78
        store = 0.0
        for i, v in enumerate(dry):
            y = buf[idx]
            store = y * 0.7 + store * 0.3
            buf[idx] = v + store * fb
            idx = (idx + 1) % d
            out[i] += y * 0.25
    for d in (225, 556):
        buf = [0.0] * d
        idx = 0
        for i in range(len(out)):
            b = buf[idx]
            y = -out[i] + b
            buf[idx] = out[i] + b * 0.5
            idx = (idx + 1) % d
            out[i] = y
    return [a * (1 - wet) + b * wet for a, b in zip(dry, out)]


def fade_edges(x, fade_in=0.002, fade_out=0.01):
    n = len(x)
    fi = max(1, n_of(fade_in))
    fo = max(1, n_of(fade_out))
    y = list(x)
    for i in range(min(fi, n)):
        y[i] *= i / fi
    for i in range(min(fo, n)):
        y[n - 1 - i] *= i / fo
    return y


def normalize(x, peak_db=-1.0):
    peak = max(1e-6, max(abs(v) for v in x))
    g = (10 ** (peak_db / 20)) / peak
    return [v * g for v in x]


def trim(x, threshold=0.0005):
    end = len(x)
    while end > 1 and abs(x[end - 1]) < threshold:
        end -= 1
    return x[:end]


def write(name, x, peak_db=-1.0, loop=False):
    x = normalize(x, peak_db)
    if not loop:
        x = fade_edges(trim(x))
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32000)) for v in x))
    print("wrote", name, "%.2fs" % (len(x) / RATE))


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


# --- the sounds ------------------------------------------------------------------------

def roll_loop():
    """Seamless 2 s marble-on-candy rumble: low filtered noise with a slow wobble."""
    dur = 2.0
    n = n_of(dur)
    x = noise(dur + 0.3)
    for _ in range(4):                 # steep 24 dB/oct rolloff: rumble, not hiss
        x = lowpass(x, 420)
    x = highpass(x, 60)[-n:]
    body = noise(dur + 0.3)
    for _ in range(3):
        body = lowpass(body, 110)
    body = body[-n:]
    wob = [0.75 + 0.25 * math.sin(2 * math.pi * 3 * i / RATE) for i in range(n)]
    y = mix(mul(x, wob), gain(normalize(body, -6), 0.6 * max(abs(v) for v in x)))
    # Crossfade the ends so the loop has no click.
    cf = n_of(0.15)
    for i in range(cf):
        t = i / cf
        y[i] = y[i] * t + y[n - cf + i] * (1 - t)
    return y[: n - cf]


def land():
    thump = mul(osc(0.35, lambda t: 110 * math.exp(-t * 9) + 45), exp_env(n_of(0.35), 0.09))
    click = mul(lowpass(noise(0.05), 1800), exp_env(n_of(0.05), 0.012))
    return mix(gain(thump, 1.0), gain(click, 0.5))


def bonk():
    body = mul(osc(0.25, 190), exp_env(n_of(0.25), 0.05))
    knock = fm_bell(0.2, 720, ratio=1.41, index=1.6, tau=0.05)
    tick = mul(bandpass(noise(0.03), 2500, 3), exp_env(n_of(0.03), 0.006))
    return mix(gain(body, 0.8), gain(knock, 0.6), gain(tick, 0.4))


def pop():
    """Candy marble cracking: glassy ping down, crunchy noise bursts."""
    ping = mul(osc(0.5, lambda t: 1400 * math.exp(-t * 5) + 300, "tri"), exp_env(n_of(0.5), 0.12))
    crunch = []
    for k in range(5):
        burst = mul(bandpass(noise(0.05), 1800 + 900 * k, 1.5), exp_env(n_of(0.05), 0.012))
        crunch = mix(crunch, at(burst, 0.018 * k + random.uniform(0, 0.01)))
    low = mul(osc(0.2, lambda t: 160 * math.exp(-t * 6)), exp_env(n_of(0.2), 0.05))
    return reverb(mix(gain(ping, 0.5), gain(crunch, 0.9), gain(low, 0.6)), wet=0.18, tail=0.4)


def splat():
    squelch = mul(lowpass(noise(0.45), lambda t: 1600 * math.exp(-t * 7) + 150), env_ad(n_of(0.45), 0.01, 1.5))
    wob = mul(osc(0.45, lambda t: 140 + 40 * math.sin(2 * math.pi * 14 * t)), exp_env(n_of(0.45), 0.12))
    return mix(gain(squelch, 1.3), gain(wob, 0.6))


def boing():
    """Pop bumper: springy FM with pitch wobble."""
    f = lambda t: 300 * (1 + 0.35 * math.sin(2 * math.pi * 22 * t) * math.exp(-t * 6)) + 120 * math.exp(-t * 20)
    n = n_of(0.45)
    tone = mul(osc(0.45, f), exp_env(n, 0.12))
    over = mul(osc(0.45, lambda t: f(t) * 2.01, "tri"), exp_env(n, 0.05))
    thock = mul(lowpass(noise(0.03), 3000), exp_env(n_of(0.03), 0.005))
    return mix(gain(tone, 0.9), gain(over, 0.35), gain(thock, 0.4))


def boost():
    """Speed pad: rising whoosh with a zing on top."""
    dur = 0.5
    air = mul(bandpass(noise(dur), lambda t: 400 + 4200 * (t / dur) ** 1.5, 1.2), env_ad(n_of(dur), 0.03, 1.6))
    zing = mul(osc(dur, lambda t: 500 + 1400 * (t / dur)), env_ad(n_of(dur), 0.01, 3.0))
    return mix(gain(air, 1.2), gain(zing, 0.25))


def chime(notes, spacing, tau=0.6, wet=0.3, ratio=3.5):
    out = []
    for k, m in enumerate(notes):
        b = fm_bell(tau * 3, note(m), ratio=ratio, index=1.8, tau=tau)
        out = mix(out, at(b, k * spacing))
    return reverb(out, wet=wet, tail=0.9)


def goal():
    arp = chime([72, 76, 79, 84], 0.09, tau=0.5)
    sparkle = []
    for k in range(10):
        s = mul(osc(0.12, note(96 + random.choice([0, 4, 7, 12]))), exp_env(n_of(0.12), 0.03))
        sparkle = mix(sparkle, at(gain(s, 0.25), 0.25 + 0.05 * k))
    return mix(arp, reverb(sparkle, 0.4, tail=0.6))


def count_tick():
    return chime([81], 0.0, tau=0.18, wet=0.15, ratio=2.0)


def count_go():
    return mix(chime([84, 88, 91], 0.0, tau=0.35, wet=0.25), gain(boost(), 0.3))


def ui_hover():
    return mul(osc(0.05, 2200), exp_env(n_of(0.05), 0.008))


def ui_click():
    return reverb(mix(gain(pluck(0.25, note(76), 0.994, 0.7), 0.9), gain(mul(osc(0.03, 3000), exp_env(n_of(0.03), 0.004)), 0.3)),
                  wet=0.12, tail=0.2)


def ui_back():
    return reverb(pluck(0.25, note(69), 0.993, 0.5), wet=0.12, tail=0.2)


def ding():
    return chime([88], 0.0, tau=0.3, wet=0.2, ratio=2.76)


def cannon():
    boom = mul(osc(0.7, lambda t: 70 * math.exp(-t * 3) + 35), exp_env(n_of(0.7), 0.18))
    blast = mul(lowpass(noise(0.5), lambda t: 3000 * math.exp(-t * 10) + 200), exp_env(n_of(0.5), 0.1))
    return reverb(mix(gain(boom, 1.0), gain(blast, 0.9)), wet=0.2, tail=0.6)


def rush():
    return mix(chime([72, 76, 79, 84, 88, 91], 0.05, tau=0.25, wet=0.3), gain(boost(), 0.5))


def lose():
    return chime([67, 64, 60], 0.16, tau=0.5, wet=0.3, ratio=2.0)


def goo():
    out = []
    for k in range(6):
        f0 = random.uniform(180, 420)
        b = mul(osc(0.09, lambda t, f0=f0: f0 * (1 + 3 * t)), env_ad(n_of(0.09), 0.005, 2))
        out = mix(out, at(b, k * 0.045 + random.uniform(0, 0.02)))
    return mix(out, gain(splat(), 0.5))


def whoosh():
    dur = 0.35
    return mul(bandpass(noise(dur), lambda t: 2500 - 1800 * (t / dur), 1.0), env_ad(n_of(dur), 0.05, 1.3))


if __name__ == "__main__":
    write("roll", roll_loop(), -3.0, loop=True)
    write("land", land())
    write("bonk", bonk(), -4.0)
    write("pop", pop())
    write("splat", splat())
    write("boing", boing())
    write("boost", boost(), -3.0)
    write("checkpoint", chime([79, 86], 0.1))
    write("goal", goal())
    write("timeup", lose())
    write("tick", count_tick(), -4.0)
    write("go", count_go())
    write("ui_hover", ui_hover(), -12.0)
    write("ui_click", ui_click(), -6.0)
    write("ui_back", ui_back(), -6.0)
    write("coin", ding(), -3.0)
    write("cannon", cannon())
    write("rush", rush())
    write("goo", goo(), -2.0)
    write("whoosh", whoosh(), -4.0)
