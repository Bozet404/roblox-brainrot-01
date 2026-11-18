// Brainrot Blast hands itself in. Node 22, standard library only.
//
// The game is a Rojo project: `rojo build default.project.json --output
// game.rbxl` turns src/ plus default.project.json into the place file. This
// program copies that place file, the Luau sources, the screenshots and
// PLAY.json from beside itself into the output directory (or the directory
// MAKEFUN_OUTPUT_DIR names when run outside the grader), then writes
// dossier.json with the vendored make.fun library. The grader rebuilds the
// dossier from the same files and compares the two byte for byte, so this
// program adds nothing of its own to the dossier.
//
// A name under the output that starts with a dot (.gitkeep, .DS_Store, .git)
// fails the entry, so src/ and screenshots/ are copied with dot-names left
// out at every depth.
//
// Local run, writing out/ in place of /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** Skip every file or directory whose name starts with a dot. */
const keepName = (path: string): boolean => !basename(path).startsWith('.');

mkdirSync(outDir, { recursive: true });
copyFileSync(join(here, 'game.rbxl'), join(outDir, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(outDir, 'PLAY.json'));
cpSync(join(here, 'src'), join(outDir, 'src'), { recursive: true, filter: keepName });
mkdirSync(join(outDir, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(outDir, 'screenshots'), { recursive: true, filter: keepName });
}

// Caps the scorer enforces: text of the dossier at most 64 KiB, at most 4
// screenshots of at most 256 KiB each, a place of at most 500000 instances,
// scripts of at most 8 MiB of source in all, script paths at most 1048576
// characters in all.
writeFileSync(
  join(outDir, 'dossier.json'),
  buildDossier(outDir, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);
