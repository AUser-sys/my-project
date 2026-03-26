import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // 用于解析 JSON

void main() => runApp(const NovelApp());

class NovelApp extends StatelessWidget {
  const NovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '极简小说',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BookshelfPage(),
    );
  }
}

// ==========================================
// 首页：书架列表页 (带分类筛选 & 协同过滤推荐功能)
// ==========================================
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  List<dynamic> categories = [];
  List<dynamic> books = [];
  List<dynamic> recommendBooks = [];
  bool isLoading = true;
  int selectedCategoryId = 0;

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchBooks(0);
    fetchRecommend();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/categories'),
      );
      if (response.statusCode == 200) {
        setState(() {
          categories = json.decode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      print('请求分类失败: $e');
    }
  }

  Future<void> fetchBooks(int categoryId) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/books?category_id=$categoryId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          books = json.decode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      print('请求书籍失败: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchRecommend() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/recommend'),
      );
      if (response.statusCode == 200) {
        setState(() {
          recommendBooks = json.decode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      print('推荐请求失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现好书')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 顶部水平分类导航栏 ---
          Container(
            height: 50,
            color: Colors.grey[100],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 8.0,
                  ),
                  child: ChoiceChip(
                    label: Text(catName),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedCategoryId = catId;
                      });
                      fetchBooks(catId);
                    },
                  ),
                );
              },
            ),
          ),

          // --- 基于协同过滤的“猜你喜欢”模块 ---
          if (recommendBooks.isNotEmpty && selectedCategoryId == 0) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
              child: Text(
                '🌟 猜你喜欢 (基于协同过滤)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recommendBooks.length,
                itemBuilder: (context, index) {
                  final rBook = recommendBooks[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReadingPage(
                            bookId: rBook['id'],
                            bookTitle: rBook['title'],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(left: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            rBook['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rBook['author'],
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
            const Divider(height: 30),
          ],

          // --- 下方的小说常规列表 ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : books.isEmpty
                ? const Center(child: Text('这个分类下还没书哦~'))
                : ListView.builder(
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return ListTile(
                        leading: const Icon(Icons.book, color: Colors.blue),
                        title: Text(book['title']),
                        subtitle: Text('${book['author']} · ${book['status']}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 极简仿真阅读器页面 (【已加入】打赏/沙箱支付功能)
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChapters();
  }

  Future<void> fetchChapters() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/chapters/${widget.bookId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          chapters = json.decode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      print('请求章节失败: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================
  // 【核心功能】处理支付/打赏请求
  // ==========================================
  Future<void> handleTip(int amount) async {
    // 1. 关闭底部的打赏弹窗
    Navigator.pop(context);

    try {
      // 2. 向 Node.js 后端发送真实的金额数据
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/pay'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        // 3. 支付成功后，在屏幕顶部弹出醒目的绿色提示框 (答辩演示效果拉满)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('🎉 成功打赏 $amount 元！作者动力满满！'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 100, // 让提示飘在屏幕上方
                left: 20,
                right: 20,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('打赏请求失败: $e');
    }
  }

  // ==========================================
  // 【核心功能】显示底部的“收银台”弹窗
  // ==========================================
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
                  // 1元按钮
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.deepOrange,
                    ),
                    onPressed: () => handleTip(1),
                    child: const Text('1元', style: TextStyle(fontSize: 16)),
                  ),
                  // 5元按钮
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[300],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => handleTip(5),
                    child: const Text(
                      '5元',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 10元按钮
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => handleTip(10),
                    child: const Text(
                      '10元 (土豪)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
        backgroundColor: Colors.brown[100],
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // 【新增】：右上角的打赏按钮 (礼物盒图标)
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.deepOrange),
            tooltip: '打赏作者',
            onPressed: showTipDialog, // 点击后触发 showTipDialog 函数
          ),
        ],
      ),
      backgroundColor: Colors.brown[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chapters.isEmpty
          ? const Center(child: Text('作者还在努力码字中...'))
          : PageView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter['title'],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          chapter['content'],
                          style: const TextStyle(fontSize: 18, height: 1.8),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
