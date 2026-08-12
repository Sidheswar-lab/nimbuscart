require("dotenv").config();

const app = require("./src/app");
const { initializeDatabase } = require("./src/databases/db");

const PORT = process.env.PORT || 3000;

const startServer = async () => {
    try {
        await initializeDatabase();

        app.listen(PORT, () => {
            console.log(`Server is running on port ${PORT}`);
        });
    } catch (error) {
        console.error("Failed to initialize database:", error);
        process.exit(1);
    }
};

startServer();