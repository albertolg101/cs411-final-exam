# syntax=docker/dockerfile:1
FROM node:24-alpine

WORKDIR /app

# Install dependencies first to leverage layer caching
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source
COPY src ./src

EXPOSE 4444

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:4444/ || exit 1

CMD ["node", "src/index.js"]
