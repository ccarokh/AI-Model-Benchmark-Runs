# Text-in-image as a measurement instead of a judgement: OCR the generated
# image and compare against the requested string. Best edit distance over all
# windows of comparable length -- that way noise from the sign frame does not
# count.
import subprocess, re, sys

SOLL = "ACHTUNG BEHAELTER"

def lev(a, b):
    m = [[0]*(len(b)+1) for _ in range(len(a)+1)]
    for i in range(len(a)+1): m[i][0] = i
    for j in range(len(b)+1): m[0][j] = j
    for i in range(1, len(a)+1):
        for j in range(1, len(b)+1):
            m[i][j] = min(m[i-1][j]+1, m[i][j-1]+1, m[i-1][j-1] + (a[i-1] != b[j-1]))
    return m[-1][-1]

print("modell\texakt\tbester_abstand\tbestes_fenster")
for m in ("flux", "sdxl"):
    r = subprocess.run(["tesseract", f"{m}_2_deutscher_text.png", "stdout", "-l", "deu", "--psm", "11"],
                       capture_output=True, text=True)
    t = re.sub(r"[^A-ZÄÖÜ ]", " ", " ".join(r.stdout.split()).upper())
    t = " ".join(t.split())
    best = (999, "")
    L = len(SOLL)
    for w in range(max(4, L-6), L+7):
        for i in range(0, max(1, len(t)-w+1)):
            d = lev(SOLL, t[i:i+w])
            if d < best[0]:
                best = (d, t[i:i+w])
    print(f"{m}\t{'ja' if SOLL in t else 'nein'}\t{best[0]}\t{best[1]}")
