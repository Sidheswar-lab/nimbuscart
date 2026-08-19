const express = require("express");
const cors = require("cors");

const { pool } = require("./databases/db");

const app = express();

app.use(cors());
app.use(express.json());


// Health check
app.get("/health", (req, res) => {
    res.status(200).json({
        status: "OK",
        message: "API is healthy"
    });
});


app.get("/api/items", async (req, res) => {
    try {
        const [products] = await pool.query(
            "SELECT id, name, price, stock FROM products"
        );

        res.status(200).json(products);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            error: "Failed to fetch products"
        });
    }
});


// Create a product
app.post("/api/items", async (req, res) => {
    try {
        const { name, price, stock } = req.body;

        if (!name || price === undefined || stock === undefined) {
            return res.status(400).json({
                error: "name, price and stock are required"
            });
        }

        const [result] = await pool.query(
            "INSERT INTO products (name, price, stock) VALUES (?, ?, ?)",
            [name, price, stock]
        );

        res.status(201).json({
            id: result.insertId,
            name,
            price,
            stock
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            error: "Failed to create product"
        });
    }
});


module.exports = app;