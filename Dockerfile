# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json .npmrc ./
RUN npm ci

COPY . .

# Vite embeds VITE_* variables at build time.
# Inject them as BuildKit secrets so they are not persisted in image metadata.
RUN --mount=type=secret,id=vite_openrouter_api_key \
    --mount=type=secret,id=vite_openai_api_key \
    VITE_OPENROUTER_API_KEY="$(cat /run/secrets/vite_openrouter_api_key 2>/dev/null || true)" \
    VITE_OPENAI_API_KEY="$(cat /run/secrets/vite_openai_api_key 2>/dev/null || true)" \
    npm run build


FROM nginx:1.27-alpine AS runtime

ENV NODE_ENV=production

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
