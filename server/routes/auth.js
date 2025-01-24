const router = require('express').Router();
const { User } = require('../models/user');
const Joi = require('joi'); // Use capital 'J' as required
const bcrypt = require('bcrypt');

// You may need to import or define passwordComplexity
const passwordComplexity = require('joi-password-complexity'); // If using joi-password-complexity, import it here

router.post("/", async (req, res) => {
    try {
        const { error } = validate(req.body);
        if (error)
            return res.status(400).send({ message: error.details[0].message });
        
        const user = await User.findOne({ email: req.body.email });
        if (!user)
            return res.status(401).send({ message: "Invalid email or password" });

        const validPassword = await bcrypt.compare(req.body.password, user.password);
        if (!validPassword)
            return res.status(401).send({ message: "Invalid email or password" });

        const token = user.generateAuthToken();
        res.status(200).send({ data: token, message: "Login successful" });
    } catch (error) {
        res.status(500).send({ message: "Internal server error" });
    }
});

const validate = (data) => {
    const Schema = Joi.object({
        userName: Joi.string().min(3).max(255).label('Username'),
        email: Joi.string().min(3).max(255).required().label("email").email(),
        password: passwordComplexity().required().label('Password') // Ensure passwordComplexity is defined or imported
    });
    return Schema.validate(data);
}

module.exports = router;
