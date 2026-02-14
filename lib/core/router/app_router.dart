import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/app_navigator.dart';
import 'package:renthus/features/auth/auth.dart';
import 'package:renthus/features/chat/chat.dart';
import 'package:renthus/features/jobs/jobs.dart';
import 'package:renthus/features/admin/admin.dart';
import 'package:renthus/features/booking/booking.dart';
import 'package:renthus/features/client/client.dart' hide PartnerStoresPage, HelpCenterPlaceholderPage;
import 'package:renthus/features/provider/provider.dart';
import 'package:renthus/features/service/service.dart';
import 'package:renthus/features/notifications/notifications.dart';
import 'package:renthus/screens/help_center_page.dart';
import 'package:renthus/screens/partner_store_details_page.dart';
import 'package:renthus/screens/partner_stores_page.dart';
import 'package:renthus/screens/privacy_policy_page.dart';
import 'package:renthus/screens/terms_of_use_page.dart';
import 'package:renthus/screens/open_dispute_page.dart';
import 'package:renthus/widgets/full_screen_image_page.dart';

/// Rotas nomeadas do app.
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String signUp = '/sign_up';
  static const String clientHome = '/client';
  static const String providerHome = '/provider';
  static const String admin = '/admin';
  static const String bookingDetails = '/booking_details';
  static const String serviceDetail = '/service_detail';
  static const String jobDetails = '/job_details';
  static const String clientJobDetails = '/client_job_details';
  static const String chat = '/chat';
  static const String providerDispute = '/provider_dispute';
  static const String clientSignupStep1 = '/client_signup_step1';
  static const String providerSignupStep1 = '/provider_signup_step1';
  static const String partnerStores = '/partner_stores';
  static const String partnerStoreDetails = '/partner_store_details';
  static const String helpCenter = '/help_center';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String providerProfile = '/provider_profile';
  static const String providerServices = '/provider_services';
  static const String providerServiceSelection = '/provider_service_selection';
  static const String providerAddressStep3 = '/provider_address_step3';
  static const String fullImage = '/full_image';
  static const String notifications = '/notifications';
  static const String clientProfileEdit = '/client_profile_edit';
  static const String clientEditEmail = '/client_edit_email';
  static const String clientChangePhone = '/client_change_phone';
  static const String clientSignupStep2 = '/client_signup_step2';
  static const String clientPayment = '/client_payment';
  static const String clientCancelJob = '/client_cancel_job';
  static const String clientReview = '/client_review';
  static const String clientDispute = '/client_dispute';
  static const String openDispute = '/open_dispute';
}

