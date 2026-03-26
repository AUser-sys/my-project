const express = require("express");
const cors = require("cors");
const mysql = require("mysql2");

const app = express();
app.use(cors());
app.use(express.json());

// 1. 连接数据库 (这一步是关键！)
const db = mysql.createConnection({
  host: "localhost",
  user: "root", // MySQL 默认用户名通常是 root
  password: "123456", // ⚠️ 必须把这里替换成你真实的数据库密码！
  database: "novel_db",
});

db.connect((err) => {
  if (err) {
    console.error("❌ 数据库连接失败:", err.message);
    return;
  }
  console.log("✅ 成功连接到 MySQL 数据库 novel_db!");
});

// 2. 极简 API 接口：获取小说列表
app.get("/api/books", (req, res) => {
  const sql = "SELECT * FROM books";
  db.query(sql, (err, results) => {
    if (err) {
      return res.status(500).json({ error: "查询失败" });
    }
    res.json({
      msg: "获取成功",
      data: results,
    });
  });
});
// ==========================================
// 🌟 论文高光时刻：基于物品的协同过滤推荐 (Item-CF)
// 逻辑：找出收藏了当前这本小说(bookId)的用户，看他们还收藏了什么其他小说，按共同收藏次数(相似度)倒序推荐。
// ==========================================
app.get("/api/recommend/:bookId", (req, res) => {
  // 获取前端传过来的书籍ID (比如用户正在看《斗破苍穹》，ID就是1)
  const currentBookId = req.params.bookId;

  const sql = `
        SELECT 
            b.id, 
            b.title, 
            b.description,
            COUNT(f2.user_id) AS similarity_score 
        FROM favorites f1
        JOIN favorites f2 ON f1.user_id = f2.user_id
        JOIN books b ON f2.book_id = b.id
        WHERE f1.book_id = ? AND f2.book_id != ?
        GROUP BY f2.book_id
        ORDER BY similarity_score DESC
        LIMIT 5
    `;

  // 执行 SQL，把 currentBookId 填入两个问号的位置
  db.query(sql, [currentBookId, currentBookId], (err, results) => {
    if (err) {
      console.error(err);
      return res.status(500).json({ error: "推荐算法计算失败" });
    }
    res.json({
      msg: "推荐成功",
      algorithm: "Item-CF", // 答辩时可以指给老师看，我们确实用了这个算法
      data: results,
    });
  });
});
app.get("/", (req, res) => {
  res.send("<h1>小说APP后端API已启动！请访问 /api/books</h1>");
});
// 3. 启动服务器
app.listen(3000, () => {
  console.log("🚀 MVP 后端已启动，运行在 http://localhost:3000");
});
