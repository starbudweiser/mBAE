// mBAE — maquette web : lit la liste des fichiers d'une vraie archive BSA / BA2
// (portage de BethesdaArchive dans macos/Sources/BAECore/Archive.swift). L'extraction est simulée.

import { L, setLang, getLang, systemLang } from './i18n.js';

// Langue : celle du navigateur (comme la langue du Mac dans l'appli), ou ?lang=en|fr|it|es ; anglais sinon.
setLang(new URLSearchParams(location.search).get('lang') || systemLang());
document.documentElement.lang = getLang();

const MAX_ROWS = 2500;
const LOCALES = { fr: 'fr-FR', en: 'en-US', it: 'it-IT', es: 'es-ES' };
const UNIT = { fr: 'Ko', en: 'KB', it: 'KB', es: 'KB' };
const fmtInt = (n) => n.toLocaleString(LOCALES[getLang()]);
const $ = (id) => document.getElementById(id);

const app = $('app');
const drop = $('drop');
const tableWrap = $('tableWrap');
const rows = $('rows');
const info = $('info');
const status = $('status');
const btnOpen = $('btnOpen');
const btnExtract = $('btnExtract');
const fileInput = $('fileInput');

let archive = null;
let sort = { key: null, dir: 1 };
let selected = -1;

// ==============================================================================
// MOTEUR BSA / BA2
// ==============================================================================

const latin1 = new TextDecoder('latin1');
const utf8 = new TextDecoder('utf-8');

async function readArchive(file) {
  const head = new DataView(await file.slice(0, 24).arrayBuffer());
  const magic = latin1.decode(new Uint8Array(head.buffer, 0, 4));
  if (magic === 'BSA\0') return { type: 'BSA', files: await parseBsa(file, head) };
  if (magic === 'BTDX') return { type: 'BA2', files: await parseBa2(file, head) };
  throw new Error(L("Archive non reconnue. Vérifiez qu'il s'agit bien d'un fichier .BSA ou .BA2."));
}

async function parseBsa(file) {
  const h = new DataView(await file.slice(0, 36).arrayBuffer());
  const version = h.getUint32(4, true);
  const flags = h.getUint32(12, true);
  const folderCount = h.getUint32(16, true);
  const fileCount = h.getUint32(20, true);
  const fileNamesLen = h.getUint32(28, true);
  const hasDirNames = !!(flags & 0x1);
  const hasFileNames = !!(flags & 0x2);
  const defaultCompressed = !!(flags & 0x100);
  const recSize = version >= 105 ? 24 : 16;

  // Borne haute de l'index : en-têtes + noms de dossiers + records + table des noms
  const indexLen = 36 + folderCount * (recSize + 256) + fileCount * 16 + fileNamesLen;
  const buf = await file.slice(0, Math.min(file.size, indexLen)).arrayBuffer();
  const v = new DataView(buf);
  const bytes = new Uint8Array(buf);
  let p = 36;

  const counts = [];
  for (let i = 0; i < folderCount; i++) {
    counts.push(v.getUint32(p + 8, true));
    p += recSize;
  }

  const folders = [];
  for (const count of counts) {
    let name = '';
    if (hasDirNames) {
      const len = v.getUint8(p++);
      const raw = bytes.subarray(p, p + len);
      const end = raw.indexOf(0);
      name = latin1.decode(end >= 0 ? raw.subarray(0, end) : raw).replaceAll('\\', '/');
      p += len;
    }
    const entries = [];
    for (let j = 0; j < count; j++) {
      const raw = v.getUint32(p + 8, true);
      let compressed = defaultCompressed;
      if (raw & (1 << 30)) compressed = !defaultCompressed;
      entries.push({ size: raw & ~(1 << 30), compressed, hash: v.getBigUint64(p, true) });
      p += 16;
    }
    folders.push({ name, entries });
  }

  let names = [];
  if (hasFileNames && fileNamesLen > 0) {
    names = latin1.decode(bytes.subarray(p, p + fileNamesLen)).split('\0').map((n) => n.trim());
  }

  const files = [];
  let k = 0;
  for (const fd of folders) {
    const prefix = fd.name.replace(/^\/+|\/+$/g, '');
    for (const e of fd.entries) {
      const fname = names[k] || `file_${e.hash.toString(16).padStart(16, '0')}.dat`;
      k++;
      const full = prefix ? `${prefix}/${fname}` : fname;
      if (full && !full.endsWith('/')) files.push({ name: full, size: e.size, compressed: e.compressed });
    }
  }
  return files;
}

