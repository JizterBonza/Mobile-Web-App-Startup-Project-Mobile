import 'package:flutter/material.dart';
import '../constants/constants.dart';
import '../services/api_service.dart';
import 'loginScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Sample user data - in real app, this would come from state management or API
  final Map<String, dynamic> _userData = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
    'phone': '+63 912 345 6789',
    'address': '123 Farm Street, Manila, Philippines',
  };

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
      'title': 'Privacy & Security',
      'icon': Icons.lock_outline,
      'subtitle': 'Account security settings',
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
      appBar: AppBar(
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
          Text(
            _userData['name'],
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 4),
          Text(
            _userData['email'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Handle edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Edit profile functionality coming soon!'),
                  backgroundColor: AppColors.mediumGreen,
                ),
              );
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
          child: Column(
            children: [
              _buildInfoRow(Icons.email_outlined, 'Email', _userData['email']),
              _buildDivider(),
              _buildInfoRow(Icons.phone_outlined, 'Phone', _userData['phone']),
              _buildDivider(),
              _buildInfoRow(
                  Icons.location_on_outlined, 'Address', _userData['address']),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item['title']} functionality coming soon!'),
              backgroundColor: AppColors.mediumGreen,
            ),
          );
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
}
