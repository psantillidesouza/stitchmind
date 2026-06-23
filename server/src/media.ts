// Conversão de mídia no upload: imagens → WebP, vídeos → MP4 (H.264/AAC).
// Usa os binários cwebp (libwebp-tools) e ffmpeg, executados via Bun.spawn.
// Estratégia best-effort: se a conversão falhar por qualquer motivo, o arquivo
// original é mantido para não quebrar o upload.

import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export type ConvertResult = {
  bytes: Uint8Array;
  mime: string;
  ext: string;
  /** true se o arquivo foi de fato re-codificado. */
  converted: boolean;
};

async function runBinary(cmd: string[]): Promise<void> {
  const proc = Bun.spawn(cmd, { stdout: "pipe", stderr: "pipe" });
  const exit = await proc.exited;
  if (exit !== 0) {
    const err = await new Response(proc.stderr).text();
    throw new Error(`${cmd[0]} saiu com código ${exit}: ${err.slice(-500)}`);
  }
}

function extOf(filename: string, fallback: string): string {
  return filename.includes(".") ? filename.split(".").pop()!.toLowerCase() : fallback;
}

function passthrough(input: Uint8Array, mime: string, filename: string): ConvertResult {
  return { bytes: input, mime, ext: extOf(filename, "bin"), converted: false };
}

// Formatos que o cwebp decodifica nativamente. Demais (svg, heic, gif animado…)
// passam direto, sem conversão.
const CWEBP_INPUT = new Set(["image/jpeg", "image/jpg", "image/png", "image/tiff"]);

/** Converte imagem → WebP (qualidade 80, sem metadados). */
export async function imageToWebp(
  input: Uint8Array,
  mime: string,
  filename: string,
): Promise<ConvertResult> {
  const lower = mime.toLowerCase();
  if (lower === "image/webp") {
    return { bytes: input, mime: "image/webp", ext: "webp", converted: false };
  }
  if (!CWEBP_INPUT.has(lower)) {
    return passthrough(input, mime, filename);
  }

  const dir = await mkdtemp(join(tmpdir(), "sm-img-"));
  const inPath = join(dir, "in");
  const outPath = join(dir, "out.webp");
  try {
    await writeFile(inPath, input);
    await runBinary(["cwebp", "-quiet", "-q", "80", "-metadata", "none", inPath, "-o", outPath]);
    const out = await readFile(outPath);
    return { bytes: new Uint8Array(out), mime: "image/webp", ext: "webp", converted: true };
  } catch (err) {
    console.warn("[media] falha ao converter imagem p/ webp:", (err as Error).message);
    return passthrough(input, mime, filename);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/** Converte vídeo → MP4 (H.264 + AAC) web-otimizado (faststart). */
export async function videoToMp4(
  input: Uint8Array,
  mime: string,
  filename: string,
): Promise<ConvertResult> {
  const dir = await mkdtemp(join(tmpdir(), "sm-vid-"));
  const inPath = join(dir, "in");
  const outPath = join(dir, "out.mp4");
  try {
    await writeFile(inPath, input);
    await runBinary([
      "ffmpeg", "-y", "-i", inPath,
      "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p",
      "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      outPath,
    ]);
    const out = await readFile(outPath);
    return { bytes: new Uint8Array(out), mime: "video/mp4", ext: "mp4", converted: true };
  } catch (err) {
    console.warn("[media] falha ao converter vídeo p/ mp4:", (err as Error).message);
    return passthrough(input, mime, filename);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}
