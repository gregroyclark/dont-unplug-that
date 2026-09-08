import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const root = fileURLToPath(new URL('../../', import.meta.url));
const require = createRequire(path.join(root, 'Website/package.json'));
const sharp = require('sharp');
const mark = await fs.readFile(path.join(root, 'Design/Brand/daylight-mark.svg'), 'utf8');
const paths = mark.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
function svg({ background = false, padding = 0, monochrome = false } = {}) {
  const art = monochrome ? paths.replaceAll('#1249dc', '#000000') : paths;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" fill="none">${background ? '<path fill="white" d="M0 0H128V128H0Z"/>' : ''}<g transform="translate(${padding} ${padding}) scale(${(128 - padding * 2) / 128})">${art}</g></svg>`;
}
async function png(relative, size, options = {}) {
  const target = path.join(root, relative);
  await fs.mkdir(path.dirname(target), { recursive: true });
  let output = sharp(Buffer.from(svg(options))).resize(size, size);
  if (options.background) output = output.flatten({ background: '#ffffff' }).removeAlpha();
  await output.png().toFile(target);
}
const appleDir = 'App/Darwin/Assets.xcassets/AppIcon.appiconset';
const apple = JSON.parse(await fs.readFile(path.join(root, appleDir, 'Contents.json')));
for (const entry of apple.images) {
  await png(`${appleDir}/${entry.filename}`, Number(entry.size.split('x')[0]) * Number(entry.scale.replace('x', '')), { background: true, padding: 10 });
}
for (const [density, scale] of Object.entries({ mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 })) {
  const dir = `App/Android/app/src/main/res/mipmap-${density}`;
  await png(`${dir}/ic_launcher.png`, 48 * scale, { background: true, padding: 10 });
  // 108dp adaptive layers: the full mark fits inside the central 66dp safe circle.
  await png(`${dir}/ic_launcher_foreground.png`, 108 * scale, { padding: 24 });
  await png(`${dir}/ic_launcher_monochrome.png`, 108 * scale, { padding: 24, monochrome: true });
  await sharp({ create: { width: 108 * scale, height: 108 * scale, channels: 3, background: '#ffffff' } }).png().toFile(path.join(root, dir, 'ic_launcher_background.png'));
}
const nativeDir = 'App/Sources/DontUnplugThat/Resources/Module.xcassets/DaylightBrand.imageset';
await png(`${nativeDir}/daylight-brand.png`, 144);
await fs.writeFile(path.join(root, nativeDir, 'Contents.json'), JSON.stringify({ images: [{ filename: 'daylight-brand.png', idiom: 'universal', scale: '3x' }], info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
await fs.writeFile(path.join(root, 'Website/public/daylight-mark.svg'), mark);
await fs.writeFile(path.join(root, 'Website/public/favicon.svg'), svg({ background: true }));
for (const [filename, size] of Object.entries({ 'favicon-16.png': 16, 'favicon-32.png': 32, 'apple-touch-icon.png': 180, 'icon-192.png': 192, 'icon-512.png': 512 })) {
  await png(`Website/public/${filename}`, size, { background: true, padding: filename.startsWith('favicon') ? 0 : 10 });
}
await png('Website/public/icon-maskable-512.png', 512, { background: true, padding: 16 });
await png('Design/Brand/app-icon-1024.png', 1024, { background: true, padding: 10 });
await png('Design/Brand/google-play-icon-512.png', 512, { background: true, padding: 10 });
// ICO container containing the 32px PNG for legacy favicon discovery.
const icoPng = await fs.readFile(path.join(root, 'Website/public/favicon-32.png'));
const ico = Buffer.alloc(22); ico.writeUInt16LE(1, 2); ico.writeUInt16LE(1, 4); ico[6] = 32; ico[7] = 32;
ico.writeUInt16LE(1, 10); ico.writeUInt16LE(32, 12); ico.writeUInt32LE(icoPng.length, 14); ico.writeUInt32LE(22, 18);
await fs.writeFile(path.join(root, 'Website/public/favicon.ico'), Buffer.concat([ico, icoPng]));
console.log('Generated iOS, Android, web and store icon assets from daylight-mark.svg.');
