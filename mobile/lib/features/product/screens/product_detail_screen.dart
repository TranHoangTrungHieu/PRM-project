import 'package:mobile/shared/widgets/notification_popup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/product/models/product.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/core/widgets/retry_network_image.dart';
import 'package:mobile/features/product/models/comment.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _isLoading = true;
  int _quantity = 1;
  bool _isAdding = false;
  List<Comment> _comments = [];
  bool _commentsLoading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  int? _replyingToCommentId;
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmittingReply = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final p = await ApiService.getProductById(widget.productId);
      setState(() {
        _product = p;
        _isLoading = false;
      });
      _fetchComments();
    } catch (e) {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Lỗi: ${e.toString()}',
          type: NotificationType.error,
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _fetchComments() async {
    try {
      final list = await ApiService.getComments(widget.productId);
      if (mounted) {
        setState(() {
          _comments = list;
          _commentsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _commentsLoading = false;
        });
      }
    }
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      showStyledSnackBar(
        context: context,
        message: 'Nội dung nhận xét không được để trống.',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      await ApiService.addComment(widget.productId, text);
      _commentController.clear();
      showStyledSnackBar(
        context: context,
        message: 'Gửi nhận xét thành công!',
        type: NotificationType.success,
      );
      _fetchComments();
    } catch (e) {
      showStyledSnackBar(
        context: context,
        message: 'Lỗi: ${e.toString()}',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _handleAddToCart() async {
    if (_product == null || _product!.stock <= 0) return;
    setState(() => _isAdding = true);
    try {
      await Provider.of<CartProvider>(context, listen: false)
          .addToCart(_product!.id, _quantity);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 4,
                        ),
                          ],
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Thành công!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Đã thêm $_quantity sản phẩm vào Giỏ hàng thành công.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context); // Go back
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                            side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'TIẾP TỤC MUA',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx); // Close dialog
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/dashboard',
                              (route) => false,
                              arguments: 1, // Redirect to Dashboard and open Cart tab
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'XEM GIỎ HÀNG',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Lỗi: $err',
          type: NotificationType.error,
        );
      }
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Widget _buildSpecTile(String label, String? value, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : MediaQuery.of(context).size.width * 0.43,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendReply(int parentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      showStyledSnackBar(
        context: context,
        message: 'Nội dung phản hồi không được để trống.',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isSubmittingReply = true);
    try {
      await ApiService.addComment(widget.productId, text, parentId: parentId);
      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
      });
      showStyledSnackBar(
        context: context,
        message: 'Đã gửi phản hồi thành công!',
        type: NotificationType.success,
      );
      _fetchComments();
    } catch (e) {
      showStyledSnackBar(
        context: context,
        message: 'Lỗi: ${e.toString()}',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReply = false);
      }
    }
  }

  Widget _buildCommentCard(Comment comment, {bool isReply = false}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.user?.role == 'ADMIN';
    final isLoggedIn = authProvider.isAuthenticated;

    String formattedDate = '';
    try {
      final diff = DateTime.now().difference(comment.createdAt);
      if (diff.inMinutes < 1) {
        formattedDate = 'Vừa xong';
      } else if (diff.inHours < 1) {
        formattedDate = '${diff.inMinutes} phút trước';
      } else if (diff.inDays < 1) {
        formattedDate = '${diff.inHours} giờ trước';
      } else if (diff.inDays < 7) {
        formattedDate = '${diff.inDays} ngày trước';
      } else {
        formattedDate = '${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year}';
      }
    } catch (_) {
      formattedDate = 'Gần đây';
    }

    final hasAvatar = comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty;
    final isReplyingThis = _replyingToCommentId == comment.id;

    return Container(
      margin: EdgeInsets.only(bottom: isReply ? 8 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReply ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isReply ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
        boxShadow: isReply
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              hasAvatar
                  ? CircleAvatar(
                      radius: isReply ? 14 : 18,
                      backgroundImage: NetworkImage(ApiService.resolveImageUrl(comment.avatarUrl)),
                      backgroundColor: const Color(0xFFF1F5F9),
                    )
                  : Container(
                      width: isReply ? 28 : 36,
                      height: isReply ? 28 : 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEAEA),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        comment.username.isNotEmpty ? comment.username.substring(0, 2).toUpperCase() : 'US',
                        style: TextStyle(
                          fontSize: isReply ? 10 : 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE53935),
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '@${comment.username}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    if (!isReply && isLoggedIn && isAdmin) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_replyingToCommentId == comment.id) {
                              _replyingToCommentId = null;
                              _replyController.clear();
                            } else {
                              _replyingToCommentId = comment.id;
                              _replyController.text = '@${comment.username} ';
                            }
                          });
                        },
                        child: Text(
                          isReplyingThis ? 'HỦY TRẢ LỜI' : 'TRẢ LỜI 💬',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE53935),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (isReplyingThis) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      maxLines: null,
                      autofocus: true,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Nhập phản hồi...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSubmittingReply ? null : () => _handleSendReply(comment.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmittingReply
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isAuthenticated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.comment_outlined, color: Color(0xFFE53935), size: 22),
              const SizedBox(width: 8),
              const Text(
                'NHẬN XÉT CỦA HUẤN LUYỆN VIÊN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              if (!_commentsLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_comments.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Write Comment Area
          if (isLoggedIn) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Chia sẻ nhận xét của bạn về thẻ bài này...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSubmittingComment ? null : _handleSubmitComment,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmittingComment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFFE53935), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Đăng nhập để gửi nhận xét của bạn dưới sản phẩm này.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ĐĂNG NHẬP',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Comments List
          if (_commentsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: Color(0xFFE53935)),
              ),
            )
          else if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFFE53935).withOpacity(0.3), size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Chưa có nhận xét nào cho sản phẩm này.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hãy là người đầu tiên đưa ra nhận xét nhé!',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            () {
              final parents = _comments.where((c) => c.parentId == null).toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: parents.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final parent = parents[index];
                  final replies = _comments.where((c) => c.parentId == parent.id).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommentCard(parent, isReply: false),
                      if (replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 32, top: 4),
                          child: Column(
                            children: replies.map((reply) => _buildCommentCard(reply, isReply: true)).toList(),
                          ),
                        ),
                    ],
                  );
                },
              );
            }(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE53935)),
        ),
      );
    }

    if (_product == null) return const Scaffold(body: Center(child: Text('Không tìm thấy sản phẩm')));

    final item = _product!;
    final resolvedImg = ApiService.resolveImageUrl(item.imageUrl);
    final inStock = item.stock > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHI TIẾT THẺ BÀI'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image background wrapper
                Container(
                  color: const Color(0xFFF8FAFC),
                  height: 300,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: RetryNetworkImage(url: resolvedImg, fit: BoxFit.contain),
                ),

                // Specs Details container
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.brand.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 16),

                      // Price and Stock row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (item.isPromo) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${item.promoPrice!.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                                ),
                                Text(
                                  'Giá gốc: \$${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                            ),

                          // Stock status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: inStock ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: inStock ? const Color(0xFFBCF0DA) : const Color(0xFFFCA5A5)),
                            ),
                            child: Text(
                              inStock ? 'Còn hàng (${item.stock})' : 'Hết hàng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: inStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      const Text(
                        'Mô tả sản phẩm',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description ?? 'Chưa có thông tin mô tả chi tiết cho sản phẩm này.',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6),
                      ),
                      const SizedBox(height: 24),

                      // Specifications Grid
                      const Text(
                        'Thông Số Kỹ Thuật',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      if (item.isCard) ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildSpecTile('Loại thẻ bài', item.cpu),
                            _buildSpecTile('HP', item.camera),
                            _buildSpecTile('Mã số thẻ', item.battery),
                            _buildSpecTile('Độ hiếm', item.ram),
                            _buildSpecTile('Tình trạng', item.rom),
                            _buildSpecTile('Set', item.screen),
                            _buildSpecTile('Họa sĩ thiết kế', item.os, fullWidth: true),
                          ],
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildSpecTile('Phân loại', item.cpu),
                            _buildSpecTile('Tình trạng', item.rom ?? 'Mới 100%'),
                            _buildSpecTile('Nhà sản xuất / Thiết kế', item.os ?? 'Nintendo', fullWidth: true),
                          ],
                        ),
                      ],

                    ],
                  ),
                ),
                _buildCommentsSection(),
              ],
            ),
          ),

          // Bottom Bar for Add to Cart
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: inStock
                  ? Row(
                      children: [
                        // Quantity Adjuster
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: () {
                                  if (_quantity > 1) setState(() => _quantity--);
                                },
                              ),
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '$_quantity',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () {
                                  if (_quantity < item.stock) setState(() => _quantity++);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Add to Cart Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isAdding ? null : _handleAddToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            child: _isAdding
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'THÊM VÀO GIỎ HÀNG',
                                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                  ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'SẢN PHẨM HIỆN ĐÃ HẾT HÀNG',
                        style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
