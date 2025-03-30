FROM node:18

# Install build tools
RUN apt-get update && apt-get install -y build-essential

#set working directory in the container
WORKDIR /usr/src/app
COPY package.json ./

#install dependencies

RUN npm install

# Copy application code
COPY . .

# exposing the port
EXPOSE 3000

CMD ["npm", "start"]



