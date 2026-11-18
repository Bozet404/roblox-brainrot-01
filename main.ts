// Brainrot Blast hands itself in. Node 22, standard library only.
//
// The game lives as a Rojo project: `rojo build default.project.json
// --output game.rbxl` turns src/ and default.project.json into the place
// file. This program copies that place file, the Luau sources, the
// screenshots and PLAY.json from beside itself into the output directory
// (or the directory MAKEFUN_OUTPUT_DIR names when run outside the grader),
// then writes dossier.json with the vendored make.fun library. The grader
// rebuilds the dossier from the same files and compares the two byte for
// byte, so this program adds nothing of its own to the dossier.
//
// A name anywhere under the output that starts with a dot (.gitkeep,
// .DS_Store, .git) fails the entry, so src/ and screenshots/ are copied
// with dot-names left out at every depth.
//
// Local run, writing out/ in place of /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const repoRoot = fileURLToPath(new URL('.', import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** True for every name the output may hold: nothing starting with a dot. */
function isAllowedName(path: string): boolean {
  return !basename(path).startsWith('.');
}

/** Copy one whole tree, leaving dot-named files and folders behind. */
function copyTree(from: string, to: string): void {
  cpSync(from, to, { recursive: true, filter: isAllowedName });
}

mkdirSync(outDir, { recursive: true });
copyFileSync(join(repoRoot, 'game.rbxl'), join(outDir, 'game.rbxl'));
copyFileSync(join(repoRoot, 'PLAY.json'), join(outDir, 'PLAY.json'));
copyTree(join(repoRoot, 'src'), join(outDir, 'src'));
mkdirSync(join(outDir, 'screenshots'), { recursive: true });
if (existsSync(join(repoRoot, 'screenshots'))) {
  copyTree(join(repoRoot, 'screenshots'), join(outDir, 'screenshots'));
}

// The caps the scorer enforces: dossier text at most 64 KiB, at most 4
// screenshots of at most 256 KiB each, a place of at most 500000 instances,
// scripts of at most 8 MiB of source in all, script paths at most 1048576
// characters in all.
const dossier = buildDossier(outDir, {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
});
writeFileSync(join(outDir, 'dossier.json'), dossier);
