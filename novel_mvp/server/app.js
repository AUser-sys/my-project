const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

const app = express();
app.use(cors()); // 允许前端跨域请求
app.use(express.json());

// 1. 配置数据库连接 (记得换成你自己的密码！)
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "123456",
  database: "novel_mvp",
});

db.connect((err) => {
  if (err) console.error("数据库连接失败:", err);
  else console.log("✅ 数据库连接成功！");
});

// ==========================================
// 获取所有分类
// ==========================================
app.get("/api/categories", (req, res) => {
  db.query("SELECT * FROM categories", (err, results) => {
    if (err) res.status(500).json({ error: "获取分类失败" });
    else res.json(results);
  });
});

// ==========================================
// [新增] 热门推荐板块接口 (随便取前3本模拟热门)
// ==========================================
app.get("/api/hot", (req, res) => {
  db.query(
    "SELECT id, title, author, status FROM books ORDER BY id DESC LIMIT 3",
    (err, results) => {
      if (err) res.status(500).json({ error: "获取热门失败" });
      else res.json(results);
    },
  );
});

// ==========================================
// 获取小说列表（支持按分类筛选）
// ==========================================
app.get("/api/books", (req, res) => {
  const categoryId = req.query.category_id;
  let sql = "SELECT id, title, author, status FROM books";
  let params = [];

  if (categoryId && categoryId !== "0") {
    sql += " WHERE category_id = ?";
    params.push(categoryId);
  }

  db.query(sql, params, (err, results) => {
    if (err) res.status(500).json({ error: "获取数据失败" });
    else res.json(results);
  });
});

// ==========================================
// 根据小说ID获取章节内容
// ==========================================
app.get("/api/chapters/:bookId", (req, res) => {
  const bookId = req.params.bookId;
  const sql =
    "SELECT chapter_num, title, content FROM chapters WHERE book_id = ? ORDER BY chapter_num ASC";

  db.query(sql, [bookId], (err, results) => {
    if (err) res.status(500).json({ error: "获取章节失败" });
    else res.json(results);
  });
});

// ==========================================
// 基于协同过滤的推荐算法 (修改为返回4本)
// ==========================================
app.get("/api/recommend", (req, res) => {
  const currentUserId = 2; // 模拟当前登录用户
  const sql = `
    SELECT DISTINCT b.id, b.title, b.author, b.status
    FROM behaviors t1
    JOIN behaviors t2 ON t1.book_id = t2.book_id AND t1.user_id != t2.user_id
    JOIN behaviors t3 ON t2.user_id = t3.user_id AND t3.book_id != t1.book_id
    JOIN books b ON t3.book_id = b.id
    WHERE t1.user_id = ?
    LIMIT 4
  `;

  db.query(sql, [currentUserId], (err, results) => {
    if (err) res.status(500).json({ error: "推荐算法运算失败" });
    else res.json(results);
  });
});

// ==========================================
// 模拟沙箱支付/打赏接口
// ==========================================
app.post("/api/pay", (req, res) => {
  const amount = req.body.amount;
  const userId = 1;

  if (!amount) return res.status(400).json({ error: "金额不能为空" });

  const insertOrderSql =
    'INSERT INTO orders (user_id, amount, status) VALUES (?, ?, "success")';
  db.query(insertOrderSql, [userId, amount], (err, results) => {
    if (err) return res.status(500).json({ error: "订单生成失败" });

    const updateBalanceSql =
      "UPDATE users SET balance = balance - ? WHERE id = ?";
    db.query(updateBalanceSql, [amount, userId], (err2) => {
      res.json({
        success: true,
        message: "打赏成功！",
        orderId: results.insertId,
      });
    });
  });
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 后端服务已启动: http://localhost:${PORT}`);
});
