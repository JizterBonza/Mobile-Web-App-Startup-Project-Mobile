import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import '../provider/provider.dart';

import '../screens/common/editProfileScreen.dart';

import 'auth_flow_helper.dart';

import 'snackbar_helper.dart';



enum PostLoginNavigation {

  navigateToDashboard,

  refreshInPlace,

}



/// Handles navigation after email or Google login succeeds.

Future<void> completeAuthNavigation({

  required BuildContext context,

  required Map<String, dynamic> result,

  required VoidCallback resetLoading,

  VoidCallback? onCloseDialog,

  PostLoginNavigation navigation = PostLoginNavigation.navigateToDashboard,

  VoidCallback? onLoginSuccess,

}) async {

  if (result['success'] != true) return;



  final data = result['data'];

  if (data is! Map) {

    resetLoading();

    if (context.mounted) {

      SnackbarHelper.showError(context, 'Invalid login response.');

    }

    return;

  }



  final userType = await AuthFlowHelper.resolveUserType(data);

  if (!AuthFlowHelper.validUserTypes.contains(userType)) {

    resetLoading();

    if (context.mounted) {

      SnackbarHelper.showError(

        context,

        'Invalid user type. Access denied.',

      );

    }

    return;

  }



  if (!context.mounted) return;



  try {

    final orderStatusProvider =

        Provider.of<OrderStatusProvider>(context, listen: false);

    orderStatusProvider.fetchAndCacheOrderStatuses().catchError((e) {

      print('Error fetching order statuses: $e');

    });

  } catch (e) {

    print('Error accessing OrderStatusProvider: $e');

  }



  if (!context.mounted) return;



  SnackbarHelper.showSuccess(

    context,

    result['message'] ?? 'Login successful!',

  );



  final navigator = Navigator.of(context, rootNavigator: true);

  onCloseDialog?.call();



  final isCustomer = userType == 'customer';

  if (navigation == PostLoginNavigation.refreshInPlace && isCustomer) {

    resetLoading();

    onLoginSuccess?.call();

    return;

  }



  if (!isCustomer && AuthFlowHelper.needsProfileCompletion(data)) {

    await navigator.push(

      MaterialPageRoute(builder: (_) => const EditProfileScreen()),

    );

  }



  final route = AuthFlowHelper.dashboardRouteFor(userType!);

  navigator.pushNamedAndRemoveUntil(route, (route) => false);

  resetLoading();

}


