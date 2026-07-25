import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/product/models/product.dart';
import 'package:mobile/features/cart/models/cart_item.dart';
import 'package:mobile/features/order/models/order.dart';

import 'package:mobile/features/auction/models/auction.dart';
import 'package:mobile/features/chat/models/chat_message.dart';
import 'package:mobile/features/auth/models/user.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/features/product/models/comment.dart';

class ApiService {
  static const String _baseUrlAndroid = 'http://129.80.105.58';
  static const String _baseUrlIos = 'http://129.80.105.58';
  
  // Default to emulator IP, in production this would be the Railway URL
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _baseUrlAndroid;
    }
    return _baseUrlIos;
  }

  static Function()? onAuthFailedCallback;

  // Set auth failed callback to reset UI on token loss
  static void onAuthFailed(Function() callback) {
    onAuthFailedCallback = callback;
  }

  /// Safely extract a List from the 'data' field of a response.
  /// Handles cases where backend returns:
  ///   - data['data'] as a List directly
  ///   - data['data'] as a Map with 'items', 'content', or 'data' sub-key
  static List<dynamic> _extractList(dynamic rawData) {
    if (rawData == null) return [];
    if (rawData is List) return rawData;
    if (rawData is Map) {
      // Try common wrapper keys
      for (final key in ['items', 'content', 'data', 'list', 'results']) {
        if (rawData.containsKey(key) && rawData[key] is List) {
          return rawData[key] as List;
        }
      }
    }
    return [];
  }

  // Get authorization headers
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper method for GET requests with automatic token refresh
  static Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _attemptTokenRefresh();
      if (refreshed) {
        return await http.get(url, headers: await _headers());
      } else {
        _handleSessionExpiry();
      }
    }
    return response;
  }

  // Helper method for POST requests with automatic token refresh
  static Future<http.Response> post(String path, dynamic body) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _attemptTokenRefresh();
      if (refreshed) {
        return await http.post(
          url,
          headers: await _headers(),
          body: jsonEncode(body),
        );
      } else {
        _handleSessionExpiry();
      }
    }
    return response;
  }

  // Helper method for PUT requests
  static Future<http.Response> put(String path, [dynamic body]) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await http.put(
      url,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _attemptTokenRefresh();
      if (refreshed) {
        return await http.put(
          url,
          headers: await _headers(),
          body: body != null ? jsonEncode(body) : null,
        );
      } else {
        _handleSessionExpiry();
      }
    }
    return response;
  }

  // Helper method for DELETE requests
  static Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await http.delete(url, headers: await _headers());

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _attemptTokenRefresh();
      if (refreshed) {
        return await http.delete(url, headers: await _headers());
      } else {
        _handleSessionExpiry();
      }
    }
    return response;
  }

  // Attempt to refresh JWT tokens silently
  static Future<bool> _attemptTokenRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final newAccessToken = data['data']['accessToken'];
          final newRefreshToken = data['data']['refreshToken'];
          await prefs.setString('token', newAccessToken);
          if (newRefreshToken != null) {
            await prefs.setString('refreshToken', newRefreshToken);
          }
          return true;
        }
      }
    } catch (e) {
      print('Token refresh error: $e');
    }
    return false;
  }

  // Clear local session on login failure or expiry
  static void _handleSessionExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('user');
    if (onAuthFailedCallback != null) {
      onAuthFailedCallback!();
    }
  }

  // Resolve Image URL
  static String resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '$baseUrl/img/swsh35/20.png';
    }
    // External Pokémon TCG CDN -> proxy through our own backend (domain/baseUrl)
    if (imageUrl.startsWith('https://images.pokemontcg.io/')) {
      return '$baseUrl/img/${imageUrl.substring('https://images.pokemontcg.io/'.length)}';
    }
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return '$baseUrl$imageUrl';
  }

  // --- API ENDPOINTS MAPPED ---

  // Auth API
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['data']['token']);
      await prefs.setString('refreshToken', data['data']['refreshToken']);
      await prefs.setString('user', jsonEncode(data['data']));
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  static Future<bool> register(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return true;
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  static Future<bool> verifyOtp(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return true;
    }
    throw Exception(data['message'] ?? 'Xác thực OTP thất bại');
  }

  static Future<bool> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return true;
    }
    throw Exception(data['message'] ?? 'Không thể gửi mã OTP');
  }

  static Future<bool> resetPassword(String email, String otp, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'newPassword': newPassword}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return true;
    }
    throw Exception(data['message'] ?? 'Đặt lại mật khẩu thất bại');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        print('Logout endpoint error: $e');
      }
    }
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('user');
  }

  // Register Firebase Cloud Messaging token so the backend can push notifications
  static Future<void> registerFcmToken(String token) async {
    try {
      await post('/api/fcm/token?token=$token', {});
    } catch (_) {
      // non-fatal: push simply won't work until next login
    }
  }

  // Retrieve the current Firebase Cloud Messaging token (if available)
  static Future<String?> getFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      return await messaging.getToken().timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  // Products & Cards
  static Future<List<Product>> getProducts() async {
    final response = await get('/api/products?size=200');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final content = _extractList(data['data']);
        return content.map((p) => Product.fromJson(p)).toList();
      }
    }
    return [];
  }

  static Future<Product> getProductById(int id) async {
    final response = await get('/api/products/$id');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Product.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to load card details');
  }

  static Future<Product> createProduct(Map<String, dynamic> productData) async {
    final response = await post('/api/products', productData);
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return Product.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to create card');
  }

  static Future<Product> updateProduct(int id, Map<String, dynamic> productData) async {
    final response = await put('/api/products/$id', productData);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Product.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to update card');
  }

  static Future<void> deleteProduct(int id) async {
    final response = await delete('/api/products/$id');
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete card');
    }
  }

  // Product Comments
  static Future<List<Comment>> getComments(int productId) async {
    final response = await get('/api/products/$productId/comments');
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((i) => Comment.fromJson(i)).toList();
      }
    }
    return [];
  }

  static Future<Comment> addComment(int productId, String content, {int? parentId}) async {
    final response = await post('/api/products/$productId/comments', {
      'content': content,
      if (parentId != null) 'parentId': parentId,
    });
    if (response.body.isEmpty) {
      throw Exception('Server phản hồi lỗi với mã trạng thái: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Comment.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Không thể gửi nhận xét');
  }

  // Cart
  static Future<List<CartItem>> getCart() async {
    final response = await get('/api/cart');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((i) => CartItem.fromJson(i)).toList();
      }
    }
    return [];
  }

  static Future<List<CartItem>> addToCart(int productId, int quantity) async {
    final response = await post('/api/cart?productId=$productId&quantity=$quantity', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return await getCart();
    }
    throw Exception(data['message'] ?? 'Failed to add card to cart');
  }

  static Future<List<CartItem>> updateCartItemQty(int itemId, int quantity) async {
    final response = await put('/api/cart/$itemId?quantity=$quantity');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return await getCart();
    }
    throw Exception(data['message'] ?? 'Failed to update quantity');
  }

  static Future<List<CartItem>> deleteCartItem(int itemId) async {
    final response = await delete('/api/cart/$itemId');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return await getCart();
    }
    throw Exception(data['message'] ?? 'Failed to delete cart item');
  }

  static Future<void> clearCart() async {
    final response = await delete('/api/cart/clear');
    if (response.statusCode != 200) {
      throw Exception('Failed to clear cart');
    }
  }

  // Orders
  static Future<Order> placeOrder(Map<String, dynamic> orderData) async {
    final response = await post('/api/orders', orderData);
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return Order.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Order placement failed');
  }

  static Future<Order> redeemGacha(Map<String, dynamic> redeemData) async {
    final response = await post('/api/orders/gacha-redeem', redeemData);
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return Order.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Gacha card exchange failed');
  }

  static Future<Order> claimAuction(int id, Map<String, dynamic> claimData) async {
    final response = await post('/api/auctions/$id/claim', claimData);
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return Order.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Không thể nhận giải thưởng đấu giá');
  }

  static Future<List<Order>> getOrders() async {
    final response = await get('/api/orders');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((o) => Order.fromJson(o)).toList();
      }
    }
    return [];
  }

  static Future<void> cancelOrder(int id) async {
    final response = await put('/api/orders/$id/cancel');
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel order');
    }
  }

  static Future<void> adminCancelOrder(int id, String reason) async {
    final response = await put('/api/orders/$id/admin-cancel', {'reason': reason});
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Không thể hủy đơn hàng');
    }
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final response = await post('/api/users/change-password',
        {'oldPassword': oldPassword, 'newPassword': newPassword});
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Đổi mật khẩu thất bại');
    }
  }

  static Future<Order> getOrderById(int id) async {
    final response = await get('/api/orders/$id');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return Order.fromJson(data['data']);
      }
    }
    throw Exception('Failed to fetch order detail');
  }

  static Future<Order> updateOrderShipping(int id, {
    required String recipientName,
    required String phone,
    required String shippingAddress,
  }) async {
    final body = {
      'recipientName': recipientName,
      'phone': phone,
      'shippingAddress': shippingAddress,
    };
    final response = await put('/api/orders/$id/shipping', body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return Order.fromJson(data['data']);
      }
      throw Exception(data['message'] ?? 'Failed to update shipping');
    }
    throw Exception('Failed to update shipping');
  }

  static Future<String> createPaymentUrl(int orderId, {String platform = 'web'}) async {
    final response = await get('/api/payment/create-payment?orderId=$orderId&platform=$platform');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to generate payment URL');
  }

  static Future<Map<String, String>> createTopUpUrl(double amount, {String platform = 'web'}) async {
    final response = await get('/api/payment/create-topup?amount=$amount&platform=$platform');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, String>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to generate top-up URL');
  }

  static Future<String> getTopUpStatus(String txnRef) async {
    final response = await get('/api/payment/topup-status?txnRef=$txnRef');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data']['status'];
    }
    throw Exception(data['message'] ?? 'Failed to get top-up status');
  }

  // Listings
  static Future<List<dynamic>> getListings({bool availableOnly = false}) async {
    final response = await get('/api/listings?availableOnly=$availableOnly');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return _extractList(data['data']);
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>> createListing(int cardId, double price) async {
    final response = await post('/api/listings', {
      'cardId': cardId,
      'price': price,
    });
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Không thể đăng bán thẻ');
  }

  // Auctions
  static Future<List<Auction>> getAuctions() async {
    final response = await get('/api/auctions');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((a) => Auction.fromJson(a)).toList();
      }
    }
    return [];
  }

  static Future<Auction> getAuctionById(int id) async {
    final response = await get('/api/auctions/$id');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Auction.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to load auction details');
  }

  static Future<Auction> placeBid(int id, double amount) async {
    final response = await post('/api/auctions/$id/bid?amount=$amount', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Auction.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Bid placement failed');
  }

  static Future<Auction> createAuction(Map<String, dynamic> auctionData) async {
    final response = await post('/api/auctions', auctionData);
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return Auction.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to create auction');
  }

  // Chat
  static Future<List<ChatMessage>> getChatHistory() async {
    final response = await get('/api/chat');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((m) => ChatMessage.fromJson(m)).toList();
      }
    }
    return [];
  }

  static Future<ChatMessage> sendChatMessage(String message, {String? imageUrl}) async {
    final uri = imageUrl != null
        ? '/api/chat?message=${Uri.encodeComponent(message)}&imageUrl=${Uri.encodeComponent(imageUrl)}'
        : '/api/chat?message=${Uri.encodeComponent(message)}';
    final response = await post(uri, {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return ChatMessage.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to send message');
  }

  // Upload an image and return its public URL
  static Future<String> uploadImage(File file) async {
    final url = Uri.parse('$baseUrl/api/upload/image');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _headers());
    final bytes = await file.readAsBytes();
    final mime = _detectImageMime(bytes) ?? 'image/jpeg';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.path.split('/').last,
        contentType: MediaType.parse(mime),
      ),
    );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 200 && data['success'] == true) {
      return data['url'];
    }
    throw Exception(data['message'] ?? 'Upload failed');
  }

  static String? _detectImageMime(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static Future<List<User>> getChatUsers() async {
    final response = await get('/api/chat/admin/users');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((u) => User.fromJson(u)).toList();
      }
    }
    return [];
  }

  static Future<List<ChatMessage>> getCustomerChatHistory(int userId) async {
    final response = await get('/api/chat/admin/$userId');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = _extractList(data['data']);
        return list.map((m) => ChatMessage.fromJson(m)).toList();
      }
    }
    return [];
  }

  static Future<ChatMessage> sendAdminMessage(int userId, String message, {String? imageUrl}) async {
    final uri = imageUrl != null
        ? '/api/chat/admin/$userId?message=${Uri.encodeComponent(message)}&imageUrl=${Uri.encodeComponent(imageUrl)}'
        : '/api/chat/admin/$userId?message=${Uri.encodeComponent(message)}';
    final response = await post(uri, {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return ChatMessage.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to send admin message');
  }

  // Locations
  static Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await get('/api/locations');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    return [];
  }

  // Notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await get('/api/notifications');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    return [];
  }

  static Future<void> markNotificationRead(int id) async {
    await put('/api/notifications/$id/read');
  }

  // User Profile & Deposit
  static Future<User> getUserProfile() async {
    final response = await get('/api/users/me');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return User.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to fetch profile');
  }

  static Future<User> depositBalance(double amount) async {
    final response = await post('/api/users/deposit?amount=$amount', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return User.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to deposit');
  }

  static Future<User> refundBalance(double amount) async {
    final response = await post('/api/users/refund?amount=$amount', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return User.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to refund');
  }

  static Future<User> deductBalance(double amount) async {
    final response = await post('/api/users/deduct?amount=$amount', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return User.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to deduct balance');
  }

  static Future<void> updateOrderStatus(int orderId, String status) async {
    final response = await put('/api/orders/$orderId/status?status=$status');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Không thể cập nhật trạng thái đơn hàng');
    }
  }

  static Future<User> updateUserProfile(Map<String, dynamic> updateData) async {
    final response = await put('/api/users/me', updateData);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return User.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? 'Cập nhật hồ sơ thất bại: ${data['message']}');
  }

  // Withdraw
  static Future<Map<String, dynamic>> createWithdrawRequest(Map<String, dynamic> body) async {
    final response = await post('/api/withdraw', body);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Không thể tạo yêu cầu rút tiền');
  }

  static Future<List<dynamic>> getMyWithdrawRequests() async {
    final response = await get('/api/withdraw/my');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return _extractList(data['data']);
      }
    }
    return [];
  }

  static Future<List<dynamic>> getAllWithdrawRequests() async {
    final response = await get('/api/withdraw/all');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return _extractList(data['data']);
      }
    }
    return [];
  }

  static Future<void> approveWithdrawRequest(int id) async {
    final response = await put('/api/withdraw/$id/approve');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Không thể duyệt yêu cầu');
    }
  }

  static Future<void> completeWithdrawRequest(int id) async {
    final response = await put('/api/withdraw/$id/complete');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Không thể hoàn tất yêu cầu');
    }
  }

  static Future<void> rejectWithdrawRequest(int id, String reason) async {
    final response = await put('/api/withdraw/$id/reject', {'reason': reason});
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Không thể từ chối yêu cầu');
    }
  }

  static Future<Map<String, dynamic>> getStoreBankInfo() async {
    final response = await get('/api/withdraw/store-bank');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Không thể lấy thông tin ngân hàng');
  }
}
