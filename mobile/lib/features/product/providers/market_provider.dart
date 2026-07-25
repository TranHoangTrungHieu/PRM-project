import 'package:flutter/material.dart';
import 'package:mobile/features/product/models/product.dart';
import 'package:mobile/features/auction/models/auction.dart';
import 'package:mobile/core/services/api_service.dart';

class MarketProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Auction> _auctions = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  List<Auction> get auctions => _auctions;
  bool get isLoading => _isLoading;

  // Fetch all products/cards
  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await ApiService.getProducts();
    } catch (e) {
      print('Error loading cards catalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch auctions
  Future<void> fetchAuctions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _auctions = await ApiService.getAuctions();
    } catch (e) {
      print('Error loading auctions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Place incremental bid
  Future<void> placeBid(int auctionId, double amount) async {
    try {
      final updated = await ApiService.placeBid(auctionId, amount);
      final index = _auctions.indexWhere((a) => a.id == auctionId);
      if (index != -1) {
        _auctions[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Create new auction
  Future<void> createAuction(Map<String, dynamic> auctionData) async {
    try {
      final created = await ApiService.createAuction(auctionData);
      _auctions.insert(0, created);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
