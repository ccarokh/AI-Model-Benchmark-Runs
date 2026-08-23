// Pre-check: does the game run at all?
//
// Answers the question that comes before all others -- and spares a person
// nineteen questions about a game that never even opens. Explicitly NOT a
// quality rating: nothing is judged here, it only establishes whether the
// browser gets the page running at all.
//
//   node vorpruefung.js /path/to/working-directory
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const wurzel = process.argv[2];
const ergebnis = { js_stuecke: 0, syntax_ok: true, syntax_fehler: [] };

function dateien(d) {
  const raus = [];
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) raus.push(...dateien(p));
    else raus.push(p);
  }
  return raus;
}

function skriptbloecke(text, datei) {
  // Real script blocks only: none with src=, no foreign types like
  // application/json or text/template -- those are not JavaScript and would
  // wrongly count as syntax errors here.
  const raus = [];
  const muster = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let m, n = 0;
  while ((m = muster.exec(text))) {
    const attr = m[1] || '';
    if (/\bsrc\s*=/i.test(attr)) continue;
    const typ = /\btype\s*=\s*["']?([^"'\s>]+)/i.exec(attr);
    if (typ && !/^(text\/javascript|module|application\/javascript)$/i.test(typ[1])) continue;
    raus.push([`${datei}#script${++n}`, m[2], /module/i.test(typ ? typ[1] : '')]);
  }
  return raus;
}

const alle = fs.existsSync(wurzel) ? dateien(wurzel) : [];
for (const p of alle) {
  const endung = path.extname(p).toLowerCase();
  const rel = path.relative(wurzel, p);
  let stuecke = [];
  if (endung === '.js') stuecke = [[rel, fs.readFileSync(p, 'utf8'), false]];
  else if (endung === '.mjs') stuecke = [[rel, fs.readFileSync(p, 'utf8'), true]];
  else if (endung === '.html' || endung === '.htm')
    stuecke = skriptbloecke(fs.readFileSync(p, 'utf8'), rel);

  for (const [name, quelle, istModul] of stuecke) {
    if (!quelle.trim()) continue;
    ergebnis.js_stuecke++;
    try {
      if (istModul) new vm.SourceTextModule(quelle, { identifier: name });
      else new vm.Script(quelle, { filename: name });
    } catch (e) {
      ergebnis.syntax_ok = false;
      ergebnis.syntax_fehler.push(`${name}: ${e.message}`.slice(0, 200));
    }
  }
}

console.log(JSON.stringify(ergebnis));
