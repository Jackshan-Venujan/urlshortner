FROM node:18

# Install build tools
RUN apt-get update && apt-get install -y build-essential

# Install nodemon globally
RUN npm install -g nodemon

#set working directory in the container
WORKDIR /usr/src/app
COPY package.json ./

#install dependencies

RUN npm install

# Copy application code
COPY . .

# exposing the port
EXPOSE 5001

CMD ["npm", "start"]



