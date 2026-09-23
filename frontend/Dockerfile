# Build stage
FROM docker.io/library/node:26-alpine@sha256:0b36e8c136b94cd4fcf02188228e76c31ad5872eef3fec8cbd2eee500cfd9e80 AS build

WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Override the committed .env value at build time if needed (Vite bakes VITE_* vars in at build, not at runtime)
ARG VITE_API_BASE_URL=http://application-lb.student.com:8080
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

# Build the React app
RUN npm run build

# Serve stage
FROM docker.io/library/nginx:1.31.6-alpine@sha256:d10753d9289b8e3f884386351f73554ce72b631378949deddd75e83ee296c427

# Copy the custom nginx.conf file to the container
COPY .docker/nginx.conf /etc/nginx/nginx.conf

# Copy the built React app from the build stage to the nginx container
COPY --from=build /app/dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
