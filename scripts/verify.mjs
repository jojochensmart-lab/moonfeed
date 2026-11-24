// Reproduce source acceptance without a shell pipeline or third-party packages.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cliOnly = process.argv.slice(2).includes('--cli-only');
const moon = process.env.MOON_HOME
  ? path.join(process.env.MOON_HOME, 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon')
  : 'moon';
function run(program, args, { input, expected = 0 } = {}) {
  const result = spawnSync(program, args, { cwd: root, encoding: 'utf8', input });
  if (result.error) throw result.error;
  assert.equal(result.status, expected, `${program} ${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  return result;
}
if (!cliOnly) for (const args of [
  ['check'], ['test'], ['build'],
  ['check', '--target', 'js'], ['test', '--target', 'js'], ['build', '--target', 'js'], ['tree'],
]) {
  const result = run(moon, args);
  process.stdout.write(result.stdout + result.stderr);
}
if (!cliOnly) for (const target of ['wasm-gc', 'js']) {
  for (const example of ['basic', 'jsonfeed', 'rss', 'atom_feed', 'atom', 'errors']) {
    const result = run(moon, ['run', `examples/${example}`, '--target', target]);
    process.stdout.write(result.stdout + result.stderr);
  }
}
const cli = path.join(root, '_build', 'js', 'debug', 'build', 'cli', 'cli.js');
const command = (args, options) => run(process.execPath, [cli, ...args], options);
const version = readFileSync(path.join(root, 'moon.mod'), 'utf8').match(/^version\s*=\s*"([^"]+)"/m)[1];
assert.equal(command(['--version']).stdout.trim(), `moonfeed ${version}`);
assert.match(command(['--help']).stdout, /normalize <file\|->/);
assert.equal(command(['detect', 'fixtures/rss/full.xml']).stdout.trim(), 'RSS 2.0');
assert.match(command(['inspect', 'fixtures/atom/full.xml']).stdout, /Format: Atom 1.0/);
const normalized = JSON.parse(command(['normalize', 'fixtures/jsonfeed/full.json']).stdout);
const original = JSON.parse(readFileSync(path.join(root, 'fixtures/jsonfeed/full.json'), 'utf8'));
assert.equal(normalized.title, original.title);
assert.equal(normalized.items.length, original.items.length);
for (const [index, item] of original.items.entries()) {
  assert.equal(normalized.items[index].language, item.language ?? original.language ?? null);
}
const stdin = '\uFEFF{"version":"https://jsonfeed.org/version/1.1","title":"stdin 月",' +
  '"language":"zh-CN","items":[{"id":"a","content_text":"body","attachments":[' +
  '{"url":"u","mime_type":"audio/mpeg","size_in_bytes":18446744073709551615}]}]}';
const encoded = command(['normalize', '-'], { input: stdin }).stdout;
assert.equal(JSON.parse(encoded).items[0].language, 'zh-CN');
assert.match(encoded, /"size_in_bytes":\s*18446744073709551615/);
// Formal RSS acceptance: optional identity and document-level XML validation.
const rss = items => '<rss version="2.0"><channel><title>News</title>' +
  '<link>https://example.org/</link><description>Feed</description>' + items + '</channel></rss>';
const bodyOnly = rss('<item><description>这是一条新闻正文</description></item>');
for (const [prefix, suffix] of [
  ['', ''], [' \t\r\n', ' \t\r\n'],
  ['<!--before-->', '<!-- valid trailing comment -->'],
  ['<?audit before?>', '<?audit complete?>'],
]) {
  const result = command(['normalize', '-'], { input: prefix + bodyOnly + suffix });
  assert.equal(result.stderr, '');
  const feed = JSON.parse(result.stdout);
  assert.equal(feed.title, 'News');
  assert.equal(feed.items.length, 1);
  assert.equal(feed.items[0].id, '');
  assert.equal(feed.items[0].url, null);
  assert.equal(feed.items[0].title, null);
  assert.equal(feed.items[0].content_html, '这是一条新闻正文');
}
const titled = JSON.parse(command(['normalize', '-'], {
  input: rss('<item><title>只有标题的新闻</title></item>'),
}).stdout).items[0];
assert.equal(titled.title, '只有标题的新闻');
assert.equal(titled.id, '');
assert.equal(titled.url, null);
for (const input of [
  'INVALID' + bodyOnly, bodyOnly + 'INVALID', bodyOnly + '<other/>',
  bodyOnly + '<unfinished', bodyOnly + '<!-- invalid -- comment -->',
  bodyOnly + '<?audit incomplete', bodyOnly + '<?xml version="1.0"?>',
  rss('<item/>'), rss('<item><guid>id</guid></item>'),
  rss('<item><link>https://example.org/a</link></item>'),
]) {
  const result = command(['normalize', '-'], { input, expected: 2 });
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /failed to parse/);
}
console.log('Formal RSS/XML CLI PASS: optional identity, XML Misc, malformed boundaries, missing content');
// Shared declaration checks and bounded entity processing must reach the CLI.
for (const input of [
  '<!DOCTYPE rss [<!ENTITY % p SYSTEM "urn:p" NDATA n>]>' + bodyOnly,
  '<!DOCTYPE rss [<!ATTLIST absent a CDATA "&missing;">]>' + bodyOnly,
  '<!DOCTYPE rss [<!ATTLIST rss a CDATA "&later;"><!ENTITY later "v">]>' + bodyOnly,
]) {
  const result = command(['normalize', '-'], { input, expected: 2 });
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /failed to parse/);
}
const smallDtd = '<!DOCTYPE rss [<!ENTITY heading "Safe">]>';
const safeFeed = JSON.parse(command(['normalize', '-'], { input: smallDtd + rss('<item><description>&heading;</description></item>') }).stdout);
assert.equal(safeFeed.items[0].content_html, 'Safe');
let amplification = '<!ENTITY e0 "">';
for (let i = 1; i <= 20; i++) amplification += `<!ENTITY e${i} "&e${i - 1};&e${i - 1};">`;
const limited = command(['normalize', '-'], {
  input: `<!DOCTYPE rss [${amplification}]>` + rss('<item><description>&e20;</description></item>'), expected: 2,
});
assert.equal(limited.stdout, '');
assert.match(limited.stderr, /XML entity reference limit exceeded/);
console.log('Entity security CLI PASS: invalid declarations rejected, small entities retained, amplification bounded');
// Strict UTF-8 decoding must precede XML parsing: never silently replace bad bytes.
const invalidUtf8File = path.join(root, '_build', `invalid-utf8-${process.pid}.xml`);
const openingBytes = Buffer.from('<rss version="2.0"><channel><title>F</title><link>u</link><description>D</description><item><description>');
const closingBytes = Buffer.from('</description></item></channel></rss>');
for (const bytes of [[0xc0, 0xaf], [0xed, 0xa0, 0x80], [0xf4, 0x90, 0x80, 0x80], [0xe2, 0x82]]) {
  const result = command(['normalize', '-'], { input: Buffer.concat([openingBytes, Buffer.from(bytes), closingBytes]), expected: 2 });
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /cannot read input/);
}
let createdUtf8Fixture = false;
try {
  writeFileSync(invalidUtf8File, Buffer.concat([openingBytes, Buffer.from([0xff]), closingBytes]), { flag: 'wx' });
  createdUtf8Fixture = true;
  const result = command(['normalize', invalidUtf8File], { expected: 2 });
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /cannot read input/);
} finally {
  if (createdUtf8Fixture) unlinkSync(invalidUtf8File);
}
const replacementCharacter = JSON.parse(command(['normalize', '-'], { input: rss('<item><description>\uFFFD</description></item>') }).stdout);
assert.equal(replacementCharacter.items[0].content_html, '\uFFFD');
console.log('UTF-8 CLI PASS: malformed bytes rejected for stdin/files, valid replacement character preserved');
for (const [args, input, error] of [
  [['normalize', '-'], '', /input is empty/],
  [['normalize', '-'], '{bad}', /failed to parse/],
  [['detect', '-'], '<html/>', /Unknown feed format/],
  [['inspect', path.join(root, '_build', 'does-not-exist.xml')], undefined, /file not found/],
  [['unsupported'], undefined, /Usage:/],
]) {
  const result = command(args, { input, expected: 2 });
  assert.equal(result.stdout, '');
  assert.match(result.stderr, error);
}
console.log(cliOnly
  ? 'CLI acceptance PASS: files/stdin/errors/version/JSON fields'
  : 'Acceptance PASS: both targets, six examples, CLI files/stdin/errors/version/JSON fields');
