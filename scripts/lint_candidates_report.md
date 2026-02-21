# Lint Rule Candidates Report

Generated on: 2026-02-21 08:38:29
Total candidates: 953 (909 actionable, 44 already handled by dart fix)
Noise filtered: 148 lines removed (reverts, CI, docs, engine internals)
Deduplicated: 37 cross-version duplicates removed
dart fix coverage: 245 Class.member pairs loaded

## Summary by Category

| Category | Actionable | dart fix | Description |
|----------|-----------|----------|-------------|
| Deprecation | 262 | 42 | Old API deprecated — lint can detect usage and suggest replacement |
| Breaking Change | 185 | 2 | API changed/removed — lint can detect old pattern and flag it |
| New Feature / API | 47 | 0 | New capability — lint can detect verbose pattern and suggest the new API |
| New Parameter / Option | 46 | 0 | New parameter — lint can suggest using the new option for better behavior |
| Performance Improvement | 77 | 0 | Performance gain — lint can detect the slower old pattern |
| Replacement / Migration | 292 | 0 | Pattern replacement — lint can detect old pattern and suggest new one |

---

## Relevance Score Guide

Items are scored by likelihood of being an actionable lint rule:
- Score 5+ = High confidence (specific API, old→new pattern)
- Score 3-4 = Medium confidence (mentions Dart/Flutter class)
- Score 1-2 = Low confidence (may need manual review)

---

# Actionable Candidates

These items are NOT handled by `dart fix` and represent opportunities for saropa_lints rules.

## Flutter SDK

### 3.41.0

**Deprecation** (6)

