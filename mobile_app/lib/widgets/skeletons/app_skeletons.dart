import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../constants/constants.dart';

/// Centralised skeleton (shimmer) placeholders used across the app while data
/// is loading. Each public widget is self-contained: it wraps its content in a
/// [Skeletonizer] so it can be dropped in directly wherever a spinner or
/// `_buildLoadingState()` used to live.
///
/// The shapes intentionally mirror the real loaded layouts (product cards,
/// order cards, list rows, etc.) so the UI doesn't jump when the data arrives.

const Color _boneBase = Color(0xFFE6E8EB);

/// Shared skeleton configuration so every placeholder animates the same way.
Widget _skeletonize({required Widget child, bool enabled = true}) {
  return Skeletonizer(
    enabled: enabled,
    effect: const ShimmerEffect(
      baseColor: _boneBase,
      highlightColor: Color(0xFFF5F6F7),
      duration: Duration(milliseconds: 1100),
    ),
    child: child,
  );
}

/// Public wrapper so screens can compose custom skeleton layouts (using
/// [SkeletonBox] children) with the app's shared shimmer effect, without
/// importing the skeletonizer package directly.
class AppSkeletonizer extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const AppSkeletonizer({super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) =>
      _skeletonize(child: child, enabled: enabled);
}

/// A small rounded block used as an image / avatar placeholder.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _boneBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A single product card placeholder matching `ProductCard`'s layout
/// (image, category label, name, store/sold line, price).
class ProductCardSkeleton extends StatelessWidget {
  final double imageHeight;

  const ProductCardSkeleton({super.key, this.imageHeight = 130});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: imageHeight, radius: 0),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 60, height: 10),
                SizedBox(height: 6),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 6),
                SkeletonBox(width: 90, height: 10),
                SizedBox(height: 12),
                SkeletonBox(width: 70, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling row of product card placeholders (dashboard sections
/// such as On Sale, Featured, Buy Again).
class ProductRowSkeleton extends StatelessWidget {
  final double height;
  final double cardWidth;
  final double imageHeight;
  final int count;
  final EdgeInsetsGeometry padding;

  const ProductRowSkeleton({
    super.key,
    required this.height,
    this.cardWidth = 165,
    this.imageHeight = 130,
    this.count = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => SizedBox(
            width: cardWidth,
            child: ProductCardSkeleton(imageHeight: imageHeight),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of product card placeholders (shop screen, favorites grid).
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  final double imageHeight;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ProductGridSkeleton({
    super.key,
    this.count = 6,
    this.imageHeight = 130,
    this.childAspectRatio = 0.62,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: GridView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: count,
        itemBuilder: (_, __) => ProductCardSkeleton(imageHeight: imageHeight),
      ),
    );
  }
}

/// Horizontal row of rounded pill placeholders (category chips).
class CategoryChipsSkeleton extends StatelessWidget {
  final int count;
  final double height;
  final EdgeInsetsGeometry padding;

  const CategoryChipsSkeleton({
    super.key,
    this.count = 6,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SkeletonBox(
            width: 70 + (i.isEven ? 20 : 0),
            height: height,
            radius: height / 2,
          ),
        ),
      ),
    );
  }
}

/// Single large rounded banner placeholder (suggested stores carousel).
class StoreBannerSkeleton extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;

  const StoreBannerSkeleton({
    super.key,
    this.height = 200,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: Padding(
        padding: padding,
        child: SkeletonBox(height: height, radius: 16),
      ),
    );
  }
}

/// A single order-card placeholder (status badge + lines + price row).
class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 120, height: 14),
              SkeletonBox(width: 70, height: 22, radius: 12),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 56, height: 56, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: double.infinity, height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 140, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 90, height: 12),
              SkeletonBox(width: 80, height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vertical list of order-card placeholders (My Orders, rider deliveries).
class OrderListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const OrderListSkeleton({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, __) => const _OrderCardSkeleton(),
      ),
    );
  }
}

/// A single list-row placeholder (leading icon + two text lines).
class _ListRowSkeleton extends StatelessWidget {
  const _ListRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: const [
          SkeletonBox(width: 44, height: 44, radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 160, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical list of generic row placeholders (notifications, address lists,
/// reviews, etc.).
class ListRowsSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ListRowsSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: ListView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: count,
        itemBuilder: (_, __) => const _ListRowSkeleton(),
      ),
    );
  }
}

/// Full product-detail placeholder (image, title/price, description, reviews).
class ProductDetailSkeleton extends StatelessWidget {
  const ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SkeletonBox(height: 300, radius: 0),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 20),
                SizedBox(height: 12),
                SkeletonBox(width: 120, height: 24),
                SizedBox(height: 20),
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: 12),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 220, height: 12),
                SizedBox(height: 24),
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 14),
                _ListRowSkeleton(),
                _ListRowSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple full-width centered skeleton block list, useful for screens whose
/// loaded layout is a generic vertical stack of cards (cart, checkout,
/// earnings, profile sections).
class GenericListSkeleton extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const GenericListSkeleton({
    super.key,
    this.count = 4,
    this.itemHeight = 90,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return _skeletonize(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => SkeletonBox(height: itemHeight, radius: 14),
      ),
    );
  }
}
