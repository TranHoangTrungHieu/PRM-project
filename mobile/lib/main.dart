import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/themes/app_theme.dart';
import 'package:mobile/core/constants/app_routes.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/product/providers/market_provider.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:mobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:mobile/features/product/screens/product_detail_screen.dart';
import 'package:mobile/features/cart/screens/checkout_screen.dart';
import 'package:mobile/features/gacha/screens/pack_simulator_screen.dart';
import 'package:mobile/features/gacha/screens/my_collection_screen.dart';
import 'package:mobile/features/auction/screens/auction_list_screen.dart';
import 'package:mobile/features/location/screens/location_list_screen.dart';
import 'package:mobile/features/notification/screens/notification_list_screen.dart';
import 'package:mobile/features/auction/screens/auction_detail_screen.dart';
import 'package:mobile/features/auction/screens/sales_stats_screen.dart';
import 'package:mobile/features/auction/screens/create_auction_screen.dart';

import 'package:mobile/features/profile/screens/withdraw_screen.dart';
import 'package:mobile/features/profile/screens/withdraw_history_screen.dart';
import 'package:mobile/features/profile/screens/admin_withdraw_screen.dart';
import 'package:mobile/core/services/notification_service.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  _initNotifications();
  runApp(const MyApp());
}

Future<void> _initNotifications() async {
  // Register the FCM token if the user is already logged in (otherwise it
  // will be registered right after a successful login elsewhere).
  await NotificationService.init(
    onTokenReceived: (token) async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('token');
      if (existing != null && existing.isNotEmpty) {
        await ApiService.registerFcmToken(token);
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MarketProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: auth.isLoading
                ? const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : auth.isAuthenticated
                    ? const DashboardScreen()
                    : const LoginScreen(),
            routes: {
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
              AppRoutes.dashboard: (context) => const DashboardScreen(),
              AppRoutes.checkout: (context) => const CheckoutScreen(),
              AppRoutes.packSimulator: (context) => const PackSimulatorScreen(),
              AppRoutes.myCollection: (context) => const MyCollectionScreen(),
              AppRoutes.auctions: (context) => const AuctionListScreen(),
              AppRoutes.locations: (context) => const LocationListScreen(),
              AppRoutes.notifications: (context) => const NotificationListScreen(),
              AppRoutes.salesStats: (context) => const SalesStatsScreen(),
              AppRoutes.createAuction: (context) => const CreateAuctionScreen(),

              AppRoutes.withdraw: (context) => const WithdrawScreen(),
              AppRoutes.withdrawHistory: (context) => const WithdrawHistoryScreen(),
              AppRoutes.adminWithdraw: (context) => const AdminWithdrawScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.productDetail) {
                final args = settings.arguments as int;
                return MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(productId: args),
                );
              }
              if (settings.name == AppRoutes.auctionDetail) {
                final args = settings.arguments as int;
                return MaterialPageRoute(
                  builder: (context) => AuctionDetailScreen(auctionId: args),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
