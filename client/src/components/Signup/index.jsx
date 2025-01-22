import styles from './styles.module.css';
import { Link } from 'react-router-dom';

const Signup = () => {
  return (
    <div className={styles.signup_container}>
        <div className={styles.signup_form_container}>
            <div className = {styles.left}>
                <h1>Welcome Back</h1>
                <Link to ="/login">
                    <button type="button" className= {styles.white_btn}>
                        Sign in
                    </button>
                </Link> 
            </div>
            <div className = {styles.right}>
                <form className={styles.form_container}>
                    <h1>Create Account</h1>
                    <input type>
                    </input>
                </form>

            </div>
        </div>
      <h1>Signup</h1>
    </div>
  );
}