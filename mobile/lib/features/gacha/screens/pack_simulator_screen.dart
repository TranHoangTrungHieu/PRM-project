import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/product/models/product.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/core/services/deep_link_handler.dart';
import 'package:mobile/core/widgets/retry_network_image.dart';
import 'package:mobile/features/gacha/services/collection_store.dart';


class BoosterPack {
  final String name;
  final double price;
  final String description;
  final double commonRate;
  final double rareRate;
  final double ultraRareRate;
  final List<Color> colors;
  final String imageUrl;

  BoosterPack({
    required this.name,
    required this.price,
    required this.description,
    required this.commonRate,
    required this.rareRate,
    required this.ultraRareRate,
    required this.colors,
    required this.imageUrl,
  });
}

class PackSimulatorScreen extends StatefulWidget {
  const PackSimulatorScreen({super.key});

  @override
  State<PackSimulatorScreen> createState() => _PackSimulatorScreenState();
}

class _PackSimulatorScreenState extends State<PackSimulatorScreen> with TickerProviderStateMixin {
  bool _isOpening = false;
  BoosterPack? _selectedPack;
  List<Product> _pulledProducts = [];
  List<String> _pulledStatus = [];

  List<Product> _commonPool = [];
  List<Product> _rarePool = [];
  List<Product> _ultraRarePool = [];
  bool _isLoadingPool = true;

  List<dynamic> _gachaHistory = [];
  bool _isLoadingHistory = false;

  String _gachaScreenState = 'SELECT'; 
  int _selectedInteractPackIdx = 2; 
  double _rotationY = 0.0;
  double _ripProgress = 0.0; 
  List<bool> _revealedCards = [false, false, false, false, false, false];
  List<AnimationController> _flipControllers = [];
  bool _ripped = false;
  late PageController _pageController;
  int _revealIndex = 0;
  bool _rareRevealActive = false;
  Product? _activeRareCard;
  late AnimationController _rareEntranceController;
  late AnimationController _shakeController;
  late AnimationController _discardController;
  bool _isFlipped = false;

