import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/app_navigator.dart';
import 'package:renthus/features/auth/auth.dart';
import 'package:renthus/features/chat/chat.dart';
import 'package:renthus/features/jobs/jobs.dart';
import 'package:renthus/features/admin/admin.dart';
import 'package:renthus/features/client/client.dart'
    hide PartnerStoresPage, HelpCenterPlaceholderPage;
import 'package:renthus/features/provider/provider.dart';
import 'package:renthus/features/notifications/notifications.dart';
import 'package:renthus/screens/help_center_page.dart';
import 'package:renthus/screens/partner_store_details_page.dart';
import 'package:renthus/screens/partner_stores_page.dart';
import 'package:renthus/screens/privacy_policy_page.dart';
import 'package:renthus/screens/terms_of_use_page.dart';
import 'package:renthus/screens/onboarding_page.dart';
import 'package:renthus/screens/open_dispute_page.dart';
import 'package:renthus/screens/provider_public_profile_page.dart';
import 'package:renthus/screens/provider_reviews_page.dart';
import 'package:renthus/screens/client_favorites_page.dart';
import 'package:renthus/screens/provider_verification_page.dart';
import 'package:renthus/screens/provider_bank_data_page.dart';
import 'package:renthus/screens/provider_bank_data_view_page.dart';
import 'package:renthus/screens/splash_screen.dart';
import 'package:renthus/screens/email_confirmation_page.dart';
import 'package:renthus/screens/forgot_password_page.dart';
import 'package:renthus/screens/reset_password_page.dart';
import 'package:renthus/widgets/full_screen_image_page.dart';

/// Rotas nomeadas do app.
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String signUp = '/sign_up';
  static const String clientHome = '/client';
  static const String providerHome = '/provider';
  static const String admin = '/admin';
  static const String jobDetails = '/job_details';
  static const String clientJobDetails = '/client_job_details';
  static const String chat = '/chat';
  static const String providerDispute = '/provider_dispute';
  static const String clientSignupStep1 = '/client_signup_step1';
  static const String providerSignupStep1 = '/provider_signup_step1';
  static const String clientPhoneVerification = '/client_phone_verification';
  static const String providerPhoneVerification = '/provider_phone_verification';
  static const String partnerStores = '/partner_stores';
  static const String partnerStoreDetails = '/partner_store_details';
  static const String helpCenter = '/help_center';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String providerProfile = '/provider_profile';
  static const String providerEditData = '/provider_edit_data';
  static const String providerServices = '/provider_services';
  static const String providerServiceSelection = '/provider_service_selection';
  static const String providerAddressStep3 = '/provider_address_step3';
  static const String fullImage = '/full_image';
  static const String notifications = '/notifications';
  static const String clientProfile = '/client_profile';
  static const String clientProfileEdit = '/client_profile_edit';
  static const String clientEditData = '/client_edit_data';
  static const String clientEditEmail = '/client_edit_email';
  static const String clientChangePhone = '/client_change_phone';
  static const String clientSignupStep2 = '/client_signup_step2';
  static const String clientPayment = '/client_payment';
  static const String clientCancelJob = '/client_cancel_job';
  static const String clientReview = '/client_review';
  static const String clientDispute = '/client_dispute';
  static const String openDispute = '/open_dispute';
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String providerPublicProfile = '/provider_public_profile';
  static const String providerReviews = '/provider_reviews';
  static const String clientFavorites = '/client_favorites';
  static const String providerVerification = '/provider_verification';
  static const String providerBankData = '/provider_bank_data';
   static const String providerBankDataEdit = '/provider_bank_data_edit';
  static const String emailConfirmation = '/email_confirmation';
  static const String forgotPassword = '/forgot_password';
  static const String resetPassword = '/reset-password';
}

