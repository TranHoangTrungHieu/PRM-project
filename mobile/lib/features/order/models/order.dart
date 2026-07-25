import 'package:mobile/features/product/models/product.dart';

class OrderItem {
  final int id;
  final Product product;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] != null 
          ? (json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0) 
          : 0,
      product: json['product'] != null
          ? Product.fromJson(json['product'])
          : Product(id: 0, name: 'Unknown', brand: '', price: 0.0, stock: 0, isAvailable: false, score: 0.0),
      quantity: json['quantity'] != null 
          ? (json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity'].toString()) ?? 0) 
          : 0,
      price: json['price'] != null ? double.parse(json['price'].toString()) : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'price': price,
    };
  }
}

class Order {
  final int id;
  final int? userId;
  final double totalAmount;
  final String status;
  final String? shippingAddress;
  final String createdAt;
  final List<OrderItem> orderItems;
  final String? recipientName;
  final String? phone;
  final String? paymentMethod;
  final String? note;
  final String? deliveryType;
  final String? cancelReason;
  final String? cancelledBy;
  final String? bankTranDateTime;

  Order({
    required this.id,
    this.userId,
    required this.totalAmount,
    required this.status,
    this.shippingAddress,
    required this.createdAt,
    required this.orderItems,
    this.recipientName,
    this.phone,
    this.paymentMethod,
    this.note,
    this.deliveryType,
    this.cancelReason,
    this.cancelledBy,
    this.bankTranDateTime,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['orderItems'] as List? ?? json['items'] as List? ?? [];
    List<OrderItem> items = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'] != null 
          ? (json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0) 
          : 0,
      userId: json['userId'] != null 
          ? (json['userId'] is int ? json['userId'] : int.tryParse(json['userId'].toString())) 
          : null,
      totalAmount: json['totalAmount'] != null 
          ? double.parse(json['totalAmount'].toString()) 
          : (json['amount'] != null ? double.parse(json['amount'].toString()) : 0.0),
      status: json['status'] ?? 'PENDING',
      shippingAddress: json['shippingAddress'] ?? json['shipping_address'],
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      orderItems: items,
      recipientName: json['recipientName'] ?? json['recipient_name'],
      phone: json['phone'],
      paymentMethod: json['paymentMethod'] ?? json['payment_method'],
      note: json['note'],
      deliveryType: json['deliveryType'] ?? json['delivery_type'],
      cancelReason: json['cancelReason'] ?? json['cancel_reason'],
      cancelledBy: json['cancelledBy'] ?? json['cancelled_by'],
      bankTranDateTime: json['bankTranDateTime'] ?? json['bank_tran_date_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'totalAmount': totalAmount,
      'status': status,
      'shippingAddress': shippingAddress,
      'createdAt': createdAt,
      'orderItems': orderItems.map((i) => i.toJson()).toList(),
      'recipientName': recipientName,
      'phone': phone,
      'paymentMethod': paymentMethod,
      'note': note,
      'deliveryType': deliveryType,
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
    };
  }
}
