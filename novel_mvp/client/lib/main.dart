import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ==========================================
// 【新增】全局状态管理（MVP极简做法）
// ==========================================
int? globalUserId;
String? globalUsername;
double globalBalance = 0.0;

void main() => runApp(const NovelApp());

class NovelApp extends StatelessWidget {
  const NovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '极简小说',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const MainScreen(),
    );
  }
}

// ==========================================
// 主骨架：带底部导航栏
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 底部导航栏对应的三个页面
  final List<Widget> _pages = [
    const DiscoverPage(),
    const BookshelfPage(), // 真实的我的书架
    const ProfilePage(), // 真实的我的页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '书城'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '书架'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

// ==========================================
// 【新增】登录与注册页面
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool isLoginMode = true; // true:登录模式 false:注册模式

  Future<void> _submit() async {
    final url = isLoginMode
        ? 'http://localhost:3000/api/login'
        : 'http://localhost:3000/api/register';
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameCtrl.text,
          'password': _passwordCtrl.text,
        }),
      );

      final data = json.decode(utf8.decode(res.bodyBytes));

      // 【核心修改】：不再判断不存在的 data['success']，只认 200 状态码
      if (res.statusCode == 200) {
        if (isLoginMode) {
          // 1. 如果是【登录成功】，后端返回了 user 对象，我们保存状态
          setState(() {
            globalUserId = data['user']['id'];
            globalUsername = data['user']['username'];
            globalBalance = double.parse(data['user']['balance'].toString());
            // 💡 提示：后期需要把 data['token'] 存到 SharedPreferences 里
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 登录成功！欢迎回来！'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // 返回上一页
        } else {
          // 2. 如果是【注册成功】，后端只返回了 message，没有 user 对象
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 注册成功！请登录。'),
              backgroundColor: Colors.green,
            ),
          );
          // 注册成功后，不要退出页面，而是自动切换到“登录”模式让用户登录
          setState(() {
            isLoginMode = true;
            _passwordCtrl.clear(); // 清空一下密码框比较好
          });
        }
      } else {
        // 如果后端返回 400, 401(密码错误/用户不存在), 500
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? '请求失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 把真实的报错打印在控制台，方便以后排查，而不是盲目猜网络错误
      debugPrint("💥 前端捕获到异常: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('数据解析异常或网络出错，请查看控制台'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLoginMode ? '欢迎登录' : '新用户注册'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle,
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: '账号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(
                  isLoginMode ? '登 录' : '立即注册',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => isLoginMode = !isLoginMode),
              child: Text(isLoginMode ? '没有账号？点击注册' : '已有账号？去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 【修改】首页：书城列表页 (加入登录拦截)
// ==========================================
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<dynamic> categories = [], books = [], recommendBooks = [], hotBooks = [];
  bool isLoading = true;
  int selectedCategoryId = 0;

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchBooks(0);
    fetchHotBooks();
    fetchRecommend();
  }

  Future<void> fetchCategories() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/categories'),
      );
      if (res.statusCode == 200)
        setState(() => categories = json.decode(utf8.decode(res.bodyBytes)));
    } catch (e) {}
  }

  Future<void> fetchHotBooks() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:3000/api/hot'));
      if (res.statusCode == 200)
        setState(() => hotBooks = json.decode(utf8.decode(res.bodyBytes)));
    } catch (e) {}
  }

  Future<void> fetchBooks(int categoryId) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/books?category_id=$categoryId'),
      );
      if (res.statusCode == 200)
        setState(() {
          books = json.decode(utf8.decode(res.bodyBytes));
          isLoading = false;
        });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchRecommend() async {
    // 推荐接口现需传 userId，若未登录传0让他兜底
    try {
      final res = await http.get(
        Uri.parse(
          'http://localhost:3000/api/recommend?userId=${globalUserId ?? 0}',
        ),
      );
      if (res.statusCode == 200)
        setState(
          () => recommendBooks = json.decode(utf8.decode(res.bodyBytes)),
        );
    } catch (e) {}
  }

  // 统一拦截阅读点击
  void _handleBookTap(dynamic b) async {
    if (globalUserId == null) {
      // 未登录，先跳登录
      final isSuccess = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (isSuccess == true) {
        fetchRecommend(); // 登录后重新拉取属于他的推荐
      }
    } else {
      // 已登录，进入阅读
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingPage(bookId: b['id'], bookTitle: b['title']),
        ),
      );
    }
  }

  Widget buildHorizontalBookList(
    List<dynamic> bookList,
    String title,
    IconData icon,
    Color iconColor,
  ) {
    if (bookList.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: bookList.length,
            itemBuilder: (context, index) {
              final b = bookList[index];
              return GestureDetector(
                onTap: () => _handleBookTap(b),
                child: Container(
                  width: 110,
                  margin: EdgeInsets.only(
                    left: 16,
                    right: index == bookList.length - 1 ? 16 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.book_online,
                        size: 40,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        b['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        b['author'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '发现好书',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final catId = isAll ? 0 : categories[index - 1]['id'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ChoiceChip(
                      label: Text(isAll ? '全部' : categories[index - 1]['name']),
                      selected: selectedCategoryId == catId,
                      selectedColor: Colors.blue.shade100,
                      onSelected: (_) {
                        setState(() => selectedCategoryId = catId);
                        fetchBooks(catId);
                      },
                    ),
                  );
                },
              ),
            ),
            if (selectedCategoryId == 0) ...[
              buildHorizontalBookList(
                hotBooks,
                '热门推荐',
                Icons.local_fire_department,
                Colors.redAccent,
              ),
              buildHorizontalBookList(
                recommendBooks,
                '猜你喜欢',
                Icons.favorite,
                Colors.orangeAccent,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16.0, top: 20, bottom: 8),
                child: Text(
                  '全部书籍',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.menu_book,
                              color: Colors.grey,
                            ),
                          ),
                          title: Text(
                            book['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${book['author']} | ${book['status']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () => _handleBookTap(book),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 【新增】我的书架页面
// ==========================================
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});
  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  List<dynamic> myBooks = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchMyBooks();
  }

  Future<void> fetchMyBooks() async {
    if (globalUserId == null) return;
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/bookshelf/$globalUserId'),
      );
      if (res.statusCode == 200)
        setState(() {
          myBooks = json.decode(utf8.decode(res.bodyBytes));
        });
    } catch (e) {}
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: globalUserId == null
          ? Center(
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                  fetchMyBooks();
                },
                child: const Text('点我登录查看书架'),
              ),
            )
          : isLoading
          ? const Center(child: CircularProgressIndicator())
          : myBooks.isEmpty
          ? const Center(
              child: Text(
                '书架空空如也，快去书城收藏吧~',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: myBooks.length,
              itemBuilder: (context, index) {
                final b = myBooks[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReadingPage(bookId: b['id'], bookTitle: b['title']),
                    ),
                  ).then((_) => fetchMyBooks()), // 看完回来刷新书架
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.book,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        b['status'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 【新增】我的主页页面
// ==========================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    refreshUserInfo();
  }

  Future<void> refreshUserInfo() async {
    if (globalUserId == null) return;
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/user/$globalUserId'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(
          () => globalBalance = double.parse(data['balance'].toString()),
        );
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: globalUserId == null
          ? Center(
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                  setState(() {});
                  refreshUserInfo();
                },
                child: const Text('点我登录'),
              ),
            )
          : ListView(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            globalUsername ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '书币余额: ￥${globalBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.refresh, color: Colors.blue),
                  title: const Text('刷新余额'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    refreshUserInfo();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已刷新')));
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    '退出登录',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    setState(() {
                      globalUserId = null;
                      globalUsername = null;
                      globalBalance = 0;
                    });
                  },
                ),
              ],
            ),
    );
  }
}

