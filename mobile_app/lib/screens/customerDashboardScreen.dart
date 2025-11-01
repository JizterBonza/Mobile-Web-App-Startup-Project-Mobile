import 'package:flutter/material.dart';
import '../constants/constants.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  int _selectedIndex = 0;

  // Sample data for the dashboard
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Seeds', 'icon': Icons.eco},
    {'name': 'Fertilizers', 'icon': Icons.science},
    {'name': 'Tools', 'icon': Icons.build},
    {'name': 'Equipment', 'icon': Icons.agriculture},
  ];

  final List<Map<String, dynamic>> _featuredProducts = [
    {
      'name': 'Organic Fertilizer',
      'price': '\$24.99',
      'rating': 4.6,
    },
    {
      'name': 'Garden Spade',
      'price': '\$18.50',
      'rating': 4.9,
    },
    {
      'name': 'Watering Can',
      'price': '\$15.99',
      'rating': 4.7,
    },
  ];

  final List<Map<String, dynamic>> _recentOrders = [
    {
      'id': '#12345',
      'status': 'Delivered',
      'date': '2024-01-15',
      'total': '\$45.99',
    },
    {
      'id': '#12346',
      'status': 'In Transit',
      'date': '2024-01-18',
      'total': '\$32.50',
    },
    {
      'id': '#12347',
      'status': 'Processing',
      'date': '2024-01-20',
      'total': '\$28.75',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting and profile
              _buildHeader(),
              SizedBox(height: 24),

              // Search bar
              _buildSearchBar(),
              SizedBox(height: 24),

              // Categories section
              // _buildCategoriesSection(),
              // SizedBox(height: 24),

              // // Featured products
              // _buildFeaturedProducts(),
              // SizedBox(height: 24),

              // // Recent orders
              // _buildRecentOrders(),
              // SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Welcome to AgrifyConnect',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.mediumGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.mediumGreen.withOpacity(0.3)),
          ),
          child: Icon(
            Icons.person,
            color: AppColors.mediumGreen,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for products...',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: AppColors.mediumGreen),
          suffixIcon: Icon(Icons.filter_list, color: Colors.grey[600]),
        ),
      ),
    );
  }

  // Widget _buildCategoriesSection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Categories',
  //         style: TextStyle(
  //           fontSize: 20,
  //           fontWeight: FontWeight.bold,
  //           color: Colors.grey[900],
  //         ),
  //       ),
  //       SizedBox(height: 16),
  //       GridView.builder(
  //         shrinkWrap: true,
  //         physics: NeverScrollableScrollPhysics(),
  //         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //           crossAxisCount: 2,
  //           crossAxisSpacing: 12,
  //           mainAxisSpacing: 12,
  //           childAspectRatio: 1.5,
  //         ),
  //         itemCount: _categories.length,
  //         itemBuilder: (context, index) {
  //           final category = _categories[index];
  //           return Container(
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(12),
  //               border: Border.all(color: Colors.grey[300]!),
  //             ),
  //             child: Material(
  //               color: Colors.transparent,
  //               child: InkWell(
  //                 borderRadius: BorderRadius.circular(12),
  //                 onTap: () {
  //                   // Handle category tap
  //                 },
  //                 child: Padding(
  //                   padding: EdgeInsets.all(16),
  //                   child: Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Icon(
  //                         category['icon'],
  //                         size: 32,
  //                         color: AppColors.mediumGreen,
  //                       ),
  //                       SizedBox(height: 8),
  //                       Text(
  //                         category['name'],
  //                         style: TextStyle(
  //                           fontSize: 14,
  //                           fontWeight: FontWeight.w600,
  //                           color: Colors.grey[800],
  //                         ),
  //                         textAlign: TextAlign.center,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           );
  //         },
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildFeaturedProducts() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(
  //             'Featured Products',
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //               color: Colors.grey[900],
  //             ),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               // Handle view all
  //             },
  //             child: Text(
  //               'View All',
  //               style: TextStyle(
  //                 color: AppColors.mediumGreen,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //       SizedBox(height: 16),
  //       SizedBox(
  //         height: 160,
  //         child: ListView.builder(
  //           scrollDirection: Axis.horizontal,
  //           itemCount: _featuredProducts.length,
  //           itemBuilder: (context, index) {
  //             final product = _featuredProducts[index];
  //             return Container(
  //               width: 140,
  //               margin: EdgeInsets.only(right: 12),
  //               decoration: BoxDecoration(
  //                 color: Colors.white,
  //                 borderRadius: BorderRadius.circular(12),
  //                 border: Border.all(color: Colors.grey[300]!),
  //               ),
  //               child: Material(
  //                 color: Colors.transparent,
  //                 child: InkWell(
  //                   borderRadius: BorderRadius.circular(12),
  //                   onTap: () {
  //                     // Handle product tap
  //                   },
  //                   child: Padding(
  //                     padding: EdgeInsets.all(12),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Container(
  //                           height: 60,
  //                           width: double.infinity,
  //                           decoration: BoxDecoration(
  //                             color: AppColors.mediumGreen.withOpacity(0.1),
  //                             borderRadius: BorderRadius.circular(8),
  //                             border: Border.all(
  //                                 color:
  //                                     AppColors.mediumGreen.withOpacity(0.2)),
  //                           ),
  //                           child: Icon(
  //                             Icons.shopping_bag,
  //                             color: AppColors.mediumGreen,
  //                             size: 24,
  //                           ),
  //                         ),
  //                         SizedBox(height: 8),
  //                         Text(
  //                           product['name'],
  //                           style: TextStyle(
  //                             fontSize: 12,
  //                             fontWeight: FontWeight.w600,
  //                             color: Colors.grey[800],
  //                           ),
  //                           maxLines: 2,
  //                           overflow: TextOverflow.ellipsis,
  //                         ),
  //                         SizedBox(height: 4),
  //                         Row(
  //                           mainAxisSize: MainAxisSize.min,
  //                           children: [
  //                             Icon(
  //                               Icons.star,
  //                               size: 12,
  //                               color: Colors.grey[600],
  //                             ),
  //                             SizedBox(width: 2),
  //                             Text(
  //                               '${product['rating']}',
  //                               style: TextStyle(
  //                                 fontSize: 10,
  //                                 color: Colors.grey[600],
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         Spacer(),
  //                         Text(
  //                           product['price'],
  //                           style: TextStyle(
  //                             fontSize: 14,
  //                             fontWeight: FontWeight.bold,
  //                             color: AppColors.mediumGreen,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildRecentOrders() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(
  //             'Recent Orders',
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //               color: Colors.grey[900],
  //             ),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               // Handle view all orders
  //             },
  //             child: Text(
  //               'View All',
  //               style: TextStyle(
  //                 color: AppColors.mediumGreen,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //       SizedBox(height: 16),
  //       Container(
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: Colors.grey[300]!),
  //         ),
  //         child: Column(
  //           children: _recentOrders.map((order) {
  //             return Container(
  //               padding: EdgeInsets.all(16),
  //               decoration: BoxDecoration(
  //                 border: Border(
  //                   bottom: BorderSide(
  //                     color: Colors.grey[200]!,
  //                     width: 1,
  //                   ),
  //                 ),
  //               ),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Expanded(
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                           'Order ${order['id']}',
  //                           style: TextStyle(
  //                             fontSize: 14,
  //                             fontWeight: FontWeight.w600,
  //                             color: Colors.grey[800],
  //                           ),
  //                           overflow: TextOverflow.ellipsis,
  //                         ),
  //                         SizedBox(height: 4),
  //                         Text(
  //                           order['date'],
  //                           style: TextStyle(
  //                             fontSize: 12,
  //                             color: Colors.grey[600],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   Column(
  //                     crossAxisAlignment: CrossAxisAlignment.end,
  //                     children: [
  //                       Container(
  //                         padding:
  //                             EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                         decoration: BoxDecoration(
  //                           color: _getStatusColor(order['status'])
  //                               .withOpacity(0.1),
  //                           borderRadius: BorderRadius.circular(8),
  //                         ),
  //                         child: Text(
  //                           order['status'],
  //                           style: TextStyle(
  //                             fontSize: 10,
  //                             fontWeight: FontWeight.w600,
  //                             color: _getStatusColor(order['status']),
  //                           ),
  //                         ),
  //                       ),
  //                       SizedBox(height: 4),
  //                       Text(
  //                         order['total'],
  //                         style: TextStyle(
  //                           fontSize: 14,
  //                           fontWeight: FontWeight.bold,
  //                           color: AppColors.mediumGreen,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             );
  //           }).toList(),
  //         ),
  //       ),
  //     ],
  //   );
  // }

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
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.mediumGreen,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        items: [
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.mediumGreen;
      case 'in transit':
        return Colors.orange[600]!;
      case 'processing':
        return Colors.grey[600]!;
      default:
        return Colors.grey[500]!;
    }
  }
}
