#!/usr/bin/env node
// Scaffolds a new GameMaker script or object resource: the folder + .yy/.gml files, the
// GMForms.yyp `resources` entry, and the GMForms.resource_order entry (see CLAUDE.md
// "Adding a resource"). Mechanical templating only — no GML content is invented.
//
// Usage:
//   node tools/add-resource.js script <name> [--folder=GMForms]
//   node tools/add-resource.js object <name> [--folder=GMForms] [--events=create,step,draw,drawgui,cleanup]
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const YYP_PATH = path.join(ROOT, 'GMForms.yyp');
const ORDER_PATH = path.join(ROOT, 'GMForms.resource_order');

const EVENT_DEFS = {
  create:  { eventType: 0,  eventNum: 0,  file: 'Create_0.gml' },
  step:    { eventType: 3,  eventNum: 0,  file: 'Step_0.gml' },
  draw:    { eventType: 8,  eventNum: 0,  file: 'Draw_0.gml' },
  drawgui: { eventType: 8,  eventNum: 64, file: 'Draw_64.gml' },
  cleanup: { eventType: 12, eventNum: 0,  file: 'CleanUp_0.gml' },
};

function die(msg) {
  console.error('add-resource: ' + msg);
  process.exit(1);
}

function parseArgs(argv) {
  const type = argv[0];
  const name = argv[1];
  const opts = { folder: 'GMForms', events: ['create'] };
  for (const arg of argv.slice(2)) {
    const m = /^--([a-z]+)=(.*)$/.exec(arg);
    if (!m) die(`unrecognized argument '${arg}'`);
    if (m[1] === 'folder') opts.folder = m[2];
    else if (m[1] === 'events') opts.events = m[2].split(',').map((s) => s.trim()).filter(Boolean);
    else die(`unknown option '--${m[1]}'`);
  }
  return { type, name, opts };
}

function crlf(lines) {
  return lines.join('\r\n') + '\r\n';
}

function readText(p) {
  return fs.readFileSync(p, 'utf8');
}

function knownFolders(yypText) {
  const block = /"Folders":\[([\s\S]*?)\n  \],/.exec(yypText);
  if (!block) die('could not find "Folders" array in GMForms.yyp');
  const names = [...block[1].matchAll(/"%Name":"([^"]+)"/g)].map((m) => m[1]);
  return names;
}

function resourceExists(yypText, name) {
  return new RegExp(`"name":"${name}"`).test(yypText);
}

// --- resources array (GMForms.yyp) -----------------------------------------------------

function sortKey(entry) {
  // Matches the project's existing convention: grouped by top-level folder (alphabetical),
  // then by resource name (alphabetical) within each group.
  const folder = entry.resourcePath.split('/')[0];
  return [folder, entry.name];
}

function cmpKey(a, b) {
  const ka = sortKey(a), kb = sortKey(b);
  if (ka[0] !== kb[0]) return ka[0] < kb[0] ? -1 : 1;
  if (ka[1] === kb[1]) return 0;
  return ka[1] < kb[1] ? -1 : 1;
}

function updateYyp(yypText, name, resourcePath) {
  const re = /("resources":\[\r?\n)([\s\S]*?)(\r?\n  \],)/;
  const m = re.exec(yypText);
  if (!m) die('could not find "resources" array in GMForms.yyp');
  const entries = m[2].split(/\r?\n/).filter((l) => l.trim().length > 0).map((line) => {
    const nm = /"name":"([^"]+)"/.exec(line)[1];
    const p = /"path":"([^"]+)"/.exec(line)[1];
    return { name: nm, resourcePath: p, line };
  });
  entries.push({ name, resourcePath, line: `    {"id":{"name":"${name}","path":"${resourcePath}",},},` });
  entries.sort(cmpKey);
  const body = entries.map((e) => e.line).join('\r\n');
  return yypText.slice(0, m.index) + m[1] + body + m[3] + yypText.slice(m.index + m[0].length);
}

// --- ResourceOrderSettings array (GMForms.resource_order) -------------------------------

function updateResourceOrder(orderText, name, resourcePath) {
  const re = /("ResourceOrderSettings":\[\r?\n)([\s\S]*?)(\r?\n  \],)/;
  const m = re.exec(orderText);
  if (!m) die('could not find "ResourceOrderSettings" array in GMForms.resource_order');
  const entries = m[2].split(/\r?\n/).filter((l) => l.trim().length > 0).map((line) => {
    const nm = /"name":"([^"]+)"/.exec(line)[1];
    const p = /"path":"([^"]+)"/.exec(line)[1];
    return { name: nm, resourcePath: p };
  });
  entries.push({ name, resourcePath });
  entries.sort(cmpKey);
  const body = entries
    .map((e, i) => `    {"name":"${e.name}","order":${i},"path":"${e.resourcePath}",},`)
    .join('\r\n');
  return orderText.slice(0, m.index) + m[1] + body + m[3] + orderText.slice(m.index + m[0].length);
}

// --- Lenient structural check (these files are JSON-with-trailing-commas, not strict JSON) ---

function assertStillParseable(text, label) {
  const stripped = text.replace(/,(\s*[\]}])/g, '$1');
  try {
    JSON.parse(stripped);
  } catch (e) {
    die(`generated ${label} is not structurally valid after edit (${e.message}) — aborting, please check manually`);
  }
}