// ==========================================
// 【修改】阅读页 (加入收藏功能与读者讨论板块)
// ==========================================
class ReadingPage extends StatefulWidget {
  final int bookId;
  final String bookTitle;
  const ReadingPage({super.key, required this.bookId, required this.bookTitle});
  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  List<dynamic> chapters = [], endRecommendations = [], comments = [];
  bool isLoading = true, isCollected = false;
  double _fontSize = 18.0;
  int _currentPage = 0;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchChapters();
    fetchEndRecommend();
    checkCollectStatus();
    fetchComments();
  }

  Future<void> fetchChapters() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/chapters/${widget.bookId}'),
      );
      if (res.statusCode == 200)
        setState(() {
          chapters = json.decode(utf8.decode(res.bodyBytes));
          isLoading = false;
        });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchEndRecommend() async {
    try {
      final res = await http.get(
        Uri.parse(
          'http://localhost:3000/api/recommend?userId=${globalUserId ?? 1}',
        ),
      );
      if (res.statusCode == 200)
        setState(
          () => endRecommendations = json.decode(utf8.decode(res.bodyBytes)),
        );
    } catch (e) {}
  }

  Future<void> checkCollectStatus() async {
    try {
      final res = await http.get(
        Uri.parse(
          'http://localhost:3000/api/collect/status?userId=$globalUserId&bookId=${widget.bookId}',
        ),
      );
      if (res.statusCode == 200)
        setState(() => isCollected = json.decode(res.body)['isCollected']);
    } catch (e) {}
  }

  Future<void> toggleCollect() async {
    try {
      final res = await http.post(
        Uri.parse('http://localhost:3000/api/collect/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': globalUserId, 'bookId': widget.bookId}),
      );
      if (res.statusCode == 200) {
        setState(() => isCollected = json.decode(res.body)['isCollected']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCollected ? '✅ 已加入书架' : '❌ 已移出书架')),
        );
      }
    } catch (e) {}
  }

  Future<void> fetchComments() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/comments/${widget.bookId}'),
      );
      if (res.statusCode == 200)
        setState(() => comments = json.decode(utf8.decode(res.bodyBytes)));
    } catch (e) {}
  }

  Future<void> submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('http://localhost:3000/api/comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': globalUserId,
          'bookId': widget.bookId,
          'content': _commentCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200) {
        _commentCtrl.clear();
        FocusScope.of(context).unfocus(); // 收起键盘
        fetchComments(); // 重新拉取评论
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🎉 评论发布成功！')));
      }
    } catch (e) {}
  }

  Future<void> handleTip(int amount) async {
    Navigator.pop(context);
    try {
      final res = await http.post(
        Uri.parse('http://localhost:3000/api/pay'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': globalUserId, 'amount': amount}),
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 成功打赏 $amount 元！'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('余额不足或网络错误'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {}
  }

  void showTipDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 220,
          child: Column(
            children: [
              const Text(
                '🎁 喜欢这本书？打赏支持一下！',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.deepOrange,
                    ),
                    onPressed: () => handleTip(1),
                    child: const Text('1元'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[300],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => handleTip(5),
                    child: const Text('5元'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => handleTip(10),
                    child: const Text('10元'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 书末界面 (推荐 + 评论区)
  Widget buildEndRecommendationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 60),
      child: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFFF4ECD8),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Colors.green,
            ),
            const SizedBox(height: 10),
            const Text(
              '全书完',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            const Text(
              '—— 猜你还喜欢 ——',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: endRecommendations.length,
              itemBuilder: (context, index) {
                final b = endRecommendations[index];
                return GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReadingPage(bookId: b['id'], bookTitle: b['title']),
                    ),
                  ),
                  child: Card(
                    color: Colors.white.withOpacity(0.8),
                    elevation: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.import_contacts,
                          size: 40,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            b['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          b['author'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            // ======= 读者讨论区 =======
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.forum, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text(
                  '读者讨论区',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: '写下你的想法...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: submitComment,
                ),
              ],
            ),
            const SizedBox(height: 20),
            comments.isEmpty
                ? const Text(
                    '暂无评论，快来抢沙发！',
                    style: TextStyle(color: Colors.grey),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c['username'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        c['time'],
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c['content'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFFE8DDCB),
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isCollected ? Icons.star : Icons.star_border,
              color: isCollected ? Colors.orange : Colors.grey,
            ),
            tooltip: '收藏',
            onPressed: toggleCollect,
          ),
          TextButton(
            onPressed: () => setState(() => _fontSize = 14.0),
            child: const Text('小', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => setState(() => _fontSize = 18.0),
            child: const Text('中', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => setState(() => _fontSize = 24.0),
            child: const Text('大', style: TextStyle(color: Colors.black)),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.deepOrange),
            tooltip: '打赏作者',
            onPressed: showTipDialog,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF4ECD8),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chapters.isEmpty
          ? const Center(child: Text('作者还在努力码字中...'))
          : Stack(
              children: [
                PageView.builder(
                  itemCount: chapters.length + 1,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    if (index == chapters.length)
                      return buildEndRecommendationPage();
                    final chapter = chapters[index];
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 16.0,
                        bottom: 40.0,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter['title'],
                              style: TextStyle(
                                fontSize: _fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              chapter['content'],
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.8,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      _currentPage == chapters.length
                          ? '讨论区'
                          : '${_currentPage + 1} / ${chapters.length}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