/// Configuração do GoRouter.
final goRouter = GoRouter(
  navigatorKey: AppNavigator.navigatorKey,
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: kDebugMode,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (_, __) => const OnboardingPage(),
    ),
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
      path: AppRoutes.emailConfirmation,
      name: 'email_confirmation',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final email = extra['email'] as String? ?? '';
        final nextRoute = extra['nextRoute'] as String? ?? AppRoutes.home;
        final password = extra['password'] as String? ?? '';
        return EmailConfirmationPage(email: email, nextRoute: nextRoute, password: password);
      },
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgot_password',
      builder: (_, __) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.resetPassword,
      name: 'reset_password',
      builder: (_, __) => const ResetPasswordPage(),
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
      path: AppRoutes.clientPhoneVerification,
      name: 'client_phone_verification',
      builder: (context, state) {
        final phone =
            (state.extra as Map<String, dynamic>?)?['phone'] as String? ?? '';
        return ClientPhoneVerificationPage(phone: phone);
      },
    ),
    GoRoute(
      path: AppRoutes.providerPhoneVerification,
      name: 'provider_phone_verification',
      builder: (context, state) {
        final phone =
            (state.extra as Map<String, dynamic>?)?['phone'] as String? ?? '';
        return ProviderPhoneVerificationPage(phone: phone);
      },
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
      path: AppRoutes.providerEditData,
      name: 'provider_edit_data',
      builder: (_, __) => const ProviderEditDataPage(),
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
      path: AppRoutes.providerBankData,
      name: 'provider_bank_data',
      builder: (_, __) => const ProviderBankDataViewPage(),
    ),
    GoRoute(
      path: AppRoutes.providerBankDataEdit,
      name: 'provider_bank_data_edit',
      builder: (_, __) => const ProviderBankDataPage(),
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
      path: AppRoutes.clientProfile,
      name: 'client_profile',
      builder: (_, __) => const ClientProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.clientProfileEdit,
      name: 'client_profile_edit',
      builder: (_, __) => const ClientProfileEditPage(),
    ),
    GoRoute(
      path: AppRoutes.clientEditData,
      name: 'client_edit_data',
      builder: (_, __) => const ClientEditDataPage(),
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
          providerName: args['providerName']?.toString(),
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
      path: '${AppRoutes.providerPublicProfile}/:id',
      name: 'provider_public_profile',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ProviderPublicProfilePage(providerId: id);
      },
    ),
    GoRoute(
      path: '${AppRoutes.providerReviews}/:id',
      name: 'provider_reviews',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final args = state.extra as Map<String, dynamic>?;
        final isOwn = args?['isOwnProfile'] == true;
        return ProviderReviewsPage(providerId: id, isOwnProfile: isOwn);
      },
    ),
    GoRoute(
      path: AppRoutes.clientFavorites,
      name: 'client_favorites',
      builder: (_, __) => const ClientFavoritesPage(),
    ),
    GoRoute(
      path: AppRoutes.providerVerification,
      name: 'provider_verification',
      builder: (_, __) => const ProviderVerificationPage(),
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
          otherUserPhotoUrl: args?['otherUserPhotoUrl']?.toString(),
        );
      },
    ),
  ],
);

/// Navegação declarativa (preferir sobre Navigator.push quando possível).
extension GoRouterExtensions on BuildContext {
  void goToLogin() => go(AppRoutes.login);
  Future<T?> pushForgotPassword<T>() => push(AppRoutes.forgotPassword);
  void goToResetPassword() => go(AppRoutes.resetPassword);
  void goToClientHome() => go(AppRoutes.clientHome);
  void goToProviderHome() => go(AppRoutes.providerHome);
  void goToAdmin() => go(AppRoutes.admin);
  void goToJobDetails(String jobId) => go('${AppRoutes.jobDetails}/$jobId');
  void goToClientJobDetails(String jobId) =>
      go('${AppRoutes.clientJobDetails}/$jobId');
  void goToChat(Map<String, dynamic> args) => go(AppRoutes.chat, extra: args);
  void goToClientSignupStep1() => go(AppRoutes.clientSignupStep1);
  void goToProviderSignupStep1() => go(AppRoutes.providerSignupStep1);
  Future<T?> pushEmailConfirmation<T>(String email, String nextRoute, String password) => push(
        AppRoutes.emailConfirmation,
        extra: {'email': email, 'nextRoute': nextRoute, 'password': password},
      );
  Future<T?> pushClientPhoneVerification<T>(String phone) =>
      push(AppRoutes.clientPhoneVerification, extra: {'phone': phone});
  Future<T?> pushProviderPhoneVerification<T>(String phone) =>
      push(AppRoutes.providerPhoneVerification, extra: {'phone': phone});
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
  Future<T?> pushProviderEditData<T>() => push(AppRoutes.providerEditData);
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
      push(AppRoutes.notifications,
          extra: {'currentUserRole': currentUserRole});
  Future<T?> pushClientProfileEdit<T>() => push(AppRoutes.clientProfileEdit);
  Future<T?> pushClientEditData<T>() => push(AppRoutes.clientEditData);
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
  Future<T?> pushClientReview<T>(
    String jobId,
    String providerId, {
    String? providerName,
  }) =>
      push(AppRoutes.clientReview, extra: {
        'jobId': jobId,
        'providerId': providerId,
        if (providerName != null) 'providerName': providerName,
      });
  Future<T?> pushClientDispute<T>(String jobId) =>
      push(AppRoutes.clientDispute, extra: {'jobId': jobId});
  Future<T?> pushOpenDispute<T>(String jobId) =>
      push(AppRoutes.openDispute, extra: {'jobId': jobId});
  Future<T?> pushProviderPublicProfile<T>(String providerId) =>
      push('${AppRoutes.providerPublicProfile}/$providerId');
  Future<T?> pushProviderReviews<T>(String providerId,
          {bool isOwnProfile = false}) =>
      push('${AppRoutes.providerReviews}/$providerId',
          extra: {'isOwnProfile': isOwnProfile});
  Future<T?> pushClientFavorites<T>() => push(AppRoutes.clientFavorites);
  Future<T?> pushProviderVerification<T>() =>
      push(AppRoutes.providerVerification);
  Future<T?> pushProviderBankData<T>() => push(AppRoutes.providerBankData);
  Future<T?> pushProviderBankDataEdit<T>() =>
      push(AppRoutes.providerBankDataEdit);
  Future<T?> pushClientProfile<T>() => push(AppRoutes.clientProfile);
}
