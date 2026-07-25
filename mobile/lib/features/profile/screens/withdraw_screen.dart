import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/core/services/api_service.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  static const List<String> _vietnamBanks = [
    'Vietcombank (VCB) - Ngân hàng Ngoại thương Việt Nam',
    'VietinBank - Ngân hàng Công thương Việt Nam',
    'BIDV - Ngân hàng Đầu tư và Phát triển Việt Nam',
    'Agribank - Ngân hàng Nông nghiệp và Phát triển Nông thôn',
    'MB Bank - Ngân hàng Quân đội',
    'Techcombank - Ngân hàng Kỹ thương Việt Nam',
    'ACB - Ngân hàng Á Châu',
    'VPBank - Ngân hàng Việt Nam Thịnh Vượng',
    'HDBank - Ngân hàng Phát triển TP.HCM',
    'SHB - Ngân hàng Sài Gòn - Hà Nội',
    'VIB - Ngân hàng Quốc tế Việt Nam',
    'Sacombank - Ngân hàng Sài Gòn Thương Tín',
    'TPBank - Ngân hàng Tiên Phong',
    'OCB - Ngân hàng Phương Đông',
    'MSB - Ngân hàng Hàng Hải Việt Nam',
    'SeABank - Ngân hàng Đông Nam Á',
    'Eximbank - Ngân hàng Xuất Nhập khẩu Việt Nam',
    'SCB - Ngân hàng Sài Gòn',
    'LPBank - Ngân hàng Bưu điện Liên Việt',
    'BacABank - Ngân hàng Bắc Á',
    'NamABank - Ngân hàng Nam Á',
    'PVcombank - Ngân hàng Đại chúng',
    'ABBANK - Ngân hàng An Bình',
    'VietABank - Ngân hàng Việt Á',
    'NCB - Ngân hàng Quốc dân',
    'VRB - Ngân hàng Liên doanh Việt Nga',
    'KienLongBank - Ngân hàng Kiên Long',
    'GPBank - Ngân hàng Dầu khí Toàn cầu',
    'DongABank - Ngân hàng Đông Á',
    'PublicBank - Ngân hàng Public Việt Nam',
    'HSBC Việt Nam',
    'Standard Chartered Việt Nam',
    'ANZ Việt Nam',
    'Shinhan Bank Việt Nam',
    'CIMB Việt Nam',
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedBank;
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiService.createWithdrawRequest({
        'amount': double.parse(_amountController.text),
        'bankName': _selectedBank!,
        'bankAccountNumber': _accountNumberController.text.trim(),
        'accountHolder': _accountHolderController.text.trim(),
      });

      if (!mounted) return;
      await Provider.of<AuthProvider>(context, listen: false).refreshProfile();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
              SizedBox(height: 12),
              Text('Yêu cầu rút tiền đã được gửi!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('Admin sẽ xem xét và duyệt yêu cầu của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final balance = auth.user?.balance ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('RÚT TIỀN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SỐ DƯ KHẢ DỤNG',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('\$${balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFE53935))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('SỐ TIỀN RÚT (USD) *',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Vui lòng nhập số tiền';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0) return 'Số tiền phải lớn hơn 0';
                  if (amount > balance) return 'Số dư không đủ (tối đa \$${balance.toStringAsFixed(2)})';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const Text('THÔNG TIN TÀI KHOẢN NHẬN TIỀN *',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedBank,
                decoration: InputDecoration(
                  labelText: 'Tên ngân hàng',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                isExpanded: true,
                hint: const Text('Chọn ngân hàng', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: _vietnamBanks.map((bank) => DropdownMenuItem<String>(
                  value: bank,
                  child: Text(bank, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                )).toList(),
                onChanged: (val) => setState(() => _selectedBank = val),
                validator: (val) => val == null ? 'Vui lòng chọn ngân hàng' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tài khoản',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập số tài khoản' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _accountHolderController,
                decoration: InputDecoration(
                  labelText: 'Chủ tài khoản',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập tên chủ tài khoản' : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.logout, color: Colors.white, size: 18),
                  label: Text(_isSubmitting ? 'ĐANG XỬ LÝ...' : 'GỬI YÊU CẦU RÚT TIỀN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
