import fs from "fs/promises";
import path from "path";
import sharp from "sharp";

const root = process.cwd();
const targets = [
  path.join(root, "public", "images"),
  path.join(root, "src", "images"),
];

const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg"]);
const MAX_DESKTOP_WIDTH = 1920;
const MAX_MOBILE_WIDTH = 1080;

async function exists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function walk(dir) {
  if (!(await exists(dir))) return [];
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walk(fullPath));
    } else if (IMAGE_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) {
      files.push(fullPath);
    }
  }

  return files;
}

async function optimizeImage(filePath) {
  const ext = path.extname(filePath);
  const dir = path.dirname(filePath);
  const name = path.basename(filePath, ext);
  const stat = await fs.stat(filePath);

  // 小圖先跳過，避免過度產生檔案。
  if (stat.size < 500 * 1024) return null;

  const image = sharp(filePath).rotate();
  const metadata = await image.metadata();
  const desktopWidth = Math.min(metadata.width || MAX_DESKTOP_WIDTH, MAX_DESKTOP_WIDTH);
  const mobileWidth = Math.min(metadata.width || MAX_MOBILE_WIDTH, MAX_MOBILE_WIDTH);

  const desktopOut = path.join(dir, `${name}-desktop.webp`);
  const mobileOut = path.join(dir, `${name}-mobile.webp`);
  const webpOut = path.join(dir, `${name}.webp`);

  await sharp(filePath)
    .rotate()
    .resize({ width: desktopWidth, withoutEnlargement: true })
    .webp({ quality: 78 })
    .toFile(desktopOut);

  await sharp(filePath)
    .rotate()
    .resize({ width: mobileWidth, withoutEnlargement: true })
    .webp({ quality: 76 })
    .toFile(mobileOut);

  await sharp(filePath)
    .rotate()
    .resize({ width: desktopWidth, withoutEnlargement: true })
    .webp({ quality: 78 })
    .toFile(webpOut);

  return {
    source: path.relative(root, filePath),
    sourceMB: +(stat.size / 1024 / 1024).toFixed(2),
    outputs: [
      path.relative(root, desktopOut),
      path.relative(root, mobileOut),
      path.relative(root, webpOut),
    ],
  };
}

const allFiles = (await Promise.all(targets.map(walk))).flat();
const results = [];

for (const file of allFiles) {
  try {
    const result = await optimizeImage(file);
    if (result) results.push(result);
  } catch (error) {
    console.error(`Failed to optimize ${file}:`, error.message);
  }
}

console.table(results);
console.log(`Done. Optimized ${results.length} large image(s).`);
