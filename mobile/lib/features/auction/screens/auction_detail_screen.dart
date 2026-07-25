import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/features/order/models/order.dart';
import 'package:mobile/features/product/providers/market_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/auction/models/auction.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/core/services/deep_link_handler.dart';
import 'package:mobile/core/widgets/retry_network_image.dart';

class AuctionDetailScreen extends StatefulWidget {
  final int auctionId;
  const AuctionDetailScreen({super.key, required this.auctionId});

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen> {
  Auction? _auction;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _bidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final data = await ApiService.getAuctionById(widget.auctionId);
      setState(() {
        _auction = data;
        _isLoading = false;
        // Pre-populate bid controller with current bid + $5
        _bidController.text = (data.currentBid + 5.0).toStringAsFixed(2);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải chi tiết đấu giá: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _showBidSuccessDialog() {
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
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đặt giá thành công!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Lượt đặt giá của bạn đã được ghi nhận vào hệ thống.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'ĐỒNG Ý (OK)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePlaceBid() async {
    if (_auction == null) return;
    final val = double.tryParse(_bidController.text);
    if (val == null || val <= _auction!.currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số tiền đấu giá phải cao hơn giá hiện tại!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Use MarketProvider so list screen updates as well
      await Provider.of<MarketProvider>(context, listen: false)
          .placeBid(widget.auctionId, val);
      
      // Re-fetch details to refresh local view & bid history
      await _fetchDetails();

      if (mounted) {
        _showBidSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đặt giá thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showClaimBottomSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _ClaimSheetContent(
        auction: _auction!,
        auth: auth,
        onSuccess: () {
          _fetchDetails();
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.03),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
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

    if (_auction == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy thông tin đấu giá')),
      );
    }

    final resolvedImg = ApiService.resolveImageUrl(_auction!.imageUrl);
    // Sort bid history so latest is first
    final bids = List<AuctionBid>.from(_auction!.bidHistory)
      ..sort((a, b) => b.id.compareTo(a.id));

    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.user?.role == 'ADMIN';
    final cleanWinner = _auction!.highestBidder?.replaceAll('@', '') ?? '';
    final cleanCurrentUser = auth.user?.username ?? '';
    final isWinner = !isAdmin && cleanWinner.isNotEmpty && cleanWinner.toLowerCase() == cleanCurrentUser.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHI TIẾT ĐẤU GIÁ'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Background Wrapper
                Container(
                  color: const Color(0xFFF8FAFC),
                  height: 300,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: RetryNetworkImage(url: resolvedImg, fit: BoxFit.contain),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rarity & Condition Tag Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _auction!.rarity ?? 'Rare',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _auction!.condition ?? 'Mint',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Active/Ended Status
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _auction!.isActive
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _auction!.isActive
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              _auction!.isActive ? 'LIVE' : 'ENDED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _auction!.isActive
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Card name
                      Text(
                        _auction!.cardName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info grid (Stats cards)
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.8,
                        children: [
                          _buildStatCard(
                            'Giá hiện tại',
                            '\$${_auction!.currentBid.toStringAsFixed(2)}',
                            Icons.monetization_on_outlined,
                          ),
                          _buildStatCard(
                            'Lượt đấu',
                            '${_auction!.bidsCount} lượt',
                            Icons.gavel_outlined,
                          ),
                          _buildStatCard(
                            'Người dẫn đầu',
                            _auction!.highestBidder ?? 'Chưa có',
                            Icons.person_outline,
                          ),
                          _buildStatCard(
                            'Kết thúc',
                            _auction!.endTime,
                            Icons.access_time,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Bid history section
                      const Text(
                        'Lịch sử đấu giá',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (bids.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.history,
                                color: Color(0xFF94A3B8),
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Chưa có lượt đặt giá nào.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Hãy là người đầu tiên đặt giá!',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: bids.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final bid = bids[index];
                            final isHighest = index == 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  // Bidder icon
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isHighest
                                        ? const Color(0xFFFEF2F2)
                                        : const Color(0xFFF1F5F9),
                                    child: Icon(
                                      Icons.gavel_rounded,
                                      size: 16,
                                      color: isHighest
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Bid details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              bid.bidderUsername,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isHighest
                                                    ? FontWeight.w900
                                                    : FontWeight.w700,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            if (isHighest) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF2F2),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Cao nhất',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          bid.bidTime,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Bid Amount
                                  Text(
                                    '\$${bid.bidAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isHighest
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF1E293B),
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
              ],
            ),
          ),

                  // Bottom Bar for Bidding
          if (_auction!.isActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: isAdmin
                  ? Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          )
                        ],
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Quyền Admin: Bạn chỉ có thể xem chi tiết đấu giá hệ thống và không được phép đặt giá thầu.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      height: 96,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          )
                        ],
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          // Bid input field
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _bidController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  prefixText: '\$ ',
                                  prefixStyle: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Bid button
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handlePlaceBid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(double.infinity, 52),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.gavel_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'ĐẶT GIÁ NGAY',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          if (!_auction!.isActive) ...[
            if (isWinner)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      )
                    ],
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: _auction!.status.toUpperCase() == 'CLAIMED'
                      ? Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBCF0DA)),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Đã xác nhận thông tin nhận hàng thành công!',
                                style: TextStyle(
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _showClaimBottomSheet(context, auth),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(double.infinity, 52),
                          ),
                          icon: const Icon(Icons.gif_box_rounded),
                          label: const Text(
                            'NHẬN THẺ CHIẾN THẮNG 🏆',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
              )
            else if (!isAdmin)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _auction!.status.toUpperCase() == 'CLAIMED'
                          ? 'Phiên đấu giá đã kết thúc và được nhận bởi người thắng cuộc.'
                          : _auction!.status.toUpperCase() == 'CANCELLED'
                              ? 'Kết quả phiên đấu giá này đã bị hủy do không thanh toán.'
                              : 'Phiên đấu giá đã kết thúc. Chúc bạn may mắn lần sau!',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ClaimSheetContent extends StatefulWidget {
  final Auction auction;
  final AuthProvider auth;
  final VoidCallback onSuccess;

  const _ClaimSheetContent({
    required this.auction,
    required this.auth,
    required this.onSuccess,
  });

  @override
  State<_ClaimSheetContent> createState() => _ClaimSheetContentState();
}

class _ClaimSheetContentState extends State<_ClaimSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recipientController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final _noteController = TextEditingController();

  String _deliveryMethod = 'SHIPPING'; // 'SHIPPING' hoặc 'STORE_PICKUP'
  String _selectedStoreName = 'PokeCard Store - Quận 7';
  String _paymentMethod = 'AUCTION'; // 'AUCTION', 'COD', or 'VNPAY'
  bool _isSubmitting = false;

  final List<String> _stores = [
    'PokeCard Store - Quận 7',
    'PokeCard Store - Quận 1',
    'PokeCard Store - Bình Thạnh'
  ];

  @override
  void initState() {
    super.initState();
    final user = widget.auth.user;
    final balance = user?.balance ?? 0.0;
    final cost = widget.auction.currentBid;
    _recipientController = TextEditingController(text: user?.username ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.shippingAddress ?? '');
    
    if (balance >= cost) {
      _paymentMethod = 'AUCTION';
    } else {
      _paymentMethod = 'COD';
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = widget.auth.user?.balance ?? 0.0;
    final cost = widget.auction.currentBid;

    if (_paymentMethod == 'AUCTION' && balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Số dư tài khoản không đủ! Cần \$${cost.toStringAsFixed(2)}, hiện tại có \$${balance.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final claimData = {
        'recipientName': _recipientController.text.trim(),
        'phone': _phoneController.text.trim(),
        'deliveryMethod': _deliveryMethod,
        'shippingAddress': _deliveryMethod == 'SHIPPING' ? _addressController.text.trim() : '',
        'storeName': _deliveryMethod == 'STORE_PICKUP' ? _selectedStoreName : '',
        'note': _noteController.text.trim(),
        'paymentMethod': _paymentMethod,
      };

      final createdOrder = await ApiService.claimAuction(widget.auction.id, claimData);
      await widget.auth.refreshProfile(); // Sync profile balance

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context); // Close sheet
        if (_paymentMethod == 'VNPAY') {
          final paymentUrl = await ApiService.createPaymentUrl(createdOrder.id, platform: 'mobile');
          if (mounted) {
            _showVNPayDialog(createdOrder.id, paymentUrl);
          }
        } else {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xác nhận thông tin thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
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
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nhận thẻ thành công!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'PokeCard Store đã tiếp nhận thông tin giao nhận cho đơn hàng đấu giá của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'ĐỒNG Ý (OK)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVNPayDialog(int orderId, String paymentUrl) {
    final deepLink = DeepLinkHandler();
    deepLink.startListening();
    deepLink.onPaymentResult.listen((result) {
      deepLink.stopListening();
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (successCtx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                      width: 90, height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5), shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 60),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Thanh toán thành công!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                const Text('Giao dịch VNPay đã được xác nhận.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(successCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('ĐỒNG Ý (OK)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🇻🇳',
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'THANH TOÁN VNPAY',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Quét mã QR dưới đây bằng App Ngân hàng hoặc Ví VNPay để thanh toán đơn hàng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    
                    // QR Code box
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: RetryNetworkImage(
                        url: 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(paymentUrl)}',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 22),
                    
                    // Open browser button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(paymentUrl);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Không thể mở trang thanh toán')),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 18),
                      label: const Text('MỞ CỔNG THANH TOÁN VNPAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.2)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Copy link button
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: paymentUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép liên kết thanh toán VNPay!'),
                            backgroundColor: Color(0xFF16A34A),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFFE53935), size: 18),
                      label: const Text('SAO CHÉP ĐƯỜNG DẪN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.2)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                        side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Finish button
                    TextButton(
                      onPressed: () {
                        deepLink.stopListening();
                        Navigator.pop(ctx); // Close VNPay dialog
                        
                        // Show success payment popup
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (successCtx) => Dialog(
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
                                    'Thành công! 🎉',
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
                                    child: const Text(
                                      'Giao dịch thanh toán qua VNPay đã được ghi nhận. Đơn hàng của bạn đang được hệ thống xử lý!',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(successCtx); // Close success dialog
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE53935),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'ĐỒNG Ý (OK)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'TÔI ĐÃ THANH TOÁN XONG',
                        style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.auth.user?.balance ?? 0.0;
    final cost = widget.auction.currentBid;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🏆 NHẬN THẺ CHIẾN THẮNG',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              
              // Auction Card Winning info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sản phẩm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Expanded(
                          child: Text(
                            widget.auction.cardName,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số tiền thanh toán:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(
                          '\$${cost.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số dư ví của bạn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(
                          '\$${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w900, 
                            color: balance >= cost ? const Color(0xFF10B981) : Colors.red
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form inputs
              TextFormField(
                controller: _recipientController,
                decoration: InputDecoration(
                  labelText: 'Tên người nhận',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên người nhận' : null,
              ),
              const SizedBox(height: 14),
              
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại liên hệ',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập số điện thoại' : null,
              ),
              const SizedBox(height: 20),

              // Delivery Method Selection
              const Text(
                'Hình thức giao nhận',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Giao hàng tận nơi 🚚'),
                      selected: _deliveryMethod == 'SHIPPING',
                      onSelected: (selected) {
                        if (selected) setState(() => _deliveryMethod = 'SHIPPING');
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _deliveryMethod == 'SHIPPING' ? Colors.white : Colors.grey.shade600,
                      ),
                      selectedColor: const Color(0xFFE53935),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Nhận tại cửa hàng 🏬'),
                      selected: _deliveryMethod == 'STORE_PICKUP',
                      onSelected: (selected) {
                        if (selected) setState(() => _deliveryMethod = 'STORE_PICKUP');
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _deliveryMethod == 'STORE_PICKUP' ? Colors.white : Colors.grey.shade600,
                      ),
                      selectedColor: const Color(0xFFE53935),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_deliveryMethod == 'SHIPPING') ...[
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ giao hàng',
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (val) => _deliveryMethod == 'SHIPPING' && (val == null || val.trim().isEmpty)
                      ? 'Vui lòng nhập địa chỉ giao hàng'
                      : null,
                ),
              ] else ...[
                const Text(
                  'Chọn chi nhánh nhận hàng',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStoreName,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      items: _stores.map((st) {
                        return DropdownMenuItem(value: st, child: Text(st));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStoreName = val);
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Ghi chú (Tùy chọn)',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              
              // Payment Method Section
              const Text(
                'Phương thức thanh toán',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  // 1. Wallet Balance Option
                  GestureDetector(
                    onTap: balance >= cost
                        ? () => setState(() => _paymentMethod = 'AUCTION')
                        : null,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: balance < cost
                            ? Colors.grey.shade50
                            : (_paymentMethod == 'AUCTION'
                                ? const Color(0xFFFEF2F2)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _paymentMethod == 'AUCTION' && balance >= cost
                              ? const Color(0xFFE53935)
                              : Colors.grey.shade200,
                          width: _paymentMethod == 'AUCTION' && balance >= cost ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: balance < cost
                                ? Colors.grey.shade300
                                : (_paymentMethod == 'AUCTION'
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade500),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Số dư ví (Tự động trừ)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: balance < cost ? Colors.grey.shade400 : const Color(0xFF1E293B),
                                  ),
                                ),
                                if (balance < cost)
                                  const Text(
                                    'Số dư không đủ để thanh toán',
                                    style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          if (_paymentMethod == 'AUCTION' && balance >= cost)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFFE53935), size: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  // 2. COD & VNPay Options (Row)
                  Row(
                    children: [
                      // Cash / COD
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _paymentMethod = 'COD');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _paymentMethod == 'COD'
                                  ? const Color(0xFFFEF2F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _paymentMethod == 'COD'
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade200,
                                width: _paymentMethod == 'COD' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.local_atm_rounded,
                                  color: _paymentMethod == 'COD'
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tiền mặt (COD)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // VNPay
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _paymentMethod = 'VNPAY');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _paymentMethod == 'VNPAY'
                                  ? const Color(0xFFFEF2F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _paymentMethod == 'VNPAY'
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade200,
                                width: _paymentMethod == 'VNPAY' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: _paymentMethod == 'VNPAY'
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Ví VNPay / QR',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'XÁC NHẬN THANH TOÁN (\$${cost.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
