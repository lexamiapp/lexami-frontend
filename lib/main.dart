import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'utils/app_localizations.dart';
import 'providers/language_provider.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/gemini_service.dart';
import 'services/local_ai_service.dart';
import 'services/config_service.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/verification_waiting_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lawyer/advisor_search_screen.dart';
import 'screens/ai_match_screen.dart';
import 'screens/alimony_calculator_screen.dart';
import 'screens/alimony_tracker_screen.dart';
import 'screens/voice_to_text_screen.dart';
import 'screens/doc_generator_screen.dart';
import 'screens/my_cases_screen.dart';
import 'screens/call_screen.dart';
import 'screens/child_custody/child_custody_hub.dart';
import 'screens/child_custody/parenting_plan_screen.dart';
import 'screens/child_custody/child_profile_screen.dart';
import 'screens/child_custody/visitation_calendar_screen.dart';
import 'screens/child_custody/secure_communication_screen.dart';
import 'screens/child_custody/compliance_safety_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/community_screen.dart';
import 'screens/user_detail_screen.dart';
import 'screens/wallet_screen.dart'; 
import 'screens/legal_library_screen.dart';
import 'screens/auth/advisor_registration_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/evidence_vault_screen.dart';
import 'screens/family_dispute_solution_screen.dart';
import 'services/google_drive_service.dart';

// Shared AuthService instance
final authService = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Fetch Remote Config (Gemini key + feature flags) — fail-safe
  await ConfigService.init();

  // Background warmup for Node.js backend on Render.com (prevents cold starts)
  LocalAIService().warmup().catchError((_) {});

  runApp(const LexAniApp());
}

class LexAniApp extends StatelessWidget {
  const LexAniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (ctx) {
          final service = GeminiService();
          service.init(ConfigService.geminiApiKey);
          // Keep quota tracker in sync with logged-in user
          authService.authStateChanges.listen((user) {
            service.currentUserId = user?.uid;
          });
          return service;
        }),
        Provider(create: (_) => LocalAIService()),
        Provider(create: (_) => GoogleDriveService()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp.router(
            title: 'LexAni',
            routerConfig: _router, // Assuming _router is the navigationRouter
            debugShowCheckedModeBanner: false,
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
            ],
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E293B)),
              fontFamily: 'Inter',
            ),
          );
        },
      ),
    );
  }
}

// 2. Configure GoRouter with refreshListenable
final _router = GoRouter(
  initialLocation: '/home',
  refreshListenable: authService,
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/home',
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => const NoTransitionPage(child: SignUpScreen()),
    ),
    GoRoute(
      path: '/verify-email',
      pageBuilder: (context, state) => const NoTransitionPage(child: VerificationWaitingScreen()),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Scaffold_With_NavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
              routes: [
                GoRoute(path: 'ai-match', pageBuilder: (context, state) => const NoTransitionPage(child: AiMatchScreen())),
                GoRoute(path: 'calculator', pageBuilder: (context, state) => const NoTransitionPage(child: AlimonyCalculatorScreen())),
                GoRoute(path: 'tracker', pageBuilder: (context, state) => const NoTransitionPage(child: AlimonyTrackerScreen())),
                GoRoute(path: 'generator', pageBuilder: (context, state) => const NoTransitionPage(child: DocGeneratorScreen())),
                GoRoute(path: 'transcriber', pageBuilder: (context, state) => const NoTransitionPage(child: VoiceToTextScreen())),
                GoRoute(path: 'vault', pageBuilder: (context, state) => const NoTransitionPage(child: EvidenceVaultScreen())),
                GoRoute(path: 'wallet', pageBuilder: (context, state) => const NoTransitionPage(child: WalletScreen())),
                GoRoute(path: 'library', pageBuilder: (context, state) => const NoTransitionPage(child: LegalLibraryScreen())),
                GoRoute(path: 'register-advisor', pageBuilder: (context, state) => const NoTransitionPage(child: AdvisorRegistrationScreen())),
                GoRoute(path: 'family-solution', pageBuilder: (context, state) => const NoTransitionPage(child: FamilyDisputeSolutionScreen())),
                GoRoute(
                  path: 'custody',
                  pageBuilder: (context, state) => const NoTransitionPage(child: ChildCustodyHubScreen()),
                  routes: [
                    GoRoute(
                      path: 'plan-builder',
                      pageBuilder: (context, state) => const NoTransitionPage(child: ParentingPlanScreen()),
                    ),
                    GoRoute(
                      path: 'child-profile',
                      pageBuilder: (context, state) => const NoTransitionPage(child: ChildProfileScreen()),
                    ),
                    GoRoute(
                      path: 'calendar',
                      pageBuilder: (context, state) => const NoTransitionPage(child: VisitationCalendarScreen()),
                    ),
                    GoRoute(
                      path: 'secure-comm',
                      pageBuilder: (context, state) => const NoTransitionPage(child: SecureCommunicationScreen()),
                    ),
                    GoRoute(
                      path: 'compliance',
                      pageBuilder: (context, state) => const NoTransitionPage(child: ComplianceSafetyScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/my-cases', pageBuilder: (context, state) => const NoTransitionPage(child: MyCasesScreen()))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/call', pageBuilder: (context, state) => const NoTransitionPage(child: CallScreen()))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/advisors', pageBuilder: (context, state) => NoTransitionPage(child: AdvisorSearchScreen()))],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/community', 
              pageBuilder: (context, state) => const NoTransitionPage(child: CommunityScreen()),
              routes: [
                GoRoute(
                  path: 'user/:uid',
                  pageBuilder: (context, state) => NoTransitionPage(child: UserDetailScreen(userId: state.pathParameters['uid']!)),
                ),
              ],
            )
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/profile', pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()))],
        ),
      ],
    ),
    GoRoute(
      path: '/admin',
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminDashboardScreen()),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) => const NoTransitionPage(child: NotificationScreen()),
    ),
  ],
  redirect: (context, state) {
    final isLoggedIn = authService.currentUser != null;
    final isVerified = authService.isEmailVerified;
    final path = state.uri.path;

    if (!isLoggedIn) {
      if (path == '/login' || path == '/signup') return null;
      return '/login';
    }

    if (isLoggedIn && !isVerified) {
      if (path == '/verify-email') return null;
      return '/verify-email';
    }

    if (isLoggedIn && isVerified) {
      if (path == '/login' || path == '/signup' || path == '/verify-email') return '/home';
    }

    return null;
  },
);

class Scaffold_With_NavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const Scaffold_With_NavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: [
          NavigationDestination(label: AppLocalizations.of(context)?.translate('home') ?? 'Home', icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home)),
          NavigationDestination(label: AppLocalizations.of(context)?.translate('my_cases') ?? 'My Cases', icon: const Icon(LucideIcons.briefcase), selectedIcon: const Icon(Icons.work)),
          NavigationDestination(label: AppLocalizations.of(context)?.translate('call') ?? 'Call', icon: const Icon(Icons.call_outlined), selectedIcon: const Icon(Icons.call)),
          NavigationDestination(label: AppLocalizations.of(context)?.translate('advisors') ?? 'Advisors', icon: const Icon(LucideIcons.users), selectedIcon: const Icon(LucideIcons.users)),
          NavigationDestination(label: AppLocalizations.of(context)?.translate('community') ?? 'Community', icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people)),
          NavigationDestination(label: AppLocalizations.of(context)?.translate('profile') ?? 'Profile', icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person)),
        ],
      ),
    );
  }
}
