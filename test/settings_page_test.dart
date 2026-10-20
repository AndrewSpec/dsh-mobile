import 'package:dsh_mobile/core/theme.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/device_key_store.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/data/relay_config_store.dart';
import 'package:dsh_mobile/features/auth/auth_controller.dart';
import 'package:dsh_mobile/features/settings/settings_page.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _settingsApp() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const SettingsPage(),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.preload();
  });

  testWidgets('shows the installed app version and build number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          relayServiceProvider.overrideWithValue(MockRelayService()),
          installedAppVersionProvider.overrideWith(
            (ref) async =>
                const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
          ),
        ],
        child: _settingsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.2.3 (42)'), findsOneWidget);
    expect(find.text('Tap to check for updates'), findsOneWidget);
  });

  testWidgets('language and theme are frameless controls in their sections', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        relayServiceProvider.overrideWithValue(MockRelayService()),
        installedAppVersionProvider.overrideWith(
          (ref) async =>
              const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _settingsApp()),
    );
    await tester.pumpAndSettle();

    // One frame per setting: the section card, never a nested boxed form field.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.byType(DropdownButton<ThemeMode>), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(container.read(appThemeProvider), ThemeMode.dark);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polish').last);
    await tester.pumpAndSettle();
    expect(container.read(appLocaleProvider)?.languageCode, 'pl');
  });

  testWidgets('changing the language in settings re-renders the page', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        relayServiceProvider.overrideWithValue(MockRelayService()),
        installedAppVersionProvider.overrideWith(
          (ref) async =>
              const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: buildDshTheme(),
            locale: ref.watch(appLocaleProvider) ?? const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polish').last);
    await tester.pumpAndSettle();

    expect(container.read(appLocaleProvider)?.languageCode, 'pl');
    expect(find.text('Język'), findsOneWidget);
    expect(find.text('Motyw'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('changes and persists a private Relay URL', (tester) async {
    final relayStore = MemoryRelayConfigStore();
    final container = ProviderContainer(
      overrides: [
        deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        relayConfigStoreProvider.overrideWithValue(relayStore),
        relayServiceProvider.overrideWithValue(MockRelayService()),
        installedAppVersionProvider.overrideWith(
          (ref) async =>
              const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _settingsApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relay server'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('relay-url-field')),
      'https://private.example.com/',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(relayStore.relayUrl, 'https://private.example.com');
    expect(find.text('https://private.example.com'), findsOneWidget);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });
}
