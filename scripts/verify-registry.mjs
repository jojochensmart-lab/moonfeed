// Verify registry latest resolves to the release version in a new consumer.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const project = path.resolve(process.argv[2] || path.join(os.tmpdir(), `moonfeed-install-${Date.now()}`));
assert.ok(!existsSync(project), 'Verification directory must not already exist');
mkdirSync(path.dirname(project), { recursive: true });
const moon = process.env.MOON_HOME
  ? path.join(process.env.MOON_HOME, 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon') : 'moon';
function run(args, cwd) {
  const result = spawnSync(moon, args, { cwd, encoding: 'utf8' });
  if (result.error) throw result.error;
  process.stdout.write(result.stdout + result.stderr);
  assert.equal(result.status, 0, `moon ${args.join(' ')} failed`);
}
run(['new', project, '--user', 'acceptance', '--name', 'moonfeed-install-review'], path.dirname(project));
run(['add', 'joanna/moonfeed'], project);
const manifest = readFileSync(path.join(project, 'moon.mod'), 'utf8');
assert.match(manifest, /joanna\/moonfeed@0\.3\.1/);
assert.doesNotMatch(manifest, /(?:path\s*=|git\s*=|moonfeed@0\.2\.)/);
assert.ok(!existsSync(path.join(project, 'moon.work')), 'Consumer must not use a workspace');
writeFileSync(path.join(project, 'moon.pkg'), 'import { "joanna/moonfeed", "joanna/moonfeed/src/atom", "joanna/moonfeed/src/rss", "moonbitlang/core/test" } for "test"\n');
const smoke = readFileSync(new URL("./registry-smoke.mbt.txt", import.meta.url), "utf8");
writeFileSync(path.join(project, 'smoke_test.mbt'), smoke);
for (const target of ['default', 'wasm-gc', 'js']) {
  for (const command of ['check', 'test', 'build']) run(target === 'default' ? [command] : [command, '--target', target], project);
}
run(['tree'], project);
console.log(`Registry acceptance PASS: joanna/moonfeed@0.3.1 (moon add latest), project=${project}`);
