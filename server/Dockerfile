FROM oven/bun:1.1-alpine

WORKDIR /app

# Binários de conversão de mídia: cwebp (libwebp-tools) p/ imagens, ffmpeg p/ vídeo.
RUN apk add --no-cache ffmpeg libwebp-tools

# Dependências primeiro (cache de layer)
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

# Código
COPY . .

EXPOSE 8000

CMD ["bun", "run", "src/index.ts"]
