import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const NovelApp());

class NovelApp extends StatelessWidget {
  const NovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '极简小说',
      debugShowCheckedModeBanner: false, // 隐藏 Debug 标签
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50], // 整体背景稍微偏灰，显得更有质感
      ),
      home: const MainScreen(), // 改为加载带导航栏的主页面
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

  final List<Widget> _pages = [
    const DiscoverPage(), // 发现好书 (原 BookshelfPage)
    const Center(
      child: Text('书架页面 (开发中...)', style: TextStyle(fontSize: 18)),
    ), // 凑数的页面
    const Center(
      child: Text('我的页面 (开发中...)', style: TextStyle(fontSize: 18)),
    ), // 凑数的页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
// 首页：书城列表页 (更美观的排版)
// ==========================================
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<dynamic> categories = [];
  List<dynamic> books = [];
  List<dynamic> recommendBooks = [];
  List<dynamic> hotBooks = []; // 热门推荐
  bool isLoading = true;
  int selectedCategoryId = 0;

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchBooks(0);
    fetchRecommend();
    fetchHotBooks();
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
      if (res.statusCode == 200) {
        setState(() {
          books = json.decode(utf8.decode(res.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchRecommend() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/recommend'),
      );
      if (res.statusCode == 200)
        setState(
          () => recommendBooks = json.decode(utf8.decode(res.bodyBytes)),
        );
    } catch (e) {}
  }

  // 构建水平书单卡片的方法
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReadingPage(bookId: b['id'], bookTitle: b['title']),
                  ),
                ),
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
                      const SizedBox(height: 4),
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
            // 分类导航
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  final isAllButton = index == 0;
                  final catId = isAllButton ? 0 : categories[index - 1]['id'];
                  final catName = isAllButton
                      ? '全部'
                      : categories[index - 1]['name'];
                  final isSelected = selectedCategoryId == catId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ChoiceChip(
                      label: Text(catName),
                      selected: isSelected,
                      selectedColor: Colors.blue.shade100,
                      onSelected: (bool selected) {
                        setState(() => selectedCategoryId = catId);
                        fetchBooks(catId);
                      },
                    ),
                  );
                },
              ),
            ),

            // 全部分类时显示热门和猜你喜欢
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

            // 底部常规列表
            isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.builder(
                    shrinkWrap: true, // 允许在 SingleChildScrollView 中嵌套
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
                          contentPadding: const EdgeInsets.all(12),
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
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${book['author']} | ${book['status']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadingPage(
                                  bookId: book['id'],
                                  bookTitle: book['title'],
                                ),
                              ),
                            );
                          },
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
// 极简仿真阅读器页面 (带打赏、调字体、尾页推荐)
// ==========================================
class ReadingPage extends StatefulWidget {
  final int bookId;
  final String bookTitle;

  const ReadingPage({super.key, required this.bookId, required this.bookTitle});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  List<dynamic> chapters = [];
  List<dynamic> endRecommendations = []; // 书末推荐
  bool isLoading = true;
  double _fontSize = 18.0; // 默认字体大小
  int _currentPage = 0; // 当前页码/章节序号

  @override
  void initState() {
    super.initState();
    fetchChapters();
    fetchEndRecommend();
  }

  Future<void> fetchChapters() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/chapters/${widget.bookId}'),
      );
      if (res.statusCode == 200) {
        setState(() {
          chapters = json.decode(utf8.decode(res.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 获取书末推荐（复用 /api/recommend 接口获取 4 本）
  Future<void> fetchEndRecommend() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/recommend'),
      );
      if (res.statusCode == 200)
        setState(
          () => endRecommendations = json.decode(utf8.decode(res.bodyBytes)),
        );
    } catch (e) {}
  }

  Future<void> handleTip(int amount) async {
    Navigator.pop(context);
    try {
      final res = await http.post(
        Uri.parse('http://localhost:3000/api/pay'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'amount': amount}),
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 成功打赏 $amount 元！作者动力满满！'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
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

  // 书末猜你喜欢界面
  Widget buildEndRecommendationPage() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFF4ECD8), // 保持羊皮纸背景色一致
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            '全书完',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          const Text(
            '—— 猜你还喜欢 ——',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 一排两本，共4本
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: endRecommendations.length,
              itemBuilder: (context, index) {
                final b = endRecommendations[index];
                return GestureDetector(
                  onTap: () {
                    // 替换当前页面为新书
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReadingPage(bookId: b['id'], bookTitle: b['title']),
                      ),
                    );
                  },
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFFE8DDCB), // 稍微比底色深一点的头部
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // 字体大小调节按钮 (大中小)
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
      backgroundColor: const Color(0xFFF4ECD8), // 经典的阅读羊皮纸底色
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chapters.isEmpty
          ? const Center(child: Text('作者还在努力码字中...'))
          : Stack(
              children: [
                // 使用 PageView.builder 翻页
                PageView.builder(
                  itemCount: chapters.length + 1, // +1 是为了最后一页展示“猜你喜欢”
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    // 如果翻到了最后一页，展示推荐内容
                    if (index == chapters.length) {
                      return buildEndRecommendationPage();
                    }

                    // 正常章节内容
                    final chapter = chapters[index];
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 16.0,
                        bottom: 40.0,
                      ), // 留出底部页码空间
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

                // 底部固定悬浮的页码显示
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      _currentPage == chapters.length
                          ? '完结'
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