/// Configuração do GoRouter.
final goRouter = GoRouter(
  navigatorKey: AppNavigator.navigatorKey,
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const RoleSelectionPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.clientHome,
      name: 'client',
      builder: (context, state) => const ClientMainPage(),
    ),
    GoRoute(
      path: AppRoutes.providerHome,
      name: 'provider',
      builder: (context, state) => const ProviderMainPage(),
    ),
    GoRoute(
      path: AppRoutes.admin,
      name: 'admin',
      builder: (context, state) => const AdminHomePage(),
    ),
    GoRoute(
      path: '${AppRoutes.serviceDetail}/:id',
      name: 'service_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ServiceDetailsScreen(serviceId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.bookingDetails,
      name: 'booking_details',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final bid = args?['bookingId']?.toString();
        return BookingDetailsScreen(bookingId: bid);
      },
    ),
    GoRoute(
      path: '${AppRoutes.jobDetails}/:id',
      name: 'job_details',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return JobDetailsPage(jobId: id);
      },
    ),
    GoRoute(
      path: '${AppRoutes.clientJobDetails}/:id',
      name: 'client_job_details',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ClientJobDetailsPage(jobId: id);
      },
    ),
    GoRoute(
      path: '${AppRoutes.providerDispute}/:id',
      name: 'provider_dispute',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ProviderDisputePage(jobId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.clientSignupStep1,
      name: 'client_signup_step1',
      builder: (_, __) => const ClientSignUpStep1Page(),
    ),
    GoRoute(
      path: AppRoutes.providerSignupStep1,
      name: 'provider_signup_step1',
      builder: (_, __) => const ProviderSignUpStep1Page(),
    ),
    GoRoute(
      path: AppRoutes.partnerStores,
      name: 'partner_stores',
      builder: (_, __) => const PartnerStoresPage(),
    ),
    GoRoute(
      path: AppRoutes.partnerStoreDetails,
      name: 'partner_store_details',
      builder: (context, state) {
        final store = state.extra as Map<String, dynamic>? ?? {};
        return PartnerStoreDetailsPage(store: store);
      },
    ),
    GoRoute(
      path: AppRoutes.helpCenter,
      name: 'help_center',
      builder: (_, __) => const HelpCenterPlaceholderPage(),
    ),
    GoRoute(
      path: AppRoutes.terms,
      name: 'terms',
      builder: (_, __) => const TermsOfUsePage(),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      name: 'privacy',
      builder: (_, __) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: AppRoutes.providerProfile,
      name: 'provider_profile',
      builder: (_, __) => const ProviderProfilePage(),
    ),
    GoRoute(
      path: '${AppRoutes.providerServices}/:id',
      name: 'provider_services',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ProviderServicesPage(providerId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.providerServiceSelection,
      name: 'provider_service_selection',
      builder: (_, __) => const ProviderServiceSelectionScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerAddressStep3,
      name: 'provider_address_step3',
      builder: (_, __) => const ProviderAddressStep3Page(),
    ),
    GoRoute(
      path: AppRoutes.fullImage,
      name: 'full_image',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final url = args?['url']?.toString() ?? '';
        return FullScreenImagePage(imageUrl: url);
      },
    ),
    GoRoute(
      path: AppRoutes.notifications,
      name: 'notifications',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final role = args?['currentUserRole']?.toString() ?? 'client';
        return NotificationsPage(currentUserRole: role);
      },
    ),
    GoRoute(
      path: AppRoutes.clientProfileEdit,
      name: 'client_profile_edit',
      builder: (_, __) => const ClientProfileEditPage(),
    ),
    GoRoute(
      path: AppRoutes.clientEditEmail,
      name: 'client_edit_email',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final email = args?['currentEmail']?.toString() ?? '';
        return ClientEditEmailPage(currentEmail: email);
      },
    ),
    GoRoute(
      path: AppRoutes.clientChangePhone,
      name: 'client_change_phone',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final phone = args?['currentPhone']?.toString() ?? '';
        return ClientChangePhonePage(currentPhone: phone);
      },
    ),
    GoRoute(
      path: AppRoutes.clientSignupStep2,
      name: 'client_signup_step2',
      builder: (_, __) => const ClientSignUpStep2Page(),
    ),
    GoRoute(
      path: AppRoutes.clientPayment,
      name: 'client_payment',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ClientPaymentPage(
          jobId: args['jobId']?.toString() ?? '',
          quoteId: args['quoteId']?.toString() ?? '',
          jobTitle: args['jobTitle']?.toString(),
          providerName: args['providerName']?.toString(),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.clientCancelJob,
      name: 'client_cancel_job',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return CancelJobPage(
          jobId: args['jobId']?.toString() ?? '',
          role: args['role']?.toString() ?? 'client',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.clientReview,
      name: 'client_review',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ClientReviewPage(
          jobId: args['jobId']?.toString() ?? '',
          providerId: args['providerId']?.toString() ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.clientDispute,
      name: 'client_dispute',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ClientDisputePage(jobId: args['jobId']?.toString() ?? '');
      },
    ),
    GoRoute(
      path: AppRoutes.openDispute,
      name: 'open_dispute',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return OpenDisputePage(jobId: args['jobId']?.toString() ?? '');
      },
    ),
    GoRoute(
      path: AppRoutes.chat,
      name: 'chat',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return ChatPage(
          conversationId: args?['conversationId']?.toString() ?? '',
          jobTitle: args?['jobTitle']?.toString() ?? '',
          otherUserName: args?['otherUserName']?.toString() ?? '',
          currentUserId: args?['currentUserId']?.toString() ?? '',
          currentUserRole: args?['currentUserRole']?.toString() ?? '',
          isChatLocked: args?['isChatLocked'] == true,
        );
      },
    ),
  ],
);

