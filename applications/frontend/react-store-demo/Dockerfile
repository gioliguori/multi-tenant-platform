FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN chown -R node:node /app

USER node

EXPOSE 3000

# Start development server
CMD ["npm", "start"]
