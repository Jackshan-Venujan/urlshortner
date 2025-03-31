FROM node:18 AS build

# working directory
WORKDIR /app

# copy package.json
COPY package.json ./

# install dependencies
RUN npm install

# copy application code 
COPY . .

# build the application
RUN npm run build

FROM nginx:alpine

# copy the build output to the nginx server
COPY --from=build /app/build /usr/share/nginx/html

# copy the nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]


