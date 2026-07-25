import 'package:flutter/material.dart';
import 'package:mobile/core/services/api_service.dart';

class AdminWithdrawScreen extends StatefulWidget {
  const AdminWithdrawScreen({super.key});

  @override
  State<AdminWithdrawScreen> createState() => _AdminWithdrawScreenState();
}

class _AdminWithdrawScreenState extends State<AdminWithdrawScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _requests = await ApiService.getAllWithdrawRequests();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return const Color(0xFFF59E0B);
      case 'APPROVED': return const Color(0xFF3B82F6);
      case 'COMPLETED': return const Color(0xFF16A34A);
      case 'REJECTED': return const Color(0xFFEF4444);
      default: return const Color(0xFF94A3B8);
    }
  }

  String _statusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return 'CHỜ DUYỆT';
      case 'APPROVED': return 'ĐÃ DUYỆT';
      case 'COMPLETED': return 'HOÀN TẤT';
      case 'REJECTED': return 'TỪ CHỐI';
      default: return status;
    }
  }

  Future<void> _approve(dynamic r) async {
    try {
      await ApiService.approveWithdrawRequest(r['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã duyệt yêu cầu rút tiền'), backgroundColor: Color(0xFF16A34A)));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _complete(dynamic r) async {
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('XÁC NHẬN CHUYỂN KHOẢN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số tiền: \$${r['amount']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE53935))),
            const SizedBox(height: 4),
            Text('Người nhận: @${r['username'] ?? ''}'),
            Text('STK: ${r['bankAccountNumber'] ?? ''} - ${r['bankName'] ?? ''}'),
            const SizedBox(height: 16),
            const Text('Bạn đã thực sự chuyển khoản đến tài khoản trên chưa?',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'no'),
            child: const Text('CHƯA CHUYỂN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'yes'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            child: const Text('ĐÃ CHUYỂN THÀNH CÔNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
    if (confirm != 'yes') return;

    try {
      await ApiService.completeWithdrawRequest(r['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hoàn tất yêu cầu'), backgroundColor: Color(0xFF16A34A)));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(dynamic r) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Từ chối yêu cầu'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('TỪ CHỐI'),
          ),
        ],
      ),
    );
    if (result == null) return;

    try {
      await ApiService.rejectWithdrawRequest(r['id'], result.isNotEmpty ? result : 'Từ chối bởi admin');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã từ chối yêu cầu'), backgroundColor: Colors.red));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QUẢN LÝ YÊU CẦU RÚT TIỀN')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFE53935),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
            : _requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Icon(Icons.history, size: 64, color: Color(0xFF94A3B8))),
                      SizedBox(height: 12),
                      Center(child: Text('Không có yêu cầu nào',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, i) {
                      final r = _requests[i];
                      final status = r['status']?.toString().toUpperCase() ?? '';

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
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
                                  Text('@${r['username'] ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(_statusText(status),
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _statusColor(status))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Rút \$${r['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFE53935))),
                              const Divider(height: 16),
                              _infoRow('Ngân hàng', r['bankName'] ?? ''),
                              _infoRow('Số tài khoản', r['bankAccountNumber'] ?? ''),
                              _infoRow('Chủ tài khoản', r['accountHolder'] ?? ''),
                              if (r['adminNote'] != null && r['adminNote'].toString().isNotEmpty)
                                _infoRow('Ghi chú', r['adminNote']),

                              if (status == 'PENDING') ...[
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _reject(r),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                      child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _approve(r),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Duyệt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ],
                              if (status == 'APPROVED') ...[
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _complete(r),
                                      icon: const Icon(Icons.check_circle, size: 16),
                                      label: const Text('Đã chuyển khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF16A34A),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
