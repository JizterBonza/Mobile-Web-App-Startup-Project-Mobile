import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../models/addressModel.dart';
import '../provider/address_provider.dart';
import '../services/api_service.dart';
import 'loginScreen.dart';
import 'customerDashboardScreen.dart';
import 'riderDashboardScreen.dart';
import 'cartScreen.dart';
import 'favoriteScreen.dart';
import 'editProfileScreen.dart';
import 'changePasswordScreen.dart';
import 'shippingAddressScreen.dart';

class ProfileScreen extends StatefulWidget {
  final bool hideBottomNavigation;

  const ProfileScreen({super.key, this.hideBottomNavigation = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 3; // Profile tab
  String? _userType;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  AddressModel? _defaultAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userType = await ApiService.getUserType();
      final userName = await ApiService.getUserName();
      final userEmail = await ApiService.getUserEmail();
      final userPhone = await ApiService.getUserMobileNumber();
      final userAddress = await ApiService.getUserAddress();

      // Fetch addresses from provider
      if (mounted) {
        final addressProvider = context.read<AddressProvider>();
        await addressProvider.fetchAddresses();
        _defaultAddress = addressProvider.defaultAddress;
      }

      if (mounted) {
        setState(() {
          _userType = userType?.toLowerCase();
          _userName = userName ?? 'User';
          _userEmail = userEmail ?? 'No email';
          _userPhone = userPhone ?? 'No phone number';
          // Use default address from provider if available
          if (_defaultAddress != null) {
            _userAddress = _defaultAddress!.fullAddress;
          } else {
            _userAddress = userAddress ?? 'No address';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'My Orders',
      'icon': Icons.shopping_bag_outlined,
      'subtitle': 'View order history',
    },
    {
      'title': 'Payment Methods',
      'icon': Icons.payment_outlined,
      'subtitle': 'Manage payment options',
    },
    {
      'title': 'Shipping Address',
      'icon': Icons.location_on_outlined,
      'subtitle': 'Manage delivery addresses',
    },
    {
      'title': 'Notifications',
      'icon': Icons.notifications_outlined,
      'subtitle': 'Manage notification settings',
    },
    {
      'title': 'Change Password',
      'icon': Icons.lock_outline,
      'subtitle': 'Manage your password',
    },
    {
      'title': 'Help & Support',
      'icon': Icons.help_outline,
      'subtitle': 'Get help and contact support',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: widget.hideBottomNavigation
          ? null
          : AppBar(
              title: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.grey[700]),
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            _buildProfileHeader(),
            SizedBox(height: 24),

            // Account information
            _buildAccountSection(),
            SizedBox(height: 24),

            // Menu items
            _buildMenuSection(),
            SizedBox(height: 24),

            // Logout button
            _buildLogoutButton(),
            SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.hideBottomNavigation ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Profile avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.mediumGreen.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 50,
              color: AppColors.mediumGreen,
            ),
          ),
          SizedBox(height: 16),
          _isLoading
              ? CircularProgressIndicator()
              : Column(
                  children: [
                    Text(
                      _userName ?? 'User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _userEmail ?? 'No email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              // Navigate to edit profile screen
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(),
                ),
              );

              // Reload user data if profile was updated
              if (result == true) {
                _loadUserData();
              }
            },
            icon: Icon(Icons.edit, size: 18),
            label: Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _isLoading
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    _buildInfoRow(Icons.email_outlined, 'Email',
                        _userEmail ?? 'No email'),
                    _buildDivider(),
                    _buildInfoRow(Icons.phone_outlined, 'Phone',
                        _userPhone ?? 'No phone number'),
                    _buildDivider(),
                    _buildInfoRow(Icons.location_on_outlined, 'Address',
                        _userAddress ?? 'No address'),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.mediumGreen,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: Colors.grey[200],
    );
  }

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: _menuItems.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> item = entry.value;
              bool isLast = index == _menuItems.length - 1;
              return Column(
                children: [
                  _buildMenuItem(item),
                  if (!isLast) _buildDivider(),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Handle menu item tap
          if (item['title'] == 'Change Password') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangePasswordScreen(),
              ),
            );
          } else if (item['title'] == 'Shipping Address') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShippingAddressScreen(),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item['title']} functionality coming soon!'),
                backgroundColor: AppColors.mediumGreen,
              ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mediumGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item['icon'],
                  color: AppColors.mediumGreen,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      item['subtitle'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Show confirmation dialog
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Logout'),
                content: Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                    ),
                    child: Text('Logout'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Call logout API
                final logoutResult = await ApiService.logout();

                // Dismiss loading indicator
                if (context.mounted) {
                  Navigator.pop(context);
                }

                // Handle result
                if (logoutResult['success'] == true) {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(logoutResult['message'] ?? 'Logout successful!'),
                      backgroundColor: Colors.green[700],
                    ),
                  );

                  // Navigate back to login screen
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false,
                    );
                  }
                } else {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(logoutResult['message'] ??
                          'Logout failed. Please try again.'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              } catch (e) {
                // Dismiss loading indicator if still showing
                if (context.mounted) {
                  Navigator.pop(context);
                }

                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('An error occurred. Please try again.'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red[700],
                ),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PageRoute _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale:
                Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 150),
      reverseTransitionDuration: Duration(milliseconds: 150),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Handle navigation based on selected index and user type
          if (_userType == 'rider') {
            // Rider navigation
            if (index == 0) {
              // Home
              Navigator.pushReplacement(
                context,
                _createFadeRoute(RiderDashboardScreen()),
              );
            } else if (index == 1) {
              // Deliveries - switch to deliveries tab in rider dashboard
              Navigator.pushReplacement(
                context,
                _createFadeRoute(RiderDashboardScreen()),
              );
            } else if (index == 2) {
              // History - switch to history tab in rider dashboard
              Navigator.pushReplacement(
                context,
                _createFadeRoute(RiderDashboardScreen()),
              );
            }
            // index == 3 is Profile, stay on current screen
          } else {
            // Customer navigation
            if (index == 0) {
              // Home
              Navigator.pushReplacement(
                context,
                _createFadeRoute(CustomerDashboardScreen()),
              );
            } else if (index == 1) {
              // Cart
              Navigator.push(
                context,
                _createFadeRoute(CartScreen()),
              ).then((_) {
                // Keep profile selected when returning
                setState(() {
                  _selectedIndex = 3;
                });
              });
            } else if (index == 2) {
              // Favorites
              Navigator.pushReplacement(
                context,
                _createFadeRoute(FavoriteScreen()),
              );
            }
            // index == 3 is Profile, stay on current screen
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.mediumGreen,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        items: _userType == 'rider'
            ? [
                // Rider navigation
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_shipping_outlined),
                  activeIcon: Icon(Icons.local_shipping),
                  label: 'Deliveries',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            : [
                // Customer navigation
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_cart),
                  label: 'Cart',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite),
                  label: 'Favorites',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }
}
