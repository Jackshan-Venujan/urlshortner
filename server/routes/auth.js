const router = require('express').Router();
const {User} = require('../models/user');
const Joi = require('joi');

router.post("/",async (req,res)=>{
    try{
        const {error} = validate(req.body);
        if (error)
            return res.status(400).send({message:error.details[0].message});
        
        const  user = await User.findOne({email: req.body.email});
        if (!user)
            return res.status(401).send({message:"Invalid email or password"}); 
        const valid password
    }catch(error){
    }
})

const validate = (data) => {
    const Schema = joi.object({
        userName: joi.string().min(3).max(255).required().label('Username'),
        email: joi.string().min(3).max(255).required().label("email").email(),
        password: passwordComplexity().required().label('Password')
    });
    return Schema.validate(data);
}

module.exports = router;