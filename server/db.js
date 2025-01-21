const mongoose = require('mongoose');

module.exports = async () => {
    const connectionParams = {
        useNewUrlParser: true,
        useCreateIndex: true,
        useUnifiedTopology: true
    };
    try{
        mongoose.connect(process.env.DB, mongoose.connectionParams);
        console.log('Connected to database');
    }catch(error){
        console.log('Error connecting to the database. \n${error}');
        //console.log(error);
    
    }   
}