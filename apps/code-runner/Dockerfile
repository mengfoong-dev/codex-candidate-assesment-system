FROM node:22-alpine

WORKDIR /app
COPY runner.mjs /app/runner.mjs

USER node
ENTRYPOINT ["node", "/app/runner.mjs"]
