FROM node:20-alpine 
WORKDIR  /app
RUN addgroup -S chaitu && adduser -S chaitu -G chaitu 
COPY package*.json  ./
RUN npm ci --only=production
COPY . .
RUN chown -R chaitu:chaitu /app
USER chaitu
EXPOSE 3000
CMD ["node", "index.js"]
