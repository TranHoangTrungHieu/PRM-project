import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/order/models/order.dart';
import 'package:mobile/features/gacha/services/collection_store.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/order/screens/order_detail_screen.dart';
import 'package:mobile/shared/widgets/notification_popup.dart';

class OrderHistoryScreen extends StatefulWidget {
  final bool isSelected;
  const OrderHistoryScreen({super.key, this.isSelected = false});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isSelected && _orders.isNotEmpty) {
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final list = await ApiService.getOrders();
      setState(() {
        _orders = list;
        _orders.sort((a, b) => b.id.compareTo(a.id)); // Newest first
        _isLoading = false;
      });
      _syncCanceledGachaOrders(list);
      _syncPurchasedCards(list);
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncPurchasedCards(List<Order> orders) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user?.role == 'ADMIN') return;
      final userId = auth.user?.id;
      if (userId == null) return;

      List<int> syncedOrderIds = await CollectionStore.getSyncedOrderIds(userId);
      List<int> ownedIds = await CollectionStore.getOwnedCardIds(userId);

      bool collectionChanged = false;
      bool syncedOrdersChanged = false;

      for (final order in orders) {
        final String paymentMethod = (order.paymentMethod ?? '').toUpperCase();
        final String status = order.status.toUpperCase();
        final String deliveryType = (order.deliveryType ?? 'ONLINE_COLLECTION').toUpperCase();

        // Online collection cards go into the collection as soon as the order
        // is placed (any non-cancelled status), no need to wait for COMPLETED.
        if (status != 'CANCELLED' && paymentMethod != 'GACHA' && deliveryType == 'ONLINE_COLLECTION') {
          if (!syncedOrderIds.contains(order.id)) {
            for (final item in order.orderItems) {
              if (item.product.isCard) {
                for (int i = 0; i < item.quantity; i++) {
                  ownedIds.add(item.product.id);
                }
              }
            }
            syncedOrderIds.add(order.id);
            collectionChanged = true;
            syncedOrdersChanged = true;
          }
        }
      }

      if (collectionChanged) {
        await CollectionStore.setOwnedCardIds(userId, ownedIds);
      }
      if (syncedOrdersChanged) {
        await CollectionStore.setSyncedOrderIds(userId, syncedOrderIds);
      }
    } catch (e) {
      print('Error syncing purchased cards: $e');
    }
  }

  Future<void> _syncCanceledGachaOrders(List<Order> orders) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user?.role == 'ADMIN') return;
      final userId = auth.user?.id;
      if (userId == null) return;

      List<int> refundedIds = await CollectionStore.getRefundedOrderIds(userId);

      bool changed = false;
      List<String> refundedCardNames = [];

      for (final order in orders) {
        if (order.paymentMethod != null && 
            order.paymentMethod!.toUpperCase() == 'GACHA' && 
            order.status.toUpperCase() == 'CANCELLED') {
          if (!refundedIds.contains(order.id)) {
            List<int> ownedIds = await CollectionStore.getOwnedCardIds(userId);
            
            for (final item in order.orderItems) {
              for (int i = 0; i < item.quantity; i++) {
                ownedIds.add(item.product.id);
              }
              refundedCardNames.add('${item.product.name} (x${item.quantity})');
            }

            await CollectionStore.setOwnedCardIds(userId, ownedIds);
            refundedIds.add(order.id);
            changed = true;
          }
        }
      }

      if (changed) {
        await CollectionStore.setRefundedOrderIds(userId, refundedIds);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.replay_circle_filled_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Hoàn trả thẻ Gacha 🎒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Text(
                'Đơn đổi thẻ Gacha của bạn đã bị hủy.\nCác thẻ bài sau đã được hoàn trả lại bộ sưu tập của bạn:\n\n${refundedCardNames.join("\n")}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ĐỒNG Ý', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error syncing canceled gacha orders: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'DELIVERED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
  Widget _buildOrderCard(Order order) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.user?.role == 'ADMIN';
    final isGacha = order.paymentMethod != null && order.paymentMethod!.toUpperCase() == 'GACHA';
    final isAuction = order.paymentMethod != null && order.paymentMethod!.toUpperCase() == 'AUCTION';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              orderId: order.id!,
              isAdmin: isAdmin,
            ),
          ),
        );
      },
      child: Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Đơn hàng #${order.id}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    if (isGacha) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          '🎟️ GACHA',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    if (isAuction) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Text(
                          '🔨 ĐẤU GIÁ',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ngày đặt: ${(order.createdAt != null && order.createdAt.length >= 16) ? order.createdAt.replaceFirst('T', ' ').substring(0, 16) : (order.createdAt ?? '')}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
            if (order.bankTranDateTime != null && order.bankTranDateTime!.length == 14)
              Text(
                'GD Ngân hàng: ${order.bankTranDateTime!.substring(0, 4)}-${order.bankTranDateTime!.substring(4, 6)}-${order.bankTranDateTime!.substring(6, 8)} ${order.bankTranDateTime!.substring(8, 10)}:${order.bankTranDateTime!.substring(10, 12)}:${order.bankTranDateTime!.substring(12, 14)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            const Divider(height: 20),
            
            // Items
            ...order.orderItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.product.name} x${item.quantity}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        ),
                      ),
                      Text(
                        isGacha ? '\$0.00 (Đổi Gacha)' : '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng cộng:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                ),
                Text(
                  isGacha ? '\$0.00 (Miễn phí)' : '\$${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFFE53935)),
                ),
              ],
            ),
            if (order.recipientName != null || order.shippingAddress != null || order.phone != null) ...[
              const Divider(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin giao nhận',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    if (order.recipientName != null)
                      Text('👤 Người nhận: ${order.recipientName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    if (order.phone != null)
                      Text('📞 Số điện thoại: ${order.phone}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    if (order.shippingAddress != null)
                      Text('📍 Địa chỉ: ${order.shippingAddress}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                    if (order.note != null && order.note!.isNotEmpty)
                      Text('📝 Ghi chú: ${order.note}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                  ],
                ),
              ),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cập nhật trạng thái:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: order.status.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        items: ['PENDING', 'PROCESSING', 'SHIPPED', 'COMPLETED', 'CANCELLED'].map((st) {
                          return DropdownMenuItem<String>(
                            value: st,
                            child: Text(st),
                          );
                        }).toList(),
                        onChanged: (newStatus) async {
                          if (newStatus == null || newStatus == order.status.toUpperCase()) return;
                          
                          setState(() {
                            _isLoading = true;
                          });
                          
                          try {
                            await ApiService.updateOrderStatus(order.id, newStatus);
                            if (mounted) {
                              showNotificationPopup(
                                context: context,
                                title: 'Thành Công',
                                message: 'Đã cập nhật trạng thái đơn hàng #${order.id} thành công sang $newStatus!',
                                isSuccess: true,
                              );
                            }
                            await _fetchOrders();
                          } catch (e) {
                            if (mounted) {
                              showNotificationPopup(
                                context: context,
                                title: 'Lỗi Cập Nhật',
                                message: 'Không thể cập nhật trạng thái đơn hàng: $e',
                                isSuccess: false,
                              );
                            }
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.user?.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'QUẢN LÝ ĐƠN HÀNG' : 'LỊCH SỬ ĐƠN HÀNG'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              color: const Color(0xFFE53935),
              child: _orders.isEmpty
                  ? Center(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        shrinkWrap: true,
                        children: [
                          const Center(child: Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              isAdmin ? 'Chưa có đơn hàng nào trên hệ thống!' : 'Bạn chưa đặt đơn hàng nào!',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _orders.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                    ),
            ),
    );
  }
}
