# syntax=docker/dockerfile:1

# --- base: install all deps + source (shared by test and prod) ---
FROM node:24-alpine AS base
WORKDIR /app

# Install dependencies first to leverage layer caching
COPY package*.json ./
RUN npm install

# Copy application source
COPY src ./src

# --- test: run the test suite; build fails here if tests fail ---
FROM base AS test
RUN npm test

# --- prod: lean runtime image, dev deps pruned ---
FROM base AS prod
RUN npm prune --omit=dev

EXPOSE 4444

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:4444/ || exit 1

CMD ["node", "src/index.js"]
