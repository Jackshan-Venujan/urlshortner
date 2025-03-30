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

EXPOSE 3000

CMD ["npm", "start"]