async function parseBa2(file, h) {
  const kind = latin1.decode(new Uint8Array(h.buffer, 8, 4));
  const count = h.getUint32(12, true);
  const nameTable = Number(h.getBigUint64(16, true));
  const recSize = kind === 'DX10' ? 68 : 36;
  if (kind !== 'GNRL' && kind !== 'DX10') throw new Error(L('Type de BA2 non pris en charge : {kind}.', { kind }));

  const recs = new DataView(await file.slice(24, 24 + count * recSize).arrayBuffer());
  const meta = [];
  for (let i = 0; i < count; i++) {
    const o = i * recSize;
    const packed = recs.getUint32(o + 8, true);
    const real = recs.getUint32(o + 12, true);
    meta.push({ size: real, compressed: packed > 0 });
  }

  const nb = await file.slice(nameTable).arrayBuffer();
  const nv = new DataView(nb);
  let p = 0;
  const files = [];
  for (const m of meta) {
    if (p + 2 > nb.byteLength) break;
    const len = nv.getUint16(p, true);
    const name = utf8.decode(new Uint8Array(nb, p + 2, len)).replaceAll('\\', '/').replace(/^\/+|\/+$/g, '');
    p += 2 + len;
    if (name && !name.endsWith('/')) files.push({ name, ...m });
  }
  return files;
}

// ==============================================================================
// DÉMO
// ==============================================================================

function demoArchive() {
  const dirs = {
    'textures/armor/dragonplate': ['cuirass.dds', 'cuirass_n.dds', 'gauntlets.dds', 'gauntlets_n.dds', 'helmet.dds', 'helmet_n.dds', 'boots.dds'],
    'textures/landscape/mountains': ['mountainslab01.dds', 'mountainslab01_n.dds', 'mountainslab02.dds', 'snow01.dds', 'snow01_n.dds'],
    'meshes/armor/dragonplate': ['cuirass_0.nif', 'cuirass_1.nif', 'helmet_0.nif', 'helmet_1.nif', 'gauntlets_0.nif'],
    'meshes/actors/dragon': ['skeleton.nif', 'dragon.nif', 'dragonhead.nif'],
    'scripts': ['dragonactorscript.pex', 'mqkilldragonscript.pex', 'wiwerewolfscript.pex'],
    'sound/fx/npc/dragon': ['npc_dragon_roar_01.xwm', 'npc_dragon_roar_02.xwm', 'npc_dragon_wingflap_01.xwm'],
    'interface': ['bethesdanetlogin.swf', 'map.swf', 'quest_journal.swf'],
  };
  let seed = 7;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  const files = [];
  for (const [d, list] of Object.entries(dirs)) {
    for (const f of list) {
      const big = f.endsWith('.dds') || f.endsWith('.xwm');
      files.push({ name: `${d}/${f}`, size: Math.round((big ? 400000 : 20000) * (0.3 + rnd() * 3)), compressed: !f.endsWith('.xwm') });
    }
  }
  return { type: 'BSA', name: L('Skyrim - Démo.bsa'), files };
}

// ==============================================================================
// INTERFACE
// ==============================================================================

const fmtSize = (b) => `${(b / 1024).toLocaleString(LOCALES[getLang()], { minimumFractionDigits: 1, maximumFractionDigits: 1 })} ${UNIT[getLang()]}`;
const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function setStatus(text, tone) {
  status.textContent = text;
  status.className = `sc-badge sc-badge--dot${tone ? ` sc-badge--${tone}` : ''}`;
}

function setProgress(pct) {
  $('progressChunk').style.width = `${pct}%`;
  $('progressLabel').textContent = `${pct} %`;
  $('progress').setAttribute('aria-valuenow', pct);
}

function render() {
  const list = archive.files.slice(0, MAX_ROWS);
  if (sort.key) {
    list.sort((a, b) => {
      const x = a[sort.key], y = b[sort.key];
      return (typeof x === 'string' ? x.localeCompare(y) : x - y) * sort.dir;
    });
  }
  let html = list.map((f, i) => {
    const slash = f.name.lastIndexOf('/');
    const path = slash >= 0 ? `<span>${esc(f.name.slice(0, slash + 1))}</span>${esc(f.name.slice(slash + 1))}` : esc(f.name);
    const badge = f.compressed
      ? `<span class="sc-badge sc-badge--accent">${esc(L('Compressé'))}</span>`
      : `<span class="sc-badge">${esc(L('Brut'))}</span>`;
    return `<tr data-i="${i}"${i === selected ? ' class="is-selected"' : ''}><td class="path" title="${esc(f.name)}">${path}</td><td class="num">${fmtSize(f.size)}</td><td>${badge}</td></tr>`;
  }).join('');
  if (archive.files.length > MAX_ROWS) {
    html += `<tr class="more"><td colspan="3">${esc(L('{n} fichiers supplémentaires non affichés. Ils seront tous extraits.', { n: fmtInt(archive.files.length - MAX_ROWS) }))}</td></tr>`;
  }
  rows.innerHTML = html;
  document.querySelectorAll('.files th').forEach((th) => {
    if (th.dataset.sort === sort.key) th.setAttribute('aria-sort', sort.dir > 0 ? 'ascending' : 'descending');
    else th.removeAttribute('aria-sort');
  });
}