// --- Templates ---------------------------------------------------------------------------

function scriptYy(name, folder) {
  return crlf([
    '{',
    '  "$GMScript":"v1",',
    `  "%Name":"${name}",`,
    '  "isCompatibility":false,',
    '  "isDnD":false,',
    `  "name":"${name}",`,
    '  "parent":{',
    `    "name":"${folder}",`,
    `    "path":"folders/${folder}.yy",`,
    '  },',
    '  "resourceType":"GMScript",',
    '  "resourceVersion":"2.0",',
    '}',
  ]);
}

function objectYy(name, folder, events) {
  const eventLines = events.map((ev) => {
    const d = EVENT_DEFS[ev];
    return `    {"$GMEvent":"v1","%Name":"","collisionObjectId":null,"eventNum":${d.eventNum},"eventType":${d.eventType},"isDnD":false,"name":"","resourceType":"GMEvent","resourceVersion":"2.0",},`;
  });
  return crlf([
    '{',
    '  "$GMObject":"",',
    `  "%Name":"${name}",`,
    '  "eventList":[',
    ...eventLines,
    '  ],',
    '  "managed":true,',
    `  "name":"${name}",`,
    '  "overriddenProperties":[],',
    '  "parent":{',
    `    "name":"${folder}",`,
    `    "path":"folders/${folder}.yy",`,
    '  },',
    '  "parentObjectId":null,',
    '  "persistent":false,',
    '  "physicsAngularDamping":0.1,',
    '  "physicsDensity":0.5,',
    '  "physicsFriction":0.2,',
    '  "physicsGroup":1,',
    '  "physicsKinematic":false,',
    '  "physicsLinearDamping":0.1,',
    '  "physicsObject":false,',
    '  "physicsRestitution":0.1,',
    '  "physicsSensor":false,',
    '  "physicsShape":1,',
    '  "physicsShapePoints":[],',
    '  "physicsStartAwake":true,',
    '  "properties":[],',
    '  "resourceType":"GMObject",',
    '  "resourceVersion":"2.0",',
    '  "solid":false,',
    '  "spriteId":null,',
    '  "spriteMaskId":null,',
    '  "visible":true,',
    '}',
  ]);
}

// --- Main ----------------------------------------------------------------------------------

function main() {
  const { type, name, opts } = parseArgs(process.argv.slice(2));
  if (type !== 'script' && type !== 'object') {
    die(`type must be 'script' or 'object' (rooms aren't supported by this tool yet)\nUsage:\n  node tools/add-resource.js script <name> [--folder=GMForms]\n  node tools/add-resource.js object <name> [--folder=GMForms] [--events=create,step,draw,drawgui,cleanup]`);
  }
  if (!name || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) {
    die(`'${name}' is not a valid resource name (must be a GML-identifier-safe name)`);
  }
  for (const ev of opts.events) {
    if (!EVENT_DEFS[ev]) die(`unknown event '${ev}' — valid: ${Object.keys(EVENT_DEFS).join(', ')}`);
  }

  const yypText = readText(YYP_PATH);
  const orderText = readText(ORDER_PATH);

  const folders = knownFolders(yypText);
  if (!folders.includes(opts.folder)) {
    die(`unknown folder '${opts.folder}' — known folders: ${folders.join(', ')}`);
  }
  if (resourceExists(yypText, name)) {
    die(`a resource named '${name}' already exists in GMForms.yyp`);
  }

  const typeDir = type === 'script' ? 'scripts' : 'objects';
  const resourceDir = path.join(ROOT, typeDir, name);
  if (fs.existsSync(resourceDir)) die(`${typeDir}/${name} already exists on disk`);

  const resourcePath = `${typeDir}/${name}/${name}.yy`;

  fs.mkdirSync(resourceDir, { recursive: true });
  const created = [];

  if (type === 'script') {
    fs.writeFileSync(path.join(resourceDir, `${name}.yy`), scriptYy(name, opts.folder));
    fs.writeFileSync(path.join(resourceDir, `${name}.gml`), '// TODO: implement ' + name + '\n');
    created.push(`${typeDir}/${name}/${name}.yy`, `${typeDir}/${name}/${name}.gml`);
  } else {
    fs.writeFileSync(path.join(resourceDir, `${name}.yy`), objectYy(name, opts.folder, opts.events));
    created.push(`${typeDir}/${name}/${name}.yy`);
    for (const ev of opts.events) {
      const file = EVENT_DEFS[ev].file;
      fs.writeFileSync(path.join(resourceDir, file), '/// @desc TODO\n');
      created.push(`${typeDir}/${name}/${file}`);
    }
  }

  const newYyp = updateYyp(yypText, name, resourcePath);
  assertStillParseable(newYyp, 'GMForms.yyp');
  const newOrder = updateResourceOrder(orderText, name, resourcePath);
  assertStillParseable(newOrder, 'GMForms.resource_order');

  fs.writeFileSync(YYP_PATH, newYyp);
  fs.writeFileSync(ORDER_PATH, newOrder);

  console.log(`Created ${type} '${name}' in folder '${opts.folder}':`);
  for (const f of created) console.log('  ' + f);
  console.log('Updated GMForms.yyp and GMForms.resource_order.');
  console.log('Next: run tools/gmtest.sh --compile-only to confirm the project still loads.');
}

main();
