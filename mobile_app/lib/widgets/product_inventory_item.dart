import 'package:flutter/material.dart';
import '../constants/constants.dart';

class ProductInventoryItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onEdit;
  final VoidCallback? onRestock;
  final VoidCallback? onDelete;

  const ProductInventoryItem({
    super.key,
    required this.product,
    this.onEdit,
    this.onRestock,
    this.onDelete,
  });

  bool get isLowStock {
    return product['stock'] < product['minStock'];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock ? Colors.orange[300]! : Colors.grey[300]!,
          width: isLowStock ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.mediumGreen.withOpacity(0.2)),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.mediumGreen,
              size: 28,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product['name'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                    if (isLowStock)
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  product['category'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock: ${product['stock'] ?? 0} ${product['unit'] ?? ''}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLowStock
                                ? Colors.orange[700]
                                : Colors.grey[700],
                          ),
                        ),
                        Text(
                          'Min: ${product['minStock'] ?? 0} ${product['unit'] ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₱${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mediumGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            itemBuilder: (context) => [
              if (onEdit != null)
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                  value: 'edit',
                ),
              if (onRestock != null)
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text('Restock'),
                    ],
                  ),
                  value: 'restock',
                ),
              if (onDelete != null)
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  value: 'delete',
                ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit?.call();
                  break;
                case 'restock':
                  onRestock?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}


