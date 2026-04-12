const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

// 1. 引入刚刚安装的两个库
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

// 2. 定义一个 JWT 专属的“签名秘钥”（相当于公章）
// 注意：在真实的商业项目中，这个秘钥应该写在隐藏的 .env 文件里，这里为了演示直接写在代码里
const JWT_SECRET = "novel_app_super_secret_key_2025";

const app = express();
app.use(cors());
app.use(express.json());

// 这是一个身份验证中间件（保安）
// 这是一个身份验证中间件（普通保安）
const authenticateToken = (req, res, next) => {
  // 1. 从请求头中获取 token (格式通常是 "Bearer eyJhbG...")
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  // 2. 如果没有 token，直接拒绝访问 (401 未授权)
  if (!token) {
    return res.status(401).json({ error: "请先登录" });
  }

  // 3. 验证 token 是否合法和过期
  jwt.verify(token, JWT_SECRET, (err, decodedUser) => {
    if (err) {
      return res.status(403).json({ error: "登录已过期或无效，请重新登录" });
    }
    // 4. 验证通过，把解析出来的用户信息挂载到 req 上，方便后面的接口使用
    req.user = decodedUser;
    next(); // 放行，进入下一个处理环节
  });
};

// 这是一个管理员权限验证中间件（高级保安，和上面的平级！）
// 必须放在 authenticateToken 后面使用
const authenticateAdmin = (req, res, next) => {
  // 从 req.user (由 authenticateToken 解析出来的) 中检查角色
  if (req.user.role !== "admin") {
    return res
      .status(403)
      .json({ error: "权限不足，需要管理员身份执行此操作" });
  }
  next(); // 是管理员，放行
};

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
// 【修改】用户注册接口 (增加防空格和防呆设计)
// ==========================================
app.post("/api/register", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: "用户名和密码不能为空" });
  }

  // 强制转为字符串，并去掉首尾可能误触的空格！
  const safeUsername = String(username).trim();
  const safePassword = String(password).trim();

  try {
    const salt = bcrypt.genSaltSync(10);
    const hashedPassword = bcrypt.hashSync(safePassword, salt); // 用去空格后的密码加密

    const sql = "INSERT INTO users (username, password) VALUES (?, ?)";
    db.query(sql, [safeUsername, hashedPassword], (err, result) => {
      if (err) {
        console.error(err);
        return res.status(500).json({ error: "数据库错误，可能用户名已存在" });
      }
      res.status(200).json({ message: "注册成功" });
    });
  } catch (error) {
    res.status(500).json({ error: "服务器内部错误" });
  }
});
// ==========================================
// 【修改】用户登录接口 (配合防空格设计)
// ==========================================
app.post("/api/login", (req, res) => {
  const { username, password } = req.body;

  // 同样强制转字符串并去掉首尾空格！
  const safeUsername = String(username).trim();
  const safePassword = String(password).trim();

  const sql = "SELECT * FROM users WHERE username = ?";

  db.query(sql, [safeUsername], (err, results) => {
    if (err) return res.status(500).json({ error: "数据库错误" });

    if (results.length === 0) {
      return res.status(401).json({ error: "用户不存在" });
    }

    const user = results[0];

    // 将处理过的明文密码与数据库密文比对
    const isPasswordValid = bcrypt.compareSync(safePassword, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: "密码错误" });
    }

    const token = jwt.sign(
      { userId: user.id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: "7d" },
    );

    res.status(200).json({
      message: "登录成功",
      token: token,
      user: {
        id: user.id,
        username: user.username,
        balance: user.balance,
        role: user.role,
      },
    });
  });
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
// ==========================================
// 【改造】我的书架 (安全获取当前登录用户的收藏)
// ==========================================
// 注意：路径去掉了 /:userId，并加上了 authenticateToken 保安
app.get("/api/bookshelf", authenticateToken, (req, res) => {
  // 从 Token 中拿用户 ID，前端再也无法伪造
  const userId = req.user.userId;

  const sql = `
    SELECT b.id, b.title, b.author, b.status 
    FROM books b 
    JOIN behaviors bh ON b.id = bh.book_id 
    WHERE bh.user_id = ? AND bh.action_type = 'collect'
    ORDER BY bh.id DESC
  `;
  db.query(sql, [userId], (err, results) => {
    if (err) res.status(500).json({ error: "获取书架失败" });
    else res.json(results);
  });
});

