import styles from './styles.module.css'


const Main = () => {

    const handleLogout =()=>{
        localStorage.removeItem("token");
        window.location.reload();
    }

    return(
        <div className={styles.main_container}>
            <nav className={styles.navbar}>
                <h1>URL Shortner</h1>
                <button className={styles.white_btn} onClick={handleLogout}>
                    Logout
                </button>
            </nav>
            <div className={styles.main_content}>
                <h1>Enter your URL</h1>
                <form className={styles.form}>
                    <input type="text" placeholder="Enter your URL" className={styles.input} />
                    <button type="submit" className={styles.green_btn}>Shorten</button>
                </form>
            </div>
        </div>
    )
}

export default Main;