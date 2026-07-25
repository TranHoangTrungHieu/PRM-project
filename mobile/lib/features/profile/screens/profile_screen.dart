import 'package:mobile/shared/widgets/notification_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/constants/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/core/services/deep_link_handler.dart';
import 'package:mobile/core/widgets/retry_network_image.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).refreshProfile();
      }
    });
  }

  void _showDepositBottomSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _DepositSheetContent(auth: auth),
    );
  }

  void _showEditProfileBottomSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _EditProfileSheetContent(auth: auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final nameValue = user?.name;
    final displayName = (nameValue != null && nameValue.isNotEmpty)
        ? nameValue
        : (user?.username ?? 'Trainer');
    final username = user?.username ?? 'Trainer';
    final email = user?.email ?? '';
    final isAdmin = user?.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('HỒ SƠ TRAINER'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // User stats summary card
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFFFFF5F5),
                              backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                                  ? (isAdmin
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(30),
                                          child: Image.asset(
                                            'assets/admin_logo.png',
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Text(
                                          username.substring(0, min(2, username.length)).toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFFE53935),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                          ),
                                        ))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _showEditProfileBottomSheet(context, auth),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      )
                                    ]
                                  ),
                                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isAdmin) ...[
                      const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SỐ DƯ TRAINER',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${(user?.balance ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showDepositBottomSheet(context, auth),
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                            label: const Text(
                              'NẠP TIỀN',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/withdraw'),
                            icon: const Icon(Icons.logout, size: 16, color: Colors.white),
                            label: const Text(
                              'RÚT TIỀN',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Profile Nav Options List
            _buildProfileOption(
              context,
              icon: Icons.manage_accounts_rounded,
              color: Colors.blueGrey,
              title: 'Chỉnh Sửa Thông Tin Cá Nhân',
              onTap: () => _showEditProfileBottomSheet(context, auth),
            ),
            if (isAdmin)
              _buildProfileOption(
                context,
                icon: Icons.analytics_outlined,
                color: const Color(0xFFE53935),
                title: 'Thống Kê Doanh Số & Mua Hàng',
                route: '/sales-stats',
              ),
            _buildProfileOption(
              context,
              icon: Icons.auto_awesome,
              color: const Color(0xFFF59E0B),
              title: isAdmin ? 'Lịch Sử Mở Gacha Hệ Thống' : 'Mở Gói Bài Pokémon (Gacha)',
              route: '/pack-simulator',
            ),
            if (!isAdmin)
              _buildProfileOption(
                context,
                icon: Icons.folder_special,
                color: const Color(0xFF10B981),
                title: 'Bộ Sưu Tập Của Tôi',
                route: '/my-collection',
              ),
            _buildProfileOption(
              context,
              icon: Icons.gavel,
              color: const Color(0xFF3B82F6),
              title: 'Đấu Giá Thẻ Bài Live',
              route: '/auctions',
            ),
            _buildProfileOption(
              context,
              icon: Icons.map,
              color: const Color(0xFF8B5CF6),
              title: 'Hệ Thống Cửa Hàng Địa Lý',
              route: '/locations',
            ),
            _buildProfileOption(
              context,
              icon: Icons.notifications,
              color: const Color(0xFF6366F1),
              title: 'Thông Báo Hệ Thống',
              route: '/notifications',
            ),
            if (!isAdmin)
              _buildProfileOption(
                context,
                icon: Icons.history,
                color: const Color(0xFF0EA5E9),
                title: 'Lịch Sử Rút Tiền',
                route: '/withdraw-history',
              ),
            if (isAdmin)
              _buildProfileOption(
                context,
                icon: Icons.account_balance,
                color: const Color(0xFFE53935),
                title: 'Quản Lý Rút Tiền',
                route: '/admin-withdraw',
              ),

            const SizedBox(height: 32),

            // Change Password Button
            ElevatedButton.icon(
              onPressed: () => _showChangePasswordSheet(context, auth),
              icon: const Icon(Icons.lock_reset, color: Colors.white, size: 16),
              label: const Text(
                'ĐỔI MẬT KHẢU',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
              ),
            ),

            const SizedBox(height: 12),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () {
                showNotificationPopup(
                  context: context,
                  title: 'Đăng xuất tài khoản',
                  message: 'Bạn có chắc chắn muốn thoát tài khoản Trainer hiện tại không?',
                  type: NotificationType.warning,
                  confirmLabel: 'Đăng xuất',
                  onConfirm: () async {
                    await auth.logout();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                    }
                  },
                  cancelLabel: 'Hủy bỏ',
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white, size: 16),
              label: const Text(
                'ĐĂNG XUẤT TÀI KHOẢN',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _ChangePasswordSheetContent(auth: auth),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? route,
    VoidCallback? onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
        onTap: onTap ?? () => Navigator.pushNamed(context, route!),
      ),
    );
  }
}

