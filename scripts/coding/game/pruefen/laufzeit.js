// Runtime check: open the page in a headless browser and log what goes wrong.
//
// Answers "does it run at all" and nothing else. Whether the dog is a dog
// still gets decided by a person -- but a game that throws on load or cannot
// find its own files need not be put in front of them in the first place.
//
//   node laufzeit.js /work /output/image.png
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
  const wurzel = process.argv[2];
  const bild = process.argv[3];
  const index = path.join(wurzel, 'index.html');
  const ergebnis = {
    geoeffnet: false, laufzeit_fehler: [], konsole_fehler: [],
    fehlende_dateien: [], canvas_bemalt: null, bild: null,
  };
  if (!fs.existsSync(index)) {
    console.log(JSON.stringify(ergebnis));
    return;
  }

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const seite = await browser.newPage({ viewport: { width: 1000, height: 520 } });

  seite.on('pageerror', e => ergebnis.laufzeit_fehler.push(String(e.message).slice(0, 200)));
  seite.on('console', m => {
    if (m.type() === 'error') ergebnis.konsole_fehler.push(m.text().slice(0, 200));
  });
  seite.on('requestfailed', r => ergebnis.fehlende_dateien.push(path.basename(r.url()).slice(0, 80)));
  seite.on('response', r => {
    if (r.status() >= 400) ergebnis.fehlende_dateien.push(`${path.basename(r.url())} (${r.status()})`);
  });

  try {
    await seite.goto('file://' + index, { waitUntil: 'load', timeout: 20000 });
    ergebnis.geoeffnet = true;
    // A game needs a few frames before it can be judged running. Two seconds
    // are enough for the first movement.
    await seite.waitForTimeout(2000);
    // Press keys so a start screen moves on too: many games only draw after
    // the first input.
    for (const t of ['Space', 'Enter']) { await seite.keyboard.press(t).catch(() => {}); }
    await seite.waitForTimeout(1500);

    // Does the game paint anything at all? An empty canvas is a signal a
    // person would otherwise only get by looking.
    ergebnis.canvas_bemalt = await seite.evaluate(() => {
      const c = document.querySelector('canvas');
      if (!c) return null;
      const g = c.getContext('2d');
      if (!g) return null;
      const d = g.getImageData(0, 0, c.width, c.height).data;
      const erste = [d[0], d[1], d[2], d[3]].join(',');
      for (let i = 4; i < d.length; i += 4) {
        if ([d[i], d[i+1], d[i+2], d[i+3]].join(',') !== erste) return true;
      }
      return false;
    });

    if (bild) { await seite.screenshot({ path: bild }); ergebnis.bild = path.basename(bild); }
  } catch (e) {
    ergebnis.laufzeit_fehler.push('Laden: ' + String(e.message).slice(0, 200));
  }
  await browser.close();
  console.log(JSON.stringify(ergebnis));
})();
