const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

const app = express();
app.use(cors()); // 允许前端跨域请求
app.use(express.json());

// 1. 配置数据库连接
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "123456", // <--- 注意！这里换成你本机的 MySQL 密码！
  database: "novel_mvp",
});

// 测试数据库连通性
db.connect((err) => {
  if (err) console.error("数据库连接失败:", err);
  else console.log("✅ 数据库连接成功！");
});

// ==========================================
// 2. 新增：获取所有分类接口
// ==========================================
app.get("/api/categories", (req, res) => {
  db.query("SELECT * FROM categories", (err, results) => {
    if (err) res.status(500).json({ error: "获取分类失败" });
    else res.json(results);
  });
});

// ==========================================
// 3. 升级：获取小说列表（支持按分类筛选！）
// ==========================================
app.get("/api/books", (req, res) => {
  const categoryId = req.query.category_id; // 接收前端传来的分类ID

  let sql = "SELECT id, title, author, status FROM books";
  let params = [];

  // 如果前端传了分类ID，我们就加上 WHERE 条件进行过滤
  if (categoryId && categoryId !== "0") {
    sql += " WHERE category_id = ?";
    params.push(categoryId);
  }

  db.query(sql, params, (err, results) => {
    if (err) res.status(500).json({ error: "获取数据失败" });
    else res.json(results);
  });
});
// 3. 新增极简接口：根据小说ID获取章节内容
app.get("/api/chapters/:bookId", (req, res) => {
  const bookId = req.params.bookId;
  // 按照章节序号从小到大排序查询
  const sql =
    "SELECT chapter_num, title, content FROM chapters WHERE book_id = ? ORDER BY chapter_num ASC";

  db.query(sql, [bookId], (err, results) => {
    if (err) {
      res.status(500).json({ error: "获取章节失败" });
    } else {
      res.json(results); // 把查到的章节数组发给前端
    }
  });
});
// ==========================================
// 4. 核心学术考点：基于协同过滤的推荐算法 (Item-CF极简版)
// ==========================================
app.get("/api/recommend", (req, res) => {
  // 为了毕设演示方便，我们假设当前登录的是“用户2”
  const currentUserId = 2;

  // 极简版 Item-CF 核心 SQL 逻辑：
  // 找“和我收藏过同样书的人，他们还收藏了什么我没看过的书”
  const sql = `
    SELECT DISTINCT b.id, b.title, b.author, b.status
    FROM behaviors t1
    JOIN behaviors t2 ON t1.book_id = t2.book_id AND t1.user_id != t2.user_id
    JOIN behaviors t3 ON t2.user_id = t3.user_id AND t3.book_id != t1.book_id
    JOIN books b ON t3.book_id = b.id
    WHERE t1.user_id = ?
    LIMIT 3
  `;

  db.query(sql, [currentUserId], (err, results) => {
    if (err) {
      console.error(err);
      res.status(500).json({ error: "推荐算法运算失败" });
    } else {
      res.json(results); // 返回推荐出来的 3 本书
    }
  });
});

// 3. 启动服务器
const PORT = 3000;
// ==========================================
// 5. 核心商业闭环：模拟沙箱支付/打赏接口
// ==========================================
app.post("/api/pay", (req, res) => {
  // 接收前端传来的打赏金额，默认操作 user_id = 1 (我们初始数据里给他充了50块钱)
  const amount = req.body.amount;
  const userId = 1;

  if (!amount) {
    return res.status(400).json({ error: "金额不能为空" });
  }

  // 1. 往订单表(orders)里插入一条成功的交易记录
  const insertOrderSql =
    'INSERT INTO orders (user_id, amount, status) VALUES (?, ?, "success")';

  db.query(insertOrderSql, [userId, amount], (err, results) => {
    if (err) {
      console.error(err);
      return res.status(500).json({ error: "订单生成失败" });
    }

    // 2. 扣除用户的余额 (模拟真实的扣款逻辑)
    const updateBalanceSql =
      "UPDATE users SET balance = balance - ? WHERE id = ?";
    db.query(updateBalanceSql, [amount, userId], (err2) => {
      if (err2) console.error("余额扣除失败，但订单已生成");

      // 返回成功信息给前端
      res.json({
        success: true,
        message: "打赏成功！",
        orderId: results.insertId,
      });
    });
  });
});
app.listen(PORT, () => {
  console.log(`🚀 后端服务已启动: http://localhost:${PORT}`);
});