class _EditProfileSheetContent extends StatefulWidget {
  final AuthProvider auth;
  const _EditProfileSheetContent({required this.auth});

  @override
  State<_EditProfileSheetContent> createState() => _EditProfileSheetContentState();
}

class _EditProfileSheetContentState extends State<_EditProfileSheetContent> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _avatarController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _uploadingAvatar = false;
  final ImagePicker _avatarPicker = ImagePicker();

  final List<String> _predefinedAvatars = [
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Ash',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Misty',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Red',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Brock',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Cynthia',
  ];

  @override
  void initState() {
    super.initState();
    final user = widget.auth.user;
    _nameController.text = user?.name ?? user?.username ?? '';
    _phoneController.text = user?.phone ?? '';
    _addressController.text = user?.shippingAddress ?? '';
    _avatarController.text = user?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await _avatarPicker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      setState(() => _uploadingAvatar = true);
      final url = await ApiService.uploadImage(File(picked.path));
      setState(() {
        _avatarController.text = url;
        _uploadingAvatar = false;
      });
    } catch (e) {
      setState(() => _uploadingAvatar = false);
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Lỗi tải ảnh: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _showAvatarSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh từ máy ảnh'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAvatar(source);
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.auth.updateProfile({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'shippingAddress': _addressController.text.trim(),
        'avatarUrl': _avatarController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        showStyledSnackBar(
          context: context,
          message: 'Cập nhật hồ sơ Trainer thành công!',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Lỗi cập nhật: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chỉnh Sửa Hồ Sơ Trainer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Display name input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.badge_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                validator: (val) {
                  final value = val?.trim() ?? '';
                  if (value.isEmpty) {
                    return 'Vui lòng nhập tên hiển thị';
                  }
                  if (value.length <= 1) {
                    return 'Tên hiển thị phải có nhiều hơn 1 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn ảnh đại diện Trainer:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              // Predefined Avatar Selector Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _predefinedAvatars.map((url) {
                  final isSelected = _avatarController.text == url;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _avatarController.text = url;
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE53935) : Colors.grey.shade200,
                          width: isSelected ? 3 : 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: RetryNetworkImage(
                          url: url,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _uploadingAvatar ? null : _showAvatarSourceSheet,
                icon: _uploadingAvatar
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_a_photo, size: 16),
                label: Text(_uploadingAvatar ? 'Đang tải ảnh...' : 'Chọn ảnh từ điện thoại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: const Color(0xFF2563EB),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              if (_avatarController.text.isNotEmpty)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                    ),
                    child: ClipOval(
                      child: RetryNetworkImage(
                        url: _avatarController.text,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Custom Avatar URL Input
              TextFormField(
                controller: _avatarController,
                decoration: InputDecoration(
                  labelText: 'Hoặc dán link ảnh tùy chỉnh (URL)',
                  labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.link_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                onChanged: (val) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              // Phone Input
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại liên hệ',
                  labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.phone_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              // Shipping Address Input
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ giao hàng',
                  labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.local_shipping_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 52),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'LƯU THÔNG TIN HỒ SƠ',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheetContent extends StatefulWidget {
  final AuthProvider auth;
  const _ChangePasswordSheetContent({required this.auth});

  @override
  State<_ChangePasswordSheetContent> createState() => _ChangePasswordSheetContentState();
}

class _ChangePasswordSheetContentState extends State<_ChangePasswordSheetContent> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService.changePassword(
        _oldController.text,
        _newController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, bool obscure, VoidCallback toggle) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
        onPressed: toggle,
      ),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Đổi mật khẩu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _oldController,
              obscureText: _obscureOld,
              decoration: _decoration('Mật khẩu cũ', Icons.lock_outline, _obscureOld,
                  () => setState(() => _obscureOld = !_obscureOld)),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu cũ';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: _decoration('Mật khẩu mới', Icons.lock, _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew)),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                if (v.length < 6) return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureNew,
              decoration: _decoration('Xác nhận mật khẩu mới', Icons.lock, _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew)),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                if (v != _newController.text) return 'Mật khẩu xác nhận không khớp';
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Xác nhận đổi mật khẩu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepositSheetContent extends StatefulWidget {
  final AuthProvider auth;
  const _DepositSheetContent({required this.auth});

  @override
  State<_DepositSheetContent> createState() => _DepositSheetContentState();
}

class _DepositSheetContentState extends State<_DepositSheetContent> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double? _selectedPredefinedAmount;
  bool _isSubmitting = false;
  String _selectedMethod = 'VNPAY'; // 'ADMIN' or 'VNPAY'
  bool _dialogActive = false;

  final List<double> _predefinedAmounts = [10.0, 50.0, 100.0, 500.0];

  @override
  void initState() {
    super.initState();
    final role = widget.auth.user?.role;
    // Only real ADMIN accounts get the direct-credit option.
    // Regular users always top up via VNPay QR scan.
    _selectedMethod = role == 'ADMIN' ? 'ADMIN' : 'VNPAY';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dialogActive = false;
    super.dispose();
  }

  void _startPolling(String txnRef, BuildContext dialogCtx) async {
    _dialogActive = true;
    int attempts = 0;
    while (_dialogActive && attempts < 100) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_dialogActive) break;
      attempts++;
      try {
        final status = await ApiService.getTopUpStatus(txnRef);
        if (status == 'SUCCESS') {
          _dialogActive = false;
          if (dialogCtx.mounted) {
            Navigator.pop(dialogCtx); // Close VNPay dialog
          }
          await widget.auth.refreshProfile();
          if (mounted) {
            _showSuccessDialog(double.parse(_amountController.text.trim()));
          }
          break;
        } else if (status == 'FAILED') {
          _dialogActive = false;
          if (dialogCtx.mounted) {
            Navigator.pop(dialogCtx); // Close VNPay dialog
          }
          if (mounted) {
            showStyledSnackBar(
              context: context,
              message: 'Giao dịch nạp tiền thất bại hoặc bị hủy!',
              type: NotificationType.error,
            );
          }
          break;
        }
      } catch (e) {
        print('Error polling top-up status: $e');
      }
    }
  }

  void _showSuccessDialog(double amount) {
    showNotificationPopup(
      context: context,
      title: 'Nạp tiền thành công!',
      message: 'Đã nạp thành công \$${amount.toStringAsFixed(2)} vào tài khoản Trainer của bạn.',
      type: NotificationType.success,
      confirmLabel: 'Xác nhận (OK)',
    );
  }

  void _showVNPayTopUpDialog(String txnRef, String paymentUrl, double amount) {
    final deepLink = DeepLinkHandler();
    deepLink.startListening();
    deepLink.onPaymentResult.listen((result) {
      deepLink.stopListening();
      _dialogActive = false;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      widget.auth.refreshProfile();
      _showSuccessDialog(amount);
    });

    bool pollingStarted = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        if (!pollingStarted) {
          pollingStarted = true;
          _startPolling(txnRef, ctx);
        }
        return StatefulBuilder(
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
                              'NẠP TIỀN VNPAY',
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
                      Text(
                        'Số tiền nạp: \$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bấm vào nút bên dưới để mở trang thanh toán VNPay qua ngân hàng nội địa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(paymentUrl);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            showStyledSnackBar(
                              context: context,
                              message: 'Không thể mở cổng thanh toán VNPay',
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
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Color(0xFFE53935), strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Đang chờ bạn thanh toán...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextButton(
                        onPressed: () {
                          _dialogActive = false;
                          Navigator.pop(ctx); // Close dialog
                          widget.auth.refreshProfile(); // Refresh balance in case they did pay
                        },
                        child: const Text(
                          'ĐÓNG / HỦY BỎ',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
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
        );
      },
    );
  }

  Future<void> _handleDeposit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showStyledSnackBar(
        context: context,
        message: 'Vui lòng nhập số tiền nạp hợp lệ!',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_selectedMethod == 'ADMIN') {
        await widget.auth.deposit(amount);
        if (mounted) {
          Navigator.pop(context); // Close sheet
          _showSuccessDialog(amount);
        }
      } else {
        // VNPay Flow
        final response = await ApiService.createTopUpUrl(amount, platform: 'mobile');
        final paymentUrl = response['paymentUrl'] ?? '';
        final txnRef = response['txnRef'] ?? '';
        
        if (mounted) {
          Navigator.pop(context); // Close sheet
          _showVNPayTopUpDialog(txnRef, paymentUrl, amount);
        }
      }
    } catch (e) {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Lỗi nạp tiền: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nạp Tiền Vào Tài Khoản',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn nhanh số tiền nạp:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _predefinedAmounts.map((amount) {
                final isSelected = _selectedPredefinedAmount == amount;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedPredefinedAmount = amount;
                          _amountController.text = amount.toStringAsFixed(0);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFE53935) : Colors.grey.shade200,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFE53935) : const Color(0xFF475569),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nhập số tiền tùy chỉnh:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE53935),
                    fontSize: 16,
                  ),
                  hintText: '0.00',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
                onChanged: (val) {
                  final parsedVal = double.tryParse(val);
                  if (parsedVal != _selectedPredefinedAmount) {
                    setState(() {
                      _selectedPredefinedAmount = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'XÁC NHẬN NẠP TIỀN',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