/// Navegação declarativa (preferir sobre Navigator.push quando possível).
extension GoRouterExtensions on BuildContext {
  void goToLogin() => go(AppRoutes.login);
  void goToClientHome() => go(AppRoutes.clientHome);
  void goToProviderHome() => go(AppRoutes.providerHome);
  void goToAdmin() => go(AppRoutes.admin);
  void goToServiceDetail(String id) => go('${AppRoutes.serviceDetail}/$id');
  void goToBookingDetails(String bookingId) =>
      go(AppRoutes.bookingDetails, extra: {'bookingId': bookingId});
  void goToJobDetails(String jobId) => go('${AppRoutes.jobDetails}/$jobId');
  void goToClientJobDetails(String jobId) =>
      go('${AppRoutes.clientJobDetails}/$jobId');
  void goToChat(Map<String, dynamic> args) =>
      go(AppRoutes.chat, extra: args);
  void goToClientSignupStep1() => go(AppRoutes.clientSignupStep1);
  void goToProviderSignupStep1() => go(AppRoutes.providerSignupStep1);
  Future<T?> pushJobDetails<T>(String jobId) =>
      push('${AppRoutes.jobDetails}/$jobId');
  Future<T?> pushClientJobDetails<T>(String jobId) =>
      push('${AppRoutes.clientJobDetails}/$jobId');
  Future<T?> pushChat<T>(Map<String, dynamic> args) =>
      push(AppRoutes.chat, extra: args);
  void goToHome() => go(AppRoutes.home);
  Future<T?> pushPartnerStores<T>() => push(AppRoutes.partnerStores);
  Future<T?> pushPartnerStoreDetails<T>(Map<String, dynamic> store) =>
      push(AppRoutes.partnerStoreDetails, extra: store);
  Future<T?> pushHelpCenter<T>() => push(AppRoutes.helpCenter);
  Future<T?> pushTerms<T>() => push(AppRoutes.terms);
  Future<T?> pushPrivacy<T>() => push(AppRoutes.privacy);
  Future<T?> pushProviderProfile<T>() => push(AppRoutes.providerProfile);
  Future<T?> pushProviderServices<T>(String providerId) =>
      push('${AppRoutes.providerServices}/$providerId');
  Future<T?> pushProviderServiceSelection<T>() =>
      push(AppRoutes.providerServiceSelection);
  void goToProviderAddressStep3() => go(AppRoutes.providerAddressStep3);
  void goToProviderServiceSelection() => go(AppRoutes.providerServiceSelection);
  Future<T?> pushProviderDispute<T>(String jobId) =>
      push('${AppRoutes.providerDispute}/$jobId');
  Future<T?> pushFullImage<T>(String url) =>
      push(AppRoutes.fullImage, extra: {'url': url});
  Future<T?> pushNotifications<T>(String currentUserRole) =>
      push(AppRoutes.notifications, extra: {'currentUserRole': currentUserRole});
  Future<T?> pushClientProfileEdit<T>() => push(AppRoutes.clientProfileEdit);
  Future<T?> pushClientEditEmail<T>(String currentEmail) =>
      push(AppRoutes.clientEditEmail, extra: {'currentEmail': currentEmail});
  Future<T?> pushClientChangePhone<T>(String currentPhone) =>
      push(AppRoutes.clientChangePhone, extra: {'currentPhone': currentPhone});
  Future<T?> pushClientSignupStep2<T>() => push(AppRoutes.clientSignupStep2);
  Future<T?> pushClientPayment<T>(
    String jobId,
    String quoteId, {
    String? jobTitle,
    String? providerName,
  }) =>
      push(AppRoutes.clientPayment, extra: {
        'jobId': jobId,
        'quoteId': quoteId,
        if (jobTitle != null) 'jobTitle': jobTitle,
        if (providerName != null) 'providerName': providerName,
      });
  Future<T?> pushClientCancelJob<T>(String jobId, {String role = 'client'}) =>
      push(AppRoutes.clientCancelJob, extra: {'jobId': jobId, 'role': role});
  Future<T?> pushClientReview<T>(String jobId, String providerId) =>
      push(AppRoutes.clientReview,
          extra: {'jobId': jobId, 'providerId': providerId});
  Future<T?> pushClientDispute<T>(String jobId) =>
      push(AppRoutes.clientDispute, extra: {'jobId': jobId});
  Future<T?> pushOpenDispute<T>(String jobId) =>
      push(AppRoutes.openDispute, extra: {'jobId': jobId});
}
