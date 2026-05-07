const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const pool = new Pool({
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
});
    pool.on('connect', client => {
    client.query("SET client_encoding TO 'UTF8'");
    });

// Регистрация
router.post('/register', async (req, res) => {
    const { name, email, password } = req.body;
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        const result = await pool.query(
            'INSERT INTO users (name, email, password) VALUES ($1, $2, $3) RETURNING id, name, email',
            [name, email, hashedPassword]
        );
        const user = result.rows[0];
        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '24h' });
        res.json({ token, user });
    } catch (err) {
        res.status(400).json({ error: 'Email уже занят' });
    }
});

// Вход
router.post('/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        const user = result.rows[0];
        if (!user) return res.status(400).json({ error: 'Пользователь не найден' });

        const valid = await bcrypt.compare(password, user.password);
        if (!valid) return res.status(400).json({ error: 'Неверный пароль' });

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '24h' });
        res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Создание заявки
router.post('/request', async (req, res) => {
    const { name, email, message } = req.body;
    const token = req.headers.authorization?.split(' ')[1];
    
    let user_id = null;
    if (token) {
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            user_id = decoded.id;
        } catch(e) {}
    }

    try {
        await pool.query(
            'INSERT INTO requests (user_id, message, status) VALUES ($1, $2, $3)',
            [user_id, `Имя: ${name}, Email: ${email}, Сообщение: ${message}`, 'новая']
        );
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Добавить отзыв
router.post('/review', async (req, res) => {
    const { name, message, rating } = req.body;
    const token = req.headers.authorization?.split(' ')[1];

    let user_id = null;
    if (token) {
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            user_id = decoded.id;
        } catch (e) { }
    }

    try {
        await pool.query(
            'INSERT INTO reviews (user_id, text, rating) VALUES ($1, $2, $3)',
            [user_id, message, parseInt(rating)]
        );
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Получить отзывы
router.get('/reviews', async (req, res) => {
    try {
        const approved = req.query.approved === 'true';
        const query = approved
            ? 'SELECT reviews.*, users.name FROM reviews LEFT JOIN users ON reviews.user_id = users.id WHERE reviews.approved = true ORDER BY reviews.created_at DESC'
            : 'SELECT reviews.*, users.name FROM reviews LEFT JOIN users ON reviews.user_id = users.id ORDER BY reviews.created_at DESC';
        const result = await pool.query(query);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Получить ВСЕ отзывы для админки
router.get('/admin/reviews', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT reviews.*, users.name FROM reviews LEFT JOIN users ON reviews.user_id = users.id ORDER BY reviews.created_at DESC'
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Одобрить / скрыть отзыв
router.patch('/admin/reviews/:id', async (req, res) => {
    const { id } = req.params;
    const { approved } = req.body;
    try {
        await pool.query('UPDATE reviews SET approved = $1 WHERE id = $2', [approved, id]);
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Удалить отзыв
router.delete('/admin/reviews/:id', async (req, res) => {
    const { id } = req.params;
    try {
        await pool.query('DELETE FROM reviews WHERE id = $1', [id]);
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;