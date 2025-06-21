FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Use existing node user (uid 1000, gid 1000)
# Change ownership to node user
RUN chown -R node:node /app

# Switch to node user
USER node

# Expose port
EXPOSE 3000

# Start development server
CMD ["npm", "start"]
