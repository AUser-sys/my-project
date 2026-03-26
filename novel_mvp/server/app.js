const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

// 1. 配置数据库连接
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "123456", // 替换为你自己的密码
  database: "novel_mvp",
});

db.connect((err) => {
  if (err) console.error("数据库连接失败:", err);
  else console.log("✅ 数据库连接成功！");
});

// ==========================================
// 【新增】用户注册接口
// ==========================================
app.post("/api/register", (req, res) => {
  const { username, password } = req.body;
  if (!username || !password)
    return res.status(400).json({ error: "账号密码不能为空" });

  // 极简版暂存明文，真实项目需要加盐 hash
  db.query(
    "INSERT INTO users (username, password, balance) VALUES (?, ?, 0)",
    [username, password],
    (err, results) => {
      if (err)
        return res.status(500).json({ error: "注册失败，用户名可能已存在" });
      res.json({
        success: true,
        user: { id: results.insertId, username, balance: 0 },
      });
    },
  );
});

// ==========================================
// 【新增】用户登录接口
// ==========================================
app.post("/api/login", (req, res) => {
  const { username, password } = req.body;
  db.query(
    "SELECT id, username, balance FROM users WHERE username = ? AND password = ?",
    [username, password],
    (err, results) => {
      if (err || results.length === 0)
        return res.status(401).json({ error: "账号或密码错误" });
      res.json({ success: true, user: results[0] });
    },
  );
});

// ==========================================
// 【新增】获取用户信息 (用于刷新余额)
// ==========================================
app.get("/api/user/:id", (req, res) => {
  db.query(
    "SELECT id, username, balance FROM users WHERE id = ?",
    [req.params.id],
    (err, results) => {
      if (err || results.length === 0)
        res.status(404).json({ error: "用户不存在" });
      else res.json(results[0]);
    },
  );
});

// ==========================================
// 【新增】我的书架 (获取收藏的书籍)
// ==========================================
app.get("/api/bookshelf/:userId", (req, res) => {
  const sql = `
    SELECT b.id, b.title, b.author, b.status 
    FROM books b 
    JOIN behaviors bh ON b.id = bh.book_id 
    WHERE bh.user_id = ? AND bh.action_type = 'collect'
    ORDER BY bh.id DESC
  `;
  db.query(sql, [req.params.userId], (err, results) => {
    if (err) res.status(500).json({ error: "获取书架失败" });
    else res.json(results);
  });
});

// ==========================================
// 【新增】收藏/取消收藏 (Toggle) 及其状态检查
// ==========================================
app.get("/api/collect/status", (req, res) => {
  const { userId, bookId } = req.query;
  db.query(
    "SELECT id FROM behaviors WHERE user_id=? AND book_id=? AND action_type='collect'",
    [userId, bookId],
    (err, results) => {
      res.json({ isCollected: results && results.length > 0 });
    },
  );
});

app.post("/api/collect/toggle", (req, res) => {
  const { userId, bookId } = req.body;
  db.query(
    "SELECT id FROM behaviors WHERE user_id=? AND book_id=? AND action_type='collect'",
    [userId, bookId],
    (err, results) => {
      if (results.length > 0) {
        // 取消收藏
        db.query("DELETE FROM behaviors WHERE id=?", [results[0].id], () =>
          res.json({ isCollected: false }),
        );
      } else {
        // 添加收藏
        db.query(
          "INSERT INTO behaviors (user_id, book_id, action_type) VALUES (?, ?, 'collect')",
          [userId, bookId],
          () => res.json({ isCollected: true }),
        );
      }
    },
  );
});

// ==========================================
// 【新增】获取/发布读者评论
// ==========================================
app.get("/api/comments/:bookId", (req, res) => {
  const sql = `
    SELECT c.id, c.content, DATE_FORMAT(c.created_at, '%Y-%m-%d %H:%i') as time, u.username 
    FROM comments c JOIN users u ON c.user_id = u.id 
    WHERE c.book_id = ? ORDER BY c.id DESC
  `;
  db.query(sql, [req.params.bookId], (err, results) => {
    if (err) res.status(500).json({ error: "获取评论失败" });
    else res.json(results);
  });
});

app.post("/api/comments", (req, res) => {
  const { userId, bookId, content } = req.body;
  if (!content) return res.status(400).json({ error: "内容不能为空" });
  db.query(
    "INSERT INTO comments (user_id, book_id, content) VALUES (?, ?, ?)",
    [userId, bookId, content],
    (err) => {
      if (err) res.status(500).json({ error: "发布失败" });
      else res.json({ success: true });
    },
  );
});

// 以下为保留的原有接口 =======================
app.get("/api/categories", (req, res) => {
  db.query("SELECT * FROM categories", (err, results) => {
    if (err) res.status(500).json({ error: "获取分类失败" });
    else res.json(results);
  });
});

app.get("/api/hot", (req, res) => {
  db.query(
    "SELECT id, title, author, status FROM books ORDER BY id DESC LIMIT 3",
    (err, results) => {
      if (err) res.status(500).json({ error: "获取热门失败" });
      else res.json(results);
    },
  );
});

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

app.get("/api/chapters/:bookId", (req, res) => {
  const sql =
    "SELECT chapter_num, title, content FROM chapters WHERE book_id = ? ORDER BY chapter_num ASC";
  db.query(sql, [req.params.bookId], (err, results) => {
    if (err) res.status(500).json({ error: "获取章节失败" });
    else res.json(results);
  });
});

app.get("/api/recommend", (req, res) => {
  // 修改为动态获取当前用户ID，默认兜底使用1号用户
  const currentUserId = req.query.userId || 1;
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

app.post("/api/pay", (req, res) => {
  const { userId, amount } = req.body;
  if (!amount || !userId) return res.status(400).json({ error: "参数不完整" });

  db.query(
    'INSERT INTO orders (user_id, amount, status) VALUES (?, ?, "success")',
    [userId, amount],
    (err, results) => {
      if (err) return res.status(500).json({ error: "订单生成失败" });
      db.query(
        "UPDATE users SET balance = balance - ? WHERE id = ?",
        [amount, userId],
        (err2) => {
          res.json({
            success: true,
            message: "打赏成功！",
            orderId: results.insertId,
          });
        },
      );
    },
  );
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 后端服务已启动: http://localhost:${PORT}`);
});
