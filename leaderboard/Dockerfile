FROM node:20-slim
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
RUN npm ci --omit=dev
COPY src ./src
COPY content ./content
COPY public ./public
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/index.js"]