- 🟡 [4] * Fix deprecation warning in some API examples using RadioListTile by @huycozy in [178635](https://github.com/flutter/flutter/pull/178635)
  - _* Refactor SnackBar behavior selection example to use `RadioGroup` by @AbdeMohlbi in [178618](https://github.com/flutter/flutter/pull/178618)_
- ⚪ [2] * [Gradle 9] Resolve Gradle 9 Deprecations in flutter/flutter part 1 by @jesswrd in [176865](https://github.com/flutter/flutter/pull/176865)
  - _* Tapping outside of `SelectableRegion` should dismiss the selection by @Renzo-Olivares in [176843](https://github.com/flutter/flutter/pull/176843)_
- ⚪ [2] * [test_fixes] Enable `deprecated_member_use_from_same_package`. by @stereotype441 in [177183](https://github.com/flutter/flutter/pull/177183)
  - _* Fix Image.network not using cache when headers are specified by @rajveermalviya in [176831](https://github.com/flutter/flutter/pull/176831)_
- ⚪ [2] * Enable deprecated_member_use_from_same_package for all packages containing tests of Dart fixes defined within the package by @jason-simmons in [177341](https://github.com/flutter/flutter/pull/177341)
  - _* Fix(AnimatedScrollView): exclude outgoing items in removeAllItems by @kazbeksultanov in [176452](https://github.com/flutter/flutter/pull/176452)_
- ⚪ [2] * New isSemantics and deprecate containsSemantics by @zemanux in [180538](https://github.com/flutter/flutter/pull/180538)
  - _* Fix Drawer.child docstring to say ListView instead of SliverList by @nathannewyen in [180326](https://github.com/flutter/flutter/pull/180326)_
- ⚪ [1] * [web] Deprecate --pwa-strategy by @mdebbar in [177613](https://github.com/flutter/flutter/pull/177613)
  - _* [web] Move webparagraph tests to their right location by @mdebbar in [177739](https://github.com/flutter/flutter/pull/177739)_

**Breaking Change** (1)

- ⚪ [1] * Preserve whitelisted files when removed from build system outputs by @vashworth in [178396](https://github.com/flutter/flutter/pull/178396)
  - _* [tool] clean up https cert configuration handling by @kevmoo in [178139](https://github.com/flutter/flutter/pull/178139)_

**New Feature / API** (1)

- ⚪ [1] * [ios] [pv] accept/reject gesture based on hitTest (with new widget API) by @hellohuanlin in [179659](https://github.com/flutter/flutter/pull/179659)
  - _* Fix draggable scrollable sheet example drag speed is off by @huycozy in [179179](https://github.com/flutter/flutter/pull/179179)_

**Performance Improvement** (4)

- ⚪ [1] * Colored box optimization (#176028) by @definev in [176073](https://github.com/flutter/flutter/pull/176073)
  - _* Add blockAccessibilityFocus flag by @hannah-hyj in [175551](https://github.com/flutter/flutter/pull/175551)_
- ⚪ [1] * Make a11y `computeChildGeometry` slightly faster by @LongCatIsLooong in [177477](https://github.com/flutter/flutter/pull/177477)
  - _* Fix deprecation warning in some API examples using RadioListTile by @huycozy in [178635](https://github.com/flutter/flutter/pull/178635)_
- ⚪ [1] * MatrixUtils.forceToPoint - simplify and optimize by @kevmoo in [179546](https://github.com/flutter/flutter/pull/179546)
  - _* Remove unused optional argument in _followDiagnosticableChain by @harryterkelsen in [179525](https://github.com/flutter/flutter/pull/179525)_
- ⚪ [1] * New optimized general convex path shadow algorithm by @flar in [178370](https://github.com/flutter/flutter/pull/178370)
  - _* Test cross import lint by @justinmc in [178693](https://github.com/flutter/flutter/pull/178693)_

**Replacement / Migration** (4)

- 🔴 [5] * [Material] Change default mouse cursor of buttons to basic arrow instead of click (except on web) by @camsim99 in [171796](https://github.com/flutter/flutter/pull/171796)
  - _* Fix drawer Semantics for mismatched platforms by @huycozy in [177095](https://github.com/flutter/flutter/pull/177095)_
- 🔴 [5] * Fix Drawer.child docstring to say ListView instead of SliverList by @nathannewyen in [180326](https://github.com/flutter/flutter/pull/180326)
  - _* Raw tooltip with smaller API surface that exposes tooltip widget by @victorsanni in [177678](https://github.com/flutter/flutter/pull/177678)_
- 🟡 [3] * Use WidgetsBinding.instance.platformDispatcher in windowing instead of PlatformDispatcher.instance by @mattkae in [178799](https://github.com/flutter/flutter/pull/178799)
  - _* Make sure that a CupertinoSpellCheckSuggestionsToolbar doesn't crash … by @ahmedsameha1 in [177978](https://github.com/flutter/flutter/pull/177978)_
- ⚪ [2] * [Windows] Allow apps to prefer high power GPUs by @9AZX in [177653](https://github.com/flutter/flutter/pull/177653)
  - _* Ensure that the engine converts std::filesystem::path objects to UTF-8 strings on Windows by @jason-simmons in [179528](https://github.com/flutter/flutter/pull/179528)_

---

### 3.38.0

**Deprecation** (14)

- 🔴 [5] * Remove deprecated `AssetManifest.json` file by @matanlurey in [172594](https://github.com/flutter/flutter/pull/172594)
  - _* fix(scrollbar): Update padding type to EdgeInsetsGeometry by @SalehTZ in [172056](https://github.com/flutter/flutter/pull/172056)_
- 🟡 [4] * Add missing deprecations to CupertinoDynamicColor. by @ksokolovskyi in [171160](https://github.com/flutter/flutter/pull/171160)
  - _* Improve assertion message in `_MixedBorderRadius.resolve()` by @SalehTZ in [172100](https://github.com/flutter/flutter/pull/172100)_
- ⚪ [2] * Suppress deprecated iOS windows API in integration_test by @jmagman in [173251](https://github.com/flutter/flutter/pull/173251)
  - _* [ Widget Preview ] Cleanup for experimental release by @bkonyi in [173289](https://github.com/flutter/flutter/pull/173289)_
- ⚪ [2] * NavigatorPopScope examples no longer use deprecated onPop. by @justinmc in [174291](https://github.com/flutter/flutter/pull/174291)
  - _* [web] Refactor LayerScene out of CanvasKit by @harryterkelsen in [174375](https://github.com/flutter/flutter/pull/174375)_
- ⚪ [2] * Fix docs referencing deprecated radio properties by @victorsanni in [176244](https://github.com/flutter/flutter/pull/176244)
  - _* Migrate to `WidgetStateOutlinedBorder` by @ValentinVignal in [176270](https://github.com/flutter/flutter/pull/176270)_
- ⚪ [2] * Adds deprecation for impeller opt out on android by @gaaclarke in [173375](https://github.com/flutter/flutter/pull/173375)
  - _* Blocks exynos9820 chip from vulkan by @gaaclarke in [173807](https://github.com/flutter/flutter/pull/173807)_
- ⚪ [2] * Fix deprecated configureStatusBarForFullscreenFlutterExperience for Android 15+ by @alexskobozev in [175501](https://github.com/flutter/flutter/pull/175501)
  - _* [CP-beta][Android] Refactor `ImageReaderSurfaceProducer` restoration after app resumes by @camsim99 in [177121](https://github.com/flutter/flutter/pull/177121)_
- ⚪ [2] * Remove 2023 deprecated `'platforms'` key from daemon output by @matanlurey in [172593](https://github.com/flutter/flutter/pull/172593)
  - _* Migrate to null aware elements - Part 3 by @jamilsaadeh97 in [172307](https://github.com/flutter/flutter/pull/172307)_
- ⚪ [2] * Add `--dart-define`, `-D` to `assemble`, deprecate `--define`, `-d`. by @matanlurey in [172510](https://github.com/flutter/flutter/pull/172510)
  - _* Rename `AppRunLogger`, stop writing status messages that break JSON by @matanlurey in [172591](https://github.com/flutter/flutter/pull/172591)_
- ⚪ [2] * Remove deprecated `--[no-]-disable-dds` by @matanlurey in [172791](https://github.com/flutter/flutter/pull/172791)
  - _* Update `main`/`master` repoExceptions analysis set by @matanlurey in [172796](https://github.com/flutter/flutter/pull/172796)_
- ⚪ [2] * [ Tool ] Remove leftover Android x86 deprecation warning constant by @bkonyi in [174941](https://github.com/flutter/flutter/pull/174941)
  - _* Make every LLDB Init error message actionable by @vashworth in [174726](https://github.com/flutter/flutter/pull/174726)_
- ⚪ [2] * Deprecate Objective-C plugin template by @okorohelijah in [174003](https://github.com/flutter/flutter/pull/174003)
  - _* [native_assets] Find more `CCompilerConfig` on Linux by @GregoryConrad in [175323](https://github.com/flutter/flutter/pull/175323)_
- ⚪ [2] * Stop using deprecated analyzer 7.x.y APIs. by @scheglov in [176242](https://github.com/flutter/flutter/pull/176242)
  - _* [native assets] Roll dependencies by @dcharkes in [176287](https://github.com/flutter/flutter/pull/176287)_
- ⚪ [1] * [web] Cleanup usages of deprecated `routeUpdated` message by @mdebbar in [173782](https://github.com/flutter/flutter/pull/173782)
  - _* [web] Fix error in ClickDebouncer when using VoiceOver by @mdebbar in [174046](https://github.com/flutter/flutter/pull/174046)_

**Breaking Change** (1)

- ⚪ [1] * [Gradle 9] Removed `minSdkVersion` and only use `minSdk` by @jesswrd in [173892](https://github.com/flutter/flutter/pull/173892)
  - _* Fix GitHub labeler platform-android typo by @jmagman in [175076](https://github.com/flutter/flutter/pull/175076)_

**New Feature / API** (1)

- 🔴 [5] * Introduce a getter for `Project` to get `gradle-wrapper.properties` directly by @AbdeMohlbi in [175485](https://github.com/flutter/flutter/pull/175485)
  - _* [ Widget Preview ] Fix filter by file on Windows by @bkonyi in [175783](https://github.com/flutter/flutter/pull/175783)_

**Replacement / Migration** (9)

- 🔴 [7] * Update gradle_utils.dart to use `constant` instead of `final` by @AbdeMohlbi in [175443](https://github.com/flutter/flutter/pull/175443)
  - _* Update gradle_errors.dart to use constants defined in gradle_utils.dart by @AbdeMohlbi in [174760](https://github.com/flutter/flutter/pull/174760)_
- 🔴 [5] * `last_engine_commit.ps1`: Use `$flutterRoot` instead of `$gitTopLevel` by @matanlurey in [172786](https://github.com/flutter/flutter/pull/172786)
  - _* fix: get content hash for master on local engine branches by @jtmcdole in [172792](https://github.com/flutter/flutter/pull/172792)_
- 🟡 [3] * [Range slider] Tap on active range, the thumb closest to the mouse cursor should move to the cursor position. by @hannah-hyj in [173725](https://github.com/flutter/flutter/pull/173725)
  - _* Add error handling for `Element` lifecycle user callbacks by @LongCatIsLooong in [173148](https://github.com/flutter/flutter/pull/173148)_
- 🟡 [3] * Using a shared message-only HWND for clip board data on win32 instead of the implicit view by @mattkae in [173076](https://github.com/flutter/flutter/pull/173076)
  - _* Provide monitor list, display size, refresh rate, and more for Windows by @9AZX in [164460](https://github.com/flutter/flutter/pull/164460)_
- 🟡 [3] * Update `flutter pub get` to use `flutter.version.json` (instead of `version`) by @matanlurey in [172798](https://github.com/flutter/flutter/pull/172798)
  - _* Add `--config-only` build option for Linux and Windows by @stuartmorgan-g in [172239](https://github.com/flutter/flutter/pull/172239)_
- 🟡 [3] * In "flutter create", use the project directory in the suggested "cd" command instead of the main source file path by @jason-simmons in [173132](https://github.com/flutter/flutter/pull/173132)
  - _* [android][tool] Consolidate minimum versions for android projects. by @reidbaker in [171965](https://github.com/flutter/flutter/pull/171965)_
- 🟡 [3] * licenses_cpp: Switched to lexically_relative for 2x speed boost. by @gaaclarke in [173048](https://github.com/flutter/flutter/pull/173048)
  - _* [macOS] Remove duplicate object initialization by @bufffun in [171767](https://github.com/flutter/flutter/pull/171767)_
- 🟡 [3] * Read `bin/cache/flutter.version.json` instead of `version` for `flutter_gallery` by @matanlurey in [173797](https://github.com/flutter/flutter/pull/173797)
  - _* Remove `luci_flags.parallel_download_builds` and friends by @matanlurey in [173799](https://github.com/flutter/flutter/pull/173799)_
- 🟡 [3] * User Invoke-Expression instead of call operator for nested Powershell scripts invocations (on Windows) by @aam in [175941](https://github.com/flutter/flutter/pull/175941)
  - _* fix typo in `Crashes.md` by @AbdeMohlbi in [175959](https://github.com/flutter/flutter/pull/175959)_

---

### 3.35.0

**Deprecation** (12)

- 🔴 [6] * Deprecate DropdownButtonFormField "value" parameter in favor of "initialValue" by @bleroux in [170805](https://github.com/flutter/flutter/pull/170805)
  - _* When maintainHintSize is false, hint is centered and aligned, it is different from the original one by @zeqinjie in [168654](https://github.com/flutter/flutter/pull/168654)_
- 🔴 [5] * Clean up references to deprecated onPop method in docs by @justinmc in [169700](https://github.com/flutter/flutter/pull/169700)
  - _* IOSSystemContextMenuItem.toString to Diagnosticable by @justinmc in [169705](https://github.com/flutter/flutter/pull/169705)_
- 🟡 [4] * docs: Update deprecation message for Slider.year2023 by @huycozy in [169053](https://github.com/flutter/flutter/pull/169053)
  - _* Update the `RangeSlider` widget to the 2024 Material Design appearance by @TahaTesser in [163736](https://github.com/flutter/flutter/pull/163736)_
- 🟡 [4] * Deprecated methods that call setStatusBarColor, setNavigationBarColor, setNavigationBarDividerColor by @narekmalk in [165737](https://github.com/flutter/flutter/pull/165737)
  - _* [Android 16] Bumped Android Defaults in Framework by @jesswrd in [166464](https://github.com/flutter/flutter/pull/166464)_
- 🟡 [4] * [ Widget Previews ] Remove deprecated desktop support by @bkonyi in [169703](https://github.com/flutter/flutter/pull/169703)
  - _* Symlink SwiftPM plugins in the same directory by @vashworth in [168932](https://github.com/flutter/flutter/pull/168932)_
- ⚪ [2] * Remove deprecated todo about caching by @ValentinVignal in [168534](https://github.com/flutter/flutter/pull/168534)
  - _* Make Cupertino sheet set the systemUIStyle through an AnnotatedRegion by @MitchellGoodwin in [168182](https://github.com/flutter/flutter/pull/168182)_
- ⚪ [2] * Clarify deprecation notice for jumpToWithoutSettling in scroll_position.dart by @dogaozyagci in [167200](https://github.com/flutter/flutter/pull/167200)
  - _* [skwasm] Add the capability of dumping live object counts in debug mode. by @eyebrowsoffire in [168389](https://github.com/flutter/flutter/pull/168389)_
- ⚪ [2] * Update Docs to Warn Users Edge-To-Edge opt out is being deprecated for Android 16+ (API 36+) by @jesswrd in [170816](https://github.com/flutter/flutter/pull/170816)
  - _* Enhance Text Contrast for WCAG AAA Compliance by @azatech in [170758](https://github.com/flutter/flutter/pull/170758)_
- ⚪ [2] * Update deprecated vector_math calls by @kevmoo in [169477](https://github.com/flutter/flutter/pull/169477)
  - _* Fixes inputDecoration sibling explicit child not included in semantic… by @chunhtai in [170079](https://github.com/flutter/flutter/pull/170079)_
- ⚪ [2] * Remove deprecated Objective-C iOS app create template by @jmagman in [169547](https://github.com/flutter/flutter/pull/169547)
  - _* [native assets] Roll dependencies by @dcharkes in [169920](https://github.com/flutter/flutter/pull/169920)_
- ⚪ [2] * [ Tool ] Remove long-deprecated `make-host-app-editable` by @bkonyi in [171715](https://github.com/flutter/flutter/pull/171715)
  - _* feat: Use engine_stamp.json in flutter tool by @jtmcdole in [171454](https://github.com/flutter/flutter/pull/171454)_
- ⚪ [1] * [web] drop more use of deprecated JS functions by @kevmoo in [166157](https://github.com/flutter/flutter/pull/166157)
  - _* Roll pub packages by @flutter-pub-roller-bot in [168509](https://github.com/flutter/flutter/pull/168509)_

**Breaking Change** (5)

- 🟡 [4] * Removed repeated entry in `CHANGELOG.md` by @ferraridamiano in [165273](https://github.com/flutter/flutter/pull/165273)
  - _* Roll Dart SDK from 7c40eba6bf77 to 56940edd099d by @jason-simmons in [169135](https://github.com/flutter/flutter/pull/169135)_
- ⚪ [1] * rename from announce to supportsAnnounce on engine by @ash2moon in [170618](https://github.com/flutter/flutter/pull/170618)
  - _* Update FormField.initialValue documentation by @bleroux in [171061](https://github.com/flutter/flutter/pull/171061)_
- ⚪ [1] * Removed string keys by @Phantom-101 in [171293](https://github.com/flutter/flutter/pull/171293)
  - _* Fix InputDecorationThemeData.activeIndicatorBorder is not applied by @bleroux in [171764](https://github.com/flutter/flutter/pull/171764)_
- ⚪ [1] * Removed the FlutterViewController.pluginRegistrant by @gaaclarke in [169995](https://github.com/flutter/flutter/pull/169995)
  - _* Export FlutterSceneDelegate by @gaaclarke in [170169](https://github.com/flutter/flutter/pull/170169)_
- ⚪ [1] * Removed superfluous copy in license checker by @gaaclarke in [167146](https://github.com/flutter/flutter/pull/167146)
  - _* Roll Dartdoc to 8.3.3 by @jason-simmons in [167231](https://github.com/flutter/flutter/pull/167231)_

**Performance Improvement** (1)

- ⚪ [0] * [web] Pass the same optimization level to both stages of JS compiler by @kevmoo in [169642](https://github.com/flutter/flutter/pull/169642)
  - _* Fix the "Missing ExternalProject for :" error by @rekire in [168403](https://github.com/flutter/flutter/pull/168403)_

**Replacement / Migration** (7)

- 🔴 [7] * Android gradle use lowercase instead of toLowerCase in preparation for removal in v9 by @reidbaker in [171397](https://github.com/flutter/flutter/pull/171397)
  - _* remove `x86` unused codepaths by @AbdeMohlbi in [170191](https://github.com/flutter/flutter/pull/170191)_
- 🔴 [7] * Add/use `addMachineOutputFlag`/`outputsMachineFormat` instead of strings by @matanlurey in [171459](https://github.com/flutter/flutter/pull/171459)
  - _* Remove now duplicate un-forward ports for Android by @matanlurey in [171473](https://github.com/flutter/flutter/pull/171473)_
- 🔴 [5] * Switch to Linux orchestrators for Windows releasers. by @matanlurey in [168941](https://github.com/flutter/flutter/pull/168941)
  - _* Revert "fix: update experiment to use different setup (#169728)" and "feat: experimental workflow for Linux tool-tests-general (#169706)" by @jason-simmons in [169770](https://github.com/flutter/flutter/pull/169770)_
- 🟡 [3] * Clear background in the GTK layer, instead of OpenGL by @robert-ancell in [170840](https://github.com/flutter/flutter/pull/170840)
  - _* Fix multi-view GL rendering not working since software rendering was added by @robert-ancell in [171409](https://github.com/flutter/flutter/pull/171409)_
- 🟡 [3] * Content aware hash moved to script and tracked by @jtmcdole in [166717](https://github.com/flutter/flutter/pull/166717)
  - _* Reverts "Content aware hash moved to script and tracked (#166717)" by @auto-submit[bot] in [166864](https://github.com/flutter/flutter/pull/166864)_
- 🟡 [3] * Change FGP unit test `expect` to match on process result instead of exit code by @gmackall in [168278](https://github.com/flutter/flutter/pull/168278)
  - _* [tool] Refactor WebTemplate to be immutable by @kevmoo in [168201](https://github.com/flutter/flutter/pull/168201)_
- ⚪ [2] * [fuchsia] Use the system loader instead of Dart_LoadELF_Fd. by @rmacnak-google in [169534](https://github.com/flutter/flutter/pull/169534)
  - _* Remove Observatory build rules and remaining references from the engine by @bkonyi in [169945](https://github.com/flutter/flutter/pull/169945)_

---

### 3.32.0

**Deprecation** (10)

- 🔴 [11] * Deprecate `ThemeData.indicatorColor` in favor of `TabBarThemeData.indicatorColor` by @TahaTesser in [160024](https://github.com/flutter/flutter/pull/160024)
  - _* Fix incorrect [enabled] documentation by @sethmfuller in [161650](https://github.com/flutter/flutter/pull/161650)_
- 🟡 [4] * Add remaining dart fixes for Color deprecations when importing painting.dart by @Piinks in [162609](https://github.com/flutter/flutter/pull/162609)
  - _* Removes assumption that basis scalar and rounded_scalar match by @gaaclarke in [165166](https://github.com/flutter/flutter/pull/165166)_
- 🟡 [4] * Add empty `io.flutter.app.FlutterApplication` to give deprecation notice, and un-break projects that have not migrated by @gmackall in [164233](https://github.com/flutter/flutter/pull/164233)
  - _* [Android] Use java for looking up Android API level. by @jonahwilliams in [163558](https://github.com/flutter/flutter/pull/163558)_
- ⚪ [2] * deprecate Android announcement events and add deprecation warning. by @ash2moon in [165195](https://github.com/flutter/flutter/pull/165195)
  - _* (#112207) Adding `view_id` parameter to DispatchSemanticsAction and UpdateSemantics by @mattkae in [164577](https://github.com/flutter/flutter/pull/164577)_
- ⚪ [2] * Update `year2023` flag deprecation message by @TahaTesser in [162607](https://github.com/flutter/flutter/pull/162607)
  - _* Add missing space between DayPeriodControl and time control in time picker by @MinSeungHyun in [162230](https://github.com/flutter/flutter/pull/162230)_
- ⚪ [2] * Deprecate ExpansionTileController by @victorsanni in [166368](https://github.com/flutter/flutter/pull/166368)
  - _* Migrate to Theme.brightnessOf method by @rkishan516 in [163950](https://github.com/flutter/flutter/pull/163950)_
- ⚪ [2] * replace deprecated [UIScreen mainScreen] in iOS by @dkyurtov in [162785](https://github.com/flutter/flutter/pull/162785)
  - _* [iOS] remove Skia interfaces from iOS platform code. by @jonahwilliams in [163505](https://github.com/flutter/flutter/pull/163505)_
- ⚪ [2] * Replace deprecated openURL API call by @hellohuanlin in [164247](https://github.com/flutter/flutter/pull/164247)
  - _* Fix `-[FlutterView focusItemsInRect:]` crash by @LongCatIsLooong in [165454](https://github.com/flutter/flutter/pull/165454)_
- ⚪ [2] * [web_ui] move several uses of (deprecated) pkg:js to js_interop_unsafe by @kevmoo in [164264](https://github.com/flutter/flutter/pull/164264)
  - _* [web_ui] dependency cleanup by @kevmoo in [164256](https://github.com/flutter/flutter/pull/164256)_
- ⚪ [1] * [web] Remove deprecated web-only APIs from dart:ui by @mdebbar in [161775](https://github.com/flutter/flutter/pull/161775)
  - _* Unskip test. by @polina-c in [162106](https://github.com/flutter/flutter/pull/162106)_

**Breaking Change** (4)

- ⚪ [1] * Remove `scenario_app/android` and rename to `ios_scenario_app`. by @matanlurey in [160992](https://github.com/flutter/flutter/pull/160992)
  - _* Table implements redepth by @chunhtai in [162282](https://github.com/flutter/flutter/pull/162282)_
- ⚪ [1] * Removed not working hyperlinks to ScriptCategory values by @Mastermind-sap in [165395](https://github.com/flutter/flutter/pull/165395)
  - _* Refactor: Migrate Date picker from MaterialState and MaterialStateProperty by @rkishan516 in [164972](https://github.com/flutter/flutter/pull/164972)_
- ⚪ [0] * [Android] Fix integration test to check if dev dependencies are removed from release builds + address no non-dev dependency plugin edge case by @camsim99 in [161826](https://github.com/flutter/flutter/pull/161826)
  - _* [Android] HC++ plumbing. by @jonahwilliams in [162407](https://github.com/flutter/flutter/pull/162407)_
- ⚪ [0] * [Android] Remove overlay when platform views are removed from screen. by @jonahwilliams in [162908](https://github.com/flutter/flutter/pull/162908)
  - _* [Android] fix hcpp overlay layer intersection. by @jonahwilliams in [163024](https://github.com/flutter/flutter/pull/163024)_

**Performance Improvement** (2)

- ⚪ [1] * Change the default optimization level to `-O2` for wasm in release mode. by @eyebrowsoffire in [162917](https://github.com/flutter/flutter/pull/162917)
  - _* [ Widget Preview ] Update generated scaffold project to include early preview rendering by @bkonyi in [162847](https://github.com/flutter/flutter/pull/162847)_
- ⚪ [1] * Run more builds faster by @jtmcdole in [164125](https://github.com/flutter/flutter/pull/164125)
  - _* Do not update patch versions for `dependabot/github-actions`. by @matanlurey in [164055](https://github.com/flutter/flutter/pull/164055)_

**Replacement / Migration** (14)

- 🔴 [7] * [CP-beta][skwasm] Use `queueMicrotask` instead of `postMessage` when single-threaded by @flutteractionsbot in [167154](https://github.com/flutter/flutter/pull/167154)
- 🔴 [7] * Make developing `flutter_tools` nicer: Use `fail` instead of `throw StateError`. by @matanlurey in [163094](https://github.com/flutter/flutter/pull/163094)
  - _* explicitly set packageConfigPath for strategy providers by @jyameo in [163080](https://github.com/flutter/flutter/pull/163080)_
- 🔴 [6] * [fuchsia] Remove explicit LogSink and InspectSink routing and use dictionaries instead by @gbbosak in [162780](https://github.com/flutter/flutter/pull/162780)
  - _* Public nodes needing paint or layout by @emerssso in [166148](https://github.com/flutter/flutter/pull/166148)_
- 🔴 [5] * Prefer using non nullable opacityAnimation property by @AhmedLSayed9 in [164795](https://github.com/flutter/flutter/pull/164795)
  - _* feat: Added forceErrorText in DropdownButtonFormField #165188 by @Memet18 in [165189](https://github.com/flutter/flutter/pull/165189)_
- 🟡 [3] * Start using `bin/cache/engine.{stamp|realm}` instead of `bin/internal/engine.{realm|version}`. by @matanlurey in [164352](https://github.com/flutter/flutter/pull/164352)
  - _* android: Clean up gen_snapshot artifact build by @cbracken in [164418](https://github.com/flutter/flutter/pull/164418)_
- 🟡 [3] * [web:a11y] wheel events switch to pointer mode by @yjbanov in [163582](https://github.com/flutter/flutter/pull/163582)
  - _* introduce system color palette by @yjbanov in [163335](https://github.com/flutter/flutter/pull/163335)_
- 🟡 [3] * route CLI command usage information through the logger instead of using `print` by @andrewkolos in [161533](https://github.com/flutter/flutter/pull/161533)
  - _* remove usage of `Usage` from build system by @andrewkolos in [160663](https://github.com/flutter/flutter/pull/160663)_
- 🟡 [3] * Make LLDB check a warning instead of a failure by @vashworth in [164828](https://github.com/flutter/flutter/pull/164828)
  - _* [tools, web] Make sure to copy the dump-info file if dump-info is used by @kevmoo in [165013](https://github.com/flutter/flutter/pull/165013)_
- 🟡 [3] * fix `felt` link to point to flutter repo instead of the engine repo by @AbdeMohlbi in [161423](https://github.com/flutter/flutter/pull/161423)
  - _* Don't depend on Dart from FML. by @chinmaygarde in [162271](https://github.com/flutter/flutter/pull/162271)_
- 🟡 [3] * Point ktlint AS docs to the `.editorconfig` that is actually used by ci, instead of making a copy in the README by @gmackall in [165213](https://github.com/flutter/flutter/pull/165213)
  - _* Delete `docs/infra/Infra-Ticket-Queue.md` by @matanlurey in [165258](https://github.com/flutter/flutter/pull/165258)_
- 🟡 [3] * Update the Dart package creation script to copy source files instead of creating symlinks to the source tree by @jason-simmons in [165242](https://github.com/flutter/flutter/pull/165242)
  - _* Update docs after #165258 by @Piinks in [165716](https://github.com/flutter/flutter/pull/165716)_
- ⚪ [2] * [Windows] Allow apps to prefer low power GPUs by @zaiste-linganer in [162490](https://github.com/flutter/flutter/pull/162490)
  - _* [windows] Implement merged UI and platform thread by @knopp in [162935](https://github.com/flutter/flutter/pull/162935)_
- ⚪ [2] * [macos] prefer integrated GPU. by @jonahwilliams in [164569](https://github.com/flutter/flutter/pull/164569)
  - _* Reverts "[Impeller] use DeviceLocal textures for gifs on non-iOS devices. (#164573)" by @auto-submit in [164600](https://github.com/flutter/flutter/pull/164600)_
- ⚪ [2] * [fuchsia][sysmem2] switch to sysmem2 tokens by @dustingreen in [166120](https://github.com/flutter/flutter/pull/166120)
  - _* [Impeller] fix min filter for GL external textures. by @jonahwilliams in [166224](https://github.com/flutter/flutter/pull/166224)_

---

### 3.29.0

**Deprecation** (13)

- 🔴 [7] * Deprecate unused `ButtonStyleButton.iconAlignment` property by @TahaTesser in 160023
  - _* Add script to check format of changed dart files by @goderbauer in 160007_
- 🔴 [5] * Add `SurfaceProducer.onSurfaceCleanup`, deprecate `onSurfaceDestroyed`. by @matanlurey in 160937
  - _* Fix docImport issues by @goderbauer in 160918_
- ⚪ [2] * Remove `gradle_deprecated_settings` test app, and remove reference from lockfile exclusion yaml by @gmackall in 161622
  - _* Check that localization files of stocks app are up-to-date by @goderbauer in 161608_
- ⚪ [2] * Proposal to deprecate `webGoldenComparator`. by @matanlurey in 161196
  - _* [Impeller] dont generate final 1x1 mip level to work around Adreno GPU bug by @jonahwilliams in 161192_
- ⚪ [2] * deprecate engine ci yaml roller by @christopherfujino in 160682
  - _* Roll to dart 3.7.0-267.0.dev by @aam in 160680_
- ⚪ [2] * Turn deprecation message analyze tests back on by @LongCatIsLooong in 160554
  - _* Split build and test builders for web engine by @eyebrowsoffire in 160550_
- ⚪ [2] * Remove more references to deprecated package:usage (executable, runner) by @andrewkolos in 160369
  - _* Skip integration tests that consistently OOM on a Windows platform. by @matanlurey in 160368_
- ⚪ [2] * Update PopInvokedCallback Deprecated message by @krokyze in 160324
  - _* Added Mohammed Chahboun to authors by @M97Chahboun in 160311_
- ⚪ [2] * [CP-beta]Add deprecation notice for Android x86 when building for the target by @flutteractionsbot in 159847
  - _* Reland Fix Date picker overlay colors aren't applied on selected state by @bleroux in 159839_
- ⚪ [2] * Add deprecation notice for Android x86 when building for the target by @bkonyi in 159750
  - _* Introduce Material 3 `year2023` flag to `SliderThemeData` by @TahaTesser in 159721_
- ⚪ [2] * [tool] Removes deprecated --web-renderer parameter. by @ditman in 159314
  - _* Suppress previous route transition if current route is fullscreenDialog by @MitchellGoodwin in 159312_
- ⚪ [2] * Fix use of deprecated `buildDir` in Android templates/tests/examples by @gmackall in 157560
  - _* Reverts "Upgrade tests to AGP 8.7/Gradle 8.10.2/Kotlin 1.8.10 (#157032)" by @auto-submit[bot] in 157559_
- ⚪ [2] * Migrate away from deprecated whereNotNull by @parlough in 157250
  - _* Fix a few typos in framework code and doc comments by @parlough in 157248_

**New Feature / API** (2)

- ⚪ [2] * Temporarily skip CustomPainter SemanticsFlag test to allow new flag to roll in by @yjbanov in 157061
  - _* Upgrade tests to AGP 8.7/Gradle 8.10.2/Kotlin 1.8.10 by @gmackall in 157032_
- ⚪ [2] * Temporarily skip SemanticsFlag test to allow new flag to roll in by @yjbanov in 157017
  - _* Roll Packages from bf751e6dff18 to a35f02d79d0e (2 revisions) by @engine-flutter-autoroll in 156983_

**New Parameter / Option** (2)

- ⚪ [2] * Temporarily skip CustomPainter SemanticsFlag test to allow new flag to roll in by @yjbanov in 157061
  - _* Upgrade tests to AGP 8.7/Gradle 8.10.2/Kotlin 1.8.10 by @gmackall in 157032_
- ⚪ [2] * Temporarily skip SemanticsFlag test to allow new flag to roll in by @yjbanov in 157017
  - _* Roll Packages from bf751e6dff18 to a35f02d79d0e (2 revisions) by @engine-flutter-autoroll in 156983_

**Performance Improvement** (1)

- ⚪ [1] * Annotate entrypoints in the "isolate spawner" files generated by `flutter test --experimental-faster-testing` by @derekxu16 in 160694
  - _* [Impeller] move barrier setting out of render pass builder. by @jonahwilliams in 160693_

**Replacement / Migration** (5)

- 🔴 [6] * [native assets] Create `NativeAssetsManifest.json` instead of kernel embedding by @dcharkes in 159322
  - _* [tool] Removes deprecated --web-renderer parameter. by @ditman in 159314_
- 🟡 [3] * use uuid from package:uuid instead of from package:usage by @devoncarew in 161102
  - _* update repo to be forward compatible with shelf_web_socket v3.0 by @devoncarew in 161101_
- 🟡 [3] * Use `flutter` repo for engine golds instead of `flutter-engine`. by @matanlurey in 160556
  - _* Turn deprecation message analyze tests back on by @LongCatIsLooong in 160554_
- 🟡 [3] * Allow integration test helpers to work on substrings instead of whole strings by @mkustermann in 160437
  - _* [native_assets] Preparation existing tests for future of other (i.e. non-Code) assets by @mkustermann in 160436_
- 🟡 [3] * Fix JS compilation to use the command 'compile js' instead of using snapshot names to invoke dart2js by @a-siva in 156735
  - _* Roll Packages from 67401e169e5c to 1e670f27a620 (7 revisions) by @engine-flutter-autoroll in 156734_

---

### 3.27.0

**Deprecation** (14)

- 🟡 [4] * Refactor: Deprecate inactiveColor from cupertino checkbox by @rkishan516 in [152981](https://github.com/flutter/flutter/pull/152981)
  - _* Implemented CupertinoButton new styles/sizes (fixes #92525) by @kerberjg in [152845](https://github.com/flutter/flutter/pull/152845)_
- ⚪ [2] * Update deprecation policy by @Piinks in [151257](https://github.com/flutter/flutter/pull/151257)
  - _* PinnedHeaderSliver example based on the iOS Settings AppBar by @HansMuller in [151205](https://github.com/flutter/flutter/pull/151205)_
- ⚪ [2] * Factor out deprecated names in example code by @nate-thegrate in [151374](https://github.com/flutter/flutter/pull/151374)
  - _* Added SliverFloatingHeader.snapMode by @HansMuller in [151289](https://github.com/flutter/flutter/pull/151289)_
- ⚪ [2] * [tool] Remove some usages of deprecated usage package by @andrewkolos in [151359](https://github.com/flutter/flutter/pull/151359)
  - _* Add Semantics Property `linkUrl` by @mdebbar in [150639](https://github.com/flutter/flutter/pull/150639)_
- ⚪ [2] * painting: drop deprecated (exported) hashList and hashValues functions by @kevmoo in [151677](https://github.com/flutter/flutter/pull/151677)
  - _* docimports for rendering library by @goderbauer in [151958](https://github.com/flutter/flutter/pull/151958)_
- ⚪ [2] * Add xcresulttool --legacy flag for deprecated usage by @jmagman in [152988](https://github.com/flutter/flutter/pull/152988)
  - _* Remove -sdk for watchOS simulator in tool by @jmagman in [152992](https://github.com/flutter/flutter/pull/152992)_
- ⚪ [2] * Add deprecation warning for "flutter create --ios-language" by @jmagman in [155867](https://github.com/flutter/flutter/pull/155867)
  - _* Roll pub packages by @flutter-pub-roller-bot in [156114](https://github.com/flutter/flutter/pull/156114)_
- ⚪ [2] * [tool] Emit a deprecation warning for some values of --web-renderer. by @ditman in [156376](https://github.com/flutter/flutter/pull/156376)
  - _* Migrator for android 35/16kb page size cmake flags for plugin_ffi by @dcharkes in [156221](https://github.com/flutter/flutter/pull/156221)_
- ⚪ [2] * Add `SurfaceProducer#onSurfaceAvailable`, deprecate `onSurfaceCreated`. by @matanlurey in [55418](https://github.com/flutter/engine/pull/55418)
  - _* Add a boolean that exposes rotation/crop metadata capability. by @matanlurey in [55434](https://github.com/flutter/engine/pull/55434)_
- ⚪ [2] * Drop deprecated hash_code functions by @kevmoo in [54000](https://github.com/flutter/engine/pull/54000)
  - _* Reverts "Drop deprecated hash_code functions (#54000)" by @auto-submit in [54002](https://github.com/flutter/engine/pull/54002)_
- ⚪ [2] * dart:ui - drop deprecated hash functions by @kevmoo in [53787](https://github.com/flutter/engine/pull/53787)
  - _* Impeller really wants premultiplied alpha by @jtmcdole in [53770](https://github.com/flutter/engine/pull/53770)_
- ⚪ [2] * Prepare engine for deprecation of async_minitest.dart by @lrhn in [53560](https://github.com/flutter/engine/pull/53560)
  - _* Align `tools/android_sdk/packages.txt` with what is uploaded to CIPD by @gmackall in [53921](https://github.com/flutter/engine/pull/53921)_
- ⚪ [1] * [web] Warn users when picking a deprecated renderer. by @ditman in [55709](https://github.com/flutter/engine/pull/55709)
  - _* [canvaskit] Fix incorrect clipping with Opacity scene layer by @harryterkelsen in [55751](https://github.com/flutter/engine/pull/55751)_
- ⚪ [1] * [Fuchsia] Remove deprecated and unnecessary parameters from fuchsia*archive by @zijiehe-google-com in [55324](https://github.com/flutter/engine/pull/55324)
  - _* [Flutter GPU] Add setStencilReference to RenderPass. by @bdero in [55270](https://github.com/flutter/engine/pull/55270)_

**New Feature / API** (1)

- ⚪ [2] * added functionality to where SR will communicate button clicked by @DBowen33 in [152185](https://github.com/flutter/flutter/pull/152185)
  - _* Implement `on` clauses by @nate-thegrate in [152706](https://github.com/flutter/flutter/pull/152706)_

**Performance Improvement** (5)

- 🟡 [4] * Optimize `Overlay` sample to avoid overflow by @TahaTesser in [155861](https://github.com/flutter/flutter/pull/155861)
  - _* Fixes column text width calculation in CupertinoDatePicker by @Mairramer in [151128](https://github.com/flutter/flutter/pull/151128)_
- ⚪ [1] * Optimize out LayoutBuilder from ReorderableList children by @moffatman in [153987](https://github.com/flutter/flutter/pull/153987)
  - _* fix `getFullHeightForCaret` when strut is disabled. by @LongCatIsLooong in [154039](https://github.com/flutter/flutter/pull/154039)_
- ⚪ [1] * Remove allowoptimization modifier from FlutterPlugin proguard rules by @rajveermalviya in [154715](https://github.com/flutter/flutter/pull/154715)
  - _* Handle `ProcessException`s due to `git` missing on the host by @andrewkolos in [154445](https://github.com/flutter/flutter/pull/154445)_
- ⚪ [0] * Re-land "Ensure flutter build apk --release optimizes+shrinks platform code" by @gmackall in [153868](https://github.com/flutter/flutter/pull/153868)
  - _* Android analyze command should run pub by @chunhtai in [153953](https://github.com/flutter/flutter/pull/153953)_
- ⚪ [0] * [DisplayList] Optimize ClipRRect and ClipPath to ClipOval when appropriate by @flar in [54088](https://github.com/flutter/engine/pull/54088)
  - _* Split up mac_host_engine builds by @zanderso in [53571](https://github.com/flutter/engine/pull/53571)_

**Replacement / Migration** (10)

- 🔴 [9] * Update fake_codec.dart to use Future.value instead of SynchronousFuture by @biggs0125 in [152182](https://github.com/flutter/flutter/pull/152182)
  - _* Add a more typical / concrete example to IntrinsicHeight / IntrinsicWidth by @LongCatIsLooong in [152246](https://github.com/flutter/flutter/pull/152246)_
- 🔴 [5] * [Flutter GPU] Use vm.Vector4 for clear color instead of ui.Color. by @bdero in [55416](https://github.com/flutter/engine/pull/55416)
  - _* [scenario_app] delete get bitmap activity. by @jonahwilliams in [55436](https://github.com/flutter/engine/pull/55436)_
- 🟡 [4] * [iOS] Switch to FlutterMetalLayer by default. by @jonahwilliams in [54086](https://github.com/flutter/engine/pull/54086)
  - _* [Impeller] Implement draw order optimization. by @bdero in [54067](https://github.com/flutter/engine/pull/54067)_
- 🟡 [3] * Directly use 4x4 matrices with surface textures instead of converting to and from the 3x3 variants. by @chinmaygarde in [54126](https://github.com/flutter/engine/pull/54126)
  - _* [Impeller] Enable on-by-default on Android. by @chinmaygarde in [54156](https://github.com/flutter/engine/pull/54156)_
- 🟡 [3] * [engine] reland weaken affinity of raster/ui to non-e core instead of only fast core by @jonahwilliams in [54616](https://github.com/flutter/engine/pull/54616)
  - _* Remove spammy warning message on `FlutterView` by @matanlurey in [54686](https://github.com/flutter/engine/pull/54686)_
- 🟡 [3] * [web:canvaskit] switch to temporary SkPaint objects by @yjbanov in [54818](https://github.com/flutter/engine/pull/54818)
  - _* Add `crossOrigin` property to  tag used for decoding by @harryterkelsen in [54961](https://github.com/flutter/engine/pull/54961)_
- 🟡 [3] * Use GNI group instead of hardcoding PNG codecs source files. by @anforowicz in [54781](https://github.com/flutter/engine/pull/54781)
  - _* macOS: Do not archive/upload FlutterMacOS.dSYM to cloud by @cbracken in [54787](https://github.com/flutter/engine/pull/54787)_
- ⚪ [2] * [web] Pass `--no-source-maps` instead of `--extra-compiler-option=--no-source-maps` to `dart compile wasm` by @mkustermann in [153417](https://github.com/flutter/flutter/pull/153417)
  - _* [Swift Package Manager] Test removing the last Flutter plugin by @loic-sharma in [153519](https://github.com/flutter/flutter/pull/153519)_
- ⚪ [2] * [web] switch to SemanticsAction.focus (attempt 3) by @yjbanov in [53689](https://github.com/flutter/engine/pull/53689)
  - _* [web] fix unexpected scrolling in semantics by @yjbanov in [53922](https://github.com/flutter/engine/pull/53922)_
- ⚪ [2] * [fuchsia][sysmem2] move to sysmem2 protocols by @dustingreen in [53138](https://github.com/flutter/engine/pull/53138)
  - _* Revert 4 Dart rolls (726cb2467 -> ffc8bb004) to recover engine roll by @bdero in [53778](https://github.com/flutter/engine/pull/53778)_

---

### 3.24.0

**Deprecation** (8)

- 🔴 [7] * Deprecate `ButtonBar`, `ButtonBarThemeData`, and `ThemeData.buttonBarTheme` by @TahaTesser in [145523](https://github.com/flutter/flutter/pull/145523)
  - _* Fix `MenuItemButton` overflow by @TahaTesser in [143932](https://github.com/flutter/flutter/pull/143932)_
- 🟡 [4] * Migrate off deprecated GrVkBackendContext fields by @kjlubick in [53122](https://github.com/flutter/engine/pull/53122)
  - _* [Impeller] fix NPE caused by implicit sk_sp to fml::Status conversion. by @jonahwilliams in [53177](https://github.com/flutter/engine/pull/53177)_
- 🟡 [4] * Update uses of GrVkBackendContext and other deprecated type names by @kjlubick in [53491](https://github.com/flutter/engine/pull/53491)
  - _* [fuchsia] Update Fuchsia API level to 19 by @jrwang in [53494](https://github.com/flutter/engine/pull/53494)_
- ⚪ [2] * Replace CocoaPods deprecated `exists?` with `exist?` by @vashworth in [147056](https://github.com/flutter/flutter/pull/147056)
  - _* Update docs around ga3 ga4 mismatch by @eliasyishak in [147075](https://github.com/flutter/flutter/pull/147075)_
- ⚪ [2] * Remove outdated `deprecated_member_use` ignores by @goderbauer in [51836](https://github.com/flutter/engine/pull/51836)
  - _* Revert "Prevent `solo: true` from being committed" by @zanderso in [51858](https://github.com/flutter/engine/pull/51858)_
- ⚪ [2] * Use non-deprecated replacements for Android JUnit and test instrumentation by @matanlurey in [51854](https://github.com/flutter/engine/pull/51854)
  - _* [scenarios] dont do a weird invalidate on TextView. by @jonahwilliams in [51866](https://github.com/flutter/engine/pull/51866)_
- ⚪ [2] * Remove TODO I will never do: `runIfNot` is deprecated. by @matanlurey in [52308](https://github.com/flutter/engine/pull/52308)
  - _* Document the new binding hooks for SceneBuilder, PictureRecorder, Canvas by @Hixie in [52374](https://github.com/flutter/engine/pull/52374)_
- ⚪ [1] * Fixes `flutter build ipa` failure: Command line name "app-store" is deprecated. Use "app-store-connect" by @LouiseHsu in [150407](https://github.com/flutter/flutter/pull/150407)
  - _* Have flutter.js load local canvaskit instead of the CDN when appropriate by @eyebrowsoffire in [150806](https://github.com/flutter/flutter/pull/150806)_

**Breaking Change** (3)

- ⚪ [1] * Fix TwoDimensionalViewport's keep alive child not always removed (when no longer should be kept alive) by @gawi151 in [148298](https://github.com/flutter/flutter/pull/148298)
  - _* Add test for text_editing_controller.0.dart API example. by @ksokolovskyi in [148872](https://github.com/flutter/flutter/pull/148872)_
- ⚪ [1] * Fix some links in the "Handling breaking change" section by @mdebbar in [149821](https://github.com/flutter/flutter/pull/149821)
  - _* Fix leaky test. by @polina-c in [149822](https://github.com/flutter/flutter/pull/149822)_
- ⚪ [1] * Removed brand references from MenuAnchor.dart by @davidhicks980 in [148760](https://github.com/flutter/flutter/pull/148760)
  - _* `switch` expressions: finale by @nate-thegrate in [148711](https://github.com/flutter/flutter/pull/148711)_

**Performance Improvement** (3)

- ⚪ [1] * Reduce rebuild times when invoking 'et run' by @johnmccutchan in [52883](https://github.com/flutter/engine/pull/52883)
  - _* Rename Skia specific TUs. by @chinmaygarde in [52855](https://github.com/flutter/engine/pull/52855)_
- ⚪ [1] * Add an unoptimized Android debug config to local_engine.json. by @chinmaygarde in [53057](https://github.com/flutter/engine/pull/53057)
  - _* Remove use of --nnbd-agnostic by @johnniwinther in [53055](https://github.com/flutter/engine/pull/53055)_
- ⚪ [0] * [DisplayList] Add support for clipOval to leverage Impeller optimization by @flar in [53622](https://github.com/flutter/engine/pull/53622)
  - _* Revert "[DisplayList] Add support for clipOval to leverage Impeller optimization" by @flar in [53629](https://github.com/flutter/engine/pull/53629)_

**Replacement / Migration** (19)

- 🔴 [10] * Use `fml::ScopedCleanupClosure` instead of `DeathRattle`. by @matanlurey in [51834](https://github.com/flutter/engine/pull/51834)
  - _* Return an empty optional in HardwareBuffer::GetSystemUniqueID if the underlying NDK API is unavailable by @jason-simmons in [51839](https://github.com/flutter/engine/pull/51839)_
- 🔴 [8] * Switch to `Iterable.cast` instance method by @parlough in [150185](https://github.com/flutter/flutter/pull/150185)
  - _* Add tests for navigator.0.dart by @ValentinVignal in [150034](https://github.com/flutter/flutter/pull/150034)_
- 🔴 [8] * Copy any previous `IconThemeData` instead of overwriting it in CupertinoButton by @ricardoboss in [149777](https://github.com/flutter/flutter/pull/149777)
  - _* Manual engine roll to ddd4814 by @gmackall in [150952](https://github.com/flutter/flutter/pull/150952)_
- 🔴 [8] * Switch to relevant `Remote` constructors by @nate-thegrate in [146773](https://github.com/flutter/flutter/pull/146773)
  - _* Create web tests suite & update utils by @sealesj in [146592](https://github.com/flutter/flutter/pull/146592)_
- 🔴 [7] * Use super.key instead of manually passing the Key parameter to the parent class by @EchoEllet in [147621](https://github.com/flutter/flutter/pull/147621)
  - _* test material text field example by @NobodyForNothing in [147864](https://github.com/flutter/flutter/pull/147864)_
- 🔴 [7] * Use --(no-)strip-wams instead of --(no-)-name-section in `dart compile wasm` by @mkustermann in [150180](https://github.com/flutter/flutter/pull/150180)
  - _* Reland "Identify and re-throw our dependency checking errors in flutter.groovy" by @gmackall in [150128](https://github.com/flutter/flutter/pull/150128)_
- 🔴 [6] * Issue an`ERROR` instead of an `INFO` for a non-working API. by @matanlurey in [52892](https://github.com/flutter/engine/pull/52892)
  - _* Fix another instance of platform view breakage on Android 14 by @johnmccutchan in [52980](https://github.com/flutter/engine/pull/52980)_
- 🔴 [5] * Switch to FilterQuality.medium for images by @goderbauer in [148799](https://github.com/flutter/flutter/pull/148799)
  - _* Fix InputDecorator default hint text style on M3 by @bleroux in [148944](https://github.com/flutter/flutter/pull/148944)_
- 🔴 [5] * Switch to more reliable flutter.dev link destinations in the tool by @parlough in [150587](https://github.com/flutter/flutter/pull/150587)
  - _* [tool] when writing to openssl as a part of macOS/iOS code-signing, flush the stdin stream before closing it by @andrewkolos in [150120](https://github.com/flutter/flutter/pull/150120)_
- 🔴 [5] * Switch to triage-* labels for platform package triage by @stuartmorgan in [149614](https://github.com/flutter/flutter/pull/149614)
  - _* Bump github/codeql-action from 3.25.7 to 3.25.8 by @dependabot in [149691](https://github.com/flutter/flutter/pull/149691)_
- 🟡 [4] * [DisplayList] Switch to recording DrawVertices objects by reference by @flar in [53548](https://github.com/flutter/engine/pull/53548)
  - _* [Impeller] blur - cropped the downsample pass for backdrop filters by @gaaclarke in [53562](https://github.com/flutter/engine/pull/53562)_
- 🟡 [3] * Make goldenFileComparator a field instead of a trivial property by @Hixie in [146800](https://github.com/flutter/flutter/pull/146800)
  - _* Bump meta to 1.14.0 by @goderbauer in [146925](https://github.com/flutter/flutter/pull/146925)_
- 🟡 [3] * Have flutter.js load local canvaskit instead of the CDN when appropriate by @eyebrowsoffire in [150806](https://github.com/flutter/flutter/pull/150806)
  - _* [tool] make the `systemTempDirectory` getter on `ErrorHandlingFileSystem` wrap the underlying filesystem's temp directory in a`ErrorHandlingDirectory` by @andrewkolos in [150876](https://github.com/flutter/flutter/pull/150876)_
- 🟡 [3] * [web:tests] switch to new HTML DOM matcher by @yjbanov in [52354](https://github.com/flutter/engine/pull/52354)
  - _* Make SkUnicode explicitly instead of relying on SkParagraph to make it for us by @kjlubick in [52086](https://github.com/flutter/engine/pull/52086)_
- 🟡 [3] * Make SkUnicode explicitly instead of relying on SkParagraph to make it for us by @kjlubick in [52086](https://github.com/flutter/engine/pull/52086)
  - _* [skwasm] Change default `FilterQuality` to `None` for image shaders. by @eyebrowsoffire in [52468](https://github.com/flutter/engine/pull/52468)_
- 🟡 [3] * Move pictures from deleted canvases to second-to-last canvas instead of last. by @harryterkelsen in [51397](https://github.com/flutter/engine/pull/51397)
  - _* Allow unsetting `TextStyle.height` by @LongCatIsLooong in [52940](https://github.com/flutter/engine/pull/52940)_
- ⚪ [2] * Relands "[Impeller] moved to bgra10_xr (#52019)" by @gaaclarke in [52142](https://github.com/flutter/engine/pull/52142)
  - _* [Impeller] remove most temporary allocation during polyline generation. by @jonahwilliams in [52131](https://github.com/flutter/engine/pull/52131)_
- ⚪ [2] * [web] switch from .didGain/LoseAccessibilityFocus to .focus by @yjbanov in [53134](https://github.com/flutter/engine/pull/53134)
  - _* Fix character getter API usage in stripLeftSlashes/stripRightSlashes by @jason-simmons in [53299](https://github.com/flutter/engine/pull/53299)_
- ⚪ [2] * [macOS] Move to new present callback by @dkwingsmt in [51436](https://github.com/flutter/engine/pull/51436)
  - _* [Windows] Fix EGL surface destruction race by @loic-sharma in [51781](https://github.com/flutter/engine/pull/51781)_

---

### 3.22.0

**Deprecation** (16)

- 🔴 [7] * Remove deprecated `TextTheme` members by @Renzo-Olivares in [139255](https://github.com/flutter/flutter/pull/139255)
  - _* Update `TabBar` and `TabBar.secondary` to use indicator height/color M3 tokens by @TahaTesser in [145753](https://github.com/flutter/flutter/pull/145753)_
- 🔴 [5] * Remove deprecated `KeepAliveHandle.release` by @LongCatIsLooong in [143961](https://github.com/flutter/flutter/pull/143961)
  - _* Remove deprecated `InteractiveViewer.alignPanAxis` by @LongCatIsLooong in [142500](https://github.com/flutter/flutter/pull/142500)_
- 🔴 [5] * Remove deprecated `InteractiveViewer.alignPanAxis` by @LongCatIsLooong in [142500](https://github.com/flutter/flutter/pull/142500)
  - _* disable debug banner in m3 page test apps. by @jonahwilliams in [143857](https://github.com/flutter/flutter/pull/143857)_
- 🔴 [5] * Remove deprecated `CupertinoContextMenu.previewBuilder` by @LongCatIsLooong in [143990](https://github.com/flutter/flutter/pull/143990)
  - _* Clean up lint ignores by @eliasyishak in [144229](https://github.com/flutter/flutter/pull/144229)_
- 🟡 [4] * Migrate use of deprecated GrDirectContext::MakeMetal by @kjlubick in [51537](https://github.com/flutter/engine/pull/51537)
  - _* Move //buildtools to //flutter/buildtools by @jason-simmons in [51526](https://github.com/flutter/engine/pull/51526)_
- ⚪ [2] * Deprecate redundant itemExtent in RenderSliverFixedExtentBoxAdaptor methods by @Piinks in [143412](https://github.com/flutter/flutter/pull/143412)
  - _* Disable color filter sepia test for Impeller. by @jonahwilliams in [143861](https://github.com/flutter/flutter/pull/143861)_
- ⚪ [2] * Remove deprecated FlutterDriver.enableAccessibility by @Piinks in [143979](https://github.com/flutter/flutter/pull/143979)
  - _* Remove deprecated MediaQuery.boldTextOverride by @goderbauer in [143960](https://github.com/flutter/flutter/pull/143960)_
- ⚪ [2] * Remove deprecated TimelineSummary.writeSummaryToFile by @Piinks in [143983](https://github.com/flutter/flutter/pull/143983)
  - _* Remove deprecated AnimatedListItemBuilder, AnimatedListRemovedItemBuilder by @goderbauer in [143974](https://github.com/flutter/flutter/pull/143974)_
- ⚪ [2] * Add WidgetsApp.debugShowWidgetInspectorOverride again (deprecated) by @passsy in [145334](https://github.com/flutter/flutter/pull/145334)
  - _* `flutter test --wasm` support by @eyebrowsoffire in [145347](https://github.com/flutter/flutter/pull/145347)_
- ⚪ [2] * Deprecate M2 curves by @guidezpl in [134417](https://github.com/flutter/flutter/pull/134417)
  - _* Reland "Remove hack from PageView." by @polina-c in [141533](https://github.com/flutter/flutter/pull/141533)_
- ⚪ [2] * cleanup now-irrelevant ignores for `deprecated_member_use` by @goderbauer in [143403](https://github.com/flutter/flutter/pull/143403)
  - _* [a11y] Fix date picker cannot focus on the edit field by @hangyujin in [143117](https://github.com/flutter/flutter/pull/143117)_
- ⚪ [2] * Replace deprecated `exists` in podhelper.rb by @stuartmorgan in [141169](https://github.com/flutter/flutter/pull/141169)
  - _* Unpin package:vm_service by @derekxu16 in [141279](https://github.com/flutter/flutter/pull/141279)_
- ⚪ [2] * Allow deprecated members from the Dart SDK and Flutter Engine to roll in by @matanlurey in [143347](https://github.com/flutter/flutter/pull/143347)
  - _* Bump github/codeql-action from 3.24.0 to 3.24.1 by @dependabot in [143395](https://github.com/flutter/flutter/pull/143395)_
- ⚪ [2] * Disable deprecation warnings for mega_gallery by @goderbauer in [143466](https://github.com/flutter/flutter/pull/143466)
  - _* Remove certs installation from win_arm builds. by @godofredoc in [143487](https://github.com/flutter/flutter/pull/143487)_
- ⚪ [2] * Allow deprecated members from the Dart SDK to roll in. by @matanlurey in [50575](https://github.com/flutter/engine/pull/50575)
  - _* [engine_build_configs] Use dart:ffi Abi to determine the host cpu by @zanderso in [50604](https://github.com/flutter/engine/pull/50604)_
- ⚪ [1] * [Fuchsia] Create dedicated testers to run tests and deprecate femu_test by @zijiehe-google-com in [50697](https://github.com/flutter/engine/pull/50697)
  - _* [et] Adds a .bat entrypoint for Windows by @zanderso in [50784](https://github.com/flutter/engine/pull/50784)_

**New Feature / API** (2)

- ⚪ [2] * [New feature]Introduce iOS multi-touch drag behavior by @xu-baolin in [141355](https://github.com/flutter/flutter/pull/141355)
  - _* Set cacheExtent for SliverFillRemaining widget by @vashworth in [143612](https://github.com/flutter/flutter/pull/143612)_
- ⚪ [2] * Introduce methods for computing the baseline location of a RenderBox without affecting the current layout by @LongCatIsLooong in [144655](https://github.com/flutter/flutter/pull/144655)
  - _* Fix for issue 140372 by @prasadsunny1 in [144947](https://github.com/flutter/flutter/pull/144947)_

**Performance Improvement** (4)

- ⚪ [1] * Optimizations for TLHC frame rate and jank by @johnmccutchan in [50033](https://github.com/flutter/engine/pull/50033)
  - _* winding order from tesellator.h to formats.h by @nikkivirtuoso in [49865](https://github.com/flutter/engine/pull/49865)_
- ⚪ [1] * Manually revert TLHC optimizations, holding on to width/height changes. by @matanlurey in [50144](https://github.com/flutter/engine/pull/50144)
  - _* Re-Re-land Manually revert TLHC optimizations by @johnmccutchan in [50155](https://github.com/flutter/engine/pull/50155)_
- ⚪ [1] * Re-Re-land Manually revert TLHC optimizations by @johnmccutchan in [50155](https://github.com/flutter/engine/pull/50155)
  - _* Revert: "Change how OpenGL textures are flipped in the Android embedder" by @matanlurey in [50158](https://github.com/flutter/engine/pull/50158)_
- ⚪ [0] * Optimize overlays in CanvasKit by @harryterkelsen in [47317](https://github.com/flutter/engine/pull/47317)
  - _* Mark the Flutter Views as focusable by setting a tabindex value. by @tugorez in [50876](https://github.com/flutter/engine/pull/50876)_

**Replacement / Migration** (6)

- 🔴 [6] * Fix chips use square delete button `InkWell` shape instead of circular by @TahaTesser in [144319](https://github.com/flutter/flutter/pull/144319)
  - _* Fix `CalendarDatePicker` day selection shape and overlay by @TahaTesser in [144317](https://github.com/flutter/flutter/pull/144317)_
- 🟡 [3] * instead of exiting the tool, print a warning when using --flavor with an incompatible device by @andrewkolos in [143735](https://github.com/flutter/flutter/pull/143735)
  - _* [flutter_tools] enable wasm compile on beta channel by @kevmoo in [143779](https://github.com/flutter/flutter/pull/143779)_
- 🟡 [3] * Fix frameworks added to bundle multiple times instead of lipo by @knopp in [144688](https://github.com/flutter/flutter/pull/144688)
  - _* [flutter_tools] add custom tool analysis to analyze.dart, lint Future.catchError by @christopherfujino in [140122](https://github.com/flutter/flutter/pull/140122)_
- ⚪ [2] * [ios]ignore single edge pixel instead of rounding by @hellohuanlin in [51687](https://github.com/flutter/engine/pull/51687)
- ⚪ [2] * [Windows] Move to new present callback by @loic-sharma in [51293](https://github.com/flutter/engine/pull/51293)
  - _* Regenerate FlutterMacOS.xcframework when sources of dependencies change by @vashworth in [51396](https://github.com/flutter/engine/pull/51396)_
- ⚪ [2] * Use top-level GN arg for Skottie instead of CanvasKit-specific arg. by @johnstiles-google in [50019](https://github.com/flutter/engine/pull/50019)
  - _* [Fuchsia] Redo - Use chromium test-scripts to download images and execute tests by @zijiehe-google-com in [49940](https://github.com/flutter/engine/pull/49940)_

---

### 3.19.0

**Deprecation** (11)

- 🔴 [5] * Remove deprecated `PlatformMenuBar.body` by @gspencergoog in [138509](https://github.com/flutter/flutter/pull/138509)
  - _* Refactor to use Apple system fonts by @MitchellGoodwin in [137275](https://github.com/flutter/flutter/pull/137275)_
- 🔴 [5] * Deprecate `RawKeyEvent`, `RawKeyboard`, et al. by @gspencergoog in [136677](https://github.com/flutter/flutter/pull/136677)
  - _* Fix dayPeriodColor handling of non-MaterialStateColors by @gspencergoog in [139845](https://github.com/flutter/flutter/pull/139845)_
- ⚪ [2] * Change some usage of RawKeyEvent to KeyEvent in preparation for deprecation by @gspencergoog in [136420](https://github.com/flutter/flutter/pull/136420)
  - _* Test cover cupertino for memory leaks tracking -2 by @droidbg in [136577](https://github.com/flutter/flutter/pull/136577)_
- ⚪ [2] * [Android] Fix `FlutterTestRunner.java` deprecations by @camsim99 in [138093](https://github.com/flutter/flutter/pull/138093)
  - _* Remove physicalGeometry by @goderbauer in [138103](https://github.com/flutter/flutter/pull/138103)_
- ⚪ [2] * Reset deprecation period for setPubRootDirectories by @Piinks in [139592](https://github.com/flutter/flutter/pull/139592)
  - _* [Android] Bump template & integration test Gradle version to 7.6.4 by @camsim99 in [139276](https://github.com/flutter/flutter/pull/139276)_
- ⚪ [2] * Fix some deprecation details by @Piinks in [136385](https://github.com/flutter/flutter/pull/136385)
  - _* SearchBar should listen to changes to the SearchController and update suggestions on change by @bryanoli in [134337](https://github.com/flutter/flutter/pull/134337)_
- ⚪ [2] * Deprecates onWillAccept and onAccept callbacks in DragTarget. by @chinmoy12c in [133691](https://github.com/flutter/flutter/pull/133691)
  - _* Docs typo: comprised -> composed by @EnduringBeta in [137896](https://github.com/flutter/flutter/pull/137896)_
- ⚪ [2] * Remove deprecated bitcode stripping from tooling by @jmagman in [140903](https://github.com/flutter/flutter/pull/140903)
  - _* Fix local engine use in macOS plugins by @stuartmorgan in [140222](https://github.com/flutter/flutter/pull/140222)_
- ⚪ [2] * [cp] Replace deprecated `exists` in podhelper.rb by @stuartmorgan in [141381](https://github.com/flutter/flutter/pull/141381)
  - _* CP: [Beta] Update DWDS to version 23.0.0+1 by @elliette in [142168](https://github.com/flutter/flutter/pull/142168)_
- ⚪ [2] * Fix forward declare and some deprecated enums by @kjlubick in [46882](https://github.com/flutter/engine/pull/46882)
  - _* Reland - [Android] Add support for text processing actions by @bleroux in [46817](https://github.com/flutter/engine/pull/46817)_
- ⚪ [2] * Replace deprecated [UIScreen mainScreen] in FlutterView.mm by @mossmana in [46802](https://github.com/flutter/engine/pull/46802)
  - _* Don't respond to the `insertionPointColor` selector on iOS 17+ by @LongCatIsLooong in [46373](https://github.com/flutter/engine/pull/46373)_

**Breaking Change** (4)

- 🟡 [4] * Fix scrollable `TabBar` expands to full width when the divider is removed by @TahaTesser in [140963](https://github.com/flutter/flutter/pull/140963)
  - _* Fix refresh cancelation by @lukehutch in [139535](https://github.com/flutter/flutter/pull/139535)_
- 🟡 [3] * InheritedElement.removeDependent() by @s0nerik in [129210](https://github.com/flutter/flutter/pull/129210)
  - _* Cover text_selection tests with leak tracking. by @ksokolovskyi in [137009](https://github.com/flutter/flutter/pull/137009)_
- ⚪ [1] * Removed TBD translations for optional remainingTextFieldCharacterCounZero message by @HansMuller in [136684](https://github.com/flutter/flutter/pull/136684)
  - _* Fixed : Empty Rows shown at last page in Paginated data table by @aakash-pamnani in [132646](https://github.com/flutter/flutter/pull/132646)_
- ⚪ [1] * Use GdkEvent methods to access values, direct access is removed in GTK4. by @robert-ancell in [46526](https://github.com/flutter/engine/pull/46526)
  - _* Replace use of Skia's Base64 Encoding/Decoding logic with a copy of the equivalent code by @kjlubick in [46543](https://github.com/flutter/engine/pull/46543)_

**New Feature / API** (1)

- ⚪ [2] * Added Features requested in #137530 by @mhbdev in [137532](https://github.com/flutter/flutter/pull/137532)
  - _* Fix Chips with Tooltip throw an assertion when enabling or disabling by @TahaTesser in [138799](https://github.com/flutter/flutter/pull/138799)_

**Performance Improvement** (4)

- 🟡 [3] * Optimize the display of the Overlay on the Slider by @hgraceb in [139021](https://github.com/flutter/flutter/pull/139021)
  - _* Convert some usage of `RawKeyEvent`, et al to `KeyEvent` by @gspencergoog in [139329](https://github.com/flutter/flutter/pull/139329)_
- ⚪ [1] * Use `coverage.collect`'s `coverableLineCache` param to speed up coverage by @liamappelbe in [136851](https://github.com/flutter/flutter/pull/136851)
  - _* CustomPainterSemantics doc typo by @EnduringBeta in [137081](https://github.com/flutter/flutter/pull/137081)_
- ⚪ [1] * Optimize file transfer when using proxied devices. by @chingjun in [139968](https://github.com/flutter/flutter/pull/139968)
  - _* [deps] update Android SDK to 34 by @dcharkes in [138183](https://github.com/flutter/flutter/pull/138183)_
- ⚪ [0] * Ensure `flutter build apk --release` optimizes+shrinks platform code by @mkustermann in [136880](https://github.com/flutter/flutter/pull/136880)
  - _* Reverts "Ensure `flutter build apk --release` optimizes+shrinks platform code" by @auto-submit in [137433](https://github.com/flutter/flutter/pull/137433)_

**Replacement / Migration** (10)

- 🔴 [7] * Changes to use valuenotifier instead of a force rebuild for WidgetInspector by @CoderDake in [131634](https://github.com/flutter/flutter/pull/131634)
  - _* [Impeller] GPU frame timings summarization. by @jonahwilliams in [136408](https://github.com/flutter/flutter/pull/136408)_
- 🔴 [7] * Use --timeline_recorder=systrace instead of --systrace_timeline by @derekxu16 in [46884](https://github.com/flutter/engine/pull/46884)
  - _* [Impeller] Only allow Impeller in flutter_tester if vulkan is enabled. by @dnfield in [46895](https://github.com/flutter/engine/pull/46895)_
- 🔴 [6] * `OverlayPortal.overlayChild` contributes semantics to `OverlayPortal` instead of `Overlay` by @LongCatIsLooong in [134921](https://github.com/flutter/flutter/pull/134921)
  - _* Update `ColorScheme.fromSwatch` docs for Material 3 by @TahaTesser in [136816](https://github.com/flutter/flutter/pull/136816)_
- 🔴 [5] * fix typo of 'not' instead of 'now' for `useInheritedMediaQuery` by @timmaffett in [139940](https://github.com/flutter/flutter/pull/139940)
  - _* [Docs] Added missing `CupertinoApp.showSemanticsDebugger` by @piedcipher in [139913](https://github.com/flutter/flutter/pull/139913)_
- 🔴 [5] * Switch to Chrome for Testing instead of vanilla Chromium. by @eyebrowsoffire in [136214](https://github.com/flutter/flutter/pull/136214)
  - _* [Windows Arm64] Add the 'platform_channel_sample_test_windows' Devicelab test by @loic-sharma in [136401](https://github.com/flutter/flutter/pull/136401)_
- 🔴 [5] * [Windows] Move to `FlutterCompositor` for rendering by @loic-sharma in [48849](https://github.com/flutter/engine/pull/48849)
  - _* [Flutter GPU] Runtime shader import. by @bdero in [48875](https://github.com/flutter/engine/pull/48875)_
- 🔴 [5] * Switch to Chrome For Testing instead of Chromium by @eyebrowsoffire in [46683](https://github.com/flutter/engine/pull/46683)
  - _* [web] Stop using `flutterViewEmbedder` for platform views by @mdebbar in [46046](https://github.com/flutter/engine/pull/46046)_
- 🔴 [5] * Switch to Android 14 for physical device firebase tests by @gmackall in [47016](https://github.com/flutter/engine/pull/47016)
  - _* Move window state update to window realize callback by @gspencergoog in [47713](https://github.com/flutter/engine/pull/47713)_
- 🟡 [3] * Tiny improve code style by using records instead of lists by @fzyzcjy in [135886](https://github.com/flutter/flutter/pull/135886)
  - _* RenderEditable should dispose created layers. by @polina-c in [135942](https://github.com/flutter/flutter/pull/135942)_
- 🟡 [3] * Use flutter mirrors for non-google origin deps instead of fuchsia by @sealesj in [48735](https://github.com/flutter/engine/pull/48735)
  - _* Run tests on macOS 13 exclusively by @vashworth in [49099](https://github.com/flutter/engine/pull/49099)_

---

### 3.16.0

**Deprecation** (15)

- 🔴 [5] * Deprecate `useMaterial3` parameter in `ThemeData.copyWith()` by @QuncCccccc in [131455](https://github.com/flutter/flutter/pull/131455)
  - _* Update `BottomSheet.enableDrag` & `BottomSheet.showDragHandle` docs for animation controller by @TahaTesser in [131484](https://github.com/flutter/flutter/pull/131484)_
- ⚪ [2] * Adds more documentations around ignoreSemantics deprecations. by @chunhtai in [131287](https://github.com/flutter/flutter/pull/131287)
  - _* Revert "Replace TextField.canRequestFocus with TextField.focusNode.canRequestFocus" by @Jasguerrero in [132104](https://github.com/flutter/flutter/pull/132104)_
- ⚪ [2] * Deprecate `describeEnum`. by @bernaferrari in [125016](https://github.com/flutter/flutter/pull/125016)
  - _* Remove shrinkWrap from flexible_space_bar_test.dart by @thkim1011 in [132173](https://github.com/flutter/flutter/pull/132173)_
- ⚪ [2] * Add missing `ignore: deprecated_member_use` to unblock the engine roller by @LongCatIsLooong in [132280](https://github.com/flutter/flutter/pull/132280)
  - _* Keep alive support for 2D scrolling by @Piinks in [131641](https://github.com/flutter/flutter/pull/131641)_
- ⚪ [2] * Remove deprecated *TestValues from TestWindow by @goderbauer in [131098](https://github.com/flutter/flutter/pull/131098)
  - _* Enable literal_only_boolean_expressions by @goderbauer in [133186](https://github.com/flutter/flutter/pull/133186)_
- ⚪ [2] * Remove deprecated MaterialButtonWithIconMixin by @Piinks in [133173](https://github.com/flutter/flutter/pull/133173)
  - _* Remove deprecated PlatformViewsService.synchronizeToNativeViewHierarchy by @Piinks in [133175](https://github.com/flutter/flutter/pull/133175)_
- ⚪ [2] * Remove deprecated PlatformViewsService.synchronizeToNativeViewHierarchy by @Piinks in [133175](https://github.com/flutter/flutter/pull/133175)
  - _* Remove `ImageProvider.load`, `DecoderCallback` and `PaintingBinding.instantiateImageCodec` by @LongCatIsLooong in [132679](https://github.com/flutter/flutter/pull/132679)_
- ⚪ [2] * Remove deprecated androidOverscrollIndicator from ScrollBehaviors by @Piinks in [133181](https://github.com/flutter/flutter/pull/133181)
  - _* Remove deprecated onPlatformMessage from TestWindow and TestPlatformDispatcher by @Piinks in [133183](https://github.com/flutter/flutter/pull/133183)_
- ⚪ [2] * Remove deprecated onPlatformMessage from TestWindow and TestPlatformDispatcher by @Piinks in [133183](https://github.com/flutter/flutter/pull/133183)
  - _* Adds callback onWillAcceptWithDetails in DragTarget. by @chinmoy12c in [131545](https://github.com/flutter/flutter/pull/131545)_
- ⚪ [2] * Remove deprecated TestWindow.textScaleFactorTestValue/TestWindow.clearTextScaleFactorTestValue by @Renzo-Olivares in [133176](https://github.com/flutter/flutter/pull/133176)
  - _* Remove deprecated TestWindow.platformBrightnessTestValue/TestWindow.clearPlatformBrightnessTestValue by @Renzo-Olivares in [133178](https://github.com/flutter/flutter/pull/133178)_
- ⚪ [2] * Remove deprecated TestWindow.platformBrightnessTestValue/TestWindow.clearPlatformBrightnessTestValue by @Renzo-Olivares in [133178](https://github.com/flutter/flutter/pull/133178)
  - _* Mark leak in _DayPickerState. by @polina-c in [133863](https://github.com/flutter/flutter/pull/133863)_
- ⚪ [2] * Remove chip tooltip deprecations by @Piinks in [134486](https://github.com/flutter/flutter/pull/134486)
  - _* Enable private field promotion for examples by @goderbauer in [134478](https://github.com/flutter/flutter/pull/134478)_
- ⚪ [2] * Remove deprecated MOCK_METHODx calls by @dkwingsmt in [45307](https://github.com/flutter/engine/pull/45307)
  - _* Adds a comment on clang_arm64_apilevel26 toolchain usage by @zanderso in [45467](https://github.com/flutter/engine/pull/45467)_
- ⚪ [2] * Replace deprecated [UIScreen mainScreen] in FlutterViewController.mm and FlutterViewControllerTest.mm by @mossmana in [43690](https://github.com/flutter/engine/pull/43690)
  - _* Uncap framerate for `iOSAppOnMac` by @moffatman in [43840](https://github.com/flutter/engine/pull/43840)_
- ⚪ [1] * [Android] Deletes deprecated splash screen meta-data element by @camsim99 in [130744](https://github.com/flutter/flutter/pull/130744)
  - _* Relax syntax for gen-l10n by @thkim1011 in [130736](https://github.com/flutter/flutter/pull/130736)_

**Breaking Change** (5)

- ⚪ [1] * Handle breaking changes in leak_tracker. by @polina-c in [131998](https://github.com/flutter/flutter/pull/131998)
  - _* More documentation about warm-up frames by @Hixie in [132085](https://github.com/flutter/flutter/pull/132085)_
- ⚪ [1] * Unpin leak_tracker and handle breaking changes in API. by @polina-c in [132352](https://github.com/flutter/flutter/pull/132352)
  - _* Update menu examples for `SafeArea` by @TahaTesser in [132390](https://github.com/flutter/flutter/pull/132390)_
- ⚪ [1] * removed unused variable in the example code of semantic event by @chrisdlangham in [134551](https://github.com/flutter/flutter/pull/134551)
  - _* Cover more test/widgets tests with leak tracking #4 by @ksokolovskyi in [134663](https://github.com/flutter/flutter/pull/134663)_
- ⚪ [1] * Resolve breaking change of adding a method to ChangeNotifier. by @polina-c in [134953](https://github.com/flutter/flutter/pull/134953)
  - _* Reland Resolve breaking change of adding a method to ChangeNotifier. by @polina-c in [134983](https://github.com/flutter/flutter/pull/134983)_
- ⚪ [1] * Pin leak_tracker before publishing breaking change. by @polina-c in [135720](https://github.com/flutter/flutter/pull/135720)
  - _* [flutter_tools] remove VmService screenshot for native devices. by @jonahwilliams in [135462](https://github.com/flutter/flutter/pull/135462)_

**New Feature / API** (4)

- 🔴 [5] * [New feature] Allowing the `ListView` slivers to have different extents while still having scrolling performance by @xu-baolin in [131393](https://github.com/flutter/flutter/pull/131393)
  - _* Revert "Adds a parent scope TraversalEdgeBehavior and fixes modal rou… by @chunhtai in [134550](https://github.com/flutter/flutter/pull/134550)_
- ⚪ [2] * added option to change color of heading row(flutter#132428) by @salmanulfarisi in [132728](https://github.com/flutter/flutter/pull/132728)
  - _* Fix stuck predictive back platform channel calls by @justinmc in [133368](https://github.com/flutter/flutter/pull/133368)_
- ⚪ [2] * Added option to disable [NavigationDrawerDestination]s by @matheus-kirchesch-btor in [132349](https://github.com/flutter/flutter/pull/132349)
  - _* _RenderChip should not create OpacityLayer without disposing. by @polina-c in [134708](https://github.com/flutter/flutter/pull/134708)_
- ⚪ [2] * Added option to disable [NavigationDestination]s ([NavigationBar] destination widget) by @matheus-kirchesch-btor in [132361](https://github.com/flutter/flutter/pull/132361)
  - _* Fix TabBarView.viewportFraction change is ignored by @bleroux in [135590](https://github.com/flutter/flutter/pull/135590)_

**New Parameter / Option** (3)

- ⚪ [2] * added option to change color of heading row(flutter#132428) by @salmanulfarisi in [132728](https://github.com/flutter/flutter/pull/132728)
  - _* Fix stuck predictive back platform channel calls by @justinmc in [133368](https://github.com/flutter/flutter/pull/133368)_
- ⚪ [2] * Added option to disable [NavigationDrawerDestination]s by @matheus-kirchesch-btor in [132349](https://github.com/flutter/flutter/pull/132349)
  - _* _RenderChip should not create OpacityLayer without disposing. by @polina-c in [134708](https://github.com/flutter/flutter/pull/134708)_
- ⚪ [2] * Added option to disable [NavigationDestination]s ([NavigationBar] destination widget) by @matheus-kirchesch-btor in [132361](https://github.com/flutter/flutter/pull/132361)
  - _* Fix TabBarView.viewportFraction change is ignored by @bleroux in [135590](https://github.com/flutter/flutter/pull/135590)_

**Performance Improvement** (8)

- ⚪ [1] * Super tiny code optimization: No need to redundantly check whether value has changed by @fzyzcjy in [130050](https://github.com/flutter/flutter/pull/130050)
  - _* Revert "fix a bug when android uses CupertinoPageTransitionsBuilder..." by @HansMuller in [130144](https://github.com/flutter/flutter/pull/130144)_
- ⚪ [1] * Optimize SliverMainAxisGroup/SliverCrossAxisGroup paint function by @thkim1011 in [129310](https://github.com/flutter/flutter/pull/129310)
  - _* Update link to unbounded constraints error by @goderbauer in [131205](https://github.com/flutter/flutter/pull/131205)_
- ⚪ [1] * Improve and optimize non-uniform Borders. by @bernaferrari in [124417](https://github.com/flutter/flutter/pull/124417)
  - _* Disable test order randomization on some leak tracker tests that are failing with today's seed by @jason-simmons in [132766](https://github.com/flutter/flutter/pull/132766)_
- ⚪ [1] * Make PollingDeviceDiscovery start the initial poll faster. by @chingjun in [130755](https://github.com/flutter/flutter/pull/130755)
  - _* Migrate more integration tests to process result matcher by @christopherfujino in [130994](https://github.com/flutter/flutter/pull/130994)_
- ⚪ [1] * [flutter_tools/dap] Improve rendering of structured errors via DAP by @DanTup in [131251](https://github.com/flutter/flutter/pull/131251)
  - _* Upgrade compile and target sdk versions in tests and benchmarks by @gmackall in [131428](https://github.com/flutter/flutter/pull/131428)_
- ⚪ [1] * Speed up native assets target by @dcharkes in [134523](https://github.com/flutter/flutter/pull/134523)
  - _* Makes scheme and target optional parameter when getting universal lin… by @chunhtai in [134571](https://github.com/flutter/flutter/pull/134571)_
- ⚪ [1] * Optimizing performance by avoiding multiple GC operations caused by multiple surface destruction notifications by @0xZOne in [43587](https://github.com/flutter/engine/pull/43587)
  - _* Add a PlatformViewRenderTarget abstraction by @johnmccutchan in [43813](https://github.com/flutter/engine/pull/43813)_
- ⚪ [0] * [web] More efficient fallback font selection by @rakudrama in [44526](https://github.com/flutter/engine/pull/44526)
  - _* Update deps on DDC build targets by @nshahan in [45404](https://github.com/flutter/engine/pull/45404)_

**Replacement / Migration** (4)

- 🔴 [7] * Use utf8.encode() instead of longer const Utf8Encoder.convert() by @mkustermann in [130567](https://github.com/flutter/flutter/pull/130567)
  - _* Fix material date picker behavior when changing year by @Lexycon in [130486](https://github.com/flutter/flutter/pull/130486)_
- 🔴 [7] * Use `start` instead of `extent` for Windows IME cursor position by @yaakovschectman in [45667](https://github.com/flutter/engine/pull/45667)
  - _* Handle external window's `WM_CLOSE` in lifecycle manager by @yaakovschectman in [45840](https://github.com/flutter/engine/pull/45840)_
- 🟡 [3] * Add `--local-engine-host`, which if specified, is used instead of being inferred by @matanlurey in [132180](https://github.com/flutter/flutter/pull/132180)
  - _* Fix flutter attach local engine by @christopherfujino in [131825](https://github.com/flutter/flutter/pull/131825)_
- 🟡 [3] * Implement JSObject instead of extending by @srujzs in [46070](https://github.com/flutter/engine/pull/46070)
  - _* Enable strict-inference by @goderbauer in [46062](https://github.com/flutter/engine/pull/46062)_

---

### 3.13.0

**Deprecation** (10)

- 🟡 [4] * Remove AbstractNode from RenderObject and deprecate it by @goderbauer in [128973](https://github.com/flutter/flutter/pull/128973)
  - _* Accept Diagnosticable as input in inspector API. by @polina-c in [128962](https://github.com/flutter/flutter/pull/128962)_
- ⚪ [2] * Migrate away from deprecated BinaryMessenger API by @goderbauer in [124348](https://github.com/flutter/flutter/pull/124348)
  - _* Fix InkWell ripple visible on right click when not expected by @bleroux in [124386](https://github.com/flutter/flutter/pull/124386)_
- ⚪ [2] * Remove deprecations from TextSelectionHandleControls instances by @justinmc in [124611](https://github.com/flutter/flutter/pull/124611)
  - _* DraggableScrollableSheet & NestedScrollView should respect NeverScrollableScrollPhysics by @xu-baolin in [123109](https://github.com/flutter/flutter/pull/123109)_
- ⚪ [2] * Improve the docs around the TextSelectionHandleControls deprecations by @justinmc in [123827](https://github.com/flutter/flutter/pull/123827)
  - _* Refactor `SliverAppBar.medium` & `SliverAppBar.large` to fix several issues by @TahaTesser in [122542](https://github.com/flutter/flutter/pull/122542)_
- ⚪ [2] * Deprecates string for reorderable list in material_localizations by @chunhtai in [124711](https://github.com/flutter/flutter/pull/124711)
  - _* Fix Chip highlight color isn't drawn on top of the background color by @TahaTesser in [124673](https://github.com/flutter/flutter/pull/124673)_
- ⚪ [2] * Remove uses of deprecated test_api imports by @natebosch in [124732](https://github.com/flutter/flutter/pull/124732)
  - _* Toolbar should re-appear on drag end by @Renzo-Olivares in [125165](https://github.com/flutter/flutter/pull/125165)_
- ⚪ [2] * Remove some ignores for un-deprecated imports by @natebosch in [125261](https://github.com/flutter/flutter/pull/125261)
  - _* Adjust selection rects inclusion criteria by @moffatman in [125022](https://github.com/flutter/flutter/pull/125022)_
- ⚪ [2] * Remove deprecated fixTextFieldOutlineLabel by @Renzo-Olivares in [125893](https://github.com/flutter/flutter/pull/125893)
  - _* Remove obsolete drawShadow bounds workaround by @flar in [127052](https://github.com/flutter/flutter/pull/127052)_
- ⚪ [2] * Removes deprecated APIs from v2.6 in `binding.dart` and `widget_tester.dart` by @pdblasi-google in [129663](https://github.com/flutter/flutter/pull/129663)
  - _* Reland Fix AnimatedList & AnimatedGrid doesn't apply MediaQuery padding #129556 by @HansMuller in [129860](https://github.com/flutter/flutter/pull/129860)_
- ⚪ [2] * Remove some trivial deprecated symbol usages in iOS Embedder by @cyanglaz in [42711](https://github.com/flutter/engine/pull/42711)
  - _* [ios] view controller based status bar by @cyanglaz in [42643](https://github.com/flutter/engine/pull/42643)_

**Breaking Change** (5)

- 🟡 [4] * [CP] Allow `OverlayPortal` to be added/removed from the tree in a layout callback (#130670) by @LongCatIsLooong in [131290](https://github.com/flutter/flutter/pull/131290)
  - _* [CP] `_RenderScaledInlineWidget` constrains child size (#130648) by @LongCatIsLooong in [131289](https://github.com/flutter/flutter/pull/131289)_
- ⚪ [1] * Address leak tracker breaking changes. by @polina-c in [128623](https://github.com/flutter/flutter/pull/128623)
  - _* Fix RangeSlider notifies start and end twice when participates in gesture arena by @nt4f04uNd in [128674](https://github.com/flutter/flutter/pull/128674)_
- ⚪ [1] * Allow .xcworkspace and .xcodeproj to be renamed from default name 'Runner' by @LouiseHsu in [124533](https://github.com/flutter/flutter/pull/124533)
  - _* Adding printOnFailure for result of process by @eliasyishak in [125910](https://github.com/flutter/flutter/pull/125910)_
- ⚪ [1] * improvement : removed required kotlin dependency by @albertoazinar in [125002](https://github.com/flutter/flutter/pull/125002)
  - _* Rename iosdeeplinksettings to iosuniversallinksettings by @chunhtai in [126173](https://github.com/flutter/flutter/pull/126173)_
- ⚪ [1] * [platform_view] Only dispose view when it is removed from the composition order by @cyanglaz in [41521](https://github.com/flutter/engine/pull/41521)
  - _* Disable flaky tests on arm64 by @dnfield in [41740](https://github.com/flutter/engine/pull/41740)_

**New Feature / API** (1)

- 🟡 [4] * [CupertinoListSection] adds new property separatorColor by @piedcipher in [124803](https://github.com/flutter/flutter/pull/124803)
  - _* iOS context menu shadow by @justinmc in [122429](https://github.com/flutter/flutter/pull/122429)_

**New Parameter / Option** (2)

- 🟡 [4] * [CupertinoListSection] adds new property separatorColor by @piedcipher in [124803](https://github.com/flutter/flutter/pull/124803)
  - _* iOS context menu shadow by @justinmc in [122429](https://github.com/flutter/flutter/pull/122429)_
- ⚪ [2] * [tools] allow explicitly specifying the JDK to use via a new config setting by @andrewkolos in [128264](https://github.com/flutter/flutter/pull/128264)
  - _* Adds vmservices to retrieve android applink settings by @chunhtai in [125998](https://github.com/flutter/flutter/pull/125998)_

**Replacement / Migration** (10)

- 🔴 [7] * Advise developers to use OverflowBar instead of ButtonBar by @leighajarett in [128437](https://github.com/flutter/flutter/pull/128437)
  - _* Sliver Main Axis Group by @thkim1011 in [126596](https://github.com/flutter/flutter/pull/126596)_
- 🔴 [7] * Give channel descriptions in `flutter channel`, use branch instead of upstream for channel name by @Hixie in [126936](https://github.com/flutter/flutter/pull/126936)
  - _* Revert "Replace rsync when unzipping artifacts on a Mac (#126703)" by @vashworth in [127430](https://github.com/flutter/flutter/pull/127430)_
- 🔴 [6] * [flutter_tools] modify Skeleton template to use ListenableBuilder instead of AnimatedBuilder by @fabiancrx in [128810](https://github.com/flutter/flutter/pull/128810)
  - _* [CP] Fix ConcurrentModificationError in DDS by @christopherfujino in [130740](https://github.com/flutter/flutter/pull/130740)_
- 🟡 [3] * Use term wireless instead of network by @vashworth in [124232](https://github.com/flutter/flutter/pull/124232)
  - _* [flutter_tools] add todo for userMessages by @andrewkolos in [125156](https://github.com/flutter/flutter/pull/125156)_
- 🟡 [3] * tool-web-wasm: make wasm-opt an "option" instead of a "flag" by @kevmoo in [126035](https://github.com/flutter/flutter/pull/126035)
  - _* Adding vmservice to get iOS app settings by @chunhtai in [123156](https://github.com/flutter/flutter/pull/123156)_
- 🟡 [3] * Suggest that people move to "beta" when they upgrade on "master" by @Hixie in [127146](https://github.com/flutter/flutter/pull/127146)
  - _* Show warning when attempting to flutter run on an ios device with developer mode turned off by @LouiseHsu in [125710](https://github.com/flutter/flutter/pull/125710)_
- 🟡 [3] * Remove package:js references and move to dart:js_interop by @srujzs in [41212](https://github.com/flutter/engine/pull/41212)
  - _* Turn @staticInterop tear-off into closure by @srujzs in [41643](https://github.com/flutter/engine/pull/41643)_
- ⚪ [2] * [Android] Lifecycle defaults to focused instead of unfocused by @gspencergoog in [41875](https://github.com/flutter/engine/pull/41875)
  - _* [Impeller] [Android] Refactor the Android context/surface implementation to work more like Skia. by @dnfield in [41059](https://github.com/flutter/engine/pull/41059)_
- ⚪ [2] * [web] Update a11y announcements to append divs instead of setting content. by @marcianx in [42258](https://github.com/flutter/engine/pull/42258)
  - _* [web] Hide JS types from dart:ui_web by @mdebbar in [42252](https://github.com/flutter/engine/pull/42252)_
- ⚪ [2] * [web] Move announcement live elements to the end of the DOM and make them `div`s instead of `label`s. by @marcianx in [42432](https://github.com/flutter/engine/pull/42432)
  - _* [web] New platform view API to get view by ID by @mdebbar in [41784](https://github.com/flutter/engine/pull/41784)_

---

### 3.10.0

**Deprecation** (18)

- 🔴 [7] * Remove deprecated `AppBar.color` & `AppBar.backwardsCompatibility` by @LongCatIsLooong in [120618](https://github.com/flutter/flutter/pull/120618)
  - _* Revert "Fix error when resetting configurations in tear down phase" by @loic-sharma in [120739](https://github.com/flutter/flutter/pull/120739)_
- 🔴 [5] * Deprecates `TestWindow` by @pdblasi-google in [122824](https://github.com/flutter/flutter/pull/122824)
  - _* Bump lower Dart SDK constraints to 3.0 & add class modifiers by @goderbauer in [122546](https://github.com/flutter/flutter/pull/122546)_
- 🔴 [5] * @alwaysThrows is deprecated. Return `Never` instead. by @eyebrowsoffire in [39269](https://github.com/flutter/engine/pull/39269)
  - _* [macOS] Move A11yBridge to FVC by @dkwingsmt in [38855](https://github.com/flutter/engine/pull/38855)_
- 🟡 [4] * Remove deprecated SystemNavigator.routeUpdated method by @goderbauer in [119187](https://github.com/flutter/flutter/pull/119187)
  - _* Deprecate MediaQuery[Data].fromWindow by @goderbauer in [119647](https://github.com/flutter/flutter/pull/119647)_
- 🟡 [4] * Remove deprecated accentTextTheme and accentIconTheme members from ThemeData by @Renzo-Olivares in [119360](https://github.com/flutter/flutter/pull/119360)
  - _* fix a [SelectableRegion] crash bug by @xu-baolin in [120076](https://github.com/flutter/flutter/pull/120076)_
- ⚪ [2] * Remove doc reference to the deprecated ui.FlutterWindow API by @jason-simmons in [118064](https://github.com/flutter/flutter/pull/118064)
  - _* Added expandIconColor property on ExpansionPanelList Widget by @M97Chahboun in [115950](https://github.com/flutter/flutter/pull/115950)_
- ⚪ [2] * Remove deprecated AnimatedSize.vsync parameter by @goderbauer in [119186](https://github.com/flutter/flutter/pull/119186)
  - _* Add debug diagnostics to channels integration test by @goderbauer in [119579](https://github.com/flutter/flutter/pull/119579)_
- ⚪ [2] * Remove deprecated kind in GestureRecognizer et al by @Piinks in [119572](https://github.com/flutter/flutter/pull/119572)
  - _* [framework] use shader tiling instead of repeated calls to drawImage by @jonahwilliams in [119495](https://github.com/flutter/flutter/pull/119495)_
- ⚪ [2] * Deprecate BindingBase.window by @goderbauer in [120998](https://github.com/flutter/flutter/pull/120998)
  - _* Remove indicator from scrolling tab bars by @Piinks in [123057](https://github.com/flutter/flutter/pull/123057)_
- ⚪ [2] * Fix warning in `flutter create`d project ("package attribute is deprecated" in AndroidManifest) by @bartekpacia in [123426](https://github.com/flutter/flutter/pull/123426)
  - _* Fix off-screen selected text throws exception by @TahaTesser in [123595](https://github.com/flutter/flutter/pull/123595)_
- ⚪ [2] * Hyperlink dart docs around BinaryMessenger deprecations by @goderbauer in [123798](https://github.com/flutter/flutter/pull/123798)
  - _* Fix docs and error messages for scroll directions + sample code by @Piinks in [123819](https://github.com/flutter/flutter/pull/123819)_
- ⚪ [2] * Deprecate these old APIs by @Hixie in [116793](https://github.com/flutter/flutter/pull/116793)
  - _* Make tester.startGesture less async, for better stack traces by @gnprice in [123946](https://github.com/flutter/flutter/pull/123946)_
- ⚪ [2] * TextSelectionHandleControls deprecation deletion timeframe by @justinmc in [124262](https://github.com/flutter/flutter/pull/124262)
  - _* [DropdownMenu] add helperText & errorText to DropdownMenu Widget by @piedcipher in [123775](https://github.com/flutter/flutter/pull/123775)_
- ⚪ [2] * Use `dart pub` instead of `dart __deprecated pub` by @sigurdm in [121605](https://github.com/flutter/flutter/pull/121605)
  - _* [tool] Proposal to multiple defines for --dart-define-from-file by @ronnnnn in [120878](https://github.com/flutter/flutter/pull/120878)_
- ⚪ [2] * Deprecate WindowPadding by @goderbauer in [39775](https://github.com/flutter/engine/pull/39775)
  - _* Roll Skia from 335cabcf8b99 to 080897012390 (4 revisions) by @skia-flutter-autoroll in [39802](https://github.com/flutter/engine/pull/39802)_
- ⚪ [2] * Deprecate SingletonFlutterWindow and global window singleton by @goderbauer in [39302](https://github.com/flutter/engine/pull/39302)
  - _* [Impeller] Avoid truncation to zero when resizing threadgroups by @dnfield in [40502](https://github.com/flutter/engine/pull/40502)_
- ⚪ [1] * [web] stop using deprecated jsonwire web-driver protocol by @yjbanov in [122560](https://github.com/flutter/flutter/pull/122560)
  - _* Reland: Updates `flutter/test/gestures` to no longer reference `TestWindow` by @pdblasi-google in [122619](https://github.com/flutter/flutter/pull/122619)_
- ⚪ [1] * [fuchsia] Replace deprecated AddLocalChild by @richkadel in [38788](https://github.com/flutter/engine/pull/38788)
  - _* Roll Skia from e1f3980272f3 to dfb838747295 (48 revisions) by @skia-flutter-autoroll in [38790](https://github.com/flutter/engine/pull/38790)_

**Breaking Change** (4)

- ⚪ [1] * Removed "if" on resolving text color at "SnackBarAction" by @MarchMore in [120050](https://github.com/flutter/flutter/pull/120050)
  - _* Fix BottomAppBar & BottomSheet M3 shadow by @esouthren in [119819](https://github.com/flutter/flutter/pull/119819)_
- ⚪ [1] * Removed "typically non-null" API doc qualifiers from ScrollMetrics min,max extent getters by @HansMuller in [121572](https://github.com/flutter/flutter/pull/121572)
  - _* showOnScreen does not crash if target node doesn't exist anymore by @goderbauer in [121575](https://github.com/flutter/flutter/pull/121575)_
- ⚪ [1] * removed forbidden skia include by @gaaclarke in [38761](https://github.com/flutter/engine/pull/38761)
  - _* Roll Dart SDK from 7b4d49402252 to 23cbd61a1327 (1 revision) by @skia-flutter-autoroll in [38764](https://github.com/flutter/engine/pull/38764)_
- ⚪ [0] * Handle removed shaders more gracefully in malioc_diff.py by @zanderso in [40720](https://github.com/flutter/engine/pull/40720)
  - _* Update ICU dependency to updated build by @yaakovschectman in [40676](https://github.com/flutter/engine/pull/40676)_

**New Feature / API** (1)

- ⚪ [2] * feature/clean-a-specific-scheme: Add this-scheme new flag for clean c… by @EArminjon in [116733](https://github.com/flutter/flutter/pull/116733)
  - _* [tool][web] Makes flutter.js more G3 friendly. by @ditman in [120504](https://github.com/flutter/flutter/pull/120504)_

**New Parameter / Option** (1)

- ⚪ [2] * feature/clean-a-specific-scheme: Add this-scheme new flag for clean c… by @EArminjon in [116733](https://github.com/flutter/flutter/pull/116733)
  - _* [tool][web] Makes flutter.js more G3 friendly. by @ditman in [120504](https://github.com/flutter/flutter/pull/120504)_

**Performance Improvement** (7)

- ⚪ [1] * Speed up first asset load by encoding asset manifest in binary rather than JSON by @andrewkolos in [113637](https://github.com/flutter/flutter/pull/113637)
  - _* Improve Flex layout comment by @loic-sharma in [116004](https://github.com/flutter/flutter/pull/116004)_
- ⚪ [1] * Speed up first asset load by using the binary-formatted asset manifest for image resolution by @andrewkolos in [118782](https://github.com/flutter/flutter/pull/118782)
  - _* [web] Unify line boundary expectations on web and non-web by @mdebbar in [121006](https://github.com/flutter/flutter/pull/121006)_
- ⚪ [1] * [flutter_tool] advertise the default value for --dart2js-optimization by @kevmoo in [121621](https://github.com/flutter/flutter/pull/121621)
  - _* flutter_tool: DRY up features that are fully enabled by @kevmoo in [121754](https://github.com/flutter/flutter/pull/121754)_
- ⚪ [1] * Update shader_optimization.md by @HannesGitH in [39497](https://github.com/flutter/engine/pull/39497)
  - _* Roll Skia from 638bfdc9e23c to 1762c093d086 (8 revisions) by @skia-flutter-autoroll in [39507](https://github.com/flutter/engine/pull/39507)_
- ⚪ [1] * Optimize search for the default bundle by @jiahaog in [39975](https://github.com/flutter/engine/pull/39975)
  - _* Roll Skia from fd380c7801f8 to 3e38c84ce48e (1 revision) by @skia-flutter-autoroll in [40096](https://github.com/flutter/engine/pull/40096)_
- ⚪ [0] * [windows] Eliminate unnecessary iostream imports by @cbracken in [38824](https://github.com/flutter/engine/pull/38824)
  - _* Roll Skia from dfb838747295 to 9e51c2c9e231 (26 revisions) by @skia-flutter-autoroll in [38827](https://github.com/flutter/engine/pull/38827)_
- ⚪ [0] * [macOS] Eliminate unnecessary dynamic declaration by @cbracken in [40327](https://github.com/flutter/engine/pull/40327)
  - _* [Impeller] fix opacity inheritance test by @jonahwilliams in [40360](https://github.com/flutter/engine/pull/40360)_

**Replacement / Migration** (16)

- 🔴 [7] * Use String.codeUnitAt instead of String.codeUnits[] in ParagraphBoundary by @Renzo-Olivares in [120234](https://github.com/flutter/flutter/pull/120234)
  - _* Fix lerping for `NavigationRailThemeData` icon themes by @guidezpl in [120066](https://github.com/flutter/flutter/pull/120066)_
- 🔴 [7] * Use variable instead of multiple accesses through a map by @ueman in [122178](https://github.com/flutter/flutter/pull/122178)
  - _* Improve Dart plugin registration handling by @stuartmorgan in [122046](https://github.com/flutter/flutter/pull/122046)_
- 🔴 [7] * Use skia_enable_ganesh instead of legacy GN arg by @kjlubick in [40382](https://github.com/flutter/engine/pull/40382)
  - _* disabled the impeller unit tests again by @gaaclarke in [40389](https://github.com/flutter/engine/pull/40389)_
- 🔴 [6] * Initialize `ThemeData.visualDensity` using `ThemeData.platform` instead of `defaultTargetPlatform` by @gspencergoog in [124357](https://github.com/flutter/flutter/pull/124357)
  - _* Revert "Refactor reorderable list semantics" by @XilaiZhang in [124368](https://github.com/flutter/flutter/pull/124368)_
- 🔴 [6] * [Windows] Use 'ninja' instead of 'ninja.exe' by @loic-sharma in [39326](https://github.com/flutter/engine/pull/39326)
  - _* [web] Hide autofill overlay by @htoor3 in [39294](https://github.com/flutter/engine/pull/39294)_
- 🔴 [5] * Switch from Noto Emoji to Noto Color Emoji and update font data by @hterkelsen in [40666](https://github.com/flutter/engine/pull/40666)
  - _* [macOS]Support SemanticsService.announce by @hangyujin in [40585](https://github.com/flutter/engine/pull/40585)_
- 🟡 [3] * [framework] use shader tiling instead of repeated calls to drawImage by @jonahwilliams in [119495](https://github.com/flutter/flutter/pull/119495)
  - _* Dispose OverlayEntry in TooltipState. by @polina-c in [117291](https://github.com/flutter/flutter/pull/117291)_
- 🟡 [3] * Modify focus traversal policy search to use focus tree instead of widget tree by @gspencergoog in [121186](https://github.com/flutter/flutter/pull/121186)
  - _* Change mouse cursor to be SystemMouseCursors.click when not editable by @QuncCccccc in [121353](https://github.com/flutter/flutter/pull/121353)_
- 🟡 [3] * implement Iterator and Comparable instead of extending them by @jakemac53 in [123282](https://github.com/flutter/flutter/pull/123282)
  - _* FIX: NavigationDrawer hover/focus/pressed do not use indicatorShape by @rydmike in [123325](https://github.com/flutter/flutter/pull/123325)_
- 🟡 [3] * Refactoring to use `ver` command instead of `systeminfo` by @eliasyishak in [119304](https://github.com/flutter/flutter/pull/119304)
  - _* Reland "Add --serve-observatory flag to run, attach, and test (#118402)" by @bkonyi in [119529](https://github.com/flutter/flutter/pull/119529)_
- 🟡 [3] * 🥅 Produce warning instead of error for storage base url overrides by @AlexV525 in [119595](https://github.com/flutter/flutter/pull/119595)
  - _* Revert "Add --serve-observatory flag to run, attach, and test (#118402)" by @zanderso in [119729](https://github.com/flutter/flutter/pull/119729)_
- 🟡 [3] * Remove test that verifies we can switch to stateless by @jonahwilliams in [120390](https://github.com/flutter/flutter/pull/120390)
  - _* Resolve dwarf paths to enable source-code mapping of stacktraces by @vaind in [114767](https://github.com/flutter/flutter/pull/114767)_
- 🟡 [3] * Use `dart pub` instead of `dart __deprecated pub` by @sigurdm in [121605](https://github.com/flutter/flutter/pull/121605)
  - _* [tool] Proposal to multiple defines for --dart-define-from-file by @ronnnnn in [120878](https://github.com/flutter/flutter/pull/120878)_
- 🟡 [3] * Uses `int64_t` instead of `int` for the |view_id| parameter. by @0xZOne in [39618](https://github.com/flutter/engine/pull/39618)
  - _* [ios] reland "[ios_platform_view] MaskView pool to reuse maskViews. #38989" by @cyanglaz in [39630](https://github.com/flutter/engine/pull/39630)_
- 🟡 [3] * Use new SkImages namespace instead of legacy SkImage static functions by @kjlubick in [40761](https://github.com/flutter/engine/pull/40761)
  - _* [Impeller] Un-ifdef vulkan code in impellerc by @zanderso in [40797](https://github.com/flutter/engine/pull/40797)_
- ⚪ [2] * [web] use a render target instead of a new surface for Picture.toImage by @jonahwilliams in [38573](https://github.com/flutter/engine/pull/38573)
  - _* Roll Skia from da5034f9d117 to c4b171fe5668 (1 revision) by @skia-flutter-autoroll in [39127](https://github.com/flutter/engine/pull/39127)_

---

### 3.7.0

**Deprecation** (14)

- 🔴 [5] * Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` by @gspencergoog in https://github.com/flutter/flutter/pull/113131
  - _* `AutomatedTestWidgetsFlutterBinding.pump` provides wrong pump time stamp, probably because of forgetting the precision by @fzyzcjy in https://github.com/flutter/flutter/pull/112609_
- 🟡 [4] * Deprecate `toggleableActiveColor` by @TahaTesser in https://github.com/flutter/flutter/pull/97972
  - _* Revert "Fix ExpansionTile shows children background when expanded" by @Piinks in https://github.com/flutter/flutter/pull/108844_
- 🟡 [4] * Deprecate ThemeData.selectedRowColor by @Piinks in https://github.com/flutter/flutter/pull/109070
  - _* Reland: "Add `outlineVariant` and `scrim` colors to `ColorScheme`" by @guidezpl in https://github.com/flutter/flutter/pull/109203_
- 🟡 [4] * Deprecate ThemeData.bottomAppBarColor by @esouthren in https://github.com/flutter/flutter/pull/111080
  - _* Fixed one-frame InkWell overlay color problem on unhover by @HansMuller in https://github.com/flutter/flutter/pull/111112_
- 🟡 [4] * Add missing deprecation notice for toggleableActiveColor by @Piinks in https://github.com/flutter/flutter/pull/111707
  - _* Reset missing deprecation for ScrollbarThemeData.copyWith(showTrackOnHover) by @Piinks in https://github.com/flutter/flutter/pull/111706_
- ⚪ [2] * Deprecate 2018 text theme parameters by @Piinks in https://github.com/flutter/flutter/pull/109817
  - _* Fixed leading button size on app bar by @QuncCccccc in https://github.com/flutter/flutter/pull/110043_
- ⚪ [2] * Remove deprecated drag anchor by @Piinks in https://github.com/flutter/flutter/pull/111713
  - _* Provide Material 3 defaults for vanilla `Chip` widget. by @darrenaustin in https://github.com/flutter/flutter/pull/111597_
- ⚪ [2] * Remove Deprecated RenderUnconstrainedBox by @Piinks in https://github.com/flutter/flutter/pull/111711
  - _* Fix an reorderable list animation issue:"Reversed ReorderableListView drop animation moves item one row higher than it should #110949" by @hangyujin in https://github.com/flutter/flutter/pull/111027_
- ⚪ [2] * [framework] add ignores for platformDispatcher deprecation by @jonahwilliams in https://github.com/flutter/flutter/pull/113238
  - _* Minor change type nullability by @fzyzcjy in https://github.com/flutter/flutter/pull/112778_
- ⚪ [2] * Remove deprecated `updateSemantics` API usage. by @a-wallen in https://github.com/flutter/flutter/pull/113382
  - _* Fix logical error in TimePickerDialog - the RenderObject forgets to update fields by @fzyzcjy in https://github.com/flutter/flutter/pull/112040_
- ⚪ [2] * Ignore NullThrownError deprecation by @mit-mit in https://github.com/flutter/flutter/pull/116135
  - _* Disable backspace/delete handling on iOS & macOS by @LongCatIsLooong in https://github.com/flutter/flutter/pull/115900_
- ⚪ [2] * Remove doc for --ignore-deprecation and check for pubspec before v1 embedding check by @GaryQian in https://github.com/flutter/flutter/pull/108523
  - _* [flutter_tools] join flutter specific with home cache by @Jasguerrero in https://github.com/flutter/flutter/pull/105343_
- ⚪ [2] * Add bitcode deprecation note for add-to-app iOS developers by @jmagman in https://github.com/flutter/flutter/pull/112900
  - _* Upgrade targetSdkVersion and compileSdkVersion to 33 by @GaryQian in https://github.com/flutter/flutter/pull/112936_
- ⚪ [2] * [flutter_tools] add deprecation message for "flutter format" by @christopherfujino in https://github.com/flutter/flutter/pull/116145
  - _* [gen_l10n] Improvements to `gen_l10n` by @thkim1011 in https://github.com/flutter/flutter/pull/116202_

**Breaking Change** (5)

- 🔴 [6] * Change type in `ImplicitlyAnimatedWidget` to remove type cast to improve performance and style by @fzyzcjy in https://github.com/flutter/flutter/pull/111849
  - _* make ModalBottomSheetRoute public by @The-Redhat in https://github.com/flutter/flutter/pull/108112_
- 🟡 [4] * Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` by @gspencergoog in https://github.com/flutter/flutter/pull/113131
  - _* `AutomatedTestWidgetsFlutterBinding.pump` provides wrong pump time stamp, probably because of forgetting the precision by @fzyzcjy in https://github.com/flutter/flutter/pull/112609_
- 🟡 [3] * fix: removed Widget type from child parameter in OutlinedButton by @alestiago in https://github.com/flutter/flutter/pull/111034
  - _* Started handling messages from background isolates. by @gaaclarke in https://github.com/flutter/flutter/pull/109005_
- ⚪ [1] * Fix wasted memory caused by debug fields - 16 bytes per object (when adding that should-be-removed field crosses double-word alignment) by @fzyzcjy in https://github.com/flutter/flutter/pull/113927
  - _* Fix text field label animation duration and curve by @Pourqavam in https://github.com/flutter/flutter/pull/105966_
- ⚪ [0] * Minor change type nullability by @fzyzcjy in https://github.com/flutter/flutter/pull/112778
  - _* Revert "Minor change type nullability" by @jmagman in https://github.com/flutter/flutter/pull/113246_

**New Feature / API** (1)

- ⚪ [2] * [New Feature]Support mouse wheel event on the scrollbar widget by @xu-baolin in https://github.com/flutter/flutter/pull/109659
  - _* Adds support for the Material Badge widget, BadgeTheme, BadgeThemeData by @HansMuller in https://github.com/flutter/flutter/pull/114560_

**New Parameter / Option** (1)

- ⚪ [2] * [flutter_tools] Introducing arg option for specifying the output directory for web by @eliasyishak in https://github.com/flutter/flutter/pull/113076
  - _* Always invoke impeller ios shader target by @jonahwilliams in https://github.com/flutter/flutter/pull/114451_

**Performance Improvement** (9)

- 🔴 [6] * Change type in `ImplicitlyAnimatedWidget` to remove type cast to improve performance and style by @fzyzcjy in https://github.com/flutter/flutter/pull/111849
  - _* make ModalBottomSheetRoute public by @The-Redhat in https://github.com/flutter/flutter/pull/108112_
- ⚪ [1] * Use toPictureSync for faster zoom page transition by @jonahwilliams in https://github.com/flutter/flutter/pull/106621
  - _* Allow trackpad inertia cancel events by @moffatman in https://github.com/flutter/flutter/pull/108190_
- ⚪ [1] * Optimize closure in input_decorator_theme by @hangyujin in https://github.com/flutter/flutter/pull/108379
  - _* Suggest predicate-based formatter in [FilteringTextInputFormatter] docs for whole string matching by @LongCatIsLooong in https://github.com/flutter/flutter/pull/107848_
- ⚪ [1] * Improve ShapeDecoration performance. by @bernaferrari in https://github.com/flutter/flutter/pull/108648
  - _* 109638: Windows framework_tests_misc is 2.06% flaky by @pdblasi-google in https://github.com/flutter/flutter/pull/109640_
- ⚪ [1] * Cache TextPainter plain text value to improve performance by @tgucio in https://github.com/flutter/flutter/pull/109841
  - _* fix stretch effect with rtl support by @youssefali424 in https://github.com/flutter/flutter/pull/113214_
- ⚪ [1] * Improve coverage speed by using new caching option for package:coverage by @jensjoha in https://github.com/flutter/flutter/pull/107395
  - _* Check for analyzer rule names instead of descriptions in a flutter_tools test by @jason-simmons in https://github.com/flutter/flutter/pull/107541_
- ⚪ [1] * Startup flutter faster (faster wrapper script on Windows) by @jensjoha in https://github.com/flutter/flutter/pull/111465
  - _* Startup `flutter` faster (Only access globals.deviceManager if actually setting something) by @jensjoha in https://github.com/flutter/flutter/pull/111461_
- ⚪ [1] * Startup `flutter` faster (Only access globals.deviceManager if actually setting something) by @jensjoha in https://github.com/flutter/flutter/pull/111461
  - _* Startup `flutter` faster (use app-jit snapshot) by @jensjoha in https://github.com/flutter/flutter/pull/111459_
- ⚪ [1] * Startup `flutter` faster (use app-jit snapshot) by @jensjoha in https://github.com/flutter/flutter/pull/111459
  - _* fix for flakey analyze test by @eliasyishak in https://github.com/flutter/flutter/pull/111895_

**Replacement / Migration** (11)

- 🔴 [9] * Use ScrollbarTheme instead Theme for Scrollbar by @Oleh-Sv in https://github.com/flutter/flutter/pull/113237
  - _* Add `AnimatedIcons` previews and examples by @TahaTesser in https://github.com/flutter/flutter/pull/113700_
- 🔴 [7] * Fix references to symbols to use brackets instead of backticks by @gspencergoog in https://github.com/flutter/flutter/pull/111331
  - _* Add doc note about when to dispose TextPainter by @dnfield in https://github.com/flutter/flutter/pull/111403_
- 🔴 [7] * [framework] use Visibility instead of Opacity by @jonahwilliams in https://github.com/flutter/flutter/pull/112191
  - _* Add regression test for TextPainter.getWordBoundary by @LongCatIsLooong in https://github.com/flutter/flutter/pull/112229_
- 🔴 [7] * Use `double.isNaN` instead of `... == double.nan` (which is always false) by @mkustermann in https://github.com/flutter/flutter/pull/115424
  - _* InkResponse highlights can be updated by @bleroux in https://github.com/flutter/flutter/pull/115635_
- 🔴 [6] * Error in docs: `CustomPaint` instead of `CustomPainter` by @0xba1 in https://github.com/flutter/flutter/pull/107836
  - _* Dropdown height large scale text fix by @foongsq in https://github.com/flutter/flutter/pull/107201_
- 🔴 [5] * Change default value of `effectiveInactivePressedOverlayColor` in Switch to refer to `effectiveInactiveThumbColor` by @QuncCccccc in https://github.com/flutter/flutter/pull/108477
  - _* Guard against usage after async callbacks in RenderAndroidView, unregister listener by @dnfield in https://github.com/flutter/flutter/pull/108496_
- 🟡 [3] * Check for analyzer rule names instead of descriptions in a flutter_tools test by @jason-simmons in https://github.com/flutter/flutter/pull/107541
  - _* [flutter_tools] Catch more general XmlException rather than XmlParserException by @christopherfujino in https://github.com/flutter/flutter/pull/107574_
- 🟡 [3] * Check device type using platformType instead of type check to support proxied devices. by @chingjun in https://github.com/flutter/flutter/pull/107618
  - _* [Windows] Remove the usage of `SETLOCAL ENABLEDELAYEDEXPANSION` from bat scripts. by @moko256 in https://github.com/flutter/flutter/pull/106861_
- 🟡 [3] * check for pubspec instead of lib/ by @Jasguerrero in https://github.com/flutter/flutter/pull/107968
  - _* [flutter_tools] add more debugging when pub get fails by @christopherfujino in https://github.com/flutter/flutter/pull/108062_
- 🟡 [3] * error handling when path to dir provided instead of file by @eliasyishak in https://github.com/flutter/flutter/pull/109796
  - _* [flutter_tools] reduce doctor timeout to debug 111686 by @christopherfujino in https://github.com/flutter/flutter/pull/111687_
- 🟡 [3] * Use directory exists instead of path.dirname by @Jasguerrero in https://github.com/flutter/flutter/pull/112219
  - _* Treat assets as variants only if they share the same filename by @jason-simmons in https://github.com/flutter/flutter/pull/112602_

---

### 3.3.0

**Deprecation** (12)

- 🔴 [5] * Ignore uses of soon-to-be deprecated `NullThrownError`. by @lrhn in https://github.com/flutter/flutter/pull/105693
  - _* Fix `StretchingOverscrollIndicator` clipping and add `clipBehavior` parameter by @TahaTesser in https://github.com/flutter/flutter/pull/105303_
- 🔴 [5] * [tool] Migrate off deprecated coverage parameters by @cbracken in https://github.com/flutter/flutter/pull/104997
  - _* Retry builds when SSL exceptions are thrown by @blasten in https://github.com/flutter/flutter/pull/105078_
- 🟡 [4] * Remove deprecated RaisedButton by @Piinks in https://github.com/flutter/flutter/pull/98547
  - _* Remove text selection ThemeData deprecations 3 by @Piinks in https://github.com/flutter/flutter/pull/100586_
- 🟡 [4] * Remove deprecated Scaffold SnackBar API by @Piinks in https://github.com/flutter/flutter/pull/98549
  - _* Migrate common buttons to Material 3 by @darrenaustin in https://github.com/flutter/flutter/pull/100794_
- 🟡 [4] * Remove deprecated FlatButton by @Piinks in https://github.com/flutter/flutter/pull/98545
  - _* Refactor chip class and move independent chips into separate classes by @TahaTesser in https://github.com/flutter/flutter/pull/101507_
- ⚪ [2] * Remove text selection ThemeData deprecations 3 by @Piinks in https://github.com/flutter/flutter/pull/100586
  - _* Configurable padding around FocusNodes in Scrollables by @ds84182 in https://github.com/flutter/flutter/pull/96815_
- ⚪ [2] * Removed required from deprecated API by @Piinks in https://github.com/flutter/flutter/pull/102107
  - _* Expose `ignoringPointer` property for `Draggable` and `LongPressDraggable` by @xu-baolin in https://github.com/flutter/flutter/pull/100475_
- ⚪ [2] * [framework] remove usage and deprecate physical model layer by @jonahwilliams in https://github.com/flutter/flutter/pull/102274
  - _* Revert "[framework] Reland: use ImageFilter for zoom page transition " by @jonahwilliams in https://github.com/flutter/flutter/pull/102611_
- ⚪ [2] * Mark use of deprecated type. by @lrhn in https://github.com/flutter/flutter/pull/106282
  - _* [platform_view]Send platform message when platform view is focused by @hellohuanlin in https://github.com/flutter/flutter/pull/105050_
- ⚪ [2] * [flutter_tools] remove assertion for deprecation .packages by @jonahwilliams in https://github.com/flutter/flutter/pull/103729
  - _* [flutter_tools] ensure linux doctor validator finishes when pkg-config is not installed by @christopherfujino in https://github.com/flutter/flutter/pull/103755_
- ⚪ [2] * Fix deprecation doc comment by @cbracken in https://github.com/flutter/flutter/pull/103776
  - _* [tool] Fix BuildInfo.packagesPath doc comment by @cbracken in https://github.com/flutter/flutter/pull/103785_
- ⚪ [2] * Remove deprecated Ruby File.exists? in helper script by @jmagman in https://github.com/flutter/flutter/pull/110045

**Breaking Change** (4)

- 🟡 [3] * fix: Removed helper method from Scaffold by @albertodev01 in https://github.com/flutter/flutter/pull/99714
  - _* [DataTable]: Add ability to only select row using checkbox by @TahaTesser in https://github.com/flutter/flutter/pull/105123_
- ⚪ [1] * removed obsolete timelineArgumentsIndicatingLandmarkEvent by @gaaclarke in https://github.com/flutter/flutter/pull/101382
  - _* [framework] use ImageFilter for zoom page transition by @jonahwilliams in https://github.com/flutter/flutter/pull/101786_
- ⚪ [1] * Removed extra the by @QuncCccccc in https://github.com/flutter/flutter/pull/101837
  - _* Revert changes to opacity/fade transition repaint boundary and secondary change by @jonahwilliams in https://github.com/flutter/flutter/pull/101844_
- ⚪ [1] * Removed required from deprecated API by @Piinks in https://github.com/flutter/flutter/pull/102107
  - _* Expose `ignoringPointer` property for `Draggable` and `LongPressDraggable` by @xu-baolin in https://github.com/flutter/flutter/pull/100475_

**New Feature / API** (4)

- 🔴 [5] * Mention that `NavigationBar` is a new widget by @guidezpl in https://github.com/flutter/flutter/pull/104264
  - _* [Keyboard, Windows] Fix that IME events are still dispatched to FocusNode.onKey by @dkwingsmt in https://github.com/flutter/flutter/pull/104244_
- ⚪ [2] * RawKeyboardMacos accepts a new field "specifiedLogicalKey" by @dkwingsmt in https://github.com/flutter/flutter/pull/100803
  - _* Revert "Add default selection style (#100719)" by @chunhtai in https://github.com/flutter/flutter/pull/101921_
- ⚪ [2] * Added option for Platform Channel statistics and Timeline events by @gaaclarke in https://github.com/flutter/flutter/pull/104531
  - _* Update links to `material` library docs by @guidezpl in https://github.com/flutter/flutter/pull/104392_
- ⚪ [2] * Add new widget of the week videos by @guidezpl in https://github.com/flutter/flutter/pull/107301
  - _* Reland "Disable cursor opacity animation on macOS, make iOS cursor animation discrete (#104335)" by @LongCatIsLooong in https://github.com/flutter/flutter/pull/106893_

**New Parameter / Option** (2)

- ⚪ [2] * RawKeyboardMacos accepts a new field "specifiedLogicalKey" by @dkwingsmt in https://github.com/flutter/flutter/pull/100803
  - _* Revert "Add default selection style (#100719)" by @chunhtai in https://github.com/flutter/flutter/pull/101921_
- ⚪ [2] * Added option for Platform Channel statistics and Timeline events by @gaaclarke in https://github.com/flutter/flutter/pull/104531
  - _* Update links to `material` library docs by @guidezpl in https://github.com/flutter/flutter/pull/104392_

**Performance Improvement** (3)

- ⚪ [1] * made ascii string encoding faster by @gaaclarke in https://github.com/flutter/flutter/pull/101777
  - _* Always finish the timeline event logged by Element.inflateWidget by @jason-simmons in https://github.com/flutter/flutter/pull/101794_
- ⚪ [1] * Provide a flag for controlling the dart2js optimization level when building for web targets by @jason-simmons in https://github.com/flutter/flutter/pull/101945
  - _* Remove trailing spaces in repo by @guidezpl in https://github.com/flutter/flutter/pull/101191_
- ⚪ [1] * Use libraryFilters flag to speed up coverage collection by @liamappelbe in https://github.com/flutter/flutter/pull/104122
  - _* [flutter_tools] Upgrade only from flutter update-packages by @christopherfujino in https://github.com/flutter/flutter/pull/103924_

**Replacement / Migration** (6)

- 🔴 [8] * `InputDecorator`: Switch hint to Opacity instead of AnimatedOpacity by @markusaksli-nc in https://github.com/flutter/flutter/pull/107156
  - _* Fix `ListTile` theme shape in a drawer by @TahaTesser in https://github.com/flutter/flutter/pull/106343_
- 🔴 [6] * Update key examples to use `Focus` widgets instead of `RawKeyboardListener` by @gspencergoog in https://github.com/flutter/flutter/pull/101537
  - _* Enable unnecessary_import by @goderbauer in https://github.com/flutter/flutter/pull/101600_
- 🟡 [3] * switched to a double variant of clamp to avoid boxing by @gaaclarke in https://github.com/flutter/flutter/pull/103559
  - _* Some MacOS control key shortcuts by @justinmc in https://github.com/flutter/flutter/pull/103936_
- 🟡 [3] * Provide flutter sdk kernel files to dwds launcher instead of dart ones by @annagrin in https://github.com/flutter/flutter/pull/103436
  - _* Add tests for migrate command methods by @GaryQian in https://github.com/flutter/flutter/pull/103466_
- 🟡 [3] * [flutter_tools] print override storage warning to STDERR instead of STDOUT by @christopherfujino in https://github.com/flutter/flutter/pull/106068
  - _* Add more CMake unit tests by @loic-sharma in https://github.com/flutter/flutter/pull/106076_
- ⚪ [1] * Use consistent date instead of DateTime.now() in evaluation tests to avoid flakes by @DanTup in https://github.com/flutter/flutter/pull/103269
  - _* [flutter_tools] stringArg refactor by @Jasguerrero in https://github.com/flutter/flutter/pull/103231_

---

### 3.0.0

**Deprecation** (12)

- 🔴 [7] * Remove deprecated RenderObjectElement methods by @Piinks in https://github.com/flutter/flutter/pull/98616
  - _* CupertinoTabBar: Add clickable cursor on web by @TahaTesser in https://github.com/flutter/flutter/pull/96996_
- 🟡 [4] * Remove deprecated OutlineButton by @Piinks in https://github.com/flutter/flutter/pull/98546
  - _* Add the refresh rate fields to perf_test by @cyanglaz in https://github.com/flutter/flutter/pull/99710_
- ⚪ [2] * Remove deprecated RectangularSliderTrackShape.disabledThumbGapWidth by @Piinks in https://github.com/flutter/flutter/pull/98613
  - _* Update stretching overscroll clip behavior by @Piinks in https://github.com/flutter/flutter/pull/97678_
- ⚪ [2] * Remove deprecated UpdateLiveRegionEvent by @Piinks in https://github.com/flutter/flutter/pull/98615
  - _* Remove `clipBehavior == Clip.none` conditions by @TahaTesser in https://github.com/flutter/flutter/pull/98503_
- ⚪ [2] * Remove deprecated VelocityTracker constructor by @Piinks in https://github.com/flutter/flutter/pull/98541
  - _* Add more tests to slider to avoid future breakages by @goderbauer in https://github.com/flutter/flutter/pull/98772_
- ⚪ [2] * Remove deprecated DayPicker and MonthPicker by @Piinks in https://github.com/flutter/flutter/pull/98543
  - _* Adds `onReorderStart` and `onReorderEnd` arguments to `ReorderableList`. by @werainkhatri in https://github.com/flutter/flutter/pull/96049_
- ⚪ [2] * Deprecate MaterialButtonWithIconMixin by @Piinks in https://github.com/flutter/flutter/pull/99088
  - _* Use `PlatformDispatcher.instance` over `window` where possible by @goderbauer in https://github.com/flutter/flutter/pull/99496_
- ⚪ [2] * Re-land removal of maxLengthEnforced deprecation by @Piinks in https://github.com/flutter/flutter/pull/99787
  - _* Revert "Add the refresh rate fields to perf_test" by @zanderso in https://github.com/flutter/flutter/pull/99801_
- ⚪ [2] * Remove deprecated RenderEditable.onSelectionChanged by @Piinks in https://github.com/flutter/flutter/pull/98582
  - _* [Material] Create an InkSparkle splash effect that matches the Material 3 ripple effect by @clocksmith in https://github.com/flutter/flutter/pull/99731_
- ⚪ [2] * Remove expired ThemeData deprecations by @Piinks in https://github.com/flutter/flutter/pull/98578
  - _* Update `NavigationRail` to support Material 3 tokens by @darrenaustin in https://github.com/flutter/flutter/pull/99171_
- ⚪ [2] * Fix `deprecated_new_in_comment_reference` for `material` library by @guidezpl in https://github.com/flutter/flutter/pull/100289
  - _* Fix stretch edge case by @Piinks in https://github.com/flutter/flutter/pull/99365_
- ⚪ [2] * [flutter_tools] deprecate the dev branch from the feature system by @christopherfujino in https://github.com/flutter/flutter/pull/98689
  - _* Revert "Reland "Enable caching of CPU samples collected at application startup (#89600)"" by @zanderso in https://github.com/flutter/flutter/pull/98803_

**Breaking Change** (3)

- ⚪ [1] * Removed the date from the Next/Previous month button's semantics for the Date Picker. by @darrenaustin in https://github.com/flutter/flutter/pull/96876
  - _* chore: added YouTube ref to docstring by @albertodev01 in https://github.com/flutter/flutter/pull/96880_
- ⚪ [1] * Fixed order dependency and removed no-shuffle-tag in build_ios_framew… by @Swiftaxe in https://github.com/flutter/flutter/pull/94699
  - _* Add option in ProxiedDevice to only transfer the delta when deploying. by @chingjun in https://github.com/flutter/flutter/pull/97462_
- ⚪ [1] * Removed no-shuffle tag and fixed order dependency in daemon_test.dart by @Swiftaxe in https://github.com/flutter/flutter/pull/98970
  - _* Skip `can validate flutter version in parallel` test in `Linux web_tool_tests` by @keyonghan in https://github.com/flutter/flutter/pull/99017_

**New Feature / API** (1)

- ⚪ [2] * Added optional parameter keyboardType to showDatePicker by @kirolous-nashaat in https://github.com/flutter/flutter/pull/93439
  - _* Fix getOffsetForCaret to return correct value if contains widget span by @chunhtai in https://github.com/flutter/flutter/pull/98542_

**New Parameter / Option** (1)

- ⚪ [2] * Added optional parameter keyboardType to showDatePicker by @kirolous-nashaat in https://github.com/flutter/flutter/pull/93439
  - _* Fix getOffsetForCaret to return correct value if contains widget span by @chunhtai in https://github.com/flutter/flutter/pull/98542_

**Performance Improvement** (1)

- 🟡 [3] * [framework] inline casts on Element.widget getter to improve web performance by @jonahwilliams in https://github.com/flutter/flutter/pull/97822
  - _* [EditableText] honor the "brieflyShowPassword" system setting by @LongCatIsLooong in https://github.com/flutter/flutter/pull/97769_

**Replacement / Migration** (3)

- 🟡 [3] For example, instead of the following:
- 🟡 [3] * Use strict-raw-types analysis instead of no-implicit-dynamic by @srawlins in https://github.com/flutter/flutter/pull/96296
  - _* [Keyboard] Dispatch solitary synthesized `KeyEvent`s by @dkwingsmt in https://github.com/flutter/flutter/pull/96874_
- 🟡 [3] * [flutter_tools] increment y instead of m when calling flutter --version on master by @christopherfujino in https://github.com/flutter/flutter/pull/97827
  - _* Include -isysroot -arch and -miphoneos-version-min when creating dummy module App.framework by @jmagman in https://github.com/flutter/flutter/pull/97689_

---

## Dart SDK

### 3.12.0

**Breaking Change** (1)

- ⚪ [1] - **Breaking Change in extension name of `isA`**: `isA` is moved from
  - _`JSAnyUtilityExtension` to `NullableObjectUtilExtension` to support_

**New Feature / API** (1)

- ⚪ [2] `loadDeferredModule` where the new function should now expect an array of
  - _module names rather than individual module names. All the module loading_

**Replacement / Migration** (1)

- 🟡 [3] deferred modules. The embedder now takes `loadDeferredModules` instead of
  - _`loadDeferredModule` where the new function should now expect an array of_

---

### 3.11.0

**Deprecation** (3)

- ⚪ [2] - The `avoid_null_checks_in_equality_operators` lint rule is now deprecated.
  - _- The `prefer_final_parameters` lint rule is now deprecated._
- ⚪ [2] - The `prefer_final_parameters` lint rule is now deprecated.
  - _- The `use_if_null_to_convert_nulls_to_bools` lint rule is now deprecated._
- ⚪ [2] - The `use_if_null_to_convert_nulls_to_bools` lint rule is now deprecated.

**Breaking Change** (1)

- ⚪ [1] - dart2wasm no longer supports `dart:js_util`. Any code that imports
  - _`dart:js_util` will no longer compile with dart2wasm. Consequently, code that_

**New Feature / API** (1)

- ⚪ [2] - New flag `dart pub publish --dry-run --ignore-warnings`

**New Parameter / Option** (1)

- ⚪ [2] - New flag `dart pub publish --dry-run --ignore-warnings`

**Performance Improvement** (1)

- ⚪ [1] - Analysis via analyzer plugins is now faster on subsequent runs, as the
  - _analysis server will now re-use an existing AOT snapshot of the plugins_

**Replacement / Migration** (1)

- 🔴 [7] but `false` on Windows. Use `FileSystemEntity.typeSync()` instead to get
  - _portable behavior._

---

### 3.10.5

**Deprecation** (2)

- ⚪ [2] - Fixes several issues with elements that are deprecated with one of the new
  - _"deprecated functionality" annotations, like `@Deprecated.implement`. This_
- ⚪ [2] fully deprecated (for example, with struck-through text). (issue
  - _[dart-lang/sdk#62013])_

---

### 3.10.0

**Deprecation** (15)

- ⚪ [2] - Support the new `@Deprecated` annotations by reporting warnings when specific
  - _functionality of an element is deprecated._
- ⚪ [2] functionality of an element is deprecated.
  - _- Offer to import a library for an appropriate extension member when method or_
- ⚪ [2] - Remove support for the deprecated `@required` annotation.
  - _- Add two assists to bind constructor parameters to an existing or a_
- ⚪ [2] - Add a new lint rule, `remove_deprecations_in_breaking_versions`, is added to
  - _encourage developers to remove any deprecated members when the containing_
- ⚪ [2] encourage developers to remove any deprecated members when the containing
  - _package has a "breaking version" number, like `x.0.0` or `0.y.0`._
- ⚪ [2] - New annotations are offered for deprecating specific functionalities:
  - _- [`@Deprecated.extend()`][] indicates the ability to extend a class is_
- ⚪ [2] deprecated.
  - _- [`@Deprecated.implement()`][] indicates the ability to implement a class or_
- ⚪ [2] mixin is deprecated.
  - _- [`@Deprecated.subclass()`][] indicates the ability to extend a class or_
- ⚪ [2] implement a class or mixin is deprecated.
  - _- [`@Deprecated.mixin()`][] indicates the ability to mix in a class is_
- ⚪ [2] class is deprecated.
  - _- The ability to implement the RegExp class and the RegExpMatch class is_
- ⚪ [1] - [`@Deprecated.extend()`][] indicates the ability to extend a class is
  - _deprecated._
- ⚪ [1] - [`@Deprecated.implement()`][] indicates the ability to implement a class or
  - _mixin is deprecated._
- ⚪ [1] - [`@Deprecated.subclass()`][] indicates the ability to extend a class or
  - _implement a class or mixin is deprecated._
- ⚪ [1] - [`@Deprecated.mixin()`][] indicates the ability to mix in a class is
  - _deprecated._
- ⚪ [1] - [`@Deprecated.instantiate()`][] indicates the ability to instantiate a
  - _class is deprecated._

**Breaking Change** (5)

- 🟡 [4] - **Breaking Change** [#61392][]: The `Uri.parseIPv4Address` function
  - _no longer incorrectly allows leading zeros. This also applies to_
- 🟡 [4] - **Breaking Change** [#56468][]: Marked `IOOverrides` as an `abstract base`
  - _class so it can no longer be implemented._
- 🟡 [4] - `Uint16ListToJSInt16Array` is renamed to `Uint16ListToJSUint16Array`.
  - _- `JSUint16ArrayToInt16List` is renamed to `JSUint16ArrayToUint16List`._
- 🟡 [4] - `JSUint16ArrayToInt16List` is renamed to `JSUint16ArrayToUint16List`.
  - _- The dart2wasm implementation of `dartify` now converts JavaScript `Promise`s_
- ⚪ [1] - dart2wasm no longer supports `dart:js_util` and will throw an
  - _`UnsupportedError` if any API from this library is invoked. This also applies_

**New Feature / API** (1)

- ⚪ [2] - New annotations are offered for deprecating specific functionalities:
  - _- [`@Deprecated.extend()`][] indicates the ability to extend a class is_

**Replacement / Migration** (2)

- 🟡 [3] `toJSBox` operation instead of returning true for all objects.
  - _- For object literals created from extension type factories, the `@JS()`_
- 🟡 [3] original typed array when unwrapped instead of instantiating a new typed array
  - _with the same buffer. This applies to both the `.toJS` conversions and_

---

### 3.9.0

**Deprecation** (1)

- ⚪ [2] flag! It will be removed in the future.) This flag directs the tool to revert
  - _to the old behavior, using the JIT-compiled analysis server snapshot. To_

**Breaking Change** (2)

- ⚪ [1] flag! It will be removed in the future.) This flag directs the tool to revert
  - _to the old behavior, using the JIT-compiled analysis server snapshot. To_
- ⚪ [1] - Breaking change of feature in preview: `dart build -f exe <target>` is now
  - _`dart build cli --target=<target>`. See `dart build cli --help` for more info._

**New Feature / API** (1)

- ⚪ [2] - Support a new annotation, `@awaitNotRequired`, which is used by the
  - _`discarded_futures` and `unawaited_futures` lint rules._

**Performance Improvement** (1)

- ⚪ [1] snapshot. But various tests indicate that there is a significant speedup in
  - _the time to analyze a project._

---

### 3.8.0

**Breaking Change** (4)

- 🔴 [6] - **Breaking change**: Native classes in `dart:html`, like `HtmlElement`, can no
  - _longer be extended. Long ago, to support custom elements, element classes_
- 🟡 [3] earlier breaking change in 3.0.0 that removed the `registerElement` APIs. See
  - _[#53264](https://github.com/dart-lang/sdk/issues/53264) for details._
- ⚪ [1] components. On this release, those constructors have been removed and with
  - _that change, the classes can no longer be extended. In a future change, they_
- ⚪ [1] Removed the `--experiment-new-rti` and `--use-old-rti` flags.

**Replacement / Migration** (1)

- 🟡 [3] Some users strongly prefer the old behavior where a trailing comma will be
  - _preserved by the formatter and force the surrounding construct to split. That_

---

### 3.7.0

**Deprecation** (8)

- ⚪ [2] will be removed.
- ⚪ [2] - `dart:html` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- ⚪ [2] - `dart:indexed_db` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- ⚪ [2] - `dart:svg` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- ⚪ [2] - `dart:web_audio` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- ⚪ [2] - `dart:web_gl` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- ⚪ [2] - `dart:js` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop`. See [#59716][]._
- ⚪ [2] - `dart:js_util` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop`. See [#59716][]._

**Breaking Change** (11)

- 🟡 [4] - **Breaking Change** [#56893][]: If a field is promoted to the type `Null`
  - _using `is` or `as`, this type promotion is now properly accounted for in_
- ⚪ [1] will be removed.
- ⚪ [1] * **Breaking change: Remove support for `dart format --fix`.** Instead, use
  - _`dart fix`. It supports all of the fixes that `dart format --fix` could apply_
- ⚪ [1] may be removed at some point in the future. You're encouraged to move to
  - _`--page-width`. Use of this option (however it's named) is rare, and will_
- ⚪ [1] - `dart:html` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- ⚪ [1] - `dart:indexed_db` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- ⚪ [1] - `dart:svg` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- ⚪ [1] - `dart:web_audio` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- ⚪ [1] - `dart:web_gl` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- ⚪ [1] - `dart:js` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop`. See [#59716][]._
- ⚪ [1] - `dart:js_util` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop`. See [#59716][]._

**Replacement / Migration** (5)

- 🟡 [3] constraint in your pubspec to move to 3.7, you are also opting in to the new
  - _style._
- 🟡 [3] may be removed at some point in the future. You're encouraged to move to
  - _`--page-width`. Use of this option (however it's named) is rare, and will_
- 🟡 [3] used has been switched to use an AOT snapshot instead of a JIT snapshot.
- 🟡 [3] The dartdevc compiler and kernel_worker utility have been switched to
  - _use an AOT snapshot instead of a JIT snapshot,_
- 🟡 [3] use an AOT snapshot instead of a JIT snapshot,
  - _the SDK build still includes a JIT snapshot of these tools as_

---

### 3.6.0

**Deprecation** (1)

- ⚪ [2] has been deprecated since Dart 3.1.

**Breaking Change** (4)

- 🟡 [4] - **Breaking Change** [#53618][]: `HttpClient` now responds to a redirect
  - _that is missing a "Location" header by throwing `RedirectException`, instead_
- ⚪ [1] - **Breaking Change** [#56065][]: The context used by the compiler and analyzer
  - _to perform type inference on the operand of a `throw` expression has been_
- ⚪ [1] - **Breaking Change** [#52444][]: Removed the `Platform()` constructor, which
  - _has been deprecated since Dart 3.1._
- ⚪ [1] - **Breaking Change** [#56466][]: The implementation of the UP and
  - _DOWN algorithms in the CFE are changed to match the specification_

**New Feature / API** (1)

- ⚪ [2] - New flag `dart pub upgrade --unlock-transitive`.

**New Parameter / Option** (1)

- ⚪ [2] - New flag `dart pub upgrade --unlock-transitive`.

**Replacement / Migration** (2)

- 🟡 [3] passed into the subtype testing procedure instead of at the very
  - _beginning of the UP and DOWN algorithms._
- 🟡 [3] dependencies of `pkg` instead of just `pkg`.

---

### 3.5.3

**Replacement / Migration** (1)

- 🟡 [3] DevTools is opened instead of only the first time (issue[#56607][]).
  - _- Fixes an issue resulting in a missing tab bar when DevTools is_

---

### 3.5.1

**Performance Improvement** (1)

- ⚪ [1] - Fixes source maps generated by `dart compile wasm` when optimizations are
  - _enabled (issue [#56423][])._

**Replacement / Migration** (1)

- 🟡 [3] implicit setter for a field of generic type will store `null` instead of the
  - _field value (issue [#56374][])._

---

### 3.5.0

**Deprecation** (1)

- ⚪ [2] have been removed. These classes were deprecated in Dart 3.4.

**Breaking Change** (10)

- 🔴 [6] - **Breaking Change** [#55786][]: `SecurityContext` is now `final`. This means
  - _that `SecurityContext` can no longer be subclassed. `SecurityContext`_
- 🟡 [4] - **Breaking Change** [#44876][]: `DateTime` on the web platform now stores
  - _microseconds. The web implementation is now practically compatible with the_
- 🟡 [4] - **Breaking Change** [#55267][]: `isTruthy` and `not` now return `JSBoolean`
  - _instead of `bool` to be consistent with the other operators._
- 🟡 [4] - **Breaking Change** `ExternalDartReference` no longer implements `Object`.
  - _`ExternalDartReference` now accepts a type parameter `T` with a bound of_
- 🟡 [4] - `Dart_DefaultCanonicalizeUrl` is removed from the Dart C API.
- ⚪ [1] - **Breaking Change** [#55418][]: The context used by the compiler to perform
  - _type inference on the operand of an `await` expression has been changed to_
- ⚪ [1] - **Breaking Change** [#55436][]: The context used by the compiler to perform
  - _type inference on the right hand side of an "if-null" expression (`e1 ?? e2`)_
- ⚪ [1] - **Breaking Change** [#53785][]: The unmodifiable view classes for typed data
  - _have been removed. These classes were deprecated in Dart 3.4._
- ⚪ [1] have been removed. These classes were deprecated in Dart 3.4.
- ⚪ [1] safe code using the option `--no-sound-null-safety` has been removed.

**New Feature / API** (1)

- ⚪ [2] - New flag `dart pub downgrade --tighten` to restrict lower bounds of
  - _dependencies' constraints to the minimum that can be resolved._

**New Parameter / Option** (1)

- ⚪ [2] - New flag `dart pub downgrade --tighten` to restrict lower bounds of
  - _dependencies' constraints to the minimum that can be resolved._

**Replacement / Migration** (1)

- 🟡 [3] instead of `bool` to be consistent with the other operators.

---

### 3.4.0

**Deprecation** (3)

- 🔴 [5] - Deprecates `FileSystemDeleteEvent.isDirectory`, which always returns
  - _`false`._
- ⚪ [2] typed data are deprecated.
- ⚪ [2] The deprecated types will be removed in Dart 3.5.

**Breaking Change** (8)

- 🟡 [4] - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  - _which allows developers to control the line ending used by `stdout` and_
- 🟡 [4] - Dart VM no longer supports external strings: `Dart_IsExternalString`,
  - _`Dart_NewExternalLatin1String` and `Dart_NewExternalUTF16String` functions are_
- ⚪ [1] - **Breaking Change** [#54640][]: The pattern context type schema for
  - _cast patterns has been changed from `Object?` to `_` (the unknown_
- ⚪ [1] - **Breaking Change** [#54828][]: The type schema used by the compiler front end
  - _to perform type inference on the operand of a null-aware spread operator_
- ⚪ [1] - **Breaking change** [#52121][]: `waitFor` is removed in 3.4.
- ⚪ [1] - **BREAKING CHANGE** [#53218][] [#53785][]: The unmodifiable view classes for
  - _typed data are deprecated._
- ⚪ [1] The deprecated types will be removed in Dart 3.5.
- ⚪ [1] removed from Dart C API.

**New Feature / API** (3)

- 🔴 [5] - Added option for `ParallelWaitError` to get some meta-information that
  - _it can expose in its `toString`, and the `Iterable<Future>.wait` and_
- 🔴 [5] - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  - _which allows developers to control the line ending used by `stdout` and_
- ⚪ [2] - Support for new annotations introduced in version 1.14.0 of the [meta]
  - _package._

**New Parameter / Option** (2)

- 🔴 [5] - Added option for `ParallelWaitError` to get some meta-information that
  - _it can expose in its `toString`, and the `Iterable<Future>.wait` and_
- 🔴 [5] - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  - _which allows developers to control the line ending used by `stdout` and_

**Performance Improvement** (1)

- ⚪ [1] `toExternalReference` and `toDartObject`. This is a faster alternative to
  - _`JSBoxedDartObject`, but with fewer safety guarantees and fewer_

**Replacement / Migration** (1)

- 🟡 [3] opaque Dart value instead of only externalizing the value. Like the JS
  - _backends, you'll now get a more useful error when trying to use it in another_

---

### 3.3.0

**Deprecation** (4)

- 🔴 [5] core `Pointer` types are now deprecated.
  - _Migrate to the new `-` and `+` operators instead._
- ⚪ [2] - The experimental and deprecated `@FfiNative` annotation has been removed.
  - _Usages should be updated to use the `@Native` annotation._
- ⚪ [2] unmodifiable view classes for typed data are deprecated. Instead of using the
  - _constructors for these classes to create an unmodifiable view, e.g._
- ⚪ [2] The deprecated types will be removed in a future Dart version.

**Breaking Change** (12)

- ⚪ [1] - **Breaking Change** [#54056][]: The rules for private field promotion have
  - _been changed so that an abstract getter is considered promotable if there are_
- ⚪ [1] - The experimental and deprecated `@FfiNative` annotation has been removed.
  - _Usages should be updated to use the `@Native` annotation._
- ⚪ [1] - **Breaking Change in the representation of JS types** [#52687][]: JS types
  - _like `JSAny` were previously represented using a custom erasure of_
- ⚪ [1] - **Breaking Change in names of extensions**: Some `dart:js_interop` extension
  - _members are moved to different extensions on the same type or a supertype to_
- ⚪ [1] - **BREAKING CHANGE** (https://github.com/dart-lang/sdk/issues/53218) The
  - _unmodifiable view classes for typed data are deprecated. Instead of using the_
- ⚪ [1] The deprecated types will be removed in a future Dart version.
- ⚪ [1] - **Breaking Change** [#51896][]: The NativeWrapperClasses are marked `base` so
  - _that none of their subtypes can be implemented. Implementing subtypes can lead_
- ⚪ [1] - **Breaking Change** [#54004][]: `dart:js_util`, `package:js`, and `dart:js`
  - _are now disallowed from being imported when compiling with `dart2wasm`. Prefer_
- ⚪ [1] - Removed "implements <...>" text from the Chrome custom formatter display for
  - _Dart classes. This information provides little value and keeping it imposes an_
- ⚪ [1] - **Breaking Change** [#54201][]:
  - _The `Invocation` that is passed to `noSuchMethod` will no longer have a_
- ⚪ [1] - Removed the `iterable_contains_unrelated_type` and
  - _`list_remove_unrelated_type` lints._
- ⚪ [1] - Removed various lints that are no longer necessary with sound null safety:
  - _- `always_require_non_null_named_parameters`_

**New Feature / API** (1)

- 🔴 [5] `JSAnyOperatorExtension` for the new extensions. This shouldn't make a
  - _difference unless the extension names were explicitly used._

**Replacement / Migration** (2)

- 🟡 [3] members are moved to different extensions on the same type or a supertype to
  - _better organize the API surface. See `JSAnyUtilityExtension` and_
- 🟡 [3] unmodifiable view classes for typed data are deprecated. Instead of using the
  - _constructors for these classes to create an unmodifiable view, e.g._

---

### 3.2.0

**Deprecation** (2)

- 🔴 [5] - Deprecated the `Service.getIsolateID` method.
  - _- Added `getIsolateId` method to `Service`._
- ⚪ [2] on `waitFor` can enable it by passing `--enable_deprecated_wait_for` flag
  - _to the VM._

**Breaking Change** (17)

- 🔴 [8] `JSNumber.toDart` is removed in favor of `toDartDouble` and `toDartInt` to
  - _make the type explicit. `Object.toJS` is also removed in favor of_
- 🟡 [4] - **Breaking change** [#53311][]: `NativeCallable.nativeFunction` now throws an
  - _error if is called after the `NativeCallable` has already been `close`d. Calls_
- 🟡 [4] `JSExportedDartObject` is renamed to `JSBoxedDartObject` and the extensions
  - _`ObjectToJSExportedDartObject` and `JSExportedDartObjectToObject` are renamed_
- 🟡 [4] - **Breaking Change on `dart:js_interop` `JSAny` and `JSObject`**:
  - _These types can only be implemented, and no longer extended, by user_
- 🟡 [4] - **Breaking Change on `dart:js_interop` `JSArray.withLength`**:
  - _This API now takes in an `int` instead of `JSNumber`._
- 🟡 [3] `globalJSObject` is also renamed to `globalContext` and returns the global
  - _context used in the lowerings._
- ⚪ [1] - **Breaking Change** [#53167][]: Use a more precise split point for refutable
  - _patterns. Previously, in an if-case statement, if flow analysis could prove_
- ⚪ [1] - **Breaking change** [#52121][]:
  - _- `waitFor` is disabled by default and slated for removal in 3.4. Attempting_
- ⚪ [1] - **Breaking change** [#52801][]:
  - _- Changed return types of `utf8.encode()` and `Utf8Codec.encode()` from_
- ⚪ [1] - Changed return types of `utf8.encode()` and `Utf8Codec.encode()` from
  - _`List<int>` to `Uint8List`._
- ⚪ [1] - **Breaking change** [#53005][]: The headers returned by
  - _`HttpClientResponse.headers` and `HttpRequest.headers` no longer include_
- ⚪ [1] - **Breaking change** [#53227][]: Folded headers values returned by
  - _`HttpClientResponse.headers` and `HttpRequest.headers` now have a space_
- ⚪ [1] - **Breaking Change on JSNumber.toDart and Object.toJS**:
  - _`JSNumber.toDart` is removed in favor of `toDartDouble` and `toDartInt` to_
- ⚪ [1] - **Breaking Change on Types of `dart:js_interop` External APIs**:
  - _External JS interop APIs when using `dart:js_interop` are restricted to a set_
- ⚪ [1] - **Breaking Change on `dart:js_interop` `isNull` and `isUndefined`**:
  - _`null` and `undefined` can only be discerned in the JS backends. dart2wasm_
- ⚪ [1] - **Breaking Change on `dart:js_interop` `typeofEquals` and `instanceof`**:
  - _Both APIs now return a `bool` instead of a `JSBoolean`. `typeofEquals` also_
- ⚪ [1] - **Breaking change for JS interop with Symbols and BigInts**:
  - _JavaScript `Symbol`s and `BigInt`s are now associated with their own_

**New Feature / API** (1)

- ⚪ [2] - New option `dart pub upgrade --tighten` which will update dependencies' lower
  - _bounds in `pubspec.yaml` to match the current version._

**New Parameter / Option** (1)

- ⚪ [2] - New option `dart pub upgrade --tighten` which will update dependencies' lower
  - _bounds in `pubspec.yaml` to match the current version._

**Replacement / Migration** (4)

- 🔴 [6] Both APIs now return a `bool` instead of a `JSBoolean`. `typeofEquals` also
  - _now takes in a `String` instead of a `JSString`._
- 🔴 [6] now takes in a `String` instead of a `JSString`.
  - _- **Breaking Change on `dart:js_interop` `JSAny` and `JSObject`**:_
- 🔴 [6] This API now takes in an `int` instead of `JSNumber`.
- 🟡 [3] instead of `globalThis` to avoid a greater migration. Static interop APIs,
  - _either through `dart:js_interop` or the `@staticInterop` annotation, have used_

---

### 3.1.2

**Replacement / Migration** (1)

- 🟡 [3] The fix uses try/catch in lookupAddresses instead of
  - _Future error so that we don't see an unhandled exception_

---

### 3.1.0

**Deprecation** (1)

- 🔴 [5] - Added a deprecation warning when `Platform` is instantiated.
  - _- Added `Platform.lineTerminator` which exposes the character or characters_

**Breaking Change** (5)

- 🟡 [4] - **Breaking change** [#52027][]: `FileSystemEvent` is
  - _[`sealed`](https://dart.dev/language/class-modifiers#sealed). This means_
- 🟡 [4] `ObjectLiteral` is removed from `dart:js_interop`. It's no longer needed in
  - _order to declare an object literal constructor with inline classes. As long as_
- ⚪ [1] - **Breaking change** [#52334][]:
  - _- Added the `interface` modifier to purely abstract classes:_
- ⚪ [1] - **Breaking change** [#51486][]:
  - _- Added `sameSite` to the `Cookie` class._
- ⚪ [1] - **Breaking change to `@staticInterop` and `external` extension members**:
  - _`external` `@staticInterop` members and `external` extension members can no_

**New Feature / API** (1)

- 🔴 [5] - Added class `SameSite`.
  - _- **Breaking change** [#52027][]: `FileSystemEvent` is_

**Replacement / Migration** (1)

- 🔴 [7] calls these members, and use that instead.
  - _- **Breaking change to `@staticInterop` and `external` extension members**:_

---

### 3.0.1

**Performance Improvement** (1)

- ⚪ [1] - Improve performance on functions with many parameters (issue [#1212]).

---

### 3.0.0

**Deprecation** (21)

- 🔴 [9] Use [`Deprecated.message`][] instead.
  - _- Removed the deprecated [`CastError`][] error._
- 🔴 [5] - Removed the deprecated `List` constructor, as it wasn't null safe.
  - _Use list literals (e.g. `[]` for an empty list or `<int>[]` for an empty_
- 🔴 [5] - Removed the deprecated [`proxy`][] and [`Provisional`][] annotations.
  - _The original `proxy` annotation has no effect in Dart 2,_
- 🔴 [5] - Removed the deprecated [`Deprecated.expires`][] getter.
  - _Use [`Deprecated.message`][] instead._
- 🔴 [5] - Removed the deprecated [`CastError`][] error.
  - _Use [`TypeError`][] instead._
- 🔴 [5] - Removed the deprecated [`FallThroughError`][] error. The kind of
  - _fall-through previously throwing this error was made a compile-time_
- 🔴 [5] - Removed the deprecated [`AbstractClassInstantiationError`][] error. It was made
  - _a compile-time error to call the constructor of an abstract class in Dart 2.0._
- 🔴 [5] - Removed the deprecated [`CyclicInitializationError`]. Cyclic dependencies are
  - _no longer detected at runtime in null safe code. Such code will fail in other_
- 🔴 [5] - Removed the deprecated [`NoSuchMethodError`][] default constructor.
  - _Use the [`NoSuchMethodError.withInvocation`][] named constructor instead._
- 🔴 [5] - Removed the deprecated [`BidirectionalIterator`][] class.
  - _Existing bidirectional iterators can still work, they just don't have_
- 🔴 [5] - Removed the deprecated [`DeferredLibrary`][] class.
  - _Use the [`deferred as`][] import syntax instead._
- 🔴 [5] - Deprecated the `HasNextIterator` class ([#50883][]).
- 🔴 [5] - Removed the deprecated [`MAX_USER_TAGS`][] constant.
  - _Use [`maxUserTags`][] instead._
- 🔴 [5] - Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],
  - _and [`Gauge`][] classes as they have been broken since Dart 2.0._
- 🔴 [5] - Deprecate `NetworkInterface.listSupported`. Has always returned true since
  - _Dart 2.3._
- 🟡 [4] - **Breaking change**: As previously announced, the deprecated `registerElement`
  - _and `registerElement2` methods in `Document` and `HtmlDocument` have been_
- ⚪ [2] - Removed the deprecated `onError` argument on [`int.parse`][], [`double.parse`][],
  - _and [`num.parse`][]. Use the [`tryParse`][] method instead._
- ⚪ [2] - The experimental `@FfiNative` annotation is now deprecated.
  - _Usages should be replaced with the new `@Native` annotation._
- ⚪ [2] - Removed deprecated command line flags `-k`, `--kernel`, and `--dart-sdk`.
  - _- The compile time flag `--nativeNonNullAsserts`, which ensures web library APIs_
- ⚪ [2] - add new lint: `deprecated_member_use_from_same_package` which replaces the
  - _soft-deprecated analyzer hint of the same name._
- ⚪ [2] soft-deprecated analyzer hint of the same name.
  - _- update `public_member_api_docs` to not require docs on enum constructors._

**Breaking Change** (27)

- 🟡 [4] - Removed the deprecated `List` constructor, as it wasn't null safe.
  - _Use list literals (e.g. `[]` for an empty list or `<int>[]` for an empty_
- 🟡 [4] - Removed the deprecated [`proxy`][] and [`Provisional`][] annotations.
  - _The original `proxy` annotation has no effect in Dart 2,_
- 🟡 [4] - Removed the deprecated [`Deprecated.expires`][] getter.
  - _Use [`Deprecated.message`][] instead._
- 🟡 [4] - Removed the deprecated [`CastError`][] error.
  - _Use [`TypeError`][] instead._
- 🟡 [4] - Removed the deprecated [`FallThroughError`][] error. The kind of
  - _fall-through previously throwing this error was made a compile-time_
- 🟡 [4] - Removed the deprecated [`NullThrownError`][] error. This error is never
  - _thrown from null safe code._
- 🟡 [4] - Removed the deprecated [`AbstractClassInstantiationError`][] error. It was made
  - _a compile-time error to call the constructor of an abstract class in Dart 2.0._
- 🟡 [4] - Removed the deprecated [`CyclicInitializationError`]. Cyclic dependencies are
  - _no longer detected at runtime in null safe code. Such code will fail in other_
- 🟡 [4] - Removed the deprecated [`NoSuchMethodError`][] default constructor.
  - _Use the [`NoSuchMethodError.withInvocation`][] named constructor instead._
- 🟡 [4] - Removed the deprecated [`BidirectionalIterator`][] class.
  - _Existing bidirectional iterators can still work, they just don't have_
- 🟡 [4] - Removed the deprecated [`DeferredLibrary`][] class.
  - _Use the [`deferred as`][] import syntax instead._
- 🟡 [4] - Removed the deprecated [`MAX_USER_TAGS`][] constant.
  - _Use [`maxUserTags`][] instead._
- 🟡 [4] - Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],
  - _and [`Gauge`][] classes as they have been broken since Dart 2.0._
- 🟡 [3] - **Breaking change**: As previously announced, the deprecated `registerElement`
  - _and `registerElement2` methods in `Document` and `HtmlDocument` have been_
- ⚪ [1] **Breaking change**: Dart 3.0 interprets [switch cases] as patterns instead of
  - _constant expressions. Most constant expressions found in switch cases are_
- ⚪ [1] **Breaking change:** Class declarations from libraries that have been upgraded
  - _to Dart 3.0 can no longer be used as mixins by default. If you want the class_
- ⚪ [1] - **Breaking change** [#50902][]: Dart reports a compile-time error if a
  - _`continue` statement targets a [label] that is not a loop (`for`, `do` and_
- ⚪ [1] - **Breaking change** [language/#2357][]: Starting in language version 3.0,
  - _Dart reports a compile-time error if a colon (`:`) is used as the_
- ⚪ [1] - **Breaking Change**: Non-`mixin` classes in the platform libraries
  - _can no longer be mixed in, unless they are explicitly marked as `mixin class`._
- ⚪ [1] - **Breaking change** [#49529][]:
  - _- Removed the deprecated `List` constructor, as it wasn't null safe._
- ⚪ [1] - Removed the deprecated `onError` argument on [`int.parse`][], [`double.parse`][],
  - _and [`num.parse`][]. Use the [`tryParse`][] method instead._
- ⚪ [1] - **Breaking change when migrating code to Dart 3.0**:
  - _Some changes to platform libraries only affect code when that code is migrated_
- ⚪ [1] - **Breaking change** [#50231][]:
  - _- Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],_
- ⚪ [1] removed.  See [#49536](https://github.com/dart-lang/sdk/issues/49536) for
  - _details._
- ⚪ [1] - **Breaking change** [#51035][]:
  - _- Update `NetworkProfiling` to accommodate new `String` ids_
- ⚪ [1] - Removed deprecated command line flags `-k`, `--kernel`, and `--dart-sdk`.
  - _- The compile time flag `--nativeNonNullAsserts`, which ensures web library APIs_
- ⚪ [1] The null safety migration tool (`dart migrate`) has been removed.  If you still
  - _have code which needs to be migrated to null safety, please run `dart migrate`_

**New Feature / API** (4)

- ⚪ [2] - **[Class modifiers]**: New modifiers `final`, `interface`, `base`, and `mixin`
  - _on `class` and `mixin` declarations let you control how the type can be used._
- ⚪ [2] current flexible defaults, but these new modifiers give you finer-grained
  - _control over how the type can be used._
- ⚪ [2] - Added extension member `wait` on iterables and 2-9 tuples of futures.
- ⚪ [2] - Added extension members `nonNulls`, `firstOrNull`, `lastOrNull`,
  - _`singleOrNull`, `elementAtOrNull` and `indexed` on `Iterable`s._

**Performance Improvement** (2)

- 🟡 [4] The `MapEntry` value class is restricted to enable later optimizations.
  - _The remaining classes are tightly coupled to the platform and not_
- ⚪ [1] - improve performance for `prefer_const_literals_to_create_immutables`.
  - _- update `use_build_context_synchronously` to check context properties._

**Replacement / Migration** (7)

- 🔴 [10] Use [`Deprecated.message`][] instead.
  - _- Removed the deprecated [`CastError`][] error._
- 🔴 [10] Use [`TypeError`][] instead.
  - _- Removed the deprecated [`FallThroughError`][] error. The kind of_
- 🔴 [7] Use [`maxUserTags`][] instead.
  - _- Callbacks passed to `registerExtension` will be run in the zone from which_
- 🔴 [6] now takes `Object` instead of `String`.
- 🔴 [6] - On Windows the `PUB_CACHE` has moved to `%LOCALAPPDATA%`, since Dart 2.8 the
  - _`PUB_CACHE` has been created in `%LOCALAPPDATA%` when one wasn't present._
- 🔴 [5] - Observatory is no longer served by default and users should instead use Dart
  - _DevTools. Users requiring specific functionality in Observatory should set_
- 🟡 [3] **Breaking change**: Dart 3.0 interprets [switch cases] as patterns instead of
  - _constant expressions. Most constant expressions found in switch cases are_

---

## Dart-Code

### 128

**Deprecation** (2)

- 🔴 [6] > There is no immediate problem but is related to a deprecation. Since `flutter pub run` was deprecated in favor of `dart run`, the built in task command in the extension should be updated to use `dart run`.
  - _>_
- ⚪ [2] * [#5874](https://github.com/Dart-Code/Dart-Code/issues/5874)/[#5882](https://github.com/Dart-Code/Dart-Code/issues/5882): Tasks like `build_runner` are now invoked with `dart run`, preventing a warning about `flutter pub run` being deprecated.

**Replacement / Migration** (1)

- 🔴 [7] > **#5728**: Use `flutterRoot` instead of looking for the `flutter` package when reading the sdk path from `.package_config.json` `is enhancement`
  - _> **Is your feature request related to a problem? Please describe.**_

---

### 126

**Deprecation** (1)

- ⚪ [2] > See https://blog.flutter.dev/whats-new-in-flutter-3-35-c58ef72e3766#:~:text=In%20our%20next%20stable%20release%2C%20Flutter%20SDKs%20before%203.16%20will%20be%20deprecated.

**Breaking Change** (4)

- ⚪ [1] > Placeholder for release notes.. this version will warn that support for Dart 3.1 / Flutter 3.13 is being removed soon.
  - _>_
- ⚪ [1] * [#5602](https://github.com/Dart-Code/Dart-Code/issues/5602): `formatOnType` no longer triggers when typing `;` inside an enhanced enum without a constructor, which caused the semicolon to be removed.
- ⚪ [1] > **#5602**: Writing `;` inside an enhanced enum without the constructor makes it get removed `is bug` `in editor` `relies on sdk changes`
  - _> **Describe the bug**_
- ⚪ [1] > When writing `;` inside enhanced enum before it contains a constructor, it gets removed.
  - _>_

**New Parameter / Option** (1)

- ⚪ [2] * [#5840](https://github.com/Dart-Code/Dart-Code/issues/5840)/[#5814](https://github.com/Dart-Code/Dart-Code/issues/5814): To improve startup performance, the widget preview now starts on first access rather than at startup. This can be controlled with a new setting `dart.flutterWidgetPreview` that accepts `"startLazily"` (default), `"startEagerly"` (starts at startup when a Flutter project is present) and `"disabled"`.

**Performance Improvement** (3)

- ⚪ [1] * [#5840](https://github.com/Dart-Code/Dart-Code/issues/5840)/[#5814](https://github.com/Dart-Code/Dart-Code/issues/5814): To improve startup performance, the widget preview now starts on first access rather than at startup. This can be controlled with a new setting `dart.flutterWidgetPreview` that accepts `"startLazily"` (default), `"startEagerly"` (starts at startup when a Flutter project is present) and `"disabled"`.
- ⚪ [1] > For now, I'm changing the default to lazy, since it can consume a lot of memory and there have been a few issues - but we can consider switching it to eagerly (to make it load faster the first time if you do use it) if that becomes a better trade-off than it is today (FYI @bkonyi).
- ⚪ [1] * [#5830](https://github.com/Dart-Code/Dart-Code/issues/5830): ~~Updated to LSP client v10.0.0-next.18 and enabled`delayOpenNotifications` for improved performance.~~ This change was reverted pending a fix in the VS Code LSP client.

**Replacement / Migration** (2)

- 🔴 [5] > **#5830**: Switch to LSP client v10.0.0-next.18 and enable delayOpenNotifications `is performance`
  - _> Fixes https://github.com/Dart-Code/Dart-Code/issues/5176_
- 🟡 [3] * [#5831](https://github.com/Dart-Code/Dart-Code/issues/5831)/[#5834](https://github.com/Dart-Code/Dart-Code/issues/5834): Deleting a test no longer sometimes causes the next test marker to move to the incorrect line.

---

### 124

**Performance Improvement** (1)

- ⚪ [1] > When https://github.com/microsoft/vscode-copilot-chat/pull/394 ships, we should test excluding the analyze_files tool and check that models will instead use #problems because it will handle unsaved files and be faster (since it doesn't require new analysis).

**Replacement / Migration** (6)

- 🔴 [7] > **#5801**: Use "package:foo" instead of foldernames in command execution `is enhancement` `in commands`
  - _> Fixes https://github.com/Dart-Code/Dart-Code/issues/5789_
- 🔴 [5] * [#5775](https://github.com/Dart-Code/Dart-Code/issues/5775): The Flutter Widget Preview now works for _all_ projects within a Pub Workspace instead of only the first.
- 🟡 [3] * [#5776](https://github.com/Dart-Code/Dart-Code/issues/5776): The `flutter/ephemeral`, `.symlinks` and `.plugin_symlinks` folders are now excluded from the explorer and search results by default. The `.dart_tool` folder is also now excluded from search results by default. If you’d prefer these were included, you can add them back by adding them to `files.exclude` and `search.exclude` configuration with a value of `false`.
- 🟡 [3] > When https://github.com/microsoft/vscode-copilot-chat/pull/394 ships, we should test excluding the analyze_files tool and check that models will instead use #problems because it will handle unsaved files and be faster (since it doesn't require new analysis).
- 🟡 [3] * [#5801](https://github.com/Dart-Code/Dart-Code/issues/5801)/[#5789](https://github.com/Dart-Code/Dart-Code/issues/5789): Commands like **Get Packages** now show the package name in the output instead of just the folder name (which is usually - but not always - the same).
- 🟡 [3] * [#5818](https://github.com/Dart-Code/Dart-Code/issues/5818): Breadcrumbs and other UI now show `extension on Foo` instead of just `<unnamed extension>` for unnamed extensions.

---

### 122

**New Feature / API** (1)

- 🟡 [4] * [#5648](https://github.com/Dart-Code/Dart-Code/issues/5648): E2E tests have been expanded to include testing of the new Widget Preview.

**Performance Improvement** (1)

- ⚪ [0] > **#5761**: `@FailingTest()` annotation on `test_reflective_loader` test timeouts but fails faster without it `is bug` `in testing` `relies on sdk changes`
  - _> **Describe the bug**_

**Replacement / Migration** (5)

- 🔴 [7] > **#5730**: Wish to inform the user to prefer USB over WiFi when developing against an iOS 26 device `is enhancement` `in flutter` `in debugging` `relies on sdk changes`
  - _> Related to https://github.com/flutter/flutter/issues/176206_
- 🔴 [5] * [#5744](https://github.com/Dart-Code/Dart-Code/issues/5744): The Flutter Widget Preview sidebar icon now appears after extension activation instead of only after the widget preview server initialises.
- 🟡 [3] * [#5740](https://github.com/Dart-Code/Dart-Code/issues/5740)/[#5746](https://github.com/Dart-Code/Dart-Code/issues/5746): Progress notifications when running the **Pub Get** command for multiple packages in a batch are now combined into a single notification that updates with the package names, instead of flickering individual notifications.
- 🟡 [3] * [#5745](https://github.com/Dart-Code/Dart-Code/issues/5745)/[#5746](https://github.com/Dart-Code/Dart-Code/issues/5746): When the **Pub Get** command is being run for multiple packages in a batch, a single cancellation will cancel the entire batch instead of only the current project.
- 🟡 [3] * [#5759](https://github.com/Dart-Code/Dart-Code/issues/5759): Exceptions shown in the Watch window once again show only the relevant part of the error message instead of prefixes like “Unhandled exception:”

---

### 120

**Breaking Change** (3)

- ⚪ [1] > Release notes placeholder for the preview flag that enables new test tracking as a solution towards https://github.com/Dart-Code/Dart-Code/issues/5668 (since that issue will be bumped to a future release when the flag is removed).
- ⚪ [1] * [#4696](https://github.com/Dart-Code/Dart-Code/issues/4696): Commands related to Dart Observatory are now hidden for Dart SDKs since 3.9 (when Observatory was removed).
- ⚪ [1] > When observatory is completely removed, we should use that SDK version number as a signal to hide the command so it's not in the palette.

**New Parameter / Option** (2)

- ⚪ [2] * [#5600](https://github.com/Dart-Code/Dart-Code/issues/5600): A new setting `dart.inlayHints` has been added to control which Inlay Hints are enabled (requires Dart 3.10)
- ⚪ [1] * [#5729](https://github.com/Dart-Code/Dart-Code/issues/5729)/[#5727](https://github.com/Dart-Code/Dart-Code/issues/5727): A new setting `dart.experimentalTestTracking` enables tracking of tests within files. This should improve the reliability of test gutter icons and the “Go to Test” commands for tests that are not discoverable statically (for example dynamic tests, or those using `pkg:test_reflective_loader`). This will be enabled by default in a future release.

**Performance Improvement** (1)

- ⚪ [1] * [#5683](https://github.com/Dart-Code/Dart-Code/issues/5683): The extension now starts up faster when running in Firebase Studio.

**Replacement / Migration** (4)

- 🟡 [3] > When I click "run tests with coverage" in VS Code, the resulting coverage pane shows coverage for some (apparently random) flutter library files, instead of for my code. See screenshot below.
  - _>_
- 🟡 [3] > We should prefer to look at the package map for the project containing the source file, and only fall back to finding another match if there isn't one.
- 🟡 [3] * [#5712](https://github.com/Dart-Code/Dart-Code/issues/5712): The **Debug: Attach to Dart Process** command now makes it clearer that a port number can be provided instead of a full URL.
- 🟡 [3] > It appears that after completing this code, the selection is just at the end of the `throw UnimplementedError()` instead of selecting it:

---

### 118

**Deprecation** (4)

- ⚪ [2] [#5667](https://github.com/Dart-Code/Dart-Code/issues/5667): Support for SDKs prior to Dart 3.1 and Flutter 3.13 is being deprecated. If you are using affected versions you will be shown a one-time warning advising you to upgrade.
- ⚪ [2] > **#5667**: Warn that Dart / Flutter SDKs prior to Dart 3.1 / Flutter 3.13 are deprecated and support will be removed soon `in flutter` `in dart`
  - _> With the recent Flutter stable release, it was announced that IDE support for SDKs prior to 3.13 is deprecated:_
- ⚪ [2] > With the recent Flutter stable release, it was announced that IDE support for SDKs prior to 3.13 is deprecated:
  - _>_
- ⚪ [2] > > With this release, we are deprecating IDE support for Flutter SDKs before 3.13.
  - _>_

**Breaking Change** (1)

- ⚪ [1] > **#5667**: Warn that Dart / Flutter SDKs prior to Dart 3.1 / Flutter 3.13 are deprecated and support will be removed soon `in flutter` `in dart`
  - _> With the recent Flutter stable release, it was announced that IDE support for SDKs prior to 3.13 is deprecated:_

**New Parameter / Option** (3)

- ⚪ [2] * [#5651](https://github.com/Dart-Code/Dart-Code/issues/5651)/[#5653](https://github.com/Dart-Code/Dart-Code/issues/5653): A new setting `dart.useFlutterDev` allows use of `flutter-dev` instead of `flutter`. This script is intended for use by contributors to the `flutter` tool to avoid having to manually rebuild the tool when making local changes.
- ⚪ [2] * [#5639](https://github.com/Dart-Code/Dart-Code/issues/5639): A new setting `dart.mcpServerTools` allows excluding some of the Dart MCP servers tools from registration with VS Code/Copilot. By default the `runTests` tool is excluded because it overlaps with an equivalent tool provided by VS Code.
- ⚪ [2] * [#5630](https://github.com/Dart-Code/Dart-Code/issues/5630): A new setting `dart.coverageExcludePatterns` allows excluding coverage from files/folders using globs. For example you could exclude `**/generated/**` or `**/*.g.dart`.

**Performance Improvement** (1)

- ⚪ [1] > @liamappelbe what are your thoughts on (3)? It would be nicer (and perhaps faster) if we this coverage wasn't collected for these files in the first place, but it might be that the difference is negligible and we should just drop it in Dart-Code.

**Replacement / Migration** (7)

- 🟡 [3] * [#5651](https://github.com/Dart-Code/Dart-Code/issues/5651)/[#5653](https://github.com/Dart-Code/Dart-Code/issues/5653): A new setting `dart.useFlutterDev` allows use of `flutter-dev` instead of `flutter`. This script is intended for use by contributors to the `flutter` tool to avoid having to manually rebuild the tool when making local changes.
- 🟡 [3] > `flutter-dev` is a version of `flutter` used by developers working on `flutter_tools` that runs the tool from source instead of precompiling the tool as a snapshot on first run and using the precompiled snapshot for subsequent runs.
  - _>_
- 🟡 [3] > **#5665**: Support space separators in `Dart: Add Dependency` instead of only commas `is enhancement` `in commands`
  - _> **Describe the bug**_
- 🟡 [3] >     --[no-]offline       Use cached packages instead of accessing the network.
  - _> -n, --dry-run            Report what dependencies would change but don't change_
- 🟡 [3] > - ~~Add support for multiple Flutter projects (currently we just pick the first one in the workspace)~~ moved to https://github.com/Dart-Code/Dart-Code/issues/5671
  - _> - [x] Pass DevTools and DTD server URIs so the preview doesn't start its own_
- 🟡 [3] > - ~~Add new icon for Sidebar version (this is in two places - container + view)~~ moved to https://github.com/Dart-Code/Dart-Code/issues/5672
- ⚪ [1] > From some local experimentation where I renamed `flutter-dev` to `flutter` and updated `bin/internal/shared.sh` to not try to build a snapshot for `flutter` instead of `flutter-dev`, it looks like Dart-Code does make use of the existence of `bin/cache/flutter_tools.snapshot` to determine if the tool is initialized:
  - _>_

---

### 116

**Deprecation** (1)

- ⚪ [2] * [#5008](https://github.com/Dart-Code/Dart-Code/issues/5008)/[#5583](https://github.com/Dart-Code/Dart-Code/issues/5583)/[#5595](https://github.com/Dart-Code/Dart-Code/issues/5595)/[#5601](https://github.com/Dart-Code/Dart-Code/issues/5601): New APIs are now exported by the extension to allow other VS Code extensions to reuse some of Dart-Code’s functionality. The internal private APIs that were intended only for testing (but had been adopted by some extensions) will be removed in an upcoming release. If you maintain a VS Code extension that uses these APIs, please see https://github.com/Dart-Code/Dart-Code/issues/5587 and ensure your extension is migrated.

**Breaking Change** (5)

- ⚪ [1] * [#5591](https://github.com/Dart-Code/Dart-Code/issues/5591): The **Flutter: New Project** command no longer shows the “Skeleton” option that was removed in Flutter 3.29.
- ⚪ [1] > When creating a Flutter project, there are several options as for the template. One of them is "Skeleton Application". However, this template has been removed from `flutter create` at the end of 2024 (see [skeleton template removal](https://github.com/flutter/flutter/issues/160673)).
  - _>_
- ⚪ [1] > As this option doesn't exist in `flutter create` anymore, it should probably be removed from the choices in project creation from the Flutter plugin as well.
  - _>_
- ⚪ [1] * [#5008](https://github.com/Dart-Code/Dart-Code/issues/5008)/[#5583](https://github.com/Dart-Code/Dart-Code/issues/5583)/[#5595](https://github.com/Dart-Code/Dart-Code/issues/5595)/[#5601](https://github.com/Dart-Code/Dart-Code/issues/5601): New APIs are now exported by the extension to allow other VS Code extensions to reuse some of Dart-Code’s functionality. The internal private APIs that were intended only for testing (but had been adopted by some extensions) will be removed in an upcoming release. If you maintain a VS Code extension that uses these APIs, please see https://github.com/Dart-Code/Dart-Code/issues/5587 and ensure your extension is migrated.
- ⚪ [1] > In the latest release, we removed the code that forced the SDK repo to always run tests through `dart` instead of the test runner. It turns out there are quite a few tests in the SDK that fail when run through the runner.
  - _>_

**New Feature / API** (1)

- ⚪ [2] * [#5008](https://github.com/Dart-Code/Dart-Code/issues/5008)/[#5583](https://github.com/Dart-Code/Dart-Code/issues/5583)/[#5595](https://github.com/Dart-Code/Dart-Code/issues/5595)/[#5601](https://github.com/Dart-Code/Dart-Code/issues/5601): New APIs are now exported by the extension to allow other VS Code extensions to reuse some of Dart-Code’s functionality. The internal private APIs that were intended only for testing (but had been adopted by some extensions) will be removed in an upcoming release. If you maintain a VS Code extension that uses these APIs, please see https://github.com/Dart-Code/Dart-Code/issues/5587 and ensure your extension is migrated.

**New Parameter / Option** (1)

- ⚪ [2] * [#5556](https://github.com/Dart-Code/Dart-Code/issues/5556)/[#5577](https://github.com/Dart-Code/Dart-Code/issues/5577): A new setting `dart.mcpServerLogFile` allows logging communication with the Dart SDK MCP server.

**Replacement / Migration** (5)

- 🟡 [3] * [#5612](https://github.com/Dart-Code/Dart-Code/issues/5612)/[#5617](https://github.com/Dart-Code/Dart-Code/issues/5617): Adding a Flutter project to a workspace that previously contained only Dart projects will now prompt to reload in order to switch to a Flutter SDK and start required Flutter services.
- 🟡 [3] * [#5606](https://github.com/Dart-Code/Dart-Code/issues/5606)/[#5610](https://github.com/Dart-Code/Dart-Code/issues/5610): Interaction with Flutter’s device daemon has been switched to newer APIs, avoiding “No devices found” on Flutter’s `master` branch.
- 🟡 [3] > It could also be synched with the removal of the [skeleton] template option from the `flutter create` command, which is still present (but only shows a message instead of creating a project).
- 🟡 [3] * [#5621](https://github.com/Dart-Code/Dart-Code/issues/5621)/[#5622](https://github.com/Dart-Code/Dart-Code/issues/5622): The `autolaunch.json` functionality now supports watching for modifications to the autolaunch file instead of only creation.
  - _* [#5613](https://github.com/Dart-Code/Dart-Code/issues/5613): An environment variable `DART_CODE_SERVICE_ACTIVATION_DELAY` can now be used to delay the activation of background services like the Dart Tooling Daemon._
- 🟡 [3] > In the latest release, we removed the code that forced the SDK repo to always run tests through `dart` instead of the test runner. It turns out there are quite a few tests in the SDK that fail when run through the runner.
  - _>_

---

### 114

**Breaking Change** (1)

- ⚪ [1] > **#4678**: Breakpoints flicker as they are removed/re-added when breakpoints are added/removed `is bug` `in debugging` `relies on sdk changes`
  - _> Because we mark breakpoints as unverified initially now, and we delete/re-create them when anything changes (because VS Code just gives us a whole new set), there's a noticable flicker._

**Performance Improvement** (1)

- ⚪ [1] * [#5532](https://github.com/Dart-Code/Dart-Code/issues/5532): Lists inspected in the debugger at the top level (for example by hovering) are now paged in the same way as child fields which improves performance and avoids stalls for very large lists.

**Replacement / Migration** (4)

- 🟡 [3] * [#5553](https://github.com/Dart-Code/Dart-Code/issues/5553): Setting `"dart.hotReloadProgress": "statusBar"` now correctly shows Flutter hot reload progress in the status bad instead of toast notifications.
- 🟡 [3] * [#5520](https://github.com/Dart-Code/Dart-Code/issues/5520): It’s now possible to specify `emulatorId` instead of `deviceId` in a launch configuration. This will automatically be mapped to the correct `deviceId` during launch, and if the emulator is not already running it will first be started.
- 🟡 [3] * [#5502](https://github.com/Dart-Code/Dart-Code/issues/5502): The **Add Dependency** command will now allow selecting which projects to add the dependency to, with the project for the active file pre-selected, instead of just automatically adding to the project for the active file.
- 🟡 [3] > Inline values show for parameters but not for pattern destruction blocks. This forces me to hover the assigned variable instead of simply looking at the value.
  - _>_

---

### 112

**Breaking Change** (1)

- ⚪ [1] > This issue is to discuss feedback about whether this works well enough that the experimental flag should be removed and ship it.

**New Feature / API** (1)

- ⚪ [2] > We should try to reduce the requirement, and handle (in code) and new APIs we require for now.

**Replacement / Migration** (3)

- 🟡 [3] * [#5480](https://github.com/Dart-Code/Dart-Code/issues/5480): When developing in the Dart SDK repository in packages that use `package:test_reflective_loader` (such as `analyzer` or `analysis_server`), the **Go to Test** actions now navigate to the test method instead of the call to `defineReflectiveTests`. When a test fails, the error popup will also show at this new location.
- 🟡 [3] > I expected it to move to the right test.
  - _>_
- 🟡 [3] > then when you load the project you would instantly have access to DevTools for the visible app in the emulator. By attaching (instead of launching ourselves), if you have a multi-user session, both would be attached to the same instance, rather than one of them replacing the other.
  - _>_

---

### 110

**Performance Improvement** (1)

- ⚪ [1] > 2. `cd packages`, `get sparse-checkout init --cone`, `get sparse-checkout set packages/camera packages/google_maps_flutter` (this restricts checkout, so that things are faster and easier to repro)
  - _> 3. `code .`_

**Replacement / Migration** (1)

- 🟡 [3] > I ran some of these tests by right-clicking on the "test/src/computer" folder (in `analysis_server`), and then when I switched to the test runner, they appear as just the filename, whereas the other discovered tests all have relative paths from the root of the workspace folder.
  - _>_

---

### 108

**Breaking Change** (2)

- ⚪ [1] * [#5456](https://github.com/Dart-Code/Dart-Code/issues/5456): Because the Dart SDK repository now uses Pub Workspaces, the `dart.experimentalTestRunnerInSdk` setting has been removed and the test runner functionality is available when working in the Dart SDK repository automatically.
- ⚪ [0] * [#5090](https://github.com/Dart-Code/Dart-Code/issues/5090): The `dart.previewDtdLspIntegration` setting has been removed and the analysis server will now always connect to DTD when using a supported SDK version. If you are interested in integrating with the analysis server over DTD please [see this issue](https://github.com/dart-lang/sdk/issues/60377) about capabilities.

**Replacement / Migration** (6)

- 🟡 [3] [#5396](https://github.com/Dart-Code/Dart-Code/issues/5396)/[#5367](https://github.com/Dart-Code/Dart-Code/issues/5367)/[#5466](https://github.com/Dart-Code/Dart-Code/issues/5466): A new experiment allows embedding DevTools pages inside the sidebar instead of as editor tabs. Trying this out requires enabling an experiment flag and then using the hidden value `"sidebar"` in the `dart.devToolsLocation` setting:
- 🟡 [3] > ~~There is work in-progress to test out embedding DevTools in sidebar panels instead of editors. It's currently blocked on https://github.com/microsoft/vscode/issues/236494 because that causes us to "restore" bad URLs into the iframes when they load.~~
  - _>_
- 🟡 [3] > Because it internally runs `dart [program]` instead of `dart run [program]`
  - _>_
- 🟡 [3] > 6. Observe that it opens in non-Chrome instead of Chrome
  - _>_
- ⚪ [1] * [#5447](https://github.com/Dart-Code/Dart-Code/issues/5447)/[#5448](https://github.com/Dart-Code/Dart-Code/issues/5448): [@davidmartos96](https://github.com/davidmartos96) contributed a fix to prefer launching `studio` over `stduio.sh` when started Android Studio to avoid a warning when Android Studio opens.
- ⚪ [1] > Android Studio displays warning when opened from VSCode because VSCode seems to launch with the shell script `studio.sh` instead of `studio` binary.
  - _> The line https://github.com/Dart-Code/Dart-Code/blob/master/src/shared/constants.ts#L23 let me think `studio.sh` has greater priority than `studio`. Maybe just swap ?_

---

### 106

**Deprecation** (1)

- ⚪ [2] > - [x] Update the website to note which extension versions deprecate and remove support for older SDKs
  - _> - [x] Clean up legacy protocol code that's no longer used_

**New Parameter / Option** (1)

- ⚪ [2] * [#5403](https://github.com/Dart-Code/Dart-Code/issues/5403): A new setting `dart.toolingDaemonAdditionalArgs` allows configuring additional arguments to pass to the Dart Tooling Daemon, for example to pass an explicit port with `--port`.

**Replacement / Migration** (1)

- 🟡 [3] > I think it would be more useful if the red tag showed the actual result instead of the expected one. I looked through preferences to see if i could configure it but I did not find anything. What you do you think?

---

### 104

**Deprecation** (1)

- ⚪ [2] In the next release of the extension, code supporting these SDK versions will be removed. A table showing which extension versions support which SDKs (and instructions on how to change extension version) is available on the [SDK Compatibility page](/sdk-version-compatibility/) if you need to continue to use unsupported SDKs.

**Breaking Change** (1)

- ⚪ [1] In the next release of the extension, code supporting these SDK versions will be removed. A table showing which extension versions support which SDKs (and instructions on how to change extension version) is available on the [SDK Compatibility page](/sdk-version-compatibility/) if you need to continue to use unsupported SDKs.

**Replacement / Migration** (4)

- 🔴 [6] [#5334](https://github.com/Dart-Code/Dart-Code/issues/5334)/[#5377](https://github.com/Dart-Code/Dart-Code/issues/5377)/[#5117](https://github.com/Dart-Code/Dart-Code/issues/5117): [@davidmartos96](https://github.com/davidmartos96) contributed new settings `dart.getFlutterSdkCommand` and `dart.getDartSdkCommand` that allow executing a command to locate the Dart/Flutter SDKs to use for a workspace. This improves compatibility with some SDK version managers (such as `mise` and `asdf`) because they can be queried for the current SDK instead of reading from `PATH` (or `package.json`).
- 🟡 [3] * [#5401](https://github.com/Dart-Code/Dart-Code/issues/5401): When using a VS Code workspace (`.code-workspace` file), relative paths in settings are now resolved relative to the folder containing the workspace file instead of the first folder in the workspace.
- 🟡 [3] > The `cacheBust` param and all following are tacked on to the end instead of adding to the existing query parameters like `wasm=true`. Additionally, we shouldn't need the # sign which may be getting added by VS code.
- 🟡 [3] * [#5363](https://github.com/Dart-Code/Dart-Code/issues/5363): The debugger no longer incorrectly evaluates values for initializing parameters instead of class variables inside constructor bodies.

---

### 102

**Replacement / Migration** (1)

- 🟡 [3] * [#5353](https://github.com/Dart-Code/Dart-Code/issues/5353): The “Peek Error” popup shown when a test fails now shows the full output of a test instead of only the last output event (which for Flutter integration tests is often just the bottom of an ascii box `==========================`).

---

### 100

**Deprecation** (2)

- ⚪ [2] [#5257](https://github.com/Dart-Code/Dart-Code/issues/5257)/[#5304](https://github.com/Dart-Code/Dart-Code/issues/5304): As [previously announced](https://groups.google.com/g/flutter-announce/c/JQHzM3FbBGI), support for older Dart/Flutter SDKs will be deprecated with Dart 3.6 and removed when Dart 3.7 releases next year. If you are using an affected SDK version (a Dart SDK before Dart 3.0 or a Flutter SDK before Flutter 3.10) you will see a notification.
- ⚪ [2] ![](/images/release_notes/v3.100/sdk_deprecation.png)

**Breaking Change** (2)

- ⚪ [1] [#5257](https://github.com/Dart-Code/Dart-Code/issues/5257)/[#5304](https://github.com/Dart-Code/Dart-Code/issues/5304): As [previously announced](https://groups.google.com/g/flutter-announce/c/JQHzM3FbBGI), support for older Dart/Flutter SDKs will be deprecated with Dart 3.6 and removed when Dart 3.7 releases next year. If you are using an affected SDK version (a Dart SDK before Dart 3.0 or a Flutter SDK before Flutter 3.10) you will see a notification.
- ⚪ [1] * [#5321](https://github.com/Dart-Code/Dart-Code/issues/5321): The temporary allowlist for allowing Pub packages to recommend their VS Code extensions has been removed.

**New Feature / API** (2)

- 🟡 [4] > This adds two new fields to `DartCapabilities` for `isUnsupportedNow` and `isUnsupportedSoon` to determine whether to warn the user about unsupported SDKs. This is a necessary step before we can remove any legacy code (such as the legacy analysis server integration, or activating DevTools from pub!).
- ⚪ [2] > Hi, given the Dart VS Code extension supports suggesting VS Code extensions based on the installed packages, it would be great to either remove [the allow list](https://github.com/Dart-Code/Dart-Code/blob/master/src/extension/sdk/dev_tools/manager.ts#L550) or have a clear process of how a new extension can be added there.

**New Parameter / Option** (1)

- 🟡 [4] > This adds two new fields to `DartCapabilities` for `isUnsupportedNow` and `isUnsupportedSoon` to determine whether to warn the user about unsupported SDKs. This is a necessary step before we can remove any legacy code (such as the legacy analysis server integration, or activating DevTools from pub!).

**Replacement / Migration** (4)

- 🔴 [5] > **#5311**: Switch customDevTools to assume `dt` instead of `devtools_tool` `is enhancement` `in devtools`
  - _> See https://github.com/flutter/devtools/pull/8410_
- 🟡 [3] > "Unsupported now" messages will always be shown as the intention is that the user will either upgrade their SDK or switch to an older extension.. this may seem annoying, but the extension will be broken in many ways when using an SDK that triggers this, so ignoring it is not an option - you must upgrade SDK or switch to an older extension.
- 🟡 [3] * [#5311](https://github.com/Dart-Code/Dart-Code/issues/5311): Using the `dart.customDevTools` setting to run DevTools from source now assumes the tool is named `dt` instead of the original name `devtools_tool`.
- 🟡 [3] * [#5235](https://github.com/Dart-Code/Dart-Code/issues/5235): The **Move To File** refactor now shows “Refactoring…” status notifications in the status bar, matching other kinds of refactors.

---

### v3-98

**New Parameter / Option** (1)

- 🟡 [4] * [#3628](https://github.com/Dart-Code/Dart-Code/issues/3628)/[#5263](https://github.com/Dart-Code/Dart-Code/issues/5263): [@FMorschel](https://github.com/FMorschel) contributed new settings for customizing the prefix (`dart.closingLabelsPrefix`) and font style (`dart.closingLabelsTextStyle`) of Closing Labels. ![](/images/release_notes/v3.98/closing_labels_customization.png)

**Replacement / Migration** (3)

- 🟡 [3] * [#5302](https://github.com/Dart-Code/Dart-Code/issues/5302): When using VS Code 1.94, ANSI color codes once again show colors in the Debug Console instead of printing escape sequences.
- 🟡 [3] * [#5283](https://github.com/Dart-Code/Dart-Code/issues/5283): The “Build errors exist in your project” dialog has been updated to no longer refer to errors as “Build errors” and uses “Run Anyway” instead of “Debug Anyway” because it can also apply to running without debugging.
- 🟡 [3] * [#5272](https://github.com/Dart-Code/Dart-Code/issues/5272): When a background process like the analyzer or Flutter daemon terminates unexpectedly, the “Open Log” button on the prompt will now open the specific log for that process (if enabled) instead of a generic log of all events from all processes.

---

### v3-96

**New Parameter / Option** (1)

- ⚪ [2] * [#5213](https://github.com/Dart-Code/Dart-Code/issues/5213): A new setting `dart.enablePub` allows disabling Pub functionality including prompts for `pub get`, automatically running `pub get` and visibility of the menu and command entries for running Pub commands.

**Replacement / Migration** (8)

- 🔴 [5] > **#5231**: Switch to parsing the new Flutter version file `bin/cache/flutter.version.json` instead of the legacy one `version` and remove workaround `is enhancement`
  - _> See:_
- 🔴 [5] > **#5225**: Switch to the DTD sidebar when using a new enough SDK `is enhancement` `in flutter sidebar`
  - _> - DevTools work done in https://github.com/flutter/devtools/commit/faeb2a3e0d49a01301ed85dd9bba989a88b4b762_
- 🟡 [3] * [#5100](https://github.com/Dart-Code/Dart-Code/issues/5100): The prompt to run `dart fix` now offers to run the **Dart: Fix All in Workspace** commands instead of recommending running `dart fix` from the terminal. See the [previous release notes](/releases/#fix-all-in-workspace-commands) for more details on the in-editor fix commands.
- 🟡 [3] * [#5218](https://github.com/Dart-Code/Dart-Code/issues/5218): An issue with the **Move to File** refactoring causing an invalidate state after creating new files has been resolved.
- 🟡 [3] > **#5218**: Move to file not moving to existing file even after agreeing to replace it `is bug` `in editor`
  - _> With this code sample:_
- 🟡 [3] * [#5225](https://github.com/Dart-Code/Dart-Code/issues/5225): When using the latest versions of Flutter (currently only `master`), the Flutter sidebar will use DTD for communication with Dart-Code instead of `postMessage`. There are currently no functional differences between the two sidebars, but this is a step towards making [the APIs used by the sidebar](https://github.com/dart-lang/sdk/blob/main/pkg/dtd_impl/dtd_common_services_editor.md) available to other DTD clients, and the sidebar more generic so that it could be used by editors besides VS Code.
- 🟡 [3] > **#5232**: In a monorepo, when you select the debug session and select "Dart & Flutter...", all projects are shown, but all with the root folder name instead of the project name. `is bug` `in debugging`
  - _> In a monorepo, when you select the debug session and select "Dart & Flutter...", all projects are shown, but all with the root folder name instead of the project name._
- 🟡 [3] > In a monorepo, when you select the debug session and select "Dart & Flutter...", all projects are shown, but all with the root folder name instead of the project name.

---

### v3-94

**Replacement / Migration** (3)

- 🟡 [3] > **#5164**: Stepping into Dart SDK sources in Flutter results in sources downloaded from the VM instead of used from disk `is bug` `in flutter` `in debugging`
  - _> Some integration tests are failing because when we step into SDK sources, we don't get back a path for the stack frames:_
- 🟡 [3] * [@rodrigogmdias](https://github.com/rodrigogmdias) contributed [#5175](https://github.com/Dart-Code/Dart-Code/issues/5175): A new command **Pub: Get Packages for All Projects** will fetch packages for all projects in the workspace instead of only the project for the active file.
- 🟡 [3] > With just the first issue fixed, we'll produce no edits instead of formatting the entire document. However, we should really produce an edit just for unwrapping the empty collection.

---

### v3-92

**New Feature / API** (1)

- ⚪ [2] > I was just able to repro this, and switching back to the Stable version seemed to fix it. My guess would be that it's related to https://github.com/Dart-Code/Dart-Code/commit/3855d1d94150745e4800b3f1eb9945a0e3726fe5 or https://github.com/Dart-Code/Dart-Code/commit/eea9929f7c90f2991c60b0415c5a3cae38e432fa (they do have some changes in the commands to support the new flags, the change was not isolated to the commands).

**New Parameter / Option** (1)

- ⚪ [2] > I was just able to repro this, and switching back to the Stable version seemed to fix it. My guess would be that it's related to https://github.com/Dart-Code/Dart-Code/commit/3855d1d94150745e4800b3f1eb9945a0e3726fe5 or https://github.com/Dart-Code/Dart-Code/commit/eea9929f7c90f2991c60b0415c5a3cae38e432fa (they do have some changes in the commands to support the new flags, the change was not isolated to the commands).

**Replacement / Migration** (5)

- 🟡 [3] > I prefer to not hardcode a default value here, and instead omit the `--web-renderer` argument by default. That way, we let the flutter tool decide what's the default. Is there a way to make the `dart.flutterWebRenderer` enum nullable?
- 🟡 [3] * [#5133](https://github.com/Dart-Code/Dart-Code/issues/5133): Several legacy settings have been moved to the **Legacy** section in the settings UI and had their descriptions updated to make it clear those settings may only work for older SDKs.
- 🟡 [3] * [#5142](https://github.com/Dart-Code/Dart-Code/issues/5142): The quick-fix for “Add missing switch cases” now adds all enum values instead of only the first.
- 🟡 [3] > The quick fix for `Add missing switch cases` only adds one case at a time, instead of all of the missing cases.
- 🟡 [3] > 5. Only one case is added, instead of all missing cases

---

### v3-90

**New Parameter / Option** (2)

- 🟡 [4] [#5029](https://github.com/Dart-Code/Dart-Code/issues/5029): A new setting **Dart: Close DevTools** (`dart.closeDevTools`) has been added to allow automatic closing of embedded DevTools windows like the Widget Inspector when a debug session ends. The `ifOpened` option will close only embedded windows that were opened automatically as a result of the **Dart: Open DevTools** (`dart.openDevTools`) setting.
- ⚪ [2] > I find it slightly annoying that I have to manually exit out of the embedded widget window when I'm done with a debug session to get back to the view I was in prior to starting the debug session.  I would like to propose a new settings flag that controls whether the debug window closes automatically upon debug session end or not.

**Replacement / Migration** (1)

- 🟡 [3] > **#5022**: Add "Fix All in Workspace" commands to apply fixes across the whole workspace instead of only current file `is enhancement` `in editor`
  - _> Seems we don't have an issue tracking this. We should support running "dart fix" for your workspace in the IDE, rather than telling users to run from the command line._

---

### v3-88

**Breaking Change** (1)

- ⚪ [1] * [#5105](https://github.com/Dart-Code/Dart-Code/issues/5105): The `dart.experimentalMacroSupport` setting has been removed and macro support is now controlled solely by SDK experiment flags.

**New Feature / API** (1)

- ⚪ [2] > The `dart.experimentalMacroSupport` setting was used to enable new APIs to get generated code from the server into VS Code. There's been enough testing that this flag is probably unnecessary now, however we should gate enabling these new APIs on a suitable version number where this API support is more stable/complete (perhaps 3.5.0-0, since 3.5 is what current bleeding-edge builds are).

**Replacement / Migration** (5)

- 🟡 [3] > **#5056**: Go to Augmentation CodeLen opens a new editor in the current group instead of jumping to an existing editor in another group `is bug` `in editor`
  - _> **Describe the bug**_
- 🟡 [3] > When using the "Run" code lens button, I'd like vscode to open the Test Results view. It sometimes opens the Debug Console and other times the only noticeable UI change is a badge number indicator showing on the Test Explorer icon. If I use the green button to the left in the "well" (I think that's what the area is called), then it does switch to the Test Results view.
- 🟡 [3] > removing the quotes (`"`) around the path added by the extension inside the path env variable fixes the issue. according to [this](https://serverfault.com/a/349216), paths inside the windows path env var shouldn't be quoted. they should instead use semicolons as delimiters. i can confirm that among all paths present on my machine (including ones with spaces), the dart/flutter's was the only quoted one
- 🟡 [3] > 1\) One of the intermediate folders was omitted (ex. instead of `test/impl/another/**` all tests are put into `test/another/**`). Which looks easy to fix unless you have 1000 tests that need to be updated + some test rely on the relative file paths which makes it a bit problematic. Although, I agree that it's mostly the consequences of my bad decisions and should not probably be covered by the extension feature.
- 🟡 [3] > For the sidebar, we can just reload the frame for now (since it will set itself back up automatically) and if we move to a new DTD API in future, we can add a theme change event to that.

---

### v3-86

**New Parameter / Option** (1)

- ⚪ [2] [#5031](https://github.com/Dart-Code/Dart-Code/issues/5031): A new setting `dart.hotReloadPatterns` allows setting custom globs for which modified files should trigger a Hot Reload:

**Replacement / Migration** (1)

- 🟡 [3] * [#5048](https://github.com/Dart-Code/Dart-Code/issues/5048): Flutter Outline, CodeLens and some other features that rely on outline information from the Dart Analysis Server are now sent for newly-opened files instead of requiring a modification to the file to show up.

---

### v3-84

**Breaking Change** (1)

- ⚪ [1] * [#5001](https://github.com/Dart-Code/Dart-Code/issues/5001): Due to breaking changes in the code completion APIs, the `dart.useLegacyAnalyzerProtocol` setting is now ignored for Dart SDKs 3.3 and later. The LSP protocol will always be used for these newer SDKs.

**New Feature / API** (1)

- ⚪ [2] > Rather than migrating to the new APIs, we should disable using the legacy protocol on Dart 3.3 onwards. LSP has been stable and the default for a long time and we've not been updating the legacy client here to keep up with any new features.

**Replacement / Migration** (4)

- 🔴 [6] * [#4877](https://github.com/Dart-Code/Dart-Code/issues/4877): The hover for `Enum.values` no longer incorrectly reports the type as `Enum` instead of `List<Enum>`.
- 🟡 [3] > - Make it clearer to the user that we failed to find Git (instead of silently going to the website)
- 🟡 [3] * [#4995](https://github.com/Dart-Code/Dart-Code/issues/4995): Automatic `toString()` invocations in the debugger (controlled by the `dart.evaluateToStringInDebugViews` setting) now evaluate up to 100 values per request instead of 11.
- 🟡 [3] > **#4995**: Debug `toString()` evaluates 11 values instead of 100 `is bug` `in debugging` `relies on sdk changes`
  - _> **Describe the bug**_

---

### v3-82

**New Parameter / Option** (1)

- 🔴 [6] * [#4966](https://github.com/Dart-Code/Dart-Code/issues/4966): The `dart.previewSdkDaps` setting has been replaced by a new `dart.useLegacyDebugAdapters`. The new setting has the opposite meaning (`true` means to use the legacy adapters, whereas for the old setting that was `false`).

**Replacement / Migration** (2)

- 🟡 [3] > Having consistent highlighting that resembles a method instead of a keyword.
- 🟡 [3] * [#4952](https://github.com/Dart-Code/Dart-Code/issues/4952): [DevTools extensions](https://pub.dev/packages/devtools_extensions) and other DevTools pages that are not specifically known to Dart-Code can now be opened embedded instead of only in an external browser.

---

### v3-80

**Breaking Change** (1)

- ⚪ [1] > Since VS Code [has removed recommending extensions](https://github.com/microsoft/vscode/issues/188467) based on file extension we should consider showing a notification when a Flutter developer opens an ARB file offering to install the extension.

**New Feature / API** (1)

- ⚪ [2] > We need to only do this for SDKs newer than when the new API was added, and still use the old one for others.

**Replacement / Migration** (1)

- 🟡 [3] * [#4885](https://github.com/Dart-Code/Dart-Code/issues/4885): For new versions of Flutter, launching an application will not overwrite any custom Pub root directories set via DevTools (by using the `addPubRootDirectories` service instead of `setPubRootDirectories`).

---

### v3-78

**New Parameter / Option** (1)

- ⚪ [2] To completely hide getters you can use the new setting `"dart.showGettersInDebugViews": false`.

**Replacement / Migration** (5)

- 🟡 [3] [#2462](https://github.com/Dart-Code/Dart-Code/issues/2462): Also when using Flutter 3.16 / Dart 3.2, code completion has been improved to include more detailed signatures for all items instead of only the one currently selected.
- 🟡 [3] > **#4234**: Allow getters to be executed lazily instead of up-front `is enhancement` `in debugging` `relies on sdk changes`
  - _> DAP now allows us to wrap expensive getters in an object and signal that it's to support lazy-fetching of expensive/potential-side-effect properties:_
- 🟡 [3] > And probably inferred single element pattern should be `(Type,)` instead of `(Type)`.
- 🟡 [3] * [#4827](https://github.com/Dart-Code/Dart-Code/issues/4827): The `dart.customDevTools` setting now uses `devtools_tool serve` instead of the legacy `build_e2e` script.
- 🟡 [3] > **#4827**: Update dart.customDevTools to support using "devtools_tool serve" instead of the old build_e2e script `is enhancement` `in devtools`
  - _> Currently the `dart.customDevTools` setting assumes we will run `dart ${dart.customDevTools.script}` to start DevTools, but the script has been replaced by `devtools_tool serve` in https://github.com/flutter/devtools/pull/6638_

---

### v3-76

**Performance Improvement** (1)

- ⚪ [1] >             SizedBox(), /// 👈 Use 'const' with the constructor to improve performance.

**Replacement / Migration** (1)

- 🟡 [3] * [#4818](https://github.com/Dart-Code/Dart-Code/issues/4818): Devices that are emulators will now show the emulator name (instead of device name) in the sidebar, matching what’s shown in other locations such as the device quick-pick.

---

### v3-74

**New Feature / API** (1)

- 🟡 [4] > The new widget should be parent of the `Text('a')`  branch and not of the entire switch expression

**Replacement / Migration** (3)

- 🟡 [3] > **#4758**: "wrap with widget" wraps the entire switch expression instead of the current branch `is bug` `in editor` `in lsp/analysis server` `relies on sdk changes`
  - _> **Describe the bug**_
- 🟡 [3] > "wrap with widget" wraps the entire switch expression instead of the current branch
- 🟡 [3] > 7. the cursor now should've moved to the top of the file.

---

### v3-72

**Deprecation** (3)

- ⚪ [2] * [#4697](https://github.com/Dart-Code/Dart-Code/issues/4697): The **Dart: Open Observatory** command is now marked as deprecated and will be removed in a future update once removed from the SDK.
- ⚪ [2] > **#4697**: Visibly mark Observatory command(s) as deprecated `in commands`
  - _> The Observatory command shouldn't be removed yet because some users are still using this. After we have a version number for complete removal, we can remov eit (https://github.com/Dart-Code/Dart-Code/issues/4696). For now, we should show "Deprecated" in the name so it's clearer to users that they should be moving away from this._
- ⚪ [2] > The Observatory command shouldn't be removed yet because some users are still using this. After we have a version number for complete removal, we can remov eit (https://github.com/Dart-Code/Dart-Code/issues/4696). For now, we should show "Deprecated" in the name so it's clearer to users that they should be moving away from this.

**Breaking Change** (5)

- ⚪ [1] * [#4697](https://github.com/Dart-Code/Dart-Code/issues/4697): The **Dart: Open Observatory** command is now marked as deprecated and will be removed in a future update once removed from the SDK.
- ⚪ [1] > The Observatory command shouldn't be removed yet because some users are still using this. After we have a version number for complete removal, we can remov eit (https://github.com/Dart-Code/Dart-Code/issues/4696). For now, we should show "Deprecated" in the name so it's clearer to users that they should be moving away from this.
- ⚪ [1] * [#4701](https://github.com/Dart-Code/Dart-Code/issues/4701): Searching the Workspace Symbols list has been fixed when using the legacy analyzer protocol (`dart.useLegacyAnalyzerProtocol`). The legacy protocol is not recommended (and will eventually be removed) - if you feel you need to use it please [file an issue](https://github.com/Dart-Code/Dart-Code/issues) with the details.
- ⚪ [1] * [#4655](https://github.com/Dart-Code/Dart-Code/issues/4655): When using `editor.codeActionsOnSave` to run `source.fixAll`, unused parameters will no longer be removed. They will still be removed if you invoke the **Fix All** command explicitly.
- ⚪ [1] > `this.param` is removed automatically, because it is (as yet) unused.

**Replacement / Migration** (5)

- 🔴 [5] > Flutter users should run `flutter pub get` instead of `dart pub get`.
- 🟡 [3] [#4518](https://github.com/Dart-Code/Dart-Code/issues/4518): When using the latest Flutter release (v3.13), the Move to File refactoring is available without setting any experimental flags.
- 🟡 [3] > When you clone the Flutter SDK with the flow provided in VS Code, you don't get the option to switch to channels other than stable.
- 🟡 [3] > Here, "Go to Test" on "(tearDownAll)" is navigating to line 33 of the left file, instead of the right one. The test I ran was on line 26 of the left file.
- ⚪ [2] > Recommendation: Users who install the SDK through the flow offered in VS Code should have the ability to switch to all the available channels (currently master, main, beta and stable).

---

### v3-70

**New Parameter / Option** (1)

- ⚪ [2] * [#4637](https://github.com/Dart-Code/Dart-Code/issues/4637): A new setting `dart.sdkSwitchingTarget` allows you to configure the SDK Picker to modify the selected SDK globally, instead of only for the current workspace.

**Performance Improvement** (3)

- ⚪ [1] * [#4106](https://github.com/Dart-Code/Dart-Code/issues/4106): The **Open Symbol in Workspace** search is now significantly faster for workspace with large numbers of projects.
- ⚪ [1] > Autocomplete is much faster for me when I use the old analyzer protocol:
- ⚪ [1] > With this change, imports will not be touched when using fix-all if it was invoked automatically by save. However, it's possible to retain the original behaviour by invoked listing the original fix, or (more efficiently) `source.organizeImports`) to run on-save:

**Replacement / Migration** (6)

- 🟡 [3] * [#4637](https://github.com/Dart-Code/Dart-Code/issues/4637): A new setting `dart.sdkSwitchingTarget` allows you to configure the SDK Picker to modify the selected SDK globally, instead of only for the current workspace.
- 🟡 [3] > **#4637**: Add a setting to allow the SDK switcher to write to global user settings instead of workspace settings `is enhancement` `in commands`
  - _> The current behaviour was convenient for me, but might not be what users prefer/expect._
- 🟡 [3] * [#4630](https://github.com/Dart-Code/Dart-Code/issues/4630): The “SDK configured in dart.[flutter]sdkPath is not a valid SDK folder” warning message now opens the specific settings file that configures the invalid path (instead of always User Settings).
- 🟡 [3] * [#4518](https://github.com/Dart-Code/Dart-Code/issues/4518)/[#4159](https://github.com/Dart-Code/Dart-Code/issues/4159)/[#1831](https://github.com/Dart-Code/Dart-Code/issues/1831): The new **Move to File** refactoring is no longer behind an experimental flag.
  - _* [#4573](https://github.com/Dart-Code/Dart-Code/issues/4573): Some stack traces printed to the Debug Console will no longer try to open files using incorrect relative paths when clicking on the filename on the right side._
- 🟡 [3] > I've recently switched from using IntelliJ to VSCode as my full time Flutter editor, and the main thing I've noticed is that the searches for symbols are incredibly slow, when they work at all.
- 🟡 [3] > 3. The main library has a file which imports 33 packages, including 8 from the Dart SDK. It has 49 `part` declarations for files within the repository. Most other files don't have imports, and instead use `part of` to inherit the global scope provided by the main file. Most of the other packages in this project do the same.

---

### v3-68

**Performance Improvement** (1)

- ⚪ [1] * [#4420](https://github.com/Dart-Code/Dart-Code/issues/4420): The debug adapter now drops references to variables, scopes and stack frames when execution resumes to reduce memory usage over long debug sessions.

---

### v3-66

**New Parameter / Option** (1)

- ⚪ [2] * [#4556](https://github.com/Dart-Code/Dart-Code/issues/4556): A new setting `dart.analyzerAdditionalVmArgs` allows passing additional VM arguments when spawning the analysis server.

**Replacement / Migration** (3)

- 🟡 [3] * [#4557](https://github.com/Dart-Code/Dart-Code/issues/4557): Multiple test suites are now run using relative instead of absolute paths. This reduces the chance of “Command line too long” errors on Windows when running a large selection of test suites (either explicitly, or because exclusions require each suite to be passed to `dart test`/`flutter test` individually). Further improvements to this will be made in a future release via [#4553](https://github.com/Dart-Code/Dart-Code/issues/4553).
- 🟡 [3] * [#4527](https://github.com/Dart-Code/Dart-Code/issues/4527): The default project names when using the **Dart: New Project** and **Flutter: New Project** commands have been updated to better reflect the kind of project. For example selecting the “package” template will provide a default name of `dart_package_1` instead of `dart_application_1`.
- 🟡 [3] > If I create a new Dart package project, the default project name is `dart_application_x` instead of `dart_package_x`. It should really be the latter.

---

### v3-64

**New Parameter / Option** (4)

- ⚪ [2] [#4021](https://github.com/Dart-Code/Dart-Code/issues/4021)/[#4487](https://github.com/Dart-Code/Dart-Code/issues/4487): A new setting `"dart.testInvocationMode"` has been added that allows you to choose how tests are executed from the test runner and CodeLens links.
- ⚪ [2] This could fail to run the correct test if groups/tests have dynamic names, unusual characters or similar/duplicated names. Selecting `"line"` in the new setting will instead (when supported by your version of `package:test`) run tests using their line number:
- ⚪ [2] [#1903](https://github.com/Dart-Code/Dart-Code/issues/1903): A new setting has been added that allows excluding SDK/package symbols from the Go to Symbol in Workspace (`cmd`+`T`) search which can considerably speed up the search for large workspaces.
- ⚪ [2] [#1831](https://github.com/Dart-Code/Dart-Code/issues/1831)[#4159](https://github.com/Dart-Code/Dart-Code/issues/4159)/[#4467](https://github.com/Dart-Code/Dart-Code/issues/4467): A new setting `"dart.experimentalRefactors"` has been added to allow gathering feedback of new refactors.

**Performance Improvement** (2)

- ⚪ [1] [#1903](https://github.com/Dart-Code/Dart-Code/issues/1903): A new setting has been added that allows excluding SDK/package symbols from the Go to Symbol in Workspace (`cmd`+`T`) search which can considerably speed up the search for large workspaces.
- ⚪ [1] > I want to be able to only list the symbols from files in my workspace, to speed up the search and greatly reduce the number of irrelevant results.

**Replacement / Migration** (3)

- 🟡 [3] * [#4150](https://github.com/Dart-Code/Dart-Code/issues/4150): Tests with the same name except for an interpolated variable will all run together instead of only the selected test
- 🟡 [3] The first available refactor (for Dart 3.0 / Flutter 3.10) is “Move to File” that allows moving top level declarations to another (new or existing) file.
- 🟡 [3] * Imports added to the destination file may be to the declaration of moved references instead of the original imports being copied from the source file. This is a bug and a fix is in progress for a future release.

---

### v3-62

**Breaking Change** (2)

- ⚪ [1] * [#4417](https://github.com/Dart-Code/Dart-Code/issues/4417): Support for project templates from the legacy Stagehand Pub package has been removed. The **Dart: New Project** command is now only usable with SDKs that support `dart create`.
- ⚪ [1] * [#3936](https://github.com/Dart-Code/Dart-Code/issues/3936): Legacy colour previews shown in the gutter have been removed. These were already hidden once the server was providing inline color picker versions, but the temporary display of them was confusing so has been removed.

**Replacement / Migration** (3)

- 🔴 [5] > **#4377**: Switch to VS Code's telemetry classes `is enhancement`
  - _> https://code.visualstudio.com/updates/v1_75#_telemetry_
- 🟡 [3] * [#4447](https://github.com/Dart-Code/Dart-Code/issues/4447): Stopping a Dart CLI test session while at a breakpoint when using SDK DAPs now automatically resumes from the breakpoint instead of waiting.
- 🟡 [3] * [#4462](https://github.com/Dart-Code/Dart-Code/issues/4462): Code Actions are now available on all lines of a multiline diagnostic instead of only the first.

---

### v3-60

**New Parameter / Option** (1)

- 🔴 [5] * [#737](https://github.com/Dart-Code/Dart-Code/issues/737): A new setting `"dart.addSdkToTerminalPath"` enables automatically adding your current SDK to the `PATH` environment variable for built-in terminals. This works with quick SDK switching and ensures running `dart` or `flutter` from the terminal matches the version being used for analysis and debugging. To avoid losing terminal state, VS Code may require you to click an icon in existing terminal windows to restart them for this change to apply (this is not required for new terminals). This setting is opt-in today, but may become the default in a future release.

**Replacement / Migration** (1)

- 🟡 [3] * [#4400](https://github.com/Dart-Code/Dart-Code/issues/4400): Errors in the Variables panel no longer show “unknown” instead of the exception text when using the new SDK debug adapters.

---

### v3-58

**Breaking Change** (3)

- ⚪ [1] * [#4341](https://github.com/Dart-Code/Dart-Code/issues/4341): The test explorer no longer sometimes shows old test names that have been removed/renamed but were never run.
- ⚪ [1] > The test explorer of VSCode shows old test names that not longer exist. For example, in Dart, a test is created with the name Test 1. When this is renamed to Test 2, Test 1 and Test 2 appear in the Explorer text. Test 1 can of course no longer be executed correctly.
- ⚪ [1] > 2. Rename to Test 2

**New Feature / API** (1)

- ⚪ [2] > Equiv of https://dart-review.googlesource.com/c/sdk/+/279353. Although I'm not generally adding new features to the legacy DA, this is a trivial change and would help if people want to try out records prior to everyone being switched to the new DAs.

**New Parameter / Option** (1)

- ⚪ [2] * [#4119](https://github.com/Dart-Code/Dart-Code/issues/4119): A new setting `dart.documentation` controls how much dartdoc documentation is shown in hovers/code completions. Options are `"full"` (the default), `"summary"` (showing just the first paragraph) or `"none"` (no dartdocs are shown).

**Replacement / Migration** (2)

- 🟡 [3] * [#4268](https://github.com/Dart-Code/Dart-Code/issues/4268): The **Flutter: New Project** command now has an additional template type “Application (empty)” which creates a basic Hello World app instead of the counter app.
- 🟡 [3] > Equiv of https://dart-review.googlesource.com/c/sdk/+/279353. Although I'm not generally adding new features to the legacy DA, this is a trivial change and would help if people want to try out records prior to everyone being switched to the new DAs.

---

### v3-56

**Replacement / Migration** (2)

- 🟡 [3] > I prefer to avoid `var` whenever possible. When I use the `extract local variable` feature, it only extracts it as var:
- 🟡 [3] > I am using VSCode to debug my flutter app. This may have been doing it for a long time. I'm new to debugging. but I noticed as im steeping through the code every variable has a property called _identityHashCode and instead of a value if I hover over it it says this.

---

### v3-54

**Breaking Change** (1)

- ⚪ [1] > Even though it'd be asymmetric with adding a comment, I think it'd be nice if uncommenting removed either `//` *or* `///`.  This would be particularly useful if I'm writing a Dartdoc comment, press Enter, which automatically adds `///` to the next line, but don't actually want the next line to be a Dartdoc comment.

**New Parameter / Option** (3)

- 🟡 [4] > Flutter recently added an option to `flutter create` to create an empty project that doesn't have any comments, the code is just a hello world instead of the counter app, and there's no test directory.  The flag is `--empty`.
- ⚪ [2] > Splitting from #4271. Initially a new setting, added to the existing Flutter Create settings editor.
- ⚪ [2] * [#4119](https://github.com/Dart-Code/Dart-Code/issues/4119): A new setting `dart.documentation` allows selecting what level of documentation (`none`, `summary`, `full`) should appear in hovers and code completion. The default is `full` to match previous behaviour.

**Performance Improvement** (1)

- ⚪ [1] >   "editor.largeFileOptimizations": false,

**Replacement / Migration** (4)

- 🔴 [5] > Flutter recently added an option to `flutter create` to create an empty project that doesn't have any comments, the code is just a hello world instead of the counter app, and there's no test directory.  The flag is `--empty`.
- 🟡 [3] * [#4290](https://github.com/Dart-Code/Dart-Code/issues/4290): Running the **Pub: Upgrade Packages** command will no longer sometimes run `pub get` instead of `pub upgrade`.
- 🟡 [3] > It would be nice to add the option to the VSCode extension to allow people to create an empty project instead of one that has the counter app in it.  I'm not sure how that should manifest, it could either be an option setting that modifies the "Flutter: New Project" command, or an additional "Flutter: New Empty Project" command, I'm not sure which is more appropriate (maybe the latter?).
- 🟡 [3] > The same issue would occur if the non-imported type is an argument of the method instead of a return type.

---

### v3-52

**Performance Improvement** (1)

- ⚪ [1] > **#4213**: Improve rendering of Uint8List (and friends) in the debugger `is enhancement` `in debugging` `relies on sdk changes`
  - _> ```dart_

**Replacement / Migration** (2)

- 🟡 [3] > **#4209**: Use line/col information from source locations instead of mapping tokenPosTables `is enhancement` `in debugging`
  - _> While investigating #4208 I noticed that the responses from the VM have line/col information and we don't need to look it up from tokenPosTable (as of https://github.com/dart-lang/sdk/commit/2db8f37cfa22d5120d56c82eeddd3f3008f72ec3). Assuming the data is there, this may save us fetching a lot of scripts._
- 🟡 [3] > Also, I can't find a way to run (using VS Code's `launch.json`) normal widget tests with `flutter run test/widget_test.dart` (=running on device) instead of `flutter test test/widget_test.dart` (running in isolation). This might be another issue, though.

---

# Already Handled by dart fix

These 44 items are already covered by `dart fix` and should NOT be duplicated.

## Flutter SDK (dart fix covered)

### 3.41.0

- ~~* Remove unnecessary `deprecated` withOpacity in `text_button.0.dart‎` in examples by @AbdeMohlbi in [177374](https://github.com/flutter/flutter/pull/177374)~~
- ~~* Replace deprecated `withOpacity` in `interactive_viewer.constrained.0.dart` by @AbdeMohlbi in [177540](https://github.com/flutter/flutter/pull/177540)~~
- ~~* Replace deprecated `withOpacity` in `interactive_viewer.builder.0.dart` by @AbdeMohlbi in [177541](https://github.com/flutter/flutter/pull/177541)~~
- ~~* Replace deprecated `withOpacity` in `focus_scope.0.dart‎` example by @AbdeMohlbi in [177542](https://github.com/flutter/flutter/pull/177542)~~
- ~~* Replace deprecated withOpacity in `radio.1.dart` example by @AbdeMohlbi in [177606](https://github.com/flutter/flutter/pull/177606)~~
- ~~* Replace deprecated `withOpacity` with `withValues` in `text_style.dart` by @AbdeMohlbi in [177537](https://github.com/flutter/flutter/pull/177537)~~
- ~~* Replace deprecated withOpacity in `chip_animation_style.0.dart‎` example by @AbdeMohlbi in [177834](https://github.com/flutter/flutter/pull/177834)~~
- ~~* Replace deprecated `withOpacity` in `switch.1.dart` example by @AbdeMohlbi in [177811](https://github.com/flutter/flutter/pull/177811)~~
- ~~* Replace deprecated `withOpacity` in `data_table.1.dart‎` example by @AbdeMohlbi in [177812](https://github.com/flutter/flutter/pull/177812)~~
- ~~* Replace deprecated `withOpacity` in `overflow_bar.0.dart‎` example by @AbdeMohlbi in [177813](https://github.com/flutter/flutter/pull/177813)~~
- ~~* Replace deprecated `withOpacity` in `hero.1.dart` example by @AbdeMohlbi in [177810](https://github.com/flutter/flutter/pull/177810)~~
- ~~* Replace deprecated `withOpacity` in `cupertino_navigation_bar.0.dart‎` example by @AbdeMohlbi in [177814](https://github.com/flutter/flutter/pull/177814)~~
- ~~* Replace deprecated `withOpacity` in `search_anchor.1.dart‎` example by @AbdeMohlbi in [178215](https://github.com/flutter/flutter/pull/178215)~~
- ~~* Replace deprecated `withOpacity` in `reorderable_list_view.reorderable_list_view_builder.0.dart‎` example by @AbdeMohlbi in [178214](https://github.com/flutter/flutter/pull/178214)~~
- ~~* Remove deprecated `activeColor` in `switch.0.dart` example by @AbdeMohlbi in [178293](https://github.com/flutter/flutter/pull/178293)~~
- ~~* Remove deprecated `activeColor` in `decorated_sliver.1.dart‎` example by @AbdeMohlbi in [178959](https://github.com/flutter/flutter/pull/178959)~~
- ~~* Remove deprecated activeColor in `dynamic_content_color.0.dart`‎ example by @AbdeMohlbi in [178961](https://github.com/flutter/flutter/pull/178961)~~

---

### 3.35.0

- ~~* feat(Switch): Add activeThumbColor and deprecate activeColor. by @StanleyCocos in [166382](https://github.com/flutter/flutter/pull/166382)~~
- ~~* Deprecate: Mark AppBarTheme & AppBarThemeData color parameter as deprecated in favor of backgroundColor by @rkishan516 in [170624](https://github.com/flutter/flutter/pull/170624)~~

---

### 3.27.0

- ~~* Deprecate invalid InputDecoration.collapsed parameters by @bleroux in [152486](https://github.com/flutter/flutter/pull/152486)~~

---

### 3.22.0

- ~~* Remove deprecated MediaQuery.boldTextOverride by @goderbauer in [143960](https://github.com/flutter/flutter/pull/143960)~~

---

### 3.19.0

- ~~* Removed deprecated NavigatorState.focusScopeNode by @Piinks in [139260](https://github.com/flutter/flutter/pull/139260)~~
- ~~* Removed deprecated NavigatorState.focusScopeNode by @Piinks in [139260](https://github.com/flutter/flutter/pull/139260)~~
- ~~* Remove deprecated parameters from `ElevatedButton.styleFrom()`, `OutlinedButton.styleFrom()`, and `TextButton.styleFrom()` by @QuncCccccc in [139267](https://github.com/flutter/flutter/pull/139267)~~

---

### 3.16.0

- ~~* Remove deprecated TextSelectionOverlay.fadeDuration by @Piinks in [134485](https://github.com/flutter/flutter/pull/134485)~~

---

### 3.13.0

- ~~* Remove deprecated `primaryVariant` and `secondaryVariant` from `ColorScheme` by @QuncCccccc in [127124](https://github.com/flutter/flutter/pull/127124)~~
- ~~* Remove deprecated OverscrollIndicatorNotification.disallowGlow by @Piinks in [127050](https://github.com/flutter/flutter/pull/127050)~~
- ~~* Remove scrollbar deprecations isAlwaysShown and hoverThickness by @Piinks in [127351](https://github.com/flutter/flutter/pull/127351)~~

---

### 3.10.0

- ~~* Remove deprecated AppBar/SliverAppBar/AppBarTheme.textTheme member by @Renzo-Olivares in [119253](https://github.com/flutter/flutter/pull/119253)~~
- ~~* Deprecate MediaQuery[Data].fromWindow by @goderbauer in [119647](https://github.com/flutter/flutter/pull/119647)~~
- ~~* Remove deprecated SystemChrome.setEnabledSystemUIOverlays by @Piinks in [119576](https://github.com/flutter/flutter/pull/119576)~~
- ~~* Remove deprecated accentColorBrightness member from ThemeData by @QuncCccccc in [120577](https://github.com/flutter/flutter/pull/120577)~~
- ~~* Remove the deprecated accentColor from ThemeData by @QuncCccccc in [120932](https://github.com/flutter/flutter/pull/120932)~~

---

### 3.7.0

- ~~* Removed references to deprecated styleFrom parameters. by @darrenaustin in https://github.com/flutter/flutter/pull/108401~~
- ~~* Removed references to deprecated styleFrom parameters. by @darrenaustin in https://github.com/flutter/flutter/pull/108401~~
- ~~* Fixed some doc typos in OutlinedButton and TextButton.styleFrom deprecations by @darrenaustin in https://github.com/flutter/flutter/pull/110308~~
- ~~* Deprecate `ThemeData` `errorColor` and `backgroundColor` by @guidezpl in https://github.com/flutter/flutter/pull/110162~~
- ~~* Reset missing deprecation for ScrollbarThemeData.copyWith(showTrackOnHover) by @Piinks in https://github.com/flutter/flutter/pull/111706~~
- ~~* Remove deprecated ScrollBehavior.buildViewportChrome by @Piinks in https://github.com/flutter/flutter/pull/111715~~

---

### 3.0.0

- ~~* Deprecate Scrollbar isAlwaysShown -> thumbVisibility by @Piinks in https://github.com/flutter/flutter/pull/96957~~
- ~~* Deprecate Scrollbar hoverThickness and showTrackOnHover by @Piinks in https://github.com/flutter/flutter/pull/97173~~
- ~~* Deprecate `useDeleteButtonTooltip` for Chips by @RoyARG02 in https://github.com/flutter/flutter/pull/96174~~
- ~~* Remove deprecated Overflow and Stack.overflow by @Piinks in https://github.com/flutter/flutter/pull/98583~~
- ~~* Remove deprecated CupertinoTextField, TextField, TextFormField maxLengthEnforced by @Piinks in https://github.com/flutter/flutter/pull/98539~~

---

