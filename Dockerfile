# syntax=docker/dockerfile:1.7
ARG TURBO_TEAM

FROM node:24-bookworm-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS build
ARG TURBO_TEAM
ENV TURBO_TEAM=$TURBO_TEAM
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml /app
# Timeout maior: tarballs grandes (ex.: emojibase-data) estouram o default de 60s
# em redes lentas.
RUN pnpm fetch --fetch-timeout=600000

COPY . /app
RUN pnpm install --offline --frozen-lockfile --config.confirmModulesPurge=false
# TURBO_TOKEN é opcional: sem o secret, o Turborepo roda sem remote cache.
RUN --mount=type=secret,id=TURBO_TOKEN \
  TURBO_TOKEN="$(cat /run/secrets/TURBO_TOKEN 2>/dev/null || true)" BUILD_MODE=production pnpm run build
RUN pnpm run clean-deps
RUN pnpm install --prod

# ----------------------------------------------------------------
# Runtime — deps de produção + dist num único artefato.
# A mesma imagem atende os três processos (mesmo modelo do ECS):
#   web:     node apps/backend/dist/processes/proc/web.js   (default)
#   worker:  node apps/backend/dist/processes/proc/worker.js
#   migrate: scripts/release.sh
# ----------------------------------------------------------------
FROM base AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app /app
# Pré-instala o pnpm (usado pelo scripts/release.sh) pra não depender de
# download do corepack em runtime.
RUN corepack install
EXPOSE 4001
CMD ["node", "apps/backend/dist/processes/proc/web.js"]