  Future<void> _loadGachaHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('gacha_history');
    if (historyJson != null) {
      try {
        setState(() {
          _gachaHistory = jsonDecode(historyJson);
        });
      } catch (e) {
        print('Error decoding history: $e');
      }
    }
  }

  final List<BoosterPack> _packs = [
    BoosterPack(
      name: 'Bronze Pack',
      price: 5.0,
      description: 'Gói Đồng cơ bản. Thẻ trên \$10 cực kì hiếm (0.5%).',
      commonRate: 0.995,
      rareRate: 0.0049,
      ultraRareRate: 0.0001,
      colors: [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
      imageUrl: '/images/bronze_pack.png',
    ),
    BoosterPack(
      name: 'Silver Pack',
      price: 15.0,
      description: 'Gói Bạc tiêu chuẩn. Thẻ trên \$10 cực kì hiếm (1.0%).',
      commonRate: 0.99,
      rareRate: 0.009,
      ultraRareRate: 0.001,
      colors: [const Color(0xFFC0C0C0), const Color(0xFF708090)],
      imageUrl: '/images/silver_pack.png',
    ),
    BoosterPack(
      name: 'Gold Pack',
      price: 35.0,
      description: 'Gói Vàng cao cấp. Thẻ trên \$10 cực kì hiếm (2.0%).',
      commonRate: 0.98,
      rareRate: 0.018,
      ultraRareRate: 0.002,
      colors: [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      imageUrl: '/images/gold_pack.png',
    ),
    BoosterPack(
      name: 'Platinum Pack',
      price: 75.0,
      description: 'Gói Bạch Kim đặc biệt. Thẻ trên \$10 rất hiếm (5.0%).',
      commonRate: 0.95,
      rareRate: 0.045,
      ultraRareRate: 0.005,
      colors: [const Color(0xFFE5E4E2), const Color(0xFF708090)],
      imageUrl: '/images/platinum_pack.png',
    ),
    BoosterPack(
      name: 'Diamond Pack',
      price: 150.0,
      description: 'Gói Kim Cương tối thượng. Thẻ trên \$10 hiếm (10.0%).',
      commonRate: 0.90,
      rareRate: 0.09,
      ultraRareRate: 0.01,
      colors: [const Color(0xFFB0DFE5), const Color(0xFF4682B4)],
      imageUrl: '/images/diamond_pack.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.68, initialPage: 300);
    _rareEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _discardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _revealIndex++;
            _isFlipped = false;
          });
          _discardController.reset();
          if (_revealIndex >= 6) {
            setState(() {
              _gachaScreenState = 'RESULTS';
            });
          }
        }
      });
    _loadCardPools();
    _loadGachaHistory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rareEntranceController.dispose();
    _shakeController.dispose();
    _discardController.dispose();
    for (var c in _flipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCardPools() async {
    try {
      final list = await ApiService.getProducts();
      final cards = list.where((p) => p.isCard && p.isAvailable).toList();
      
      setState(() {
        _commonPool = cards.where((c) => c.activePrice < 10.0).toList();
        _rarePool = cards.where((c) => c.activePrice >= 10.0 && c.activePrice < 50.0).toList();
        _ultraRarePool = cards.where((c) => c.activePrice >= 50.0).toList();
        _isLoadingPool = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPool = false;
        });
        _showNotificationDialog(
          title: 'Lỗi Tải Thẻ Bài',
          message: 'Không thể tải danh sách thẻ bài: $e',
          isSuccess: false,
        );
      }
    }
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

  Future<void> _openPack(BoosterPack pack) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if ((auth.user?.balance ?? 0.0) < pack.price) {
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
                        color: const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.08),
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
                        color: const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFFEF4444),
                        size: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Số dư không đủ!',
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bạn cần \$${pack.price.toStringAsFixed(2)} để mở gói này.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Số dư hiện tại: \$${(auth.user?.balance ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDepositBottomSheet(context, auth);
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
                    'NẠP TIỀN NGAY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text(
                    'HỦY BỎ',
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
      return;
    }

    setState(() {
      _isOpening = true;
      _selectedPack = pack;
      _pulledProducts.clear();
      _ripped = false;
      _ripProgress = 0.0;
      _rotationY = 0.0;
      _selectedInteractPackIdx = 2;
      _revealIndex = 0;
      _rareRevealActive = false;
      _activeRareCard = null;
    });

    try {
      await auth.deduct(pack.price);

      final random = Random();
      final List<Product> drawn = [];

      for (int i = 0; i < 6; i++) {
        final double r = random.nextDouble();
        
        List<Product> targetPool;
        if (r < pack.ultraRareRate) {
          targetPool = _ultraRarePool.isNotEmpty 
              ? _ultraRarePool 
              : (_rarePool.isNotEmpty ? _rarePool : _commonPool);
        } else if (r < (pack.ultraRareRate + pack.rareRate)) {
          targetPool = _rarePool.isNotEmpty 
              ? _rarePool 
              : _commonPool;
        } else {
          targetPool = _commonPool.isNotEmpty 
              ? _commonPool 
              : (_rarePool.isNotEmpty ? _rarePool : _ultraRarePool);
        }

        if (targetPool.isNotEmpty) {
          drawn.add(targetPool[random.nextInt(targetPool.length)]);
        }
      }

      if (mounted) {
        for (var c in _flipControllers) {
          c.dispose();
        }
        _flipControllers = List.generate(6, (index) {
          return AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 600),
          );
        });

        setState(() {
          _pulledProducts = drawn;
          _pulledStatus = List.generate(drawn.length, (_) => 'PENDING');
          _revealedCards = List.generate(6, (_) => false);
          _isOpening = false;
          _selectedInteractPackIdx = 0;
          _revealIndex = 0;
          _rareRevealActive = false;
          _activeRareCard = null;
          _isFlipped = false;
          _gachaScreenState = 'INTERACT';
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(300);
          }
        });
        
        try {
          final prefs = await SharedPreferences.getInstance();
          List<dynamic> historyList = [];
          final String? historyJson = prefs.getString('gacha_history');
          if (historyJson != null) {
            historyList = jsonDecode(historyJson);
          }
          historyList.insert(0, {
            'packName': pack.name,
            'openedBy': auth.user?.username ?? 'Trainer',
            'timestamp': DateTime.now().toIso8601String(),
            'cards': drawn.map((c) => c.toJson()).toList(),
          });
          await prefs.setString('gacha_history', jsonEncode(historyList));
          _loadGachaHistory();
        } catch (e) {
          print('Error saving history: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOpening = false;
          _gachaScreenState = 'SELECT';
        });
        _showNotificationDialog(
          title: 'Lỗi Mở Gói Bài',
          message: 'Lỗi khi mở gói bài: $e',
          isSuccess: false,
        );
      }
    }
  }

  void _flipCard(int index) async {
    setState(() {
      _revealedCards[index] = true;
    });
    HapticFeedback.lightImpact();
    
    _flipControllers[index].forward();

    final prod = _pulledProducts[index];
    final isRare = prod.activePrice >= 30.0 || 
        (prod.ram != null && (
            prod.ram!.toLowerCase().contains('rare') ||
            prod.ram!.toLowerCase().contains('vmax') ||
            prod.ram!.toLowerCase().contains('vstar') ||
            prod.ram!.toLowerCase().contains('star')
        ));
    
    if (isRare) {
      await Future.delayed(const Duration(milliseconds: 300));
      for (int i = 0; i < 3; i++) {
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  void _revealNextCard() async {
    if (_revealIndex >= 6) return;
    
    final index = _revealIndex;
    final prod = _pulledProducts[index];
    final isRare = prod.activePrice >= 30.0 || 
        (prod.ram != null && (
            prod.ram!.toLowerCase().contains('rare') ||
            prod.ram!.toLowerCase().contains('vmax') ||
            prod.ram!.toLowerCase().contains('vstar') ||
            prod.ram!.toLowerCase().contains('star')
        ));
    
    if (isRare) {
      setState(() {
        _activeRareCard = prod;
        _rareRevealActive = true;
      });
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      _rareEntranceController.forward(from: 0.0);
      
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();
    } else {
      setState(() {
        _revealedCards[index] = true;
        _revealIndex++;
      });
      HapticFeedback.lightImpact();
      _flipControllers[index].forward();
    }
  }

  Widget _buildStackedDeck() {
    final remainingCount = 6 - _revealIndex;
    if (remainingCount == 0) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 48),
              SizedBox(height: 8),
              Text(
                'Đã mở hết tất cả các thẻ bài!',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              )
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      width: 150,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: List.generate(remainingCount, (stackIdx) {
          final isTopCard = stackIdx == remainingCount - 1;
          final double offsetVal = (remainingCount - 1 - stackIdx) * 3.0;

          return Positioned(
            top: offsetVal,
            left: offsetVal,
            child: GestureDetector(
              onTap: isTopCard ? () {
                _revealNextCard();
              } : null,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateZ(isTopCard ? 0.0 : (remainingCount - 1 - stackIdx) * 0.015 * (stackIdx % 2 == 0 ? 1 : -1)),
                alignment: Alignment.center,
                child: _buildCardBack(width: 130, height: 195),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRareRevealOverlay() {
    if (_activeRareCard == null) return const SizedBox.shrink();
    
    final prod = _activeRareCard!;
    final resolvedImg = ApiService.resolveImageUrl(prod.imageUrl);

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _rareEntranceController,
        builder: (context, child) {
          final scale = Tween<double>(begin: 0.0, end: 1.0)
              .animate(CurvedAnimation(
                parent: _rareEntranceController,
                curve: Curves.elasticOut,
              ))
              .value;

          final rotateAngle = Tween<double>(begin: pi * 1.5, end: 0.0)
              .animate(CurvedAnimation(
                parent: _rareEntranceController,
                curve: Curves.easeOutCubic,
              ))
              .value;

          return Container(
            color: Colors.black.withOpacity(0.85),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 420,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amberAccent.withOpacity(0.6),
                            blurRadius: 100,
                            spreadRadius: 30,
                          ),
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 120,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: GachaRareEffectWidget(
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '✨ THẺ SIÊU CẤP XUẤT HIỆN! ✨',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.red,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prod.ram?.toUpperCase() ?? 'RARE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..scale(scale)
                        ..rotateY(rotateAngle),
                      alignment: Alignment.center,
                      child: Container(
                        width: 200,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.amberAccent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: RetryNetworkImage(
                                  url: resolvedImg,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              prod.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${prod.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _rareRevealActive = false;
                          _activeRareCard = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black87,
                        elevation: 5,
                        shadowColor: Colors.amber.withOpacity(0.5),
                        minimumSize: const Size(180, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'TIẾP TỤC',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _triggerTearEffect() async {
    setState(() {
      _ripped = true;
    });
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _revealedCards = List.generate(6, (_) => false);
        _revealIndex = 0;
        _isFlipped = false;
        _gachaScreenState = 'REVEAL';
      });
    }
  }

  void _showNotificationDialog({
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ĐỒNG Ý',
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
  }

  Future<void> _addToLocalCollection(int cardId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;
    if (userId == null) return;
    List<int> ownedIds = await CollectionStore.getOwnedCardIds(userId);
    ownedIds.add(cardId);
    await CollectionStore.setOwnedCardIds(userId, ownedIds);
  }

  Future<void> _collectCard(int index, Product prod) async {
    await _addToLocalCollection(prod.id);
    setState(() {
      _pulledStatus[index] = 'COLLECTED';
    });
    if (mounted) {
      _showNotificationDialog(
        title: 'Thành Công',
        message: 'Đã thêm ${prod.name} vào bộ sưu tập của bạn!',
        isSuccess: true,
      );
    }
  }

  Future<void> _sellCardBack(int index, Product prod) async {
    final double sellPrice = prod.activePrice * 0.8;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await auth.refund(sellPrice);
      setState(() {
        _pulledStatus[index] = 'SOLD';
      });
      if (mounted) {
        _showNotificationDialog(
          title: 'Đã Bán Thẻ Bài',
          message: 'Đã bán lại ${prod.name} cho cửa hàng!\nNhận +\$${sellPrice.toStringAsFixed(2)}',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showNotificationDialog(
          title: 'Lỗi Bán Lại',
          message: 'Lỗi bán lại: $e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _collectAllCards() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;
    if (userId == null) return;
    List<int> ownedIds = await CollectionStore.getOwnedCardIds(userId);
    
    int addedCount = 0;
    for (int i = 0; i < _pulledProducts.length; i++) {
      if (_pulledStatus[i] == 'PENDING') {
        ownedIds.add(_pulledProducts[i].id);
        _pulledStatus[i] = 'COLLECTED';
        addedCount++;
      }
    }
    
    if (addedCount > 0) {
      await CollectionStore.setOwnedCardIds(userId, ownedIds);
      setState(() {});
      if (mounted) {
        _showNotificationDialog(
          title: 'Thành Công',
          message: 'Đã thêm tất cả $addedCount thẻ bài vào bộ sưu tập!',
          isSuccess: true,
        );
      }
    }
  }

  Future<void> _sellAllCards() async {
    double totalRefund = 0.0;
    int soldCount = 0;
    for (int i = 0; i < _pulledProducts.length; i++) {
      if (_pulledStatus[i] == 'PENDING') {
        totalRefund += _pulledProducts[i].activePrice * 0.8;
        _pulledStatus[i] = 'SOLD';
        soldCount++;
      }
    }
    
    if (soldCount > 0) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      try {
        await auth.refund(totalRefund);
        setState(() {});
        if (mounted) {
          _showNotificationDialog(
            title: 'Bán Thành Công',
            message: 'Đã bán lại $soldCount thẻ bài!\nNhận +\$${totalRefund.toStringAsFixed(2)}',
            isSuccess: true,
          );
        }
      } catch (e) {
        if (mounted) {
          _showNotificationDialog(
            title: 'Lỗi Bán Tất Cả',
            message: 'Lỗi khi bán lại tất cả: $e',
            isSuccess: false,
          );
        }
      }
    }
  }

  Widget _buildCardActions(int index, Product prod) {
    final status = _pulledStatus[index];
    if (status == 'COLLECTED') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Đã cất BST 🎒',
          style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    } else if (status == 'SOLD') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Đã bán +\$${(prod.activePrice * 0.8).toStringAsFixed(1)} 💵',
          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => _collectCard(index, prod),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 24),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text(
            'Cất sưu tập',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        ElevatedButton(
          onPressed: () => _sellCardBack(index, prod),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 24),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'Bán lại (-\$${(prod.activePrice * 0.2).toStringAsFixed(0)})',
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPackCard(BoosterPack pack) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: pack.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RetryNetworkImage(
                url: ApiService.resolveImageUrl(pack.imageUrl),
                width: 70,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pack.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tỉ lệ rơi: Thường ${(pack.commonRate * 100).toStringAsFixed(1)}% | Hiếm ${(pack.rareRate * 100).toStringAsFixed(2)}% | Siêu Hiếm ${(pack.ultraRareRate * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${pack.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: pack.colors[0],
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _openPack(pack),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'MỞ GÓI',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminHistoryView() {
    if (_gachaHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 64,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lịch sử trống',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chưa có lịch sử mở thẻ gacha nào trên hệ thống.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _gachaHistory.length,
      itemBuilder: (context, index) {
        final item = _gachaHistory[index];
        final String packName = item['packName'] ?? 'Booster Pack';
        final String openedBy = item['openedBy'] ?? 'Trainer';
        final String timestampStr = item['timestamp'] ?? '';
        final List<dynamic> cardsJson = item['cards'] ?? [];
        final List<Product> cards = cardsJson.map((c) => Product.fromJson(c)).toList();
        
        final packInfo = _packs.firstWhere(
          (p) => p.name == packName,
          orElse: () => _packs[0],
        );

        String displayTime = '';
        if (timestampStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(timestampStr).toLocal();
            displayTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
          } catch (_) {
            displayTime = timestampStr;
          }
        }

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: packInfo.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        packName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          displayTime,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    const Text(
                      'Người mở: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      openedBy,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                const Text(
                  'Thẻ bài mở được (Bấm để xem chi tiết):',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: cards.length,
                    itemBuilder: (ctx, cIdx) {
                      final c = cards[cIdx];
                      final resolvedImg = ApiService.resolveImageUrl(c.imageUrl);
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/product-detail', arguments: c.id);
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Expanded(
                                child: RetryNetworkImage(
                                  url: resolvedImg,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractScreen(AuthProvider auth) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'GÓI BÀI MAY MẮN CỦA BẠN 🍀',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Hệ thống đã chuẩn bị 6 gói bài nằm cạnh nhau. Hãy vuốt ngang trái/phải để xoay vòng tìm gói bài bạn muốn, sau đó xác nhận mở gói!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 35),
        
        // Carousel PageView containing the 6 packs side-by-side
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _pageController,
            itemCount: 10000,
            onPageChanged: (index) {
              setState(() {
                _selectedInteractPackIdx = index % 6;
              });
              HapticFeedback.lightImpact();
            },
            itemBuilder: (context, index) {
              final packIdx = index % 6;
              
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double pageOffset = 0.0;
                  if (_pageController.position.haveDimensions) {
                    pageOffset = _pageController.page! - index;
                  } else {
                    pageOffset = (300 - index).toDouble();
                  }
                  
                  // scale factor: central item is 1.0, side items are 0.8
                  final double scale = (1.0 - (pageOffset.abs() * 0.2)).clamp(0.8, 1.0);
                  
                  // rotation Y: rotation angle depending on scroll offset
                  final double rotateY = (-pageOffset * 0.45).clamp(-pi / 3, pi / 3);
                  
                  // translate X: pull items closer
                  final double translateX = pageOffset * 22.0;

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015) // perspective
                      ..translate(translateX, 0.0, 0.0)
                      ..scale(scale)
                      ..rotateY(rotateY),
                    alignment: Alignment.center,
                    child: child,
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPackFoilDesign(_selectedPack!, 0.0),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedInteractPackIdx == packIdx 
                            ? const Color(0xFFE53935) 
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedInteractPackIdx == packIdx ? [
                          BoxShadow(
                            color: const Color(0xFFE53935).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ] : [],
                      ),
                      child: Text(
                        'GÓI SỐ ${packIdx + 1}',
                        style: TextStyle(
                          color: _selectedInteractPackIdx == packIdx ? Colors.white : const Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 25),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _gachaScreenState = 'RIP';
              _ripProgress = 0.0;
            });
          },
          icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
          label: const Text(
            'XÁC NHẬN CHỌN GÓI NÀY',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(220, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRipScreen() {
    final double topDisplacement = _ripped ? -250.0 : 0.0;
    final double bottomDisplacement = _ripped ? 250.0 : 0.0;
    final double opacity = _ripped ? 0.0 : 1.0;

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'XÉ VỎ GÓI BÀI! ⚡',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hãy vuốt ngang qua gói bài để xé vỏ bao bì!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 50),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (_ripped) return;
            final screenWidth = MediaQuery.of(context).size.width;
            setState(() {
              _ripProgress += details.delta.dx / (screenWidth * 0.5);
              _ripProgress = _ripProgress.clamp(0.0, 1.0);
            });
            if (_ripProgress >= 1.0) {
              _triggerTearEffect();
            }
          },
          child: Container(
            height: 380,
            width: double.infinity,
            color: Colors.transparent, // Makes the entire wrapper zone hit-testable
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_ripped)
                  const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFD700),
                      size: 100,
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  top: 60 + topDisplacement,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: opacity,
                    child: ClipRect(
                      clipper: FoilTopClipper(),
                      child: _buildPackFoilDesign(_selectedPack!, 0.0),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  top: 60 + bottomDisplacement,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: opacity,
                    child: ClipRect(
                      clipper: FoilBottomClipper(),
                      child: _buildPackFoilDesign(_selectedPack!, 0.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!_ripped)
          Text(
            'Tiến trình xé: ${(_ripProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE53935),
              fontSize: 14,
            ),
          )
        else
          const Text(
            'ĐÃ XÉ XONG! Đang mở bài...',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildRevealScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        const Text(
          'MỞ GÓI BÀI POKÉMON! 🃏',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Chạm để lật mở, chạm tiếp để vuốt qua thẻ tiếp theo!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: SizedBox(
            height: 360,
            width: 240,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Cards from bottom to top
                for (int i = 5; i >= _revealIndex; i--) ...[
                  if (i > _revealIndex) ...[
                    // Underside face-down card
                    _buildOffsetDeckCard(i),
                  ] else ...[
                    // Top active card
                    _buildTopDeckCard(i),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        // Progress text
        Text(
          'Thẻ thứ ${_revealIndex + 1} trên 6',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE53935),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  void _handleCardTap() async {
    if (_revealIndex >= 6 || _discardController.isAnimating) return;

    if (!_isFlipped) {
      // 1. Flip card face-up
      setState(() {
        _isFlipped = true;
      });
      HapticFeedback.lightImpact();
      _flipControllers[_revealIndex].forward();

      // Check if it's a rare card
      final prod = _pulledProducts[_revealIndex];
      final isRare = prod.activePrice >= 30.0 || 
          (prod.ram != null && (
              prod.ram!.toLowerCase().contains('rare') ||
              prod.ram!.toLowerCase().contains('vmax') ||
              prod.ram!.toLowerCase().contains('vstar') ||
              prod.ram!.toLowerCase().contains('star')
          ));

      if (isRare) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() {
            _activeRareCard = prod;
            _rareRevealActive = true;
          });
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0.0);
          _rareEntranceController.forward(from: 0.0);
          
          await Future.delayed(const Duration(milliseconds: 200));
          HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 150));
          HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 150));
          HapticFeedback.heavyImpact();
        }
      }
    } else {
      // 2. Discard card and show next card
      _discardController.forward(from: 0.0);
      HapticFeedback.mediumImpact();
    }
  }

  Widget _buildOffsetDeckCard(int i) {
    final double offsetVal = (i - _revealIndex) * 4.0;
    final double rotateZ = (i - _revealIndex) * 0.025 * (i % 2 == 0 ? 1 : -1);

    return Positioned(
      top: offsetVal,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateZ(rotateZ),
        alignment: Alignment.center,
        child: _buildCardBack(width: 220, height: 330),
      ),
    );
  }

  Widget _buildTopDeckCard(int i) {
    return Positioned(
      top: 0,
      child: GestureDetector(
        onTap: _handleCardTap,
        child: AnimatedBuilder(
          animation: _discardController,
          builder: (context, child) {
            final double translateX = -450.0 * _discardController.value;
            final double rotateZ = -0.35 * _discardController.value;
            final double opacity = (1.0 - _discardController.value).clamp(0.0, 1.0);
            
            return Transform(
              transform: Matrix4.identity()
                ..translate(translateX, 0.0, 0.0)
                ..rotateZ(rotateZ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            );
          },
          child: AnimatedBuilder(
            animation: _flipControllers[i],
            builder: (context, child) {
              final angle = pi - (_flipControllers[i].value * pi);
              final showFront = angle < pi / 2;

              if (showFront) {
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: _buildFrontCard(i, width: 220, height: 330),
                );
              } else {
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardBack(width: 220, height: 330),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFrontCard(int index, {double width = 220, double height = 330}) {
    final prod = _pulledProducts[index];
    final resolvedImg = ApiService.resolveImageUrl(prod.imageUrl);
    final isRare = prod.activePrice >= 30.0 || 
        (prod.ram != null && (
            prod.ram!.toLowerCase().contains('rare') ||
            prod.ram!.toLowerCase().contains('vmax') ||
            prod.ram!.toLowerCase().contains('vstar') ||
            prod.ram!.toLowerCase().contains('star')
        ));

    Widget cardWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RetryNetworkImage(
                url: resolvedImg,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            prod.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: width * 0.06,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '\$${prod.price.toStringAsFixed(2)}',
            style: TextStyle(
              color: const Color(0xFFE53935),
              fontWeight: FontWeight.w900,
              fontSize: width * 0.055,
            ),
          ),
        ],
      ),
    );

    if (isRare) {
      cardWidget = GachaRareEffectWidget(child: cardWidget);
    }

    return cardWidget;
  }

  Widget _buildResultsScreen(AuthProvider auth) {
    return Column(
      children: [
        const Text(
          'KẾT QUẢ MỞ GÓI BÀI! 🎉',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Từ ${_selectedPack!.name} | Phí: -\$${_selectedPack!.price.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 335,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: _pulledProducts.length,
            itemBuilder: (context, index) {
              final prod = _pulledProducts[index];
              final resolvedImg = ApiService.resolveImageUrl(prod.imageUrl);
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(
                      child: RetryNetworkImage(
                        url: resolvedImg,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      prod.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prod.ram ?? 'Rare',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${prod.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCardActions(index, prod),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_pulledStatus.contains('PENDING')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _collectAllCards,
                    icon: const Icon(Icons.library_add_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'THÊM HẾT VÀO BST',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sellAllCards,
                    icon: const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'BÁN HẾT CHO SHOP',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        ElevatedButton(
          onPressed: () => _openPack(_selectedPack!),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(200, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'MỞ TIẾP GÓI NÀY',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            setState(() {
              _pulledProducts.clear();
              _pulledStatus.clear();
              _gachaScreenState = 'SELECT';
            });
          },
          child: const Text(
            'Quay lại',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRotatingPack(BoosterPack pack, double angle) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) 
        ..rotateY(angle),
      alignment: Alignment.center,
      child: _buildPackFoilDesign(pack, angle),
    );
  }

  Widget _buildPackFoilDesign(BoosterPack pack, double angle) {
    final normalizedAngle = angle % (2 * pi);
    final isFront = normalizedAngle < pi / 2 || normalizedAngle > 3 * pi / 2;

    if (isFront) {
      return Container(
        width: 180,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: pack.colors[0].withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ],
          border: Border.all(color: Colors.white30, width: 2),
          image: DecorationImage(
            image: NetworkImage(ApiService.resolveImageUrl(pack.imageUrl)),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildCrimpedEdge(),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildCrimpedEdge(),
            ),
          ],
        ),
      );
    } else {
      return Transform(
        transform: Matrix4.identity()..rotateY(pi),
        alignment: Alignment.center,
        child: Container(
          width: 180,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
              )
            ],
            border: Border.all(color: Colors.white30, width: 2),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildCrimpedEdge(color: Colors.grey.shade400),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildCrimpedEdge(color: Colors.grey.shade400),
              ),
              Center(
                child: Container(
                  width: 20,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 2,
                        offset: const Offset(2, 0),
                      )
                    ],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code, color: Colors.grey.shade600, size: 30),
                    const SizedBox(height: 12),
                    Text(
                      'BARCODE & SAFETY INFO',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCrimpedEdge({Color? color}) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: color ?? Colors.white24,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          15,
          (index) => Container(
            width: 2,
            height: 10,
            color: Colors.black12,
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack({double width = 120, double height = 180}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0F24), Color(0xFF1E3A8A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background cosmic stars
            Positioned(
              top: height * 0.15,
              left: width * 0.2,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: height * 0.2,
              right: width * 0.15,
              child: Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
              ),
            ),
            
            // Concentric orbit lines
            Container(
              width: width * 0.75,
              height: width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.15), width: 1.5),
              ),
            ),
            Container(
              width: width * 0.58,
              height: width * 0.58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25), width: 1),
              ),
            ),

            // Inner golden border frame
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Corner gold stars
            Positioned(
              top: 10, left: 10,
              child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 10),
            ),
            Positioned(
              top: 10, right: 10,
              child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 10),
            ),
            Positioned(
              bottom: 10, left: 10,
              child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 10),
            ),
            Positioned(
              bottom: 10, right: 10,
              child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 10),
            ),

            // Middle gold poke-ball crest
            Center(
              child: Container(
                width: width * 0.35,
                height: width * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Center(
                  child: Container(
                    width: width * 0.22,
                    height: width * 0.22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0A0F24),
                    ),
                    child: Center(
                      child: Container(
                        width: width * 0.1,
                        height: width * 0.1,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Text top
            Positioned(
              top: height * 0.12,
              child: Text(
                'POKÉCARD',
                style: TextStyle(
                  color: const Color(0xFFFFD700),
                  fontSize: width * 0.065,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    )
                  ],
                ),
              ),
            ),

            // Text bottom
            Positioned(
              bottom: height * 0.12,
              child: Text(
                'TRAINER',
                style: TextStyle(
                  color: const Color(0xFFFFD700),
                  fontSize: width * 0.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isAdmin = user?.role == 'ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isAdmin ? 'LỊCH SỬ MỞ GACHA' : 'MỞ GÓI BÀI POKÉMON'),
      ),
      body: Stack(
        children: [
          _isLoadingPool
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
              : AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final double shakeOffset = sin(_shakeController.value * 4 * pi) * 8.0;
                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: child,
                    );
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isAdmin) ...[
                          const Row(
                            children: [
                              Icon(Icons.history_rounded, color: Color(0xFFE53935), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'LỊCH SỬ MỞ THẺ HỆ THỐNG',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildAdminHistoryView(),
                        ] else ...[
                          if (_gachaScreenState == 'SELECT') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFEF2F2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Color(0xFFE53935),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SỐ DƯ TRAINER',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${(user?.balance ?? 0.0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const Text(
                              'HÃY CHỌN GÓI BÀI ĐỂ MỞ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),

                            ..._packs.map((pack) => _buildPackCard(pack)),
                          ] else if (_gachaScreenState == 'INTERACT') ...[
                            _buildInteractScreen(auth),
                          ] else if (_gachaScreenState == 'RIP') ...[
                            _buildRipScreen(),
                          ] else if (_gachaScreenState == 'REVEAL') ...[
                            _buildRevealScreen(),
                          ] else if (_gachaScreenState == 'RESULTS') ...[
                            _buildResultsScreen(auth),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
          if (_rareRevealActive) _buildRareRevealOverlay(),
        ],
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
  void _showNotificationDialog({
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ĐỒNG Ý',
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
  }

  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double? _selectedPredefinedAmount;
  bool _isSubmitting = false;
  String _selectedMethod = 'VNPAY'; // 'ADMIN' or 'VNPAY'
  bool _dialogActive = false;

  final List<double> _predefinedAmounts = [10.0, 50.0, 100.0, 500.0];

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
            _showNotificationDialog(
              title: 'Thất Bại',
              message: 'Giao dịch nạp tiền thất bại hoặc bị hủy!',
              isSuccess: false,
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
                'Nạp tiền thành công!',
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
                  'Đã nạp thành công \$${amount.toStringAsFixed(2)} vào tài khoản Trainer của bạn.',
                  style: const TextStyle(
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
                onPressed: () => Navigator.pop(ctx),
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
                  'XÁC NHẬN (OK)',
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
      if (mounted) {
        _showSuccessDialog(amount);
      }
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
                        'Quét mã QR dưới đây bằng App Ngân hàng hoặc Ví VNPay để thực hiện giao dịch thanh toán.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      
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
                      
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(paymentUrl);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            _showNotificationDialog(
                              title: 'Lỗi Mở Cổng',
                              message: 'Không thể mở cổng thanh toán VNPay',
                              isSuccess: false,
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
                          _showNotificationDialog(
                            title: 'Sao Chép',
                            message: 'Đã sao chép liên kết thanh toán VNPay!',
                            isSuccess: true,
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
      _showNotificationDialog(
        title: 'Nhập Sai',
        message: 'Vui lòng nhập số tiền nạp hợp lệ!',
        isSuccess: false,
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
        _showNotificationDialog(
          title: 'Lỗi Nạp Tiền',
          message: 'Lỗi nạp tiền: $e',
          isSuccess: false,
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

class FoilTopClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width, size.height / 2);
  }
  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class FoilBottomClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, size.height / 2, size.width, size.height);
  }
  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class GachaRareEffectWidget extends StatefulWidget {
  final Widget child;
  const GachaRareEffectWidget({super.key, required this.child});

  @override
  State<GachaRareEffectWidget> createState() => _GachaRareEffectWidgetState();
}

class _GachaRareEffectWidgetState extends State<GachaRareEffectWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ParticleModel> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Initialize particles
    for (int i = 0; i < 20; i++) {
      _particles.add(ParticleModel(
        x: _random.nextDouble() * 120,
        y: 180.0,
        vx: (_random.nextDouble() - 0.5) * 1.5,
        vy: -(_random.nextDouble() * 1.5 + 0.5),
        life: _random.nextDouble(),
        color: Colors.amberAccent.withOpacity(0.8),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.01;
      if (p.life <= 0) {
        p.x = _random.nextDouble() * 120;
        p.y = 180.0;
        p.vx = (_random.nextDouble() - 0.5) * 1.5;
        p.vy = -(_random.nextDouble() * 1.5 + 0.5);
        p.life = 1.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateParticles();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Pulsing glow background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5 + 0.3 * sin(_controller.value * 2 * pi)),
                      blurRadius: 20 + 10 * sin(_controller.value * 2 * pi),
                      spreadRadius: 4 + 2 * sin(_controller.value * 2 * pi),
                    ),
                  ],
                ),
              ),
            ),
            widget.child,
            // Particles
            Positioned.fill(
              child: CustomPaint(
                painter: ParticlePainter(particles: _particles),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ParticleModel {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  Color color;

  ParticleModel({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });
}

class ParticlePainter extends CustomPainter {
  final List<ParticleModel> particles;
  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      if (p.life > 0) {
        paint.color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(p.x, p.y), 2.0 + p.life * 3.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CardBackSeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height);
    path.moveTo(size.width, 0);
    path.lineTo(0, size.height);
    path.addRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
