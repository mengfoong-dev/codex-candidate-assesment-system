FROM node:22-alpine

RUN apk add --no-cache docker-cli

WORKDIR /app
COPY package.json /app/package.json
COPY server.js /app/server.js

EXPOSE 18080
CMD ["node", "server.js"]
