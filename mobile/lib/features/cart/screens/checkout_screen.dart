import 'package:mobile/shared/widgets/notification_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/core/services/deep_link_handler.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _selectedPaymentMethod = 'VNPAY'; // Default: online collection doesn't allow COD
  String _selectedDeliveryType = 'ONLINE_COLLECTION'; // Default to ONLINE_COLLECTION
  bool _isPlacing = false;

  bool get _codDisabled => _selectedDeliveryType == 'ONLINE_COLLECTION';

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.user?.username ?? '';
    _phoneController.text = auth.user?.phone ?? '';
    _addressController.text = auth.user?.shippingAddress ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;

    setState(() => _isPlacing = true);
    try {
      final payload = {
        'recipientName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'shippingAddress': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'paymentMethod': _selectedPaymentMethod,
        'deliveryType': _selectedDeliveryType,
      };
      
      final createdOrder = await ApiService.placeOrder(payload);
      
      if (_selectedPaymentMethod == 'COD' || _selectedPaymentMethod == 'BALANCE') {
        await cart.clearCart();
        if (_selectedPaymentMethod == 'BALANCE') {
          if (mounted) {
            await Provider.of<AuthProvider>(context, listen: false).refreshProfile();
          }
        }
        if (mounted) {
          showNotificationPopup(
            context: context,
            title: 'Đặt hàng thành công! 🎉',
            message: _selectedPaymentMethod == 'BALANCE'
                ? 'Đơn hàng của bạn đã được thanh toán và đặt thành công bằng số dư tài khoản trong ứng dụng.'
                : 'Đơn hàng của bạn đã được đặt thành công theo hình thức nhận hàng thanh toán (COD).',
            type: NotificationType.success,
            confirmLabel: 'XEM ĐƠN HÀNG',
            onConfirm: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/dashboard',
                (route) => false,
                arguments: 2,
              );
            },
          );
        }
      } else if (_selectedPaymentMethod == 'VNPAY') {
        final paymentUrl = await ApiService.createPaymentUrl(createdOrder.id, platform: 'mobile');
        if (mounted) {
          _showVNPayDialog(createdOrder.id, paymentUrl);
        }
      }
    } catch (e) {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Đặt hàng thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
          type: NotificationType.error,
        );
      }
    } finally {
      setState(() => _isPlacing = false);
    }
  }

  void _showVNPayDialog(int orderId, String paymentUrl) {
    final deepLink = DeepLinkHandler();
    deepLink.startListening();
    deepLink.onPaymentResult.listen((result) {
      deepLink.stopListening();
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Provider.of<CartProvider>(context, listen: false).clearCart();
      try {
        Provider.of<AuthProvider>(context, listen: false).refreshProfile();
      } catch (_) {}
      showNotificationPopup(
        context: context,
        title: 'Thành công! \u{1F389}',
        message: 'Giao dịch thanh toán qua VNPay đã được ghi nhận. Đơn hàng của bạn đang được hệ thống xử lý!',
        type: NotificationType.success,
        confirmLabel: 'XEM ĐƠN HÀNG',
        onConfirm: () {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false, arguments: 2);
        },
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
                      'Bấm vào nút bên dưới để mở trang thanh toán VNPay qua ngân hàng nội địa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    
                    // Open browser button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(paymentUrl);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          showStyledSnackBar(
                            context: context,
                            message: 'Không thể mở trang thanh toán',
                            type: NotificationType.error,
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
                        showStyledSnackBar(
                          context: context,
                          message: 'Đã sao chép liên kết thanh toán VNPay!',
                          type: NotificationType.success,
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
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('THANH TOÁN ĐƠN HÀNG'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary
                    const Text(
                      'Tóm tắt đơn hàng',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ...cart.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.product.name} x${item.quantity}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        '\$${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                )),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng số tiền',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                                Text(
                                  '\$${cart.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFE53935)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Delivery Type Selection
                    const Text(
                      'Hình thức nhận thẻ bài',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Online Collection Option
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDeliveryType = 'ONLINE_COLLECTION';
                                if (_selectedPaymentMethod == 'COD') {
                                  _selectedPaymentMethod = 'VNPAY';
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _selectedDeliveryType == 'ONLINE_COLLECTION'
                                    ? const Color(0xFFFEF2F2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedDeliveryType == 'ONLINE_COLLECTION'
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade200,
                                  width: _selectedDeliveryType == 'ONLINE_COLLECTION' ? 2 : 1,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, color: Color(0xFFE53935), size: 28),
                                  SizedBox(height: 8),
                                  Text(
                                    'Lưu giữ online',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Đưa vào bộ sưu tập để trao đổi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Physical Shipping Option
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedDeliveryType = 'PHYSICAL_SHIPPING');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _selectedDeliveryType == 'PHYSICAL_SHIPPING'
                                    ? const Color(0xFFFEF2F2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedDeliveryType == 'PHYSICAL_SHIPPING'
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade200,
                                  width: _selectedDeliveryType == 'PHYSICAL_SHIPPING' ? 2 : 1,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.local_shipping_outlined, color: Color(0xFFE53935), size: 28),
                                  SizedBox(height: 8),
                                  Text(
                                    'Giao hàng vật lý',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Đóng gói và ship thẳng về nhà',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Shipping Details Form (Always visible and required)
                    const Text(
                      'Thông tin nhận hàng',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    
                    // Name Field
                    const Text(
                      'Họ tên người nhận *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Nhập họ tên người nhận...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập họ tên người nhận';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    const Text(
                      'Số điện thoại liên hệ *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Nhập số điện thoại liên hệ...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        final phoneRegex = RegExp(r'^\d{9,11}$');
                        if (!phoneRegex.hasMatch(val.trim())) {
                          return 'Số điện thoại không hợp lệ (yêu cầu từ 9 đến 11 chữ số)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address Field
                    const Text(
                      'Địa chỉ giao hàng *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Nhập địa chỉ giao hàng của bạn...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập địa chỉ giao hàng';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Note Field
                    const Text(
                      'Ghi chú giao hàng (Không bắt buộc)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Ví dụ: Giao giờ hành chính, gọi trước khi đến...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Payment Method Options
                    const Text(
                      'Phương thức thanh toán',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        // Cash / COD (disabled when storing online)
                        Expanded(
                          child: Opacity(
                            opacity: _codDisabled ? 0.45 : 1.0,
                            child: GestureDetector(
                              onTap: () {
                                if (_codDisabled) {
                                  showStyledSnackBar(
                                    context: context,
                                    message: 'Hình thức "Lưu giữ online" không hỗ trợ thanh toán tiền mặt (COD).',
                                    type: NotificationType.error,
                                  );
                                  return;
                                }
                                setState(() => _selectedPaymentMethod = 'COD');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _selectedPaymentMethod == 'COD'
                                      ? const Color(0xFFFEF2F2)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _selectedPaymentMethod == 'COD'
                                        ? const Color(0xFFE53935)
                                        : Colors.grey.shade200,
                                    width: _selectedPaymentMethod == 'COD' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_atm_rounded,
                                      color: _selectedPaymentMethod == 'COD'
                                          ? const Color(0xFFE53935)
                                          : Colors.grey.shade400,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tiền mặt (COD)',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _codDisabled ? 'Không khả dụng' : 'Khi nhận hàng',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // VNPay
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedPaymentMethod = 'VNPAY');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedPaymentMethod == 'VNPAY'
                                    ? const Color(0xFFFEF2F2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedPaymentMethod == 'VNPAY'
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade200,
                                  width: _selectedPaymentMethod == 'VNPAY' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: _selectedPaymentMethod == 'VNPAY'
                                        ? const Color(0xFFE53935)
                                        : Colors.grey.shade400,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Ví VNPay / QR',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Cổng online',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Balance
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedPaymentMethod = 'BALANCE');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedPaymentMethod == 'BALANCE'
                                    ? const Color(0xFFFEF2F2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedPaymentMethod == 'BALANCE'
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade200,
                                  width: _selectedPaymentMethod == 'BALANCE' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: _selectedPaymentMethod == 'BALANCE'
                                        ? const Color(0xFFE53935)
                                        : Colors.grey.shade400,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Số dư app',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${auth.user?.balance.toStringAsFixed(2) ?? "0.00"}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Action bottom bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: ElevatedButton(
              onPressed: _isPlacing ? null : _handleCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
              ),
              child: _isPlacing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'XÁC NHẬN ĐẶT HÀNG',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
