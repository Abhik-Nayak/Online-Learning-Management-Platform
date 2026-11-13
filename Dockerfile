# LearnHub LMS app image.
FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production

# Install dependencies first (cached layer while package*.json is unchanged).
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# App code.
COPY server.js ./
COPY public ./public

# Run as the unprivileged "node" user that ships with the image.
USER node

EXPOSE 3000

# busybox wget is included in alpine.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/health || exit 1

CMD ["node", "server.js"]
