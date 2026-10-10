import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/laporan_panen_page.dart';
import 'package:hidrosense_mobile/views/pages/panen_form_page.dart';
import 'package:hidrosense_mobile/views/pages/panen_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/harvest_access.dart';
import 'package:hidrosense_mobile/views/components/dashboard_body.dart';
import 'support/harvest_fixture.dart';
import 'package:hidrosense_mobile/views/widgets/custom_back_button.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart'
    show growthClockProvider;

void main() {
  final qaDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff14675f),
      brightness: Brightness.dark,
    ),
  );
  double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
  }

  Color background(WidgetTester tester, Finder finder) {
    Color? color;
    tester.element(finder).visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Material && widget.color != null) {
        color = widget.color;
        return false;
      }
      return true;
    });
    return color ?? Theme.of(tester.element(finder)).colorScheme.surface;
  }

  void checkDecoration(WidgetTester tester, Finder finder) {
    final decorator = tester.widget<InputDecorator>(finder);
    final decoration = decorator.decoration;
    final fill = decoration.filled == true
        ? decoration.fillColor!
        : background(tester, finder);
    final border = decoration.errorText != null
        ? decorator.isFocused
              ? decoration.focusedErrorBorder!
              : decoration.errorBorder!
        : decorator.isFocused
        ? decoration.focusedBorder!
        : decoration.enabledBorder!;
    expect(contrast(border.borderSide.color, fill), greaterThanOrEqualTo(3));
    for (final style in [
      decoration.hintStyle,
      decoration.labelStyle,
      decoration.errorStyle,
    ]) {
      expect(contrast(style!.color!, fill), greaterThanOrEqualTo(4.5));
    }
    final states = <WidgetState>{
      if (decorator.isFocused) WidgetState.focused,
      if (decoration.errorText != null) WidgetState.error,
    };
    final label = WidgetStateProperty.resolveAs(
      decoration.floatingLabelStyle!,
      states,
    );
    expect(contrast(label.color!, fill), greaterThanOrEqualTo(4.5));
    final textField = find.ancestor(
      of: finder,
      matching: find.byType(TextField),
    );
    if (textField.evaluate().isNotEmpty) {
      final value = tester.widget<EditableText>(
        find.descendant(
          of: textField.first,
          matching: find.byType(EditableText),
        ),
      );
      expect(contrast(value.style.color!, fill), greaterThanOrEqualTo(4.5));
      debugPrint(
        'HARVEST VALUE ${value.style.color!.toARGB32().toRadixString(16)} '
        'fill=${fill.toARGB32().toRadixString(16)} '
        'ratio=${contrast(value.style.color!, fill).toStringAsFixed(2)}',
      );
    }
    final renderedLabel = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.text(decoration.labelText!)),
    );
    expect(
      contrast(renderedLabel.text.style!.color!, fill),
      greaterThanOrEqualTo(4.5),
    );
    debugPrint(
      'HARVEST PAIR ${decoration.labelText} '
      'focus=${decorator.isFocused} error=${decoration.errorText != null} '
      'boundary=${border.borderSide.color.toARGB32().toRadixString(16)} '
      'fill=${fill.toARGB32().toRadixString(16)} '
      'ratio=${contrast(border.borderSide.color, fill).toStringAsFixed(2)} '
      'hint=${decoration.hintStyle!.color!.toARGB32().toRadixString(16)} '
      'hintRatio=${contrast(decoration.hintStyle!.color!, fill).toStringAsFixed(2)} '
      'label=${label.color!.toARGB32().toRadixString(16)} '
      'labelRatio=${contrast(label.color!, fill).toStringAsFixed(2)} '
      'error=${decoration.errorStyle!.color!.toARGB32().toRadixString(16)} '
      'errorRatio=${contrast(decoration.errorStyle!.color!, fill).toStringAsFixed(2)}',
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget page,
    FakeHarvestRepository repo, {
    SessionUser? user = harvestUser,
    PanenViewModel? vm,
    ThemeData? theme,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 10),
          ),
          apiClientProvider.overrideWithValue(
            harvestApi((_) async => harvestPage([])),
          ),
          sessionProvider.overrideWith(
            (ref) => SessionViewModel(
              ref.read(apiClientProvider),
              initialState: SessionState(user: user),
            ),
          ),
          harvestRepositoryProvider.overrideWithValue(repo),
          if (vm != null) panenViewModelProvider.overrideWith((ref) => vm),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'real completed/upcoming list and tabs count data; estimate opens new form',
    (tester) async {
      final repo = await loadedRepo();
      repo.records = [HarvestRecord.fromJson(harvestJson())];
      final vm = harvestVm(repo);
      await vm.refresh();
      await pump(tester, const PanenPage(), repo, vm: vm);
      expect(find.text('Mendatang (1)'), findsOneWidget);
      expect(find.text('Selesai (1)'), findsOneWidget);
      expect(find.text('Panen #1'), findsOneWidget);
      expect(find.textContaining('Estimasi 2026-10-10'), findsOneWidget);
      await tester.tap(find.text('Batch #1'));
      await tester.pumpAndSettle();
      expect(find.text('Tambah Hasil Panen'), findsOneWidget);
      expect(find.text('Berat total (kg)'), findsOneWidget);
      expect(find.text('Harga Estimasi / Kg (Rp)'), findsNothing);
    },
  );
  testWidgets(
    'completed ID opens truthful persisted report and no PDF/fabricated variety',
    (tester) async {
      final repo = await loadedRepo();
      repo.records = [HarvestRecord.fromJson(harvestJson())];
      await pump(tester, const LaporanPanenPage(harvestId: '1'), repo);
      expect(find.text('Layak jual: 2.25 kg'), findsOneWidget);
      expect(find.textContaining('PDF'), findsNothing);
      expect(find.textContaining('Grand Rapids'), findsNothing);
    },
  );
  testWidgets(
    'legacy report shows unknown sorting instead of zero and note correction remains usable',
    (tester) async {
      final repo = await loadedRepo();
      repo.records = [HarvestRecord.fromJson(harvestJson(legacy: true))];
      await pump(tester, const LaporanPanenPage(harvestId: '1'), repo);
      expect(find.text('Berat total: belum tercatat'), findsOneWidget);
      expect(find.text('Reject: belum tercatat'), findsOneWidget);
      await tester.ensureVisible(find.text('Koreksi Sortasi atau Catatan'));
      await tester.tap(find.text('Koreksi Sortasi atau Catatan'));
      await tester.pumpAndSettle();
      expect(find.text('Koreksi berat sortasi'), findsOneWidget);
      expect(find.text('Berat total (kg)'), findsNothing);
    },
  );
  testWidgets(
    'form invalid decimals show validation without saving; date picker bounded to transfer and today',
    (tester) async {
      final repo = await loadedRepo();
      await pump(tester, const PanenFormPage(transferId: '1'), repo);
      await tester.tap(find.text('Tanggal panen: 2026-10-10'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2026, 9, 16));
      expect(picker.lastDate, DateTime(2026, 10, 10));
      expect(picker.initialEntryMode, DatePickerEntryMode.inputOnly);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah'), '5');
      await tester.enterText(
        find.widgetWithText(TextField, 'Berat total (kg)'),
        'NaN',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Berat reject (kg)'),
        '0',
      );
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('Simpan Hasil Panen'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Simpan Hasil Panen'));
      await tester.pumpAndSettle();
      expect(repo.keys, isEmpty);
      expect(find.textContaining('dua desimal'), findsOneWidget);
    },
  );
  for (final page in [
    const PanenPage(),
    const PanenFormPage(),
    const LaporanPanenPage(harvestId: '1'),
  ]) {
    testWidgets(
      'unauthorized direct ${page.runtimeType} builds no harvest provider and makes no request',
      (tester) async {
        final repo = await loadedRepo();
        await pump(tester, page, repo, user: null);
        expect(
          find.textContaining('Akses panen tidak diizinkan'),
          findsOneWidget,
        );
        expect(repo.harvestReads, 0);
        expect(repo.transferReads, 0);
      },
    );
  }
  testWidgets(
    'panen read without budidaya never fetches batch and cannot open create',
    (tester) async {
      final repo = await loadedRepo();
      const user = SessionUser(
        id: '2',
        name: 'Pegawai',
        username: 'p',
        role: 'pegawai',
        permissions: ['panen:read'],
      );
      await pump(tester, const PanenPage(), repo, user: user);
      expect(repo.transferReads, 0);
      expect(find.text('Catat Hasil Panen Baru'), findsNothing);
      expect(find.textContaining('Akses budidaya diperlukan'), findsOneWidget);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'harvest effective inputs and input-only date at320 text2 ${dark ? 'seeded QA dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final repo = await loadedRepo();
        await pump(
          tester,
          const PanenFormPage(transferId: '1'),
          repo,
          theme: dark ? qaDarkTheme : AppTheme.lightTheme,
          scale: 2,
        );
        final dropdown = find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.byType(InputDecorator),
        );
        checkDecoration(tester, dropdown);
        final dropdownValue = tester.renderObject<RenderParagraph>(
          find.text('#1 • Meja #1'),
        );
        final dropdownFill =
            tester.widget<InputDecorator>(dropdown).decoration.filled == true
            ? tester.widget<InputDecorator>(dropdown).decoration.fillColor!
            : background(tester, dropdown);
        expect(
          contrast(dropdownValue.text.style!.color!, dropdownFill),
          greaterThanOrEqualTo(4.5),
        );
        tester
            .widgetList<Focus>(
              find.descendant(
                of: find.byType(DropdownButtonFormField<String>),
                matching: find.byType(Focus),
              ),
            )
            .firstWhere((widget) => widget.focusNode != null)
            .focusNode!
            .requestFocus();
        await tester.pumpAndSettle();
        expect(tester.widget<InputDecorator>(dropdown).isFocused, true);
        checkDecoration(tester, dropdown);
        final count = find.widgetWithText(TextField, 'Jumlah');
        await tester.ensureVisible(count);
        await tester.pumpAndSettle();
        final label = find.descendant(of: count, matching: find.text('Jumlah'));
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, false);
        debugPrint(
          'HARVEST COUNT LABEL truncated=${paragraph.didExceedMaxLines}',
        );
        checkDecoration(
          tester,
          find.descendant(of: count, matching: find.byType(InputDecorator)),
        );
        await tester.tap(count);
        await tester.pumpAndSettle();
        checkDecoration(
          tester,
          find.descendant(of: count, matching: find.byType(InputDecorator)),
        );
        tester.testTextInput.hide();
        final dateButton = find.text('Tanggal panen: 2026-10-10');
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(dateButton);
        await tester.pumpAndSettle();
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(picker.initialEntryMode, DatePickerEntryMode.inputOnly);
        expect(picker.firstDate, DateTime(2026, 9, 16));
        expect(picker.lastDate, DateTime(2026, 10, 10));
        expect(find.byType(CalendarDatePicker), findsNothing);
        final input = find.descendant(
          of: find.byType(InputDatePickerFormField),
          matching: find.byType(TextField),
        );
        final decorator = find.descendant(
          of: input,
          matching: find.byType(InputDecorator),
        );
        checkDecoration(tester, decorator);
        await tester.enterText(input, '');
        await tester.pumpAndSettle();
        expect(find.text('mm/dd/yyyy'), findsOneWidget);
        final hintColor = tester
            .renderObject<RenderParagraph>(find.text('mm/dd/yyyy'))
            .text
            .style!
            .color!;
        final dateFill =
            tester.widget<InputDecorator>(decorator).decoration.filled == true
            ? tester.widget<InputDecorator>(decorator).decoration.fillColor!
            : background(tester, decorator);
        expect(contrast(hintColor, dateFill), greaterThanOrEqualTo(4.5));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.widget<InputDecorator>(decorator).isFocused, false);
        checkDecoration(tester, decorator);
        await tester.tap(input);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, true);
        for (final target in [
          find.descendant(
            of: input,
            matching: find.byType(TextSelectionGestureDetector),
          ),
          find.descendant(
            of: find.widgetWithText(TextButton, 'Cancel'),
            matching: find.byType(InkWell),
          ),
          find.descendant(
            of: find.widgetWithText(TextButton, 'OK'),
            matching: find.byType(InkWell),
          ),
        ]) {
          final size = tester.getSize(target);
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
          debugPrint('HARVEST DATE TARGET $size');
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        expect(tester.getRect(input).bottom, lessThanOrEqualTo(368));
        expect(tester.takeException(), isNull);
        for (final invalid in ['bad', '09/15/2026', '10/11/2026']) {
          await tester.enterText(input, invalid);
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(
            find.text(invalid == 'bad' ? 'Invalid format.' : 'Out of range.'),
            findsOneWidget,
          );
          checkDecoration(tester, decorator);
          final error = find.text(
            invalid == 'bad' ? 'Invalid format.' : 'Out of range.',
          );
          final errorColor = tester
              .renderObject<RenderParagraph>(error)
              .text
              .style!
              .color!;
          expect(
            contrast(errorColor, background(tester, error)),
            greaterThanOrEqualTo(4.5),
          );
          debugPrint(
            'HARVEST ERROR TEXT ${errorColor.toARGB32().toRadixString(16)} '
            'background=${background(tester, error).toARGB32().toRadixString(16)} '
            'ratio=${contrast(errorColor, background(tester, error)).toStringAsFixed(2)}',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          checkDecoration(tester, decorator);
          expect(tester.takeException(), isNull);
        }
        await tester.enterText(input, '09/20/2026');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(find.text('Tanggal panen: 2026-09-20'), findsOneWidget);
        await tester.tap(find.text('Tanggal panen: 2026-09-20'));
        await tester.pumpAndSettle();
        await tester.enterText(input, '09/25/2026');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('Tanggal panen: 2026-09-20'), findsOneWidget);
        expect(repo.keys, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'harvest actual chip borders and labels ${dark ? 'seeded QA dark' : 'light'}',
      (tester) async {
        final repo = await loadedRepo();
        await pump(
          tester,
          const PanenPage(),
          repo,
          theme: dark ? qaDarkTheme : AppTheme.lightTheme,
          scale: 2,
        );
        for (final chip in find.byType(RawChip).evaluate()) {
          final finder = find.byWidget(chip.widget);
          final shape = tester.widget<Material>(
            find.descendant(of: finder, matching: find.byType(Material)).first,
          );
          final border = (shape.shape! as OutlinedBorder).side.color;
          final ink = tester.widget<Ink>(
            find.descendant(of: finder, matching: find.byType(Ink)).first,
          );
          final paintedFill =
              (ink.decoration! as ShapeDecoration).color ?? Colors.transparent;
          final fill = Color.alphaBlend(
            paintedFill,
            shape.color ?? background(tester, finder),
          );
          final label = find
              .descendant(of: finder, matching: find.byType(RichText))
              .first;
          final text = tester.widget<RichText>(label).text.style!.color!;
          expect(contrast(border, fill), greaterThanOrEqualTo(3));
          expect(contrast(text, fill), greaterThanOrEqualTo(4.5));
          debugPrint(
            'HARVEST CHIP border=${border.toARGB32().toRadixString(16)} fill=${fill.toARGB32().toRadixString(16)} ratio=${contrast(border, fill).toStringAsFixed(2)} text=${text.toARGB32().toRadixString(16)} textRatio=${contrast(text, fill).toStringAsFixed(2)}',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
    for (final page in [
      const PanenPage(),
      const PanenFormPage(transferId: '1'),
    ]) {
      testWidgets(
        '${page.runtimeType} at 320x568 text2 ${dark ? 'dark' : 'light'} has no overflow and scrolls states',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = await loadedRepo();
          await pump(
            tester,
            page,
            repo,
            theme: dark ? qaDarkTheme : AppTheme.lightTheme,
            scale: 2,
          );
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'error and empty light/dark ${dark ? 'dark' : 'light'} have readable real actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = await loadedRepo();
        repo.readError = const ApiException(
          503,
          'READ',
          'Layanan sedang bermasalah.',
        );
        final vm = harvestVm(repo);
        await vm.refresh();
        await pump(
          tester,
          const PanenPage(),
          repo,
          vm: vm,
          theme: dark ? qaDarkTheme : AppTheme.lightTheme,
          scale: 2,
        );
        expect(find.text('Coba lagi'), findsOneWidget);
        expect(tester.takeException(), isNull);
        repo.readError = null;
        repo.transfers = [];
        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Belum ada data panen'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'uncertain request form retains selected zero active batch and locked input; identical retry saves',
    (tester) async {
      final repo = await loadedRepo();
      final vm = harvestVm(repo);
      await vm.refresh();
      repo.onWrite = (_, _, _) async => throw TimeoutException('lost');
      await vm.submit(harvestDraft);
      repo.transfers = [
        TransferRecord.fromJson(harvestTransferJson(active: 0)),
      ];
      await vm.refresh();
      await pump(tester, const PanenFormPage(), repo, vm: vm);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Isian terkunci'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Jumlah'))
            .enabled,
        false,
      );
      repo.onWrite = (_, _, _) async => HarvestRecord.fromJson(harvestJson());
      await tester.scrollUntilVisible(
        find.text('Ulangi Request yang Sama'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ulangi Request yang Sama'));
      await tester.pumpAndSettle();
      expect(repo.keys.length, 2);
      expect(repo.keys[0], repo.keys[1]);
    },
  );
  testWidgets(
    'midnight and resume refresh; disposing scope cancels listener and timer',
    (tester) async {
      final repo = await loadedRepo();
      var clock = DateTime.utc(2026, 10, 10, 16, 59, 59);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            growthClockProvider.overrideWithValue(() => clock),
            apiClientProvider.overrideWithValue(
              harvestApi((_) async => harvestPage([])),
            ),
            sessionProvider.overrideWith(
              (ref) => SessionViewModel(
                ref.read(apiClientProvider),
                initialState: const SessionState(user: harvestUser),
              ),
            ),
            harvestRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PanenPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reads = repo.harvestReads;
      clock = clock.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.harvestReads, reads + 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.harvestReads, reads + 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      clock = clock.add(const Duration(days: 1));
      await tester.pump(const Duration(days: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repo.harvestReads, reads + 2);
    },
  );
  test(
    'concrete theme text and status color pairs meet contrast requirements',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
      }

      for (final theme in [AppTheme.lightTheme, qaDarkTheme]) {
        final c = harvestTheme(theme).colorScheme;
        for (final pair in [
          (c.onSurface, c.surface),
          (c.primary, c.surface),
          (c.error, c.surface),
          (c.onPrimary, c.primary),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
      }
    },
  );
  test(
    'harvest input overrides preserve inherited geometry and global theme',
    () {
      final base = AppTheme.lightTheme;
      final before = base.inputDecorationTheme;
      final after = harvestTheme(base).inputDecorationTheme;
      expect(after.contentPadding, before.contentPadding);
      expect(after.fillColor, before.fillColor);
      expect(after.filled, before.filled);
      for (final pair in [
        (before.enabledBorder!, after.enabledBorder!),
        (before.focusedBorder!, after.focusedBorder!),
        (before.errorBorder!, after.errorBorder!),
      ]) {
        expect(
          (pair.$2 as OutlineInputBorder).borderRadius,
          (pair.$1 as OutlineInputBorder).borderRadius,
        );
        expect(pair.$2.borderSide.width, pair.$1.borderSide.width);
      }
      expect(
        base.inputDecorationTheme.enabledBorder!.borderSide.color,
        const Color(0xffe5e7eb),
      );
      expect(
        base.inputDecorationTheme.hintStyle!.color,
        const Color(0xff9ca3af),
      );
    },
  );
  testWidgets('dashboard harvest entry hidden without panen read permission', (
    tester,
  ) async {
    final repo = await loadedRepo();
    const user = SessionUser(
      id: '2',
      name: 'Pegawai',
      username: 'p',
      role: 'pegawai',
      permissions: [],
    );
    await pump(tester, const Scaffold(body: DashboardBody()), repo, user: user);
    expect(find.text('Manajemen Panen'), findsNothing);
    expect(repo.harvestReads, 0);
  });
  testWidgets('still mounted form resets controllers on account switch', (
    tester,
  ) async {
    final repo = await loadedRepo();
    final api = harvestApi((_) async => harvestPage([]));
    final session = _SwitchableSession(api);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 10),
          ),
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith((ref) => session),
          harvestRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PanenFormPage(transferId: '1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Jumlah'), '5');
    await tester.enterText(
      find.widgetWithText(TextField, 'Berat total (kg)'),
      '7.25',
    );
    session.switchUser(
      const SessionUser(
        id: '2',
        name: 'B',
        username: 'b',
        role: 'pegawai',
        permissions: ['panen:read', 'panen:write', 'budidaya:read'],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Jumlah'))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Berat total (kg)'))
          .controller!
          .text,
      isEmpty,
    );
    expect(repo.keys, isEmpty);
  });
  for (final status in [500, 403, 404]) {
    testWidgets(
      'cached detail GET slow then $status shows loading/error without cached fallback',
      (tester) async {
        final repo = await loadedRepo();
        repo.records = [HarvestRecord.fromJson(harvestJson())];
        final vm = harvestVm(repo);
        await vm.refresh();
        final detail = Completer<HarvestRecord>();
        repo.onDetail = (_) => detail.future;
        await pump(
          tester,
          const LaporanPanenPage(harvestId: '1'),
          repo,
          vm: vm,
        );
        expect(find.text('Memuat laporan panen...'), findsOneWidget);
        expect(find.text('Layak jual: 2.25 kg'), findsNothing);
        detail.completeError(
          ApiException(status, 'READ', 'Detail gagal dimuat.'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Detail gagal dimuat.'), findsOneWidget);
        expect(find.text('Coba lagi'), findsOneWidget);
        expect(find.text('Layak jual: 2.25 kg'), findsNothing);
      },
    );
  }
  testWidgets(
    'edit form never hydrates cached values before successful target GET',
    (tester) async {
      final repo = await loadedRepo();
      repo.records = [HarvestRecord.fromJson(harvestJson(note: 'old note'))];
      final vm = harvestVm(repo);
      await vm.refresh();
      final detail = Completer<HarvestRecord>();
      repo.onDetail = (_) => detail.future;
      await pump(tester, const PanenFormPage(harvestId: '1'), repo, vm: vm);
      expect(find.text('Memuat panen...'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      detail.complete(
        HarvestRecord.fromJson(harvestJson(note: 'fresh note', version: '2')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Catatan panen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Catatan panen'))
            .controller!
            .text,
        'fresh note',
      );
    },
  );
  for (final status in [500, 403, 404]) {
    testWidgets(
      'prior report cache cannot hydrate edit while its fresh GET waits or returns $status',
      (tester) async {
        final repo = await loadedRepo();
        repo.records = [
          HarvestRecord.fromJson(harvestJson(note: 'cached note')),
        ];
        final vm = harvestVm(repo);
        await vm.refresh();
        await vm.loadDetail('1');
        expect(vm.current.detailReads['1']?.record?.note, 'cached note');
        final fresh = Completer<HarvestRecord>();
        repo.onDetail = (_) => fresh.future;
        await pump(tester, const PanenFormPage(harvestId: '1'), repo, vm: vm);
        expect(find.text('Memuat panen...'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        fresh.completeError(
          ApiException(status, 'READ', 'Koreksi gagal dimuat.'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Koreksi gagal dimuat.'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Coba lagi'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'prior report cache is replaced by this edit GET newer version; entered note survives later refresh',
    (tester) async {
      final repo = await loadedRepo();
      repo.records = [HarvestRecord.fromJson(harvestJson(note: 'cached note'))];
      final vm = harvestVm(repo);
      await vm.refresh();
      await vm.loadDetail('1');
      final fresh = Completer<HarvestRecord>();
      repo.onDetail = (_) => fresh.future;
      await pump(tester, const PanenFormPage(harvestId: '1'), repo, vm: vm);
      expect(find.byType(TextField), findsNothing);
      fresh.complete(
        HarvestRecord.fromJson(harvestJson(note: 'fresh note', version: '2')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Catatan panen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final note = find.widgetWithText(TextField, 'Catatan panen');
      expect(tester.widget<TextField>(note).controller!.text, 'fresh note');
      await tester.enterText(note, 'entered note');
      await vm.refresh();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(note).controller!.text, 'entered note');
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('Simpan Koreksi'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Simpan Koreksi'));
      await tester.pumpAndSettle();
      expect(repo.bodies.single['expected_version'], '2');
      expect(repo.bodies.single['keterangan'], 'entered note');
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'harvest header back hitbox stays at least44dp at320dp text$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = await loadedRepo();
        await pump(
          tester,
          const PanenFormPage(),
          repo,
          user: null,
          scale: scale,
        );
        final target = find.descendant(
          of: find.byType(CustomBackButton),
          matching: find.byType(InkWell),
        );
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
        final titleSize = tester.getSize(find.text('Tambah Hasil Panen'));
        expect(
          titleSize.height,
          lessThanOrEqualTo(tester.getSize(find.byType(AppBar)).height),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _SwitchableSession extends SessionViewModel {
  _SwitchableSession(super.api)
    : super(initialState: const SessionState(user: harvestUser));
  void switchUser(SessionUser user) {
    state = SessionState(user: user);
  }
}
