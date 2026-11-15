# Multi-stage build: compile the static Storybook site, then serve it from a
# tiny nginx image. The runtime stage carries no Node, source, or dependencies
# -- only the generated storybook-static/ output and the nginx config.

# --- Stage 1: build the Storybook static site ---------------------------------
FROM node:lts-alpine AS build
WORKDIR /app

# Install against the committed manifest. --legacy-peer-deps mirrors .npmrc and
# CI so the container resolves the same tree.
COPY package.json .npmrc ./
RUN npm install --ignore-scripts --legacy-peer-deps

COPY . .
RUN npm run build-storybook

# --- Stage 2: serve the static site -------------------------------------------
FROM nginx:alpine AS runtime

# Replace the default server block with one that serves the static catalog.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/storybook-static /usr/share/nginx/html

EXPOSE 80

# Built-in healthcheck so orchestrators can tell when the site is serving.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