// ==========================================
// 【新增】收藏/取消收藏 (Toggle) 及其状态检查
// ==========================================
// ==========================================
// 【改造】收藏/取消收藏 (Toggle) 及其状态检查
// ==========================================
app.get("/api/collect/status", authenticateToken, (req, res) => {
  const userId = req.user.userId; // 安全获取
  const { bookId } = req.query;
  db.query(
    "SELECT id FROM behaviors WHERE user_id=? AND book_id=? AND action_type='collect'",
    [userId, bookId],
    (err, results) => {
      res.json({ isCollected: results && results.length > 0 });
    },
  );
});

app.post("/api/collect/toggle", authenticateToken, (req, res) => {
  const userId = req.user.userId; // 安全获取
  const { bookId } = req.body;
  db.query(
    "SELECT id FROM behaviors WHERE user_id=? AND book_id=? AND action_type='collect'",
    [userId, bookId],
    (err, results) => {
      if (results.length > 0) {
        db.query("DELETE FROM behaviors WHERE id=?", [results[0].id], () =>
          res.json({ isCollected: false }),
        );
      } else {
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

// 注意中间加了 authenticateToken
app.get("/api/balance", authenticateToken, (req, res) => {
  // 此时可以直接用 req.user.userId 来获取当前操作人的 ID，绝对安全！
  const currentUserId = req.user.userId;

  // ... 去数据库查余额的代码
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

// ==========================================
// 【改造】打赏/支付接口 (引入事务处理)
// ==========================================
app.post("/api/pay", authenticateToken, (req, res) => {
  const userId = req.user.userId; // 安全获取当前付款人
  const { amount } = req.body;

  if (!amount || amount <= 0)
    return res.status(400).json({ error: "金额不合法" });

  // 1. 开启 MySQL 事务
  db.beginTransaction((err) => {
    if (err) return res.status(500).json({ error: "开启事务失败" });

    // 2. 第一步：先检查余额够不够 (防止扣成负数)
    db.query(
      "SELECT balance FROM users WHERE id = ?",
      [userId],
      (err, results) => {
        if (err || results.length === 0) {
          return db.rollback(() =>
            res.status(500).json({ error: "用户查询失败" }),
          );
        }

        const currentBalance = results[0].balance;
        if (currentBalance < amount) {
          return db.rollback(() => res.status(400).json({ error: "余额不足" }));
        }

        // 3. 第二步：扣除余额
        db.query(
          "UPDATE users SET balance = balance - ? WHERE id = ?",
          [amount, userId],
          (err2) => {
            if (err2) {
              return db.rollback(() =>
                res.status(500).json({ error: "扣款失败" }),
              );
            }

            // 4. 第三步：生成订单记录
            db.query(
              'INSERT INTO orders (user_id, amount, status) VALUES (?, ?, "success")',
              [userId, amount],
              (err3, orderResult) => {
                if (err3) {
                  // 如果生成订单失败，之前的扣款会被自动撤销（回滚）
                  return db.rollback(() =>
                    res.status(500).json({ error: "订单生成失败" }),
                  );
                }

                // 5. 全部成功，提交事务！
                db.commit((err4) => {
                  if (err4) {
                    return db.rollback(() =>
                      res.status(500).json({ error: "事务提交失败" }),
                    );
                  }
                  res.json({
                    success: true,
                    message: "打赏成功！",
                    orderId: orderResult.insertId,
                    newBalance: currentBalance - amount,
                  });
                });
              },
            );
          },
        );
      },
    );
  });
});

// ==========================================
// 【新增】充值余额接口 (模拟第三方支付回调)
// ==========================================
app.post("/api/recharge", authenticateToken, (req, res) => {
  const userId = req.user.userId;
  const { amount } = req.body;

  if (!amount || amount <= 0)
    return res.status(400).json({ error: "金额不合法" });

  // 开启事务，保证充值和订单记录同时成功
  db.beginTransaction((err) => {
    if (err) return res.status(500).json({ error: "开启事务失败" });

    // 1. 更新用户的余额（加上充值的钱）
    db.query(
      "UPDATE users SET balance = balance + ? WHERE id = ?",
      [amount, userId],
      (err2) => {
        if (err2)
          return db.rollback(() => res.status(500).json({ error: "充值失败" }));

        // 2. 生成充值订单记录 (复用 orders 表)
        db.query(
          'INSERT INTO orders (user_id, amount, status) VALUES (?, ?, "success")',
          [userId, amount],
          (err3) => {
            if (err3)
              return db.rollback(() =>
                res.status(500).json({ error: "订单生成失败" }),
              );

            // 3. 查出最新余额返回给前端
            db.query(
              "SELECT balance FROM users WHERE id = ?",
              [userId],
              (err4, results) => {
                if (err4 || results.length === 0)
                  return db.rollback(() =>
                    res.status(500).json({ error: "获取余额失败" }),
                  );

                db.commit((err5) => {
                  if (err5)
                    return db.rollback(() =>
                      res.status(500).json({ error: "事务提交失败" }),
                    );
                  res.json({
                    success: true,
                    message: "充值成功！",
                    newBalance: results[0].balance,
                  });
                });
              },
            );
          },
        );
      },
    );
  });
});
// ==========================================
// 【新增】管理员专属 API (图书、章节、用户管理)
// ==========================================

// (1) 图书资源管理
// 录入新书
app.post(
  "/api/admin/books",
  authenticateToken,
  authenticateAdmin,
  (req, res) => {
    const { category_id, title, author, description, cover_url } = req.body;
    const sql =
      "INSERT INTO books (category_id, title, author, description, cover_url) VALUES (?, ?, ?, ?, ?)";
    db.query(
      sql,
      [
        category_id,
        title,
        author,
        description,
        cover_url || "https://via.placeholder.com/150x200?text=Cover",
      ],
      (err) => {
        if (err) return res.status(500).json({ error: "录入新书失败" });
        res.json({ success: true, message: "新书录入成功" });
      },
    );
  },
);

// 修改书籍基础信息
app.put(
  "/api/admin/books/:id",
  authenticateToken,
  authenticateAdmin,
  (req, res) => {
    const { category_id, title, author, description, status, publish_status } =
      req.body;
    const sql =
      "UPDATE books SET category_id=?, title=?, author=?, description=?, status=?, publish_status=? WHERE id=?";
    db.query(
      sql,
      [
        category_id,
        title,
        author,
        description,
        status,
        publish_status,
        req.params.id,
      ],
      (err) => {
        if (err) return res.status(500).json({ error: "修改失败" });
        res.json({ success: true, message: "修改成功" });
      },
    );
  },
);

// (2) 章节内容管理
// 添加新章节
app.post(
  "/api/admin/chapters",
  authenticateToken,
  authenticateAdmin,
  (req, res) => {
    const { book_id, chapter_num, title, content } = req.body;
    const sql =
      "INSERT INTO chapters (book_id, chapter_num, title, content) VALUES (?, ?, ?, ?)";
    db.query(sql, [book_id, chapter_num, title, content], (err) => {
      if (err) return res.status(500).json({ error: "添加章节失败" });
      res.json({ success: true, message: "章节发布成功" });
    });
  },
);

// 修改已发布章节
app.put(
  "/api/admin/chapters/:id",
  authenticateToken,
  authenticateAdmin,
  (req, res) => {
    const { chapter_num, title, content } = req.body;
    const sql =
      "UPDATE chapters SET chapter_num=?, title=?, content=? WHERE id=?";
    db.query(sql, [chapter_num, title, content, req.params.id], (err) => {
      if (err) return res.status(500).json({ error: "修改章节失败" });
      res.json({ success: true, message: "章节修改成功" });
    });
  },
);

// (3) 用户档案管理
// 获取所有读者列表
app.get(
  "/api/admin/users",
  authenticateToken,
  authenticateAdmin,
  (req, res) => {
    db.query(
      "SELECT id, username, balance, role, status, created_at FROM users ORDER BY id DESC",
      (err, results) => {
        if (err) return res.status(500).json({ error: "获取用户列表失败" });
        res.json(results);
      },
    );
  },
);

// 封禁/解封用户 (修改 status 字段)
app.put(
  "/api/admin/users/:id/status",
  authenticateToken,
  authenticateAdmin,
  (req, res) => {
    const { status } = req.body; // 传入 'active' 或 'banned'
    if (req.params.id == req.user.userId)
      return res.status(400).json({ error: "不能封禁管理员自己" });
    db.query(
      "UPDATE users SET status=? WHERE id=?",
      [status, req.params.id],
      (err) => {
        if (err) return res.status(500).json({ error: "操作失败" });
        res.json({ success: true, message: `用户状态已更新为 ${status}` });
      },
    );
  },
);
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 后端服务已启动: http://localhost:${PORT}`);
});
