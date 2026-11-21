# Use official lightweight Node.js image
FROM node:18-alpine

# Set working directory inside container
WORKDIR /app

# Copy dependency files first (for caching)
COPY package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy the rest of the app
COPY . .

# Tell Docker which port the app uses
EXPOSE 8080

# Set environment variable for port
ENV PORT=8080

# Start the app
CMD ["node", "index.js"]