function show(a) {
  archive = a;
  selected = -1;
  sort = { key: null, dir: 1 };
  info.innerHTML = L('{name} — {type} ({n} fichiers)', { name: `<b>${esc(a.name)}</b>`, type: a.type, n: fmtInt(a.files.length) });
  drop.hidden = true;
  tableWrap.hidden = false;
  tableWrap.scrollTop = 0;
  render();
  setProgress(0);
  setStatus(L("Prêt pour l'extraction. Aucun fichier d'origine n'est modifié."), 'accent');
  btnExtract.disabled = a.files.length === 0;
}

async function load(file) {
  if (!/\.(bsa|ba2)$/i.test(file.name)) {
    setStatus(L('Impossible d\'ouvrir {name}. Choisissez un fichier .BSA ou .BA2.', { name: file.name }), 'danger');
    return;
  }
  setStatus(L('Lecture de l\'archive…'));
  try {
    const a = await readArchive(file);
    show({ ...a, name: file.name });
  } catch (e) {
    setStatus(L('Impossible de lire l\'archive. {err}', { err: e.message }), 'danger');
  }
}

function extract() {
  if (!archive) return;
  const total = archive.files.length;
  btnExtract.disabled = btnOpen.disabled = true;
  setStatus(L('Extraction en cours…'), 'accent');
  let done = 0;
  const step = Math.max(1, Math.ceil(total / 60));
  const tick = () => {
    done = Math.min(total, done + step);
    setProgress(Math.round((done / total) * 100));
    if (done < total) return setTimeout(tick, 30);
    setStatus(L('Extraction terminée : {n} fichiers extraits (simulation).', { n: fmtInt(total) }), 'success');
    btnExtract.disabled = btnOpen.disabled = false;
  };
  tick();
}

// Événements
btnOpen.addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', () => { if (fileInput.files[0]) load(fileInput.files[0]); fileInput.value = ''; });
$('btnDemo').addEventListener('click', () => show(demoArchive()));
btnExtract.addEventListener('click', extract);

document.querySelector('.files thead').addEventListener('click', (e) => {
  const key = e.target.closest('th')?.dataset.sort;
  if (!key || !archive) return;
  sort = { key, dir: sort.key === key ? -sort.dir : 1 };
  selected = -1;
  render();
});
rows.addEventListener('click', (e) => {
  const tr = e.target.closest('tr[data-i]');
  if (!tr) return;
  rows.querySelector('.is-selected')?.classList.remove('is-selected');
  tr.classList.add('is-selected');
  selected = Number(tr.dataset.i);
});

let depth = 0;
window.addEventListener('dragenter', (e) => { e.preventDefault(); depth++; app.classList.add('is-dragging'); });
window.addEventListener('dragleave', () => { if (--depth <= 0) { depth = 0; app.classList.remove('is-dragging'); } });
window.addEventListener('dragover', (e) => e.preventDefault());
window.addEventListener('drop', (e) => {
  e.preventDefault();
  depth = 0;
  app.classList.remove('is-dragging');
  const f = [...e.dataTransfer.files].find((x) => /\.(bsa|ba2)$/i.test(x.name)) || e.dataTransfer.files[0];
  if (f) load(f);
});

// Thème : sombre par défaut, bascule clair / sombre
const btnTheme = $('btnTheme');
function applyTheme(t) {
  document.documentElement.dataset.theme = t;
  btnTheme.textContent = L(t === 'dark' ? 'Thème clair' : 'Thème sombre');
  try { localStorage.setItem('bae-theme', t); } catch {}
}
let saved = null;
try { saved = localStorage.getItem('bae-theme'); } catch {}
applyTheme(saved || 'dark');
btnTheme.addEventListener('click', () => applyTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'));

// Textes fixes de la page (clés de i18n/strings.json)
const fixed = {
  '#btnOpen': '📦 Ouvrir une archive (.BSA / .BA2)',
  '#info': "Ouvrez ou glissez-déposez une archive n'importe où dans la fenêtre.",
  '#btnDemo': 'Charger une démo',
  '.drop__title': 'Déposez une archive ici',
  'th[data-sort="name"]': 'Chemin du fichier', 'th[data-sort="size"]': 'Taille brute', 'th[data-sort="compressed"]': 'Compression',
  '#status': 'En attente', '#btnExtract': 'Extraire tout',
};
for (const [sel, key] of Object.entries(fixed)) document.querySelector(sel).textContent = L(key);
document.querySelector('.drop__hint').innerHTML =
  `${esc(L('Formats pris en charge : .BSA (Oblivion à Skyrim SE) et .BA2 (Fallout 4, Starfield).'))}<br>${esc(L("La lecture se fait dans le navigateur, aucun fichier n'est envoyé."))}`;
