const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const joi = require('joi');
const passwordComplexity = require('joi-password-complexity');

const userSchema = new mongoose.Schema({
    userName: {
        type: String,
        required: true,
        unique: true
    },
    email: {
        type: String,
        required: true,
        unique: true
    },
    password: {
        type: String,
        required: true,
        unique: true
    },
})

userSchema.methods.generateAuthToken = function(){
    const token = jwt.sign({_id: this._id}, process.env.SECRET_KEY, {expiresIn: '7h'});
    return token;
};

const User = mongoose.model('User', userSchema);
const validate = (data) => {
    const Schema = joi.object({
        userName: joi.string().min(3).max(255).required().label('Username'),
        email: joi.string().min(3).max(255).required().label("email").email(),
        password: passwordComplexity().required().label('Password')
    });
    return Schema.validate(data);
}

module.exports = {User, validate};