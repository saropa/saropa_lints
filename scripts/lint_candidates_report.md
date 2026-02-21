# Lint Rule Candidates Report

Generated on: 2026-02-21 08:10:15
Total candidates: 1512

## Summary by Category

| Category | Count | Description |
|----------|-------|-------------|
| Deprecation | 341 | Old API deprecated — lint can detect usage and suggest replacement |
| Breaking Change | 208 | API changed/removed — lint can detect old pattern and flag it |
| New Feature / API | 47 | New capability — lint can detect verbose pattern and suggest the new API |
| New Parameter / Option | 48 | New parameter — lint can suggest using the new option for better behavior |
| Performance Improvement | 517 | Performance gain — lint can detect the slower old pattern |
| Replacement / Migration | 351 | Pattern replacement — lint can detect old pattern and suggest new one |

---

## Flutter SDK

### 3.41.0

**Deprecation** (24)

- * [Gradle 9] Resolve Gradle 9 Deprecations in flutter/flutter part 1 by @jesswrd in [176865](https://github.com/flutter/flutter/pull/176865)
  - _* Tapping outside of `SelectableRegion` should dismiss the selection by @Renzo-Olivares in [176843](https://github.com/flutter/flutter/pull/176843)_
- * [test_fixes] Enable `deprecated_member_use_from_same_package`. by @stereotype441 in [177183](https://github.com/flutter/flutter/pull/177183)
  - _* Fix Image.network not using cache when headers are specified by @rajveermalviya in [176831](https://github.com/flutter/flutter/pull/176831)_
- * Enable deprecated_member_use_from_same_package for all packages containing tests of Dart fixes defined within the package by @jason-simmons in [177341](https://github.com/flutter/flutter/pull/177341)
  - _* Fix(AnimatedScrollView): exclude outgoing items in removeAllItems by @kazbeksultanov in [176452](https://github.com/flutter/flutter/pull/176452)_
- * Remove unnecessary `deprecated` withOpacity in `text_button.0.dart‎` in examples by @AbdeMohlbi in [177374](https://github.com/flutter/flutter/pull/177374)
  - _* Add more docs to TextBaseline by @loic-sharma in [177507](https://github.com/flutter/flutter/pull/177507)_
- * Replace deprecated `withOpacity` in `interactive_viewer.constrained.0.dart` by @AbdeMohlbi in [177540](https://github.com/flutter/flutter/pull/177540)
  - _* Replace deprecated `withOpacity` in `interactive_viewer.builder.0.dart` by @AbdeMohlbi in [177541](https://github.com/flutter/flutter/pull/177541)_
- * Replace deprecated `withOpacity` in `interactive_viewer.builder.0.dart` by @AbdeMohlbi in [177541](https://github.com/flutter/flutter/pull/177541)
  - _* Replace deprecated `withOpacity` in `focus_scope.0.dart‎` example by @AbdeMohlbi in [177542](https://github.com/flutter/flutter/pull/177542)_
- * Replace deprecated `withOpacity` in `focus_scope.0.dart‎` example by @AbdeMohlbi in [177542](https://github.com/flutter/flutter/pull/177542)
  - _* Fix EditableText _justResumed is not accurate by @bleroux in [177658](https://github.com/flutter/flutter/pull/177658)_
- * Replace deprecated withOpacity in `radio.1.dart` example by @AbdeMohlbi in [177606](https://github.com/flutter/flutter/pull/177606)
  - _* Replace deprecated `withOpacity` with `withValues` in `text_style.dart` by @AbdeMohlbi in [177537](https://github.com/flutter/flutter/pull/177537)_
- * Replace deprecated `withOpacity` with `withValues` in `text_style.dart` by @AbdeMohlbi in [177537](https://github.com/flutter/flutter/pull/177537)
  - _* Add `Navigator.popUntilWithResult` by @alex-medinsh in [169341](https://github.com/flutter/flutter/pull/169341)_
- * Replace deprecated withOpacity in `chip_animation_style.0.dart‎` example by @AbdeMohlbi in [177834](https://github.com/flutter/flutter/pull/177834)
  - _* Replace deprecated `withOpacity` in `switch.1.dart` example by @AbdeMohlbi in [177811](https://github.com/flutter/flutter/pull/177811)_
- * Replace deprecated `withOpacity` in `switch.1.dart` example by @AbdeMohlbi in [177811](https://github.com/flutter/flutter/pull/177811)
  - _* Replace deprecated `withOpacity` in `data_table.1.dart‎` example by @AbdeMohlbi in [177812](https://github.com/flutter/flutter/pull/177812)_
- * Replace deprecated `withOpacity` in `data_table.1.dart‎` example by @AbdeMohlbi in [177812](https://github.com/flutter/flutter/pull/177812)
  - _* Replace deprecated `withOpacity` in `overflow_bar.0.dart‎` example by @AbdeMohlbi in [177813](https://github.com/flutter/flutter/pull/177813)_
- * Replace deprecated `withOpacity` in `overflow_bar.0.dart‎` example by @AbdeMohlbi in [177813](https://github.com/flutter/flutter/pull/177813)
  - _* Fix `ReorderableList` items jumping when drag direction reverses mid-animation by @lukemmtt in [173241](https://github.com/flutter/flutter/pull/173241)_
- * Replace deprecated `withOpacity` in `hero.1.dart` example by @AbdeMohlbi in [177810](https://github.com/flutter/flutter/pull/177810)
  - _* Replace deprecated `withOpacity` in `cupertino_navigation_bar.0.dart‎` example by @AbdeMohlbi in [177814](https://github.com/flutter/flutter/pull/177814)_
- * Replace deprecated `withOpacity` in `cupertino_navigation_bar.0.dart‎` example by @AbdeMohlbi in [177814](https://github.com/flutter/flutter/pull/177814)
  - _* Replace deprecated `withOpacity` in `search_anchor.1.dart‎` example by @AbdeMohlbi in [178215](https://github.com/flutter/flutter/pull/178215)_
- * Replace deprecated `withOpacity` in `search_anchor.1.dart‎` example by @AbdeMohlbi in [178215](https://github.com/flutter/flutter/pull/178215)
  - _* Update CupertinoSwitch thumb to snap to the sides on drag. by @ksokolovskyi in [176825](https://github.com/flutter/flutter/pull/176825)_
- * Replace deprecated `withOpacity` in `reorderable_list_view.reorderable_list_view_builder.0.dart‎` example by @AbdeMohlbi in [178214](https://github.com/flutter/flutter/pull/178214)
  - _* fix #178045: update expansible documentation for default maintainSta… by @koukibadr in [178203](https://github.com/flutter/flutter/pull/178203)_
- * Fix deprecation warning in some API examples using RadioListTile by @huycozy in [178635](https://github.com/flutter/flutter/pull/178635)
  - _* Refactor SnackBar behavior selection example to use `RadioGroup` by @AbdeMohlbi in [178618](https://github.com/flutter/flutter/pull/178618)_
- * Remove deprecated `activeColor` in `switch.0.dart` example by @AbdeMohlbi in [178293](https://github.com/flutter/flutter/pull/178293)
  - _* Roll pub manually, pick up flutter_lints in examples/api by @Piinks in [179030](https://github.com/flutter/flutter/pull/179030)_
- * Remove deprecated `activeColor` in `decorated_sliver.1.dart‎` example by @AbdeMohlbi in [178959](https://github.com/flutter/flutter/pull/178959)
  - _* Remove deprecated activeColor in `dynamic_content_color.0.dart`‎ example by @AbdeMohlbi in [178961](https://github.com/flutter/flutter/pull/178961)_
- * Remove deprecated activeColor in `dynamic_content_color.0.dart`‎ example by @AbdeMohlbi in [178961](https://github.com/flutter/flutter/pull/178961)
  - _* Make sure that a CupertinoActivityIndicator doesn't crash in 0x0 envi… by @ahmedsameha1 in [178565](https://github.com/flutter/flutter/pull/178565)_
- * New isSemantics and deprecate containsSemantics by @zemanux in [180538](https://github.com/flutter/flutter/pull/180538)
  - _* Fix Drawer.child docstring to say ListView instead of SliverList by @nathannewyen in [180326](https://github.com/flutter/flutter/pull/180326)_
- * [web] Deprecate --pwa-strategy by @mdebbar in [177613](https://github.com/flutter/flutter/pull/177613)
  - _* [web] Move webparagraph tests to their right location by @mdebbar in [177739](https://github.com/flutter/flutter/pull/177739)_
- * Suppress deprecation warning for AChoreographer_postFrameCallback by @777genius in [178580](https://github.com/flutter/flutter/pull/178580)
  - _* Bump dessant/lock-threads from 5.0.1 to 6.0.0 in the all-github-actions group by @dependabot[bot] in [179901](https://github.com/flutter/flutter/pull/179901)_

**Breaking Change** (2)

- * Preserve whitelisted files when removed from build system outputs by @vashworth in [178396](https://github.com/flutter/flutter/pull/178396)
  - _* [tool] clean up https cert configuration handling by @kevmoo in [178139](https://github.com/flutter/flutter/pull/178139)_
- * Added type annotations and removed lints for run_tests.py by @gaaclarke in [180597](https://github.com/flutter/flutter/pull/180597)
  - _* [web] [triage] Exclude PRs that have been approved/triaged by @mdebbar in [180644](https://github.com/flutter/flutter/pull/180644)_

**New Feature / API** (1)

- * [ios] [pv] accept/reject gesture based on hitTest (with new widget API) by @hellohuanlin in [179659](https://github.com/flutter/flutter/pull/179659)
  - _* Fix draggable scrollable sheet example drag speed is off by @huycozy in [179179](https://github.com/flutter/flutter/pull/179179)_

**Performance Improvement** (25)

- * [a11y] fix table semantics cache for cells by @hannah-hyj in [177073](https://github.com/flutter/flutter/pull/177073)
  - _* [test_fixes] Enable `deprecated_member_use_from_same_package`. by @stereotype441 in [177183](https://github.com/flutter/flutter/pull/177183)_
- * Fix Image.network not using cache when headers are specified by @rajveermalviya in [176831](https://github.com/flutter/flutter/pull/176831)
  - _* Update `image.error_builder.0.dart` to replace the emoji with some text by @AbdeMohlbi in [176886](https://github.com/flutter/flutter/pull/176886)_
- * [Impeller] Add the paint color to the key of the text shadow cache by @jason-simmons in [177140](https://github.com/flutter/flutter/pull/177140)
  - _* Delete stray 'text' file by @harryterkelsen in [177355](https://github.com/flutter/flutter/pull/177355)_
- * Adds cache extent type to two_dimentional_viewport by @chunhtai in [177411](https://github.com/flutter/flutter/pull/177411)
  - _* Clean up links to docs website by @guidezpl in [177792](https://github.com/flutter/flutter/pull/177792)_
- * Colored box optimization (#176028) by @definev in [176073](https://github.com/flutter/flutter/pull/176073)
  - _* Add blockAccessibilityFocus flag by @hannah-hyj in [175551](https://github.com/flutter/flutter/pull/175551)_
- * Make a11y `computeChildGeometry` slightly faster by @LongCatIsLooong in [177477](https://github.com/flutter/flutter/pull/177477)
  - _* Fix deprecation warning in some API examples using RadioListTile by @huycozy in [178635](https://github.com/flutter/flutter/pull/178635)_
- * MatrixUtils.forceToPoint - simplify and optimize by @kevmoo in [179546](https://github.com/flutter/flutter/pull/179546)
  - _* Remove unused optional argument in _followDiagnosticableChain by @harryterkelsen in [179525](https://github.com/flutter/flutter/pull/179525)_
- * Improve Container color/decoration error message clarity by @777genius in [178823](https://github.com/flutter/flutter/pull/178823)
  - _* Make sure that a DecoratedBox doesn't crash in 0x0 environment by @ahmedsameha1 in [180329](https://github.com/flutter/flutter/pull/180329)_
- * Improve documentation about ValueNotifier's behavior by @AbdeMohlbi in [179870](https://github.com/flutter/flutter/pull/179870)
  - _* Add tooltip support to PlatformMenuItem and PlatformMenu. by @ksokolovskyi in [180069](https://github.com/flutter/flutter/pull/180069)_
- * Improve menu item accessibility semantics by @flutter-zl in [176255](https://github.com/flutter/flutter/pull/176255)
  - _* Make sure that a MenuBar doesn't crash in 0x0 environment by @ahmedsameha1 in [176368](https://github.com/flutter/flutter/pull/176368)_
- * Improve assertion messages in Tab widget for better clarity by @JeelChandegra in [178295](https://github.com/flutter/flutter/pull/178295)
  - _* Improve the documentation of `Card` by @dkwingsmt in [178834](https://github.com/flutter/flutter/pull/178834)_
- * Improve the documentation of `Card` by @dkwingsmt in [178834](https://github.com/flutter/flutter/pull/178834)
  - _* Add Slider.showValueIndicator property. by @ksokolovskyi in [179661](https://github.com/flutter/flutter/pull/179661)_
- * Fix Xcode cache errors by @okorohelijah in [175659](https://github.com/flutter/flutter/pull/175659)
  - _* iOS can set application locale before view controller is set by @chunhtai in [176592](https://github.com/flutter/flutter/pull/176592)_
- * Add guided error for precompiled cache error by @vashworth in [177327](https://github.com/flutter/flutter/pull/177327)
  - _* [ Tool ] Add `Stream.transformWithCallSite` to provide more useful stack traces by @bkonyi in [177470](https://github.com/flutter/flutter/pull/177470)_
- * Improve code quality `FlutterViewTest.java` by @AbdeMohlbi in [178594](https://github.com/flutter/flutter/pull/178594)
  - _* Remove unnecessary `final` modifier in `StandardMessageCodec.java‎` by @AbdeMohlbi in [178598](https://github.com/flutter/flutter/pull/178598)_
- * Improve code quality in `FlutterActivityTest.java` by @AbdeMohlbi in [180585](https://github.com/flutter/flutter/pull/180585)
  - _* Fix resonant explosion of scroll disconnect when scrolling a pv in a list by @gmackall in [180246](https://github.com/flutter/flutter/pull/180246)_
- * Improve code quality in `KeyboardManagerTest.java` by @AbdeMohlbi in [180625](https://github.com/flutter/flutter/pull/180625)
  - _* Prevent calling `setStatusBarColor` on `API_35` and update related documentation by @AbdeMohlbi in [180062](https://github.com/flutter/flutter/pull/180062)_
- * Improve code quality in `AndroidTouchProcessorTest.java` by @AbdeMohlbi in [180583](https://github.com/flutter/flutter/pull/180583)
- * Replace use of eglCreateImage with eglCreateImageKHR to reduce EGL requirement by @robert-ancell in [179310](https://github.com/flutter/flutter/pull/179310)
  - _* Implement flutter/accessibility channel by @robert-ancell in [179484](https://github.com/flutter/flutter/pull/179484)_
- * add gn flag to optimize builds for size by @planetmarshall in [176835](https://github.com/flutter/flutter/pull/176835)
  - _* Bump actions/upload-artifact from 4 to 5 in the all-github-actions group by @dependabot[bot] in [177620](https://github.com/flutter/flutter/pull/177620)_
- * Improve Impeller's docs in the top-level docs folder by @loic-sharma in [177848](https://github.com/flutter/flutter/pull/177848)
  - _* [skia] Explicitly disable XPS backend by @kjlubick in [177050](https://github.com/flutter/flutter/pull/177050)_
- * [web] Reduce Skwasm test shards to 2 by @mdebbar in [178239](https://github.com/flutter/flutter/pull/178239)
  - _* Reduce the data copying in CanvasPath related to the SkPathBuilder API migration by @jason-simmons in [178512](https://github.com/flutter/flutter/pull/178512)_
- * Reduce the data copying in CanvasPath related to the SkPathBuilder API migration by @jason-simmons in [178512](https://github.com/flutter/flutter/pull/178512)
  - _* Roll customer tests by @Piinks in [178652](https://github.com/flutter/flutter/pull/178652)_
- * Check for a null cached image in SingleFrameCodec::getNextFrame by @jason-simmons in [179483](https://github.com/flutter/flutter/pull/179483)
  - _* Use kPreventOverdraw for arcs with overlapping stroke caps by @b-luk in [179312](https://github.com/flutter/flutter/pull/179312)_
- * New optimized general convex path shadow algorithm by @flar in [178370](https://github.com/flutter/flutter/pull/178370)
  - _* Test cross import lint by @justinmc in [178693](https://github.com/flutter/flutter/pull/178693)_

**Replacement / Migration** (4)

- * Use WidgetsBinding.instance.platformDispatcher in windowing instead of PlatformDispatcher.instance by @mattkae in [178799](https://github.com/flutter/flutter/pull/178799)
  - _* Make sure that a CupertinoSpellCheckSuggestionsToolbar doesn't crash … by @ahmedsameha1 in [177978](https://github.com/flutter/flutter/pull/177978)_
- * [Material] Change default mouse cursor of buttons to basic arrow instead of click (except on web) by @camsim99 in [171796](https://github.com/flutter/flutter/pull/171796)
  - _* Fix drawer Semantics for mismatched platforms by @huycozy in [177095](https://github.com/flutter/flutter/pull/177095)_
- * Fix Drawer.child docstring to say ListView instead of SliverList by @nathannewyen in [180326](https://github.com/flutter/flutter/pull/180326)
  - _* Raw tooltip with smaller API surface that exposes tooltip widget by @victorsanni in [177678](https://github.com/flutter/flutter/pull/177678)_
- * [Windows] Allow apps to prefer high power GPUs by @9AZX in [177653](https://github.com/flutter/flutter/pull/177653)
  - _* Ensure that the engine converts std::filesystem::path objects to UTF-8 strings on Windows by @jason-simmons in [179528](https://github.com/flutter/flutter/pull/179528)_

---

### 3.38.0

**Deprecation** (16)

- * Add missing deprecations to CupertinoDynamicColor. by @ksokolovskyi in [171160](https://github.com/flutter/flutter/pull/171160)
  - _* Improve assertion message in `_MixedBorderRadius.resolve()` by @SalehTZ in [172100](https://github.com/flutter/flutter/pull/172100)_
- * Remove deprecated `AssetManifest.json` file by @matanlurey in [172594](https://github.com/flutter/flutter/pull/172594)
  - _* fix(scrollbar): Update padding type to EdgeInsetsGeometry by @SalehTZ in [172056](https://github.com/flutter/flutter/pull/172056)_
- * Suppress deprecated iOS windows API in integration_test by @jmagman in [173251](https://github.com/flutter/flutter/pull/173251)
  - _* [ Widget Preview ] Cleanup for experimental release by @bkonyi in [173289](https://github.com/flutter/flutter/pull/173289)_
- * NavigatorPopScope examples no longer use deprecated onPop. by @justinmc in [174291](https://github.com/flutter/flutter/pull/174291)
  - _* [web] Refactor LayerScene out of CanvasKit by @harryterkelsen in [174375](https://github.com/flutter/flutter/pull/174375)_
- * Fix docs referencing deprecated radio properties by @victorsanni in [176244](https://github.com/flutter/flutter/pull/176244)
  - _* Migrate to `WidgetStateOutlinedBorder` by @ValentinVignal in [176270](https://github.com/flutter/flutter/pull/176270)_
- * Adds deprecation for impeller opt out on android by @gaaclarke in [173375](https://github.com/flutter/flutter/pull/173375)
  - _* Blocks exynos9820 chip from vulkan by @gaaclarke in [173807](https://github.com/flutter/flutter/pull/173807)_
- * Update `build.gradle` to remove deprecation warning in `flutter\engine\src\flutter\shell\platform\android` by @AbdeMohlbi in [175305](https://github.com/flutter/flutter/pull/175305)
  - _* Remove redundant public modifier in `PlatformViewRenderTarget.java` by @AbdeMohlbi in [175284](https://github.com/flutter/flutter/pull/175284)_
- * Fix deprecated configureStatusBarForFullscreenFlutterExperience for Android 15+ by @alexskobozev in [175501](https://github.com/flutter/flutter/pull/175501)
  - _* [CP-beta][Android] Refactor `ImageReaderSurfaceProducer` restoration after app resumes by @camsim99 in [177121](https://github.com/flutter/flutter/pull/177121)_
- * [web] Cleanup usages of deprecated `routeUpdated` message by @mdebbar in [173782](https://github.com/flutter/flutter/pull/173782)
  - _* [web] Fix error in ClickDebouncer when using VoiceOver by @mdebbar in [174046](https://github.com/flutter/flutter/pull/174046)_
- * Remove 2023 deprecated `'platforms'` key from daemon output by @matanlurey in [172593](https://github.com/flutter/flutter/pull/172593)
  - _* Migrate to null aware elements - Part 3 by @jamilsaadeh97 in [172307](https://github.com/flutter/flutter/pull/172307)_
- * Add `--dart-define`, `-D` to `assemble`, deprecate `--define`, `-d`. by @matanlurey in [172510](https://github.com/flutter/flutter/pull/172510)
  - _* Rename `AppRunLogger`, stop writing status messages that break JSON by @matanlurey in [172591](https://github.com/flutter/flutter/pull/172591)_
- * Remove deprecated `--[no-]-disable-dds` by @matanlurey in [172791](https://github.com/flutter/flutter/pull/172791)
  - _* Update `main`/`master` repoExceptions analysis set by @matanlurey in [172796](https://github.com/flutter/flutter/pull/172796)_
- * Revert "Remove 2023 deprecated `'platforms'` key from daemon output (#172593)" by @chingjun in [172883](https://github.com/flutter/flutter/pull/172883)
  - _* Made `android_gradle_print_build_variants_test.dart` more robust by @gaaclarke in [172910](https://github.com/flutter/flutter/pull/172910)_
- * [ Tool ] Remove leftover Android x86 deprecation warning constant by @bkonyi in [174941](https://github.com/flutter/flutter/pull/174941)
  - _* Make every LLDB Init error message actionable by @vashworth in [174726](https://github.com/flutter/flutter/pull/174726)_
- * Deprecate Objective-C plugin template by @okorohelijah in [174003](https://github.com/flutter/flutter/pull/174003)
  - _* [native_assets] Find more `CCompilerConfig` on Linux by @GregoryConrad in [175323](https://github.com/flutter/flutter/pull/175323)_
- * Stop using deprecated analyzer 7.x.y APIs. by @scheglov in [176242](https://github.com/flutter/flutter/pull/176242)
  - _* [native assets] Roll dependencies by @dcharkes in [176287](https://github.com/flutter/flutter/pull/176287)_

**Breaking Change** (1)

- * [Gradle 9] Removed `minSdkVersion` and only use `minSdk` by @jesswrd in [173892](https://github.com/flutter/flutter/pull/173892)
  - _* Fix GitHub labeler platform-android typo by @jmagman in [175076](https://github.com/flutter/flutter/pull/175076)_

**New Feature / API** (1)

- * Introduce a getter for `Project` to get `gradle-wrapper.properties` directly by @AbdeMohlbi in [175485](https://github.com/flutter/flutter/pull/175485)
  - _* [ Widget Preview ] Fix filter by file on Windows by @bkonyi in [175783](https://github.com/flutter/flutter/pull/175783)_

**Performance Improvement** (21)

- * Improve assertion message in `AlignmentDirectional.resolve` by @SalehTZ in [172096](https://github.com/flutter/flutter/pull/172096)
  - _* Fix: Ensure Text widget locale is included in semantics language tag by @pedromassango in [172034](https://github.com/flutter/flutter/pull/172034)_
- * Improve assertion message in `_MixedBorderRadius.resolve()` by @SalehTZ in [172100](https://github.com/flutter/flutter/pull/172100)
  - _* Remove deprecated `AssetManifest.json` file by @matanlurey in [172594](https://github.com/flutter/flutter/pull/172594)_
- * Improve assertion message in `EdgeInsetsDirectional.resolve` by @SalehTZ in [172099](https://github.com/flutter/flutter/pull/172099)
  - _* Fix the issue where calling showOnScreen on a sliver after a pinned child in SliverMainAxisGroup does not reveal it. by @yiiim in [171339](https://github.com/flutter/flutter/pull/171339)_
- * Improve `SweepGradient` angle and `TileMode` documentation by @SalehTZ in [172406](https://github.com/flutter/flutter/pull/172406)
  - _* Reapply "Add set semantics enabled API and wire iOS a11y bridge (#161… by @chunhtai in [171198](https://github.com/flutter/flutter/pull/171198)_
- * Improve Stack widget error message for bounded constraints by @Rushikeshbhavsar20 in [173352](https://github.com/flutter/flutter/pull/173352)
  - _* Update CupertinoSliverNavigationBar.middle by @victorsanni in [173868](https://github.com/flutter/flutter/pull/173868)_
- * Fix Menu anchor reduce padding on web and desktop by @huycozy in [172691](https://github.com/flutter/flutter/pull/172691)
  - _* Make component theme data defaults use `WidgetStateProperty` by @ValentinVignal in [173893](https://github.com/flutter/flutter/pull/173893)_
- * Improve xcresult comment and naming by @okorohelijah in [173129](https://github.com/flutter/flutter/pull/173129)
  - _* Stream logs from `devicectl` and `lldb` by @vashworth in [173724](https://github.com/flutter/flutter/pull/173724)_
- * [CP-beta]Add guided error for precompiled cache error by @flutteractionsbot in [177607](https://github.com/flutter/flutter/pull/177607)
- * Improve code quality in `AccessibilityBridgeTest.java` by @AbdeMohlbi in [175718](https://github.com/flutter/flutter/pull/175718)
  - _* Fix linter issues in `VsyncWaiterTest` Capital L for long values by @AbdeMohlbi in [175780](https://github.com/flutter/flutter/pull/175780)_
- * Improve code quality in `SensitiveContentPluginTest.java` by @AbdeMohlbi in [175721](https://github.com/flutter/flutter/pull/175721)
  - _* Add warn java evaluation to android_workflow by @reidbaker in [176097](https://github.com/flutter/flutter/pull/176097)_
- * Improve robustness of comment detection when using flutter analyze --suggestions by @reidbaker in [172977](https://github.com/flutter/flutter/pull/172977)
  - _* In "flutter create", use the project directory in the suggested "cd" command instead of the main source file path by @jason-simmons in [173132](https://github.com/flutter/flutter/pull/173132)_
- * [ Widget Preview ] Improve `--machine` output by @bkonyi in [175003](https://github.com/flutter/flutter/pull/175003)
  - _* Fix crash when attaching to a device with multiple active flutter apps by @chingjun in [175147](https://github.com/flutter/flutter/pull/175147)_
- * [ Widget Preview ] Improve IDE integration support by @bkonyi in [176114](https://github.com/flutter/flutter/pull/176114)
  - _* Add tests for `Project` getters by @AbdeMohlbi in [175994](https://github.com/flutter/flutter/pull/175994)_
- * [Impeller] Improvements to the Vulkan pipeline cache data writer by @jason-simmons in [173014](https://github.com/flutter/flutter/pull/173014)
  - _* [Impeller] Terminate the fence waiter but do not reset it during ContextVK shutdown by @jason-simmons in [173085](https://github.com/flutter/flutter/pull/173085)_
- * Add a gn --ccache argument by @robert-ancell in [174621](https://github.com/flutter/flutter/pull/174621)
  - _* Merge the engine README into the README of the old buildroot. by @chinmaygarde in [175384](https://github.com/flutter/flutter/pull/175384)_
- * [Impeller] Disable the render target cache when creating a snapshot in DlImageImpeller::MakeFromYUVTextures by @jason-simmons in [174912](https://github.com/flutter/flutter/pull/174912)
  - _* [docs] Add initial version of Flutter AI rules by @johnpryan in [175011](https://github.com/flutter/flutter/pull/175011)_
- * [Impeller] Optimize scale translate rectangle transforms by @flar in [171841](https://github.com/flutter/flutter/pull/171841)
  - _* Revert "[Impeller] Optimize scale translate rectangle transforms" by @flar in [176061](https://github.com/flutter/flutter/pull/176061)_
- * Revert "[Impeller] Optimize scale translate rectangle transforms" by @flar in [176061](https://github.com/flutter/flutter/pull/176061)
  - _* Fix link to .gclient setup instructions by @gmackall in [176046](https://github.com/flutter/flutter/pull/176046)_
- * [Impeller] Optimize scale translate rectangle transforms by @flar in [176123](https://github.com/flutter/flutter/pull/176123)
  - _* Revert "[Impeller] Optimize scale translate rectangle transforms" by @flar in [176161](https://github.com/flutter/flutter/pull/176161)_
- * Revert "[Impeller] Optimize scale translate rectangle transforms" by @flar in [176161](https://github.com/flutter/flutter/pull/176161)
  - _* Fix name of driver file by @robert-ancell in [176186](https://github.com/flutter/flutter/pull/176186)_
- * Reduce timeout for Linux web_tool_tests back to 60 by @mdebbar in [176286](https://github.com/flutter/flutter/pull/176286)
  - _* Add verbose logs to module_uiscene_test_ios by @vashworth in [176306](https://github.com/flutter/flutter/pull/176306)_

**Replacement / Migration** (10)

- * [Range slider] Tap on active range, the thumb closest to the mouse cursor should move to the cursor position. by @hannah-hyj in [173725](https://github.com/flutter/flutter/pull/173725)
  - _* Add error handling for `Element` lifecycle user callbacks by @LongCatIsLooong in [173148](https://github.com/flutter/flutter/pull/173148)_
- * Using a shared message-only HWND for clip board data on win32 instead of the implicit view by @mattkae in [173076](https://github.com/flutter/flutter/pull/173076)
  - _* Provide monitor list, display size, refresh rate, and more for Windows by @9AZX in [164460](https://github.com/flutter/flutter/pull/164460)_
- * Update `flutter pub get` to use `flutter.version.json` (instead of `version`) by @matanlurey in [172798](https://github.com/flutter/flutter/pull/172798)
  - _* Add `--config-only` build option for Linux and Windows by @stuartmorgan-g in [172239](https://github.com/flutter/flutter/pull/172239)_
- * In "flutter create", use the project directory in the suggested "cd" command instead of the main source file path by @jason-simmons in [173132](https://github.com/flutter/flutter/pull/173132)
  - _* [android][tool] Consolidate minimum versions for android projects. by @reidbaker in [171965](https://github.com/flutter/flutter/pull/171965)_
- * Update gradle_utils.dart to use `constant` instead of `final` by @AbdeMohlbi in [175443](https://github.com/flutter/flutter/pull/175443)
  - _* Update gradle_errors.dart to use constants defined in gradle_utils.dart by @AbdeMohlbi in [174760](https://github.com/flutter/flutter/pull/174760)_
- * fix typo in comments to mention `settings.gradle/.kts` instead of `build.gradle/.kts` by @AbdeMohlbi in [175486](https://github.com/flutter/flutter/pull/175486)
  - _* [ Tool ] Serve DevTools from DDS, remove ResidentDevToolsHandler by @bkonyi in [174580](https://github.com/flutter/flutter/pull/174580)_
- * `last_engine_commit.ps1`: Use `$flutterRoot` instead of `$gitTopLevel` by @matanlurey in [172786](https://github.com/flutter/flutter/pull/172786)
  - _* fix: get content hash for master on local engine branches by @jtmcdole in [172792](https://github.com/flutter/flutter/pull/172792)_
- * licenses_cpp: Switched to lexically_relative for 2x speed boost. by @gaaclarke in [173048](https://github.com/flutter/flutter/pull/173048)
  - _* [macOS] Remove duplicate object initialization by @bufffun in [171767](https://github.com/flutter/flutter/pull/171767)_
- * Read `bin/cache/flutter.version.json` instead of `version` for `flutter_gallery` by @matanlurey in [173797](https://github.com/flutter/flutter/pull/173797)
  - _* Remove `luci_flags.parallel_download_builds` and friends by @matanlurey in [173799](https://github.com/flutter/flutter/pull/173799)_
- * User Invoke-Expression instead of call operator for nested Powershell scripts invocations (on Windows) by @aam in [175941](https://github.com/flutter/flutter/pull/175941)
  - _* fix typo in `Crashes.md` by @AbdeMohlbi in [175959](https://github.com/flutter/flutter/pull/175959)_

---

### 3.35.0

**Deprecation** (15)

- * [web] drop more use of deprecated JS functions by @kevmoo in [166157](https://github.com/flutter/flutter/pull/166157)
  - _* Roll pub packages by @flutter-pub-roller-bot in [168509](https://github.com/flutter/flutter/pull/168509)_
- * Remove deprecated todo about caching by @ValentinVignal in [168534](https://github.com/flutter/flutter/pull/168534)
  - _* Make Cupertino sheet set the systemUIStyle through an AnnotatedRegion by @MitchellGoodwin in [168182](https://github.com/flutter/flutter/pull/168182)_
- * Clarify deprecation notice for jumpToWithoutSettling in scroll_position.dart by @dogaozyagci in [167200](https://github.com/flutter/flutter/pull/167200)
  - _* [skwasm] Add the capability of dumping live object counts in debug mode. by @eyebrowsoffire in [168389](https://github.com/flutter/flutter/pull/168389)_
- * Clean up references to deprecated onPop method in docs by @justinmc in [169700](https://github.com/flutter/flutter/pull/169700)
  - _* IOSSystemContextMenuItem.toString to Diagnosticable by @justinmc in [169705](https://github.com/flutter/flutter/pull/169705)_
- * Update Docs to Warn Users Edge-To-Edge opt out is being deprecated for Android 16+ (API 36+) by @jesswrd in [170816](https://github.com/flutter/flutter/pull/170816)
  - _* Enhance Text Contrast for WCAG AAA Compliance by @azatech in [170758](https://github.com/flutter/flutter/pull/170758)_
- * feat(Switch): Add activeThumbColor and deprecate activeColor. by @StanleyCocos in [166382](https://github.com/flutter/flutter/pull/166382)
  - _* Fix: Delay showing tooltip during page transition by @rkishan516 in [167614](https://github.com/flutter/flutter/pull/167614)_
- * docs: Update deprecation message for Slider.year2023 by @huycozy in [169053](https://github.com/flutter/flutter/pull/169053)
  - _* Update the `RangeSlider` widget to the 2024 Material Design appearance by @TahaTesser in [163736](https://github.com/flutter/flutter/pull/163736)_
- * Update deprecated vector_math calls by @kevmoo in [169477](https://github.com/flutter/flutter/pull/169477)
  - _* Fixes inputDecoration sibling explicit child not included in semantic… by @chunhtai in [170079](https://github.com/flutter/flutter/pull/170079)_
- * Deprecate DropdownButtonFormField "value" parameter in favor of "initialValue" by @bleroux in [170805](https://github.com/flutter/flutter/pull/170805)
  - _* When maintainHintSize is false, hint is centered and aligned, it is different from the original one by @zeqinjie in [168654](https://github.com/flutter/flutter/pull/168654)_
- * Deprecate: Mark AppBarTheme & AppBarThemeData color parameter as deprecated in favor of backgroundColor by @rkishan516 in [170624](https://github.com/flutter/flutter/pull/170624)
  - _* Add `backgroundColor` to `RadioThemeData` by @ValentinVignal in [171326](https://github.com/flutter/flutter/pull/171326)_
- * Deprecated methods that call setStatusBarColor, setNavigationBarColor, setNavigationBarDividerColor by @narekmalk in [165737](https://github.com/flutter/flutter/pull/165737)
  - _* [Android 16] Bumped Android Defaults in Framework by @jesswrd in [166464](https://github.com/flutter/flutter/pull/166464)_
- * [tool] Fix deprecated API calls within tool by @kevmoo in [168200](https://github.com/flutter/flutter/pull/168200)
  - _* Replace hardcoded host and app level build.gradle paths with `AndroidProject`-level getters in `gradle_errors.dart` by @AbdeMohlbi in [167949](https://github.com/flutter/flutter/pull/167949)_
- * [ Widget Previews ] Remove deprecated desktop support by @bkonyi in [169703](https://github.com/flutter/flutter/pull/169703)
  - _* Symlink SwiftPM plugins in the same directory by @vashworth in [168932](https://github.com/flutter/flutter/pull/168932)_
- * Remove deprecated Objective-C iOS app create template by @jmagman in [169547](https://github.com/flutter/flutter/pull/169547)
  - _* [native assets] Roll dependencies by @dcharkes in [169920](https://github.com/flutter/flutter/pull/169920)_
- * [ Tool ] Remove long-deprecated `make-host-app-editable` by @bkonyi in [171715](https://github.com/flutter/flutter/pull/171715)
  - _* feat: Use engine_stamp.json in flutter tool by @jtmcdole in [171454](https://github.com/flutter/flutter/pull/171454)_

**Breaking Change** (7)

- * rename from announce to supportsAnnounce on engine by @ash2moon in [170618](https://github.com/flutter/flutter/pull/170618)
  - _* Update FormField.initialValue documentation by @bleroux in [171061](https://github.com/flutter/flutter/pull/171061)_
- * Removed string keys by @Phantom-101 in [171293](https://github.com/flutter/flutter/pull/171293)
  - _* Fix InputDecorationThemeData.activeIndicatorBorder is not applied by @bleroux in [171764](https://github.com/flutter/flutter/pull/171764)_
- * Removed the FlutterViewController.pluginRegistrant by @gaaclarke in [169995](https://github.com/flutter/flutter/pull/169995)
  - _* Export FlutterSceneDelegate by @gaaclarke in [170169](https://github.com/flutter/flutter/pull/170169)_
- * Removed superfluous copy in license checker by @gaaclarke in [167146](https://github.com/flutter/flutter/pull/167146)
  - _* Roll Dartdoc to 8.3.3 by @jason-simmons in [167231](https://github.com/flutter/flutter/pull/167231)_
- * Revert "Removed superfluous copy in license checker (#167146)" by @jason-simmons in [167246](https://github.com/flutter/flutter/pull/167246)
  - _* Updated docstrings for TextureContents by @gaaclarke in [167221](https://github.com/flutter/flutter/pull/167221)_
- * Removed repeated entry in `CHANGELOG.md` by @ferraridamiano in [165273](https://github.com/flutter/flutter/pull/165273)
  - _* Roll Dart SDK from 7c40eba6bf77 to 56940edd099d by @jason-simmons in [169135](https://github.com/flutter/flutter/pull/169135)_
- * [skia] Update usage of removed gn flag by @kjlubick in [171800](https://github.com/flutter/flutter/pull/171800)
  - _* Revert "Mark web_long_running_tests_2_5 as bringup" by @mdebbar in [171872](https://github.com/flutter/flutter/pull/171872)_

**Performance Improvement** (19)

- * [ Widget Preview ] Improve widget inspector support for widget previews by @bkonyi in [168013](https://github.com/flutter/flutter/pull/168013)
  - _* Fix the incorrect position of SliverTree child nodes. by @yiiim in [167928](https://github.com/flutter/flutter/pull/167928)_
- * Improve documentation for KeyedSubtree constructor by @dogaozyagci in [167198](https://github.com/flutter/flutter/pull/167198)
  - _* Remove deprecated todo about caching by @ValentinVignal in [168534](https://github.com/flutter/flutter/pull/168534)_
- * Reduce app startup latency by initializing the engine on a separate thread by @jason-simmons in [166918](https://github.com/flutter/flutter/pull/166918)
  - _* Revert "Reduce app startup latency by initializing the engine on a separate thread (#166918)" by @jason-simmons in [167427](https://github.com/flutter/flutter/pull/167427)_
- * Revert "Reduce app startup latency by initializing the engine on a separate thread (#166918)" by @jason-simmons in [167427](https://github.com/flutter/flutter/pull/167427)
  - _* Reland "Reduce app startup latency by initializing the engine on a separate thread (#166918)" by @jason-simmons in [167519](https://github.com/flutter/flutter/pull/167519)_
- * Reland "Reduce app startup latency by initializing the engine on a separate thread (#166918)" by @jason-simmons in [167519](https://github.com/flutter/flutter/pull/167519)
  - _* [a11y] Semanctis flag refactor step 1: engine part by @hannah-hyj in [167421](https://github.com/flutter/flutter/pull/167421)_
- * [Impeller] Speed up vulkan startup time by re-using existing vulkan context. by @jonahwilliams in [166784](https://github.com/flutter/flutter/pull/166784)
  - _* Reverts "[Impeller] Speed up vulkan startup time by re-using existing vulkan context. (#166784)" by @auto-submit[bot] in [166938](https://github.com/flutter/flutter/pull/166938)_
- * Reverts "[Impeller] Speed up vulkan startup time by re-using existing vulkan context. (#166784)" by @auto-submit[bot] in [166938](https://github.com/flutter/flutter/pull/166938)
  - _* [Impeller] defer vulkan context initialization as long as possible. by @jonahwilliams in [166941](https://github.com/flutter/flutter/pull/166941)_
- * [web] Pass the same optimization level to both stages of JS compiler by @kevmoo in [169642](https://github.com/flutter/flutter/pull/169642)
  - _* Fix the "Missing ExternalProject for :" error by @rekire in [168403](https://github.com/flutter/flutter/pull/168403)_
- * Combine expression evaluation tests to reduce testing time by @mdebbar in [169860](https://github.com/flutter/flutter/pull/169860)
  - _* Roll pub packages by @flutter-pub-roller-bot in [170066](https://github.com/flutter/flutter/pull/170066)_
- * [Impeller] Make incremental builds faster when tinkering on the compiler. by @chinmaygarde in [167492](https://github.com/flutter/flutter/pull/167492)
  - _* Fix a race in ShellTest.EncodeImageFailsWithoutGPUImpeller by @jason-simmons in [167669](https://github.com/flutter/flutter/pull/167669)_
- * Improve log output of keyboard_hot_restart_ios by @loic-sharma in [167834](https://github.com/flutter/flutter/pull/167834)
  - _* macOS: remove unused mac_sdk_min by @cbracken in [167907](https://github.com/flutter/flutter/pull/167907)_
- * Reduces the compile size of Pipelines and ContentContext by @gaaclarke in [167671](https://github.com/flutter/flutter/pull/167671)
  - _* Roll ICU to c9fb4b3a6fb5 by @jason-simmons in [167691](https://github.com/flutter/flutter/pull/167691)_
- * Revert "[Impeller] Make incremental builds faster when tinkering on the compiler." by @chinmaygarde in [167965](https://github.com/flutter/flutter/pull/167965)
  - _* Roll Skia to 25bba45c7b25 by @jason-simmons in [168012](https://github.com/flutter/flutter/pull/168012)_
- * [Windows] Improve et's error if gclient has never been run by @loic-sharma in [167956](https://github.com/flutter/flutter/pull/167956)
  - _* A few more updates to Google-Testing. by @matanlurey in [168000](https://github.com/flutter/flutter/pull/168000)_
- * [Impeller] libImpeller: Usability improvements for WASM and python bindings. by @chinmaygarde in [168397](https://github.com/flutter/flutter/pull/168397)
  - _* add missing lockfiles not checked in from running generate_gradle_lockfiles.dart by @ash2moon in [168600](https://github.com/flutter/flutter/pull/168600)_
- * dev/bots: improve service worker test code by @kevmoo in [169231](https://github.com/flutter/flutter/pull/169231)
  - _* Update DEPS to add dart-lang/ai repo by @jakemac53 in [169540](https://github.com/flutter/flutter/pull/169540)_
- * Reduce some CI timeouts by @mdebbar in [169512](https://github.com/flutter/flutter/pull/169512)
  - _* Update triage for new team-devexp by @stuartmorgan-g in [169668](https://github.com/flutter/flutter/pull/169668)_
- * [Impeller] let drawImage nine use porter duff optimization. by @jonahwilliams in [169611](https://github.com/flutter/flutter/pull/169611)
  - _* Mark `Linux web_tool_tests` as `bringup` due to being 10%+ flaky by @matanlurey in [169716](https://github.com/flutter/flutter/pull/169716)_
- * Reland workflow cache by @zanderso in [170111](https://github.com/flutter/flutter/pull/170111)
  - _* [Impeller] Fix vertex allocation counts for flat curves by @flar in [170194](https://github.com/flutter/flutter/pull/170194)_

**Replacement / Migration** (12)

- * [Impeller] Use device property uniform aligment instead of conservative value of 256. by @jonahwilliams in [166884](https://github.com/flutter/flutter/pull/166884)
  - _* Reland "SliverEnsureSemantics (#165589)" by @Renzo-Olivares in [166889](https://github.com/flutter/flutter/pull/166889)_
- * Android gradle use lowercase instead of toLowerCase in preparation for removal in v9 by @reidbaker in [171397](https://github.com/flutter/flutter/pull/171397)
  - _* remove `x86` unused codepaths by @AbdeMohlbi in [170191](https://github.com/flutter/flutter/pull/170191)_
- * Clear background in the GTK layer, instead of OpenGL by @robert-ancell in [170840](https://github.com/flutter/flutter/pull/170840)
  - _* Fix multi-view GL rendering not working since software rendering was added by @robert-ancell in [171409](https://github.com/flutter/flutter/pull/171409)_
- * [skwasm] Use `queueMicrotask` instead of `postMessage` when single-threaded by @eyebrowsoffire in [166997](https://github.com/flutter/flutter/pull/166997)
  - _* [Web] Remove `webOnlyUniformRadii` from `RRect` by @dkwingsmt in [167237](https://github.com/flutter/flutter/pull/167237)_
- * Revert "[skwasm] Use `transferToImageBitmap` instead of `createImageBitmap` (#163251)" by @eyebrowsoffire in [171238](https://github.com/flutter/flutter/pull/171238)
  - _* feat(web): Add navigation focus handler for assistive technology focus restoration by @flutter-zl in [170046](https://github.com/flutter/flutter/pull/170046)_
- * Content aware hash moved to script and tracked by @jtmcdole in [166717](https://github.com/flutter/flutter/pull/166717)
  - _* Reverts "Content aware hash moved to script and tracked (#166717)" by @auto-submit[bot] in [166864](https://github.com/flutter/flutter/pull/166864)_
- * Reverts "Content aware hash moved to script and tracked (#166717)" by @auto-submit[bot] in [166864](https://github.com/flutter/flutter/pull/166864)
  - _* Reverts "[ Widget Preview ] Add initial support for communications over the Dart Tooling Daemon (DTD) (#166698)" by @auto-submit[bot] in [166866](https://github.com/flutter/flutter/pull/166866)_
- * Change FGP unit test `expect` to match on process result instead of exit code by @gmackall in [168278](https://github.com/flutter/flutter/pull/168278)
  - _* [tool] Refactor WebTemplate to be immutable by @kevmoo in [168201](https://github.com/flutter/flutter/pull/168201)_
- * Add/use `addMachineOutputFlag`/`outputsMachineFormat` instead of strings by @matanlurey in [171459](https://github.com/flutter/flutter/pull/171459)
  - _* Remove now duplicate un-forward ports for Android by @matanlurey in [171473](https://github.com/flutter/flutter/pull/171473)_
- * [Impeller] prefer 24 bit depth buffer format on vulkan backend. by @jonahwilliams in [166854](https://github.com/flutter/flutter/pull/166854)
  - _* bump max tasks to a huge number. by @jonahwilliams in [166876](https://github.com/flutter/flutter/pull/166876)_
- * Switch to Linux orchestrators for Windows releasers. by @matanlurey in [168941](https://github.com/flutter/flutter/pull/168941)
  - _* Revert "fix: update experiment to use different setup (#169728)" and "feat: experimental workflow for Linux tool-tests-general (#169706)" by @jason-simmons in [169770](https://github.com/flutter/flutter/pull/169770)_
- * [fuchsia] Use the system loader instead of Dart_LoadELF_Fd. by @rmacnak-google in [169534](https://github.com/flutter/flutter/pull/169534)
  - _* Remove Observatory build rules and remaining references from the engine by @bkonyi in [169945](https://github.com/flutter/flutter/pull/169945)_

---

### 3.32.0

**Deprecation** (11)

- * Add remaining dart fixes for Color deprecations when importing painting.dart by @Piinks in [162609](https://github.com/flutter/flutter/pull/162609)
  - _* Removes assumption that basis scalar and rounded_scalar match by @gaaclarke in [165166](https://github.com/flutter/flutter/pull/165166)_
- * deprecate Android announcement events and add deprecation warning. by @ash2moon in [165195](https://github.com/flutter/flutter/pull/165195)
  - _* (#112207) Adding `view_id` parameter to DispatchSemanticsAction and UpdateSemantics by @mattkae in [164577](https://github.com/flutter/flutter/pull/164577)_
- * Deprecate `ThemeData.indicatorColor` in favor of `TabBarThemeData.indicatorColor` by @TahaTesser in [160024](https://github.com/flutter/flutter/pull/160024)
  - _* Fix incorrect [enabled] documentation by @sethmfuller in [161650](https://github.com/flutter/flutter/pull/161650)_
- * Update `year2023` flag deprecation message by @TahaTesser in [162607](https://github.com/flutter/flutter/pull/162607)
  - _* Add missing space between DayPeriodControl and time control in time picker by @MinSeungHyun in [162230](https://github.com/flutter/flutter/pull/162230)_
- * Deprecate ExpansionTileController by @victorsanni in [166368](https://github.com/flutter/flutter/pull/166368)
  - _* Migrate to Theme.brightnessOf method by @rkishan516 in [163950](https://github.com/flutter/flutter/pull/163950)_
- * replace deprecated [UIScreen mainScreen] in iOS by @dkyurtov in [162785](https://github.com/flutter/flutter/pull/162785)
  - _* [iOS] remove Skia interfaces from iOS platform code. by @jonahwilliams in [163505](https://github.com/flutter/flutter/pull/163505)_
- * Replace deprecated openURL API call by @hellohuanlin in [164247](https://github.com/flutter/flutter/pull/164247)
  - _* Fix `-[FlutterView focusItemsInRect:]` crash by @LongCatIsLooong in [165454](https://github.com/flutter/flutter/pull/165454)_
- * [ios][pv]fully revert the UIScreen.main deprecated API change by @hellohuanlin in [166080](https://github.com/flutter/flutter/pull/166080)
  - _* [Engine][iOS] Cancel animation when recieved `UIKeyboardWillHideNotification` with duration 0.0 by @koji-1009 in [164884](https://github.com/flutter/flutter/pull/164884)_
- * Add empty `io.flutter.app.FlutterApplication` to give deprecation notice, and un-break projects that have not migrated by @gmackall in [164233](https://github.com/flutter/flutter/pull/164233)
  - _* [Android] Use java for looking up Android API level. by @jonahwilliams in [163558](https://github.com/flutter/flutter/pull/163558)_
- * [web] Remove deprecated web-only APIs from dart:ui by @mdebbar in [161775](https://github.com/flutter/flutter/pull/161775)
  - _* Unskip test. by @polina-c in [162106](https://github.com/flutter/flutter/pull/162106)_
- * [web_ui] move several uses of (deprecated) pkg:js to js_interop_unsafe by @kevmoo in [164264](https://github.com/flutter/flutter/pull/164264)
  - _* [web_ui] dependency cleanup by @kevmoo in [164256](https://github.com/flutter/flutter/pull/164256)_

**Breaking Change** (4)

- * Remove `scenario_app/android` and rename to `ios_scenario_app`. by @matanlurey in [160992](https://github.com/flutter/flutter/pull/160992)
  - _* Table implements redepth by @chunhtai in [162282](https://github.com/flutter/flutter/pull/162282)_
- * Removed not working hyperlinks to ScriptCategory values by @Mastermind-sap in [165395](https://github.com/flutter/flutter/pull/165395)
  - _* Refactor: Migrate Date picker from MaterialState and MaterialStateProperty by @rkishan516 in [164972](https://github.com/flutter/flutter/pull/164972)_
- * [Android] Fix integration test to check if dev dependencies are removed from release builds + address no non-dev dependency plugin edge case by @camsim99 in [161826](https://github.com/flutter/flutter/pull/161826)
  - _* [Android] HC++ plumbing. by @jonahwilliams in [162407](https://github.com/flutter/flutter/pull/162407)_
- * [Android] Remove overlay when platform views are removed from screen. by @jonahwilliams in [162908](https://github.com/flutter/flutter/pull/162908)
  - _* [Android] fix hcpp overlay layer intersection. by @jonahwilliams in [163024](https://github.com/flutter/flutter/pull/163024)_

**Performance Improvement** (21)

- * Improved error message when PageController is not attached to PageView by @Paulik8 in [162422](https://github.com/flutter/flutter/pull/162422)
  - _* Fix doc reference typos by @goderbauer in [162893](https://github.com/flutter/flutter/pull/162893)_
- * [skwasm] Clear font collection cache when font is loaded manually. by @eyebrowsoffire in [164588](https://github.com/flutter/flutter/pull/164588)
  - _* Fix: Update CupertinoSheetRoute transition rounded corner by @rkishan516 in [163700](https://github.com/flutter/flutter/pull/163700)_
- * [Cupertino] Improve comment in navigation bar docs by @loic-sharma in [164067](https://github.com/flutter/flutter/pull/164067)
  - _* adds status and alert roles by @chunhtai in [164925](https://github.com/flutter/flutter/pull/164925)_
- * [Impeller] cache for text shadows. by @jonahwilliams in [166228](https://github.com/flutter/flutter/pull/166228)
  - _* Fix: DelegateTransition for cupertino sheet route by @rkishan516 in [164675](https://github.com/flutter/flutter/pull/164675)_
- * [iOS] reduce wide gamut memory by 50% (for onscreen surfaces). by @jonahwilliams in [165601](https://github.com/flutter/flutter/pull/165601)
  - _* Reverts "[iOS] reduce wide gamut memory by 50% (for onscreen surfaces). (#165601)" by @auto-submit in [165915](https://github.com/flutter/flutter/pull/165915)_
- * Reverts "[iOS] reduce wide gamut memory by 50% (for onscreen surfaces). (#165601)" by @auto-submit in [165915](https://github.com/flutter/flutter/pull/165915)
  - _* Replace deprecated openURL API call by @hellohuanlin in [164247](https://github.com/flutter/flutter/pull/164247)_
- * Clip layers reduce rrects and paths to simpler shapes when possible by @flar in [164693](https://github.com/flutter/flutter/pull/164693)
  - _* Write macOS universal gen_snapshot binaries to a separate output directory by @jason-simmons in [164667](https://github.com/flutter/flutter/pull/164667)_
- * [Web] Improve onboarding docs by @loic-sharma in [164246](https://github.com/flutter/flutter/pull/164246)
  - _* [skwasm] Dynamic Threading by @eyebrowsoffire in [164748](https://github.com/flutter/flutter/pull/164748)_
- * Change the default optimization level to `-O2` for wasm in release mode. by @eyebrowsoffire in [162917](https://github.com/flutter/flutter/pull/162917)
  - _* [ Widget Preview ] Update generated scaffold project to include early preview rendering by @bkonyi in [162847](https://github.com/flutter/flutter/pull/162847)_
- * [tool] Improve using project files in build targets by @loic-sharma in [166211](https://github.com/flutter/flutter/pull/166211)
  - _* Add `--ignore-timeouts` flag for `flutter test` command by @nilsreichardt in [164437](https://github.com/flutter/flutter/pull/164437)_
- * Remove unnecessary cache busting mechanism in hot restart by @srujzs in [166295](https://github.com/flutter/flutter/pull/166295)
  - _* [native_assets] Roll dependencies by @dcharkes in [166282](https://github.com/flutter/flutter/pull/166282)_
- * Improve the test for `clangd --check` to choose files deterministically by @bc-lee in [161072](https://github.com/flutter/flutter/pull/161072)
  - _* Add Benchmarks and examples to compare swiftui and flutter by @LouiseHsu in [160681](https://github.com/flutter/flutter/pull/160681)_
- * Revert web_benchmarks back to default optimization level (`-O4`) by @eyebrowsoffire in [162762](https://github.com/flutter/flutter/pull/162762)
  - _* support running et fetch from anywhere by @yjbanov in [162712](https://github.com/flutter/flutter/pull/162712)_
- * [iOS] increase backdrop cached task limit. by @jonahwilliams in [164036](https://github.com/flutter/flutter/pull/164036)
  - _* Enable luci_flags for faster builds by @jtmcdole in [164069](https://github.com/flutter/flutter/pull/164069)_
- * Enable luci_flags for faster builds by @jtmcdole in [164069](https://github.com/flutter/flutter/pull/164069)
  - _* [fuchsia] enable assets_unittests by @zijiehe-google-com in [164019](https://github.com/flutter/flutter/pull/164019)_
- * Run more builds faster by @jtmcdole in [164125](https://github.com/flutter/flutter/pull/164125)
  - _* Do not update patch versions for `dependabot/github-actions`. by @matanlurey in [164055](https://github.com/flutter/flutter/pull/164055)_
- * [Impeller] Store the TextureGLES cached framebuffer object as a reactor handle by @jason-simmons in [164761](https://github.com/flutter/flutter/pull/164761)
  - _* Roll gn to 7a8aa3a08a13521336853a28c46537ec04338a2d by @cbracken in [164806](https://github.com/flutter/flutter/pull/164806)_
- * [Impeller] Fixes to YUV imports on Android, Incomplete read of pipeline cache data, missing enabled extensions. by @jonahwilliams in [164744](https://github.com/flutter/flutter/pull/164744)
  - _* increase Linux tool_integration_tests* subsharding by @andrewkolos in [164935](https://github.com/flutter/flutter/pull/164935)_
- * [Impeller] cache descriptor set layouts. by @jonahwilliams in [164952](https://github.com/flutter/flutter/pull/164952)
  - _* Changelog updates from 3.29.2 by @reidbaker in [165194](https://github.com/flutter/flutter/pull/165194)_
- * [Impeller] fix barriers on PowerVR hardware / ensure Render pass cached on non-MSAA. by @jonahwilliams in [165497](https://github.com/flutter/flutter/pull/165497)
  - _* [Impeller][DisplayList] Consolidate BlendMode definitions by @flar in [165450](https://github.com/flutter/flutter/pull/165450)_
- * [Impeller] optimize drawImageRect with blend and matrix color filter. by @jonahwilliams in [165998](https://github.com/flutter/flutter/pull/165998)
  - _* move around shaders in vertices uber 1/2 by @jonahwilliams in [166180](https://github.com/flutter/flutter/pull/166180)_

**Replacement / Migration** (18)

- * [fuchsia] Remove explicit LogSink and InspectSink routing and use dictionaries instead by @gbbosak in [162780](https://github.com/flutter/flutter/pull/162780)
  - _* Public nodes needing paint or layout by @emerssso in [166148](https://github.com/flutter/flutter/pull/166148)_
- * Prefer using non nullable opacityAnimation property by @AhmedLSayed9 in [164795](https://github.com/flutter/flutter/pull/164795)
  - _* feat: Added forceErrorText in DropdownButtonFormField #165188 by @Memet18 in [165189](https://github.com/flutter/flutter/pull/165189)_
- * Start using `bin/cache/engine.{stamp|realm}` instead of `bin/internal/engine.{realm|version}`. by @matanlurey in [164352](https://github.com/flutter/flutter/pull/164352)
  - _* android: Clean up gen_snapshot artifact build by @cbracken in [164418](https://github.com/flutter/flutter/pull/164418)_
- * [Windows] Allow apps to prefer low power GPUs by @zaiste-linganer in [162490](https://github.com/flutter/flutter/pull/162490)
  - _* [windows] Implement merged UI and platform thread by @knopp in [162935](https://github.com/flutter/flutter/pull/162935)_
- * [canvaskit] Use `transferToImageBitmap` instead of `createImageBitmap` by @harryterkelsen in [163175](https://github.com/flutter/flutter/pull/163175)
  - _* [skwasm] Use `transferToImageBitmap` instead of `createImageBitmap` by @eyebrowsoffire in [163251](https://github.com/flutter/flutter/pull/163251)_
- * [skwasm] Use `transferToImageBitmap` instead of `createImageBitmap` by @eyebrowsoffire in [163251](https://github.com/flutter/flutter/pull/163251)
  - _* [canvaskit] Handle MakeGrContext returning null by @harryterkelsen in [163332](https://github.com/flutter/flutter/pull/163332)_
- * [web:a11y] wheel events switch to pointer mode by @yjbanov in [163582](https://github.com/flutter/flutter/pull/163582)
  - _* introduce system color palette by @yjbanov in [163335](https://github.com/flutter/flutter/pull/163335)_
- * [CP-beta][skwasm] Use `queueMicrotask` instead of `postMessage` when single-threaded by @flutteractionsbot in [167154](https://github.com/flutter/flutter/pull/167154)
- * route CLI command usage information through the logger instead of using `print` by @andrewkolos in [161533](https://github.com/flutter/flutter/pull/161533)
  - _* remove usage of `Usage` from build system by @andrewkolos in [160663](https://github.com/flutter/flutter/pull/160663)_
- * Make developing `flutter_tools` nicer: Use `fail` instead of `throw StateError`. by @matanlurey in [163094](https://github.com/flutter/flutter/pull/163094)
  - _* explicitly set packageConfigPath for strategy providers by @jyameo in [163080](https://github.com/flutter/flutter/pull/163080)_
- * Make LLDB check a warning instead of a failure by @vashworth in [164828](https://github.com/flutter/flutter/pull/164828)
  - _* [tools, web] Make sure to copy the dump-info file if dump-info is used by @kevmoo in [165013](https://github.com/flutter/flutter/pull/165013)_
- * fix `felt` link to point to flutter repo instead of the engine repo by @AbdeMohlbi in [161423](https://github.com/flutter/flutter/pull/161423)
  - _* Don't depend on Dart from FML. by @chinmaygarde in [162271](https://github.com/flutter/flutter/pull/162271)_
- * Add missing `properties: ...` and move to presubmit. by @matanlurey in [162170](https://github.com/flutter/flutter/pull/162170)
  - _* Fix update_engine_version_test in presence of FLUTTER_PREBUILT_ENGINE_VERSION env vars. by @aam in [162270](https://github.com/flutter/flutter/pull/162270)_
- * [macos] prefer integrated GPU. by @jonahwilliams in [164569](https://github.com/flutter/flutter/pull/164569)
  - _* Reverts "[Impeller] use DeviceLocal textures for gifs on non-iOS devices. (#164573)" by @auto-submit in [164600](https://github.com/flutter/flutter/pull/164600)_
- * Point ktlint AS docs to the `.editorconfig` that is actually used by ci, instead of making a copy in the README by @gmackall in [165213](https://github.com/flutter/flutter/pull/165213)
  - _* Delete `docs/infra/Infra-Ticket-Queue.md` by @matanlurey in [165258](https://github.com/flutter/flutter/pull/165258)_
- * Update the Dart package creation script to copy source files instead of creating symlinks to the source tree by @jason-simmons in [165242](https://github.com/flutter/flutter/pull/165242)
  - _* Update docs after #165258 by @Piinks in [165716](https://github.com/flutter/flutter/pull/165716)_
- * [Impeller] Move to the new location before rendering a stroke path contour containing only one point by @jason-simmons in [165940](https://github.com/flutter/flutter/pull/165940)
  - _* Fix build_android_host_app_with_module_source device lab tests by @bkonyi in [166077](https://github.com/flutter/flutter/pull/166077)_
- * [fuchsia][sysmem2] switch to sysmem2 tokens by @dustingreen in [166120](https://github.com/flutter/flutter/pull/166120)
  - _* [Impeller] fix min filter for GL external textures. by @jonahwilliams in [166224](https://github.com/flutter/flutter/pull/166224)_

---

### 3.29.0

**Deprecation** (13)

- * Remove `gradle_deprecated_settings` test app, and remove reference from lockfile exclusion yaml by @gmackall in 161622
  - _* Check that localization files of stocks app are up-to-date by @goderbauer in 161608_
- * Proposal to deprecate `webGoldenComparator`. by @matanlurey in 161196
  - _* [Impeller] dont generate final 1x1 mip level to work around Adreno GPU bug by @jonahwilliams in 161192_
- * Add `SurfaceProducer.onSurfaceCleanup`, deprecate `onSurfaceDestroyed`. by @matanlurey in 160937
  - _* Fix docImport issues by @goderbauer in 160918_
- * deprecate engine ci yaml roller by @christopherfujino in 160682
  - _* Roll to dart 3.7.0-267.0.dev by @aam in 160680_
- * Turn deprecation message analyze tests back on by @LongCatIsLooong in 160554
  - _* Split build and test builders for web engine by @eyebrowsoffire in 160550_
- * Remove more references to deprecated package:usage (executable, runner) by @andrewkolos in 160369
  - _* Skip integration tests that consistently OOM on a Windows platform. by @matanlurey in 160368_
- * Update PopInvokedCallback Deprecated message by @krokyze in 160324
  - _* Added Mohammed Chahboun to authors by @M97Chahboun in 160311_
- * Deprecate unused `ButtonStyleButton.iconAlignment` property by @TahaTesser in 160023
  - _* Add script to check format of changed dart files by @goderbauer in 160007_
- * [CP-beta]Add deprecation notice for Android x86 when building for the target by @flutteractionsbot in 159847
  - _* Reland Fix Date picker overlay colors aren't applied on selected state by @bleroux in 159839_
- * Add deprecation notice for Android x86 when building for the target by @bkonyi in 159750
  - _* Introduce Material 3 `year2023` flag to `SliderThemeData` by @TahaTesser in 159721_
- * [tool] Removes deprecated --web-renderer parameter. by @ditman in 159314
  - _* Suppress previous route transition if current route is fullscreenDialog by @MitchellGoodwin in 159312_
- * Fix use of deprecated `buildDir` in Android templates/tests/examples by @gmackall in 157560
  - _* Reverts "Upgrade tests to AGP 8.7/Gradle 8.10.2/Kotlin 1.8.10 (#157032)" by @auto-submit[bot] in 157559_
- * Migrate away from deprecated whereNotNull by @parlough in 157250
  - _* Fix a few typos in framework code and doc comments by @parlough in 157248_

**New Feature / API** (2)

- * Temporarily skip CustomPainter SemanticsFlag test to allow new flag to roll in by @yjbanov in 157061
  - _* Upgrade tests to AGP 8.7/Gradle 8.10.2/Kotlin 1.8.10 by @gmackall in 157032_
- * Temporarily skip SemanticsFlag test to allow new flag to roll in by @yjbanov in 157017
  - _* Roll Packages from bf751e6dff18 to a35f02d79d0e (2 revisions) by @engine-flutter-autoroll in 156983_

**New Parameter / Option** (2)

- * Temporarily skip CustomPainter SemanticsFlag test to allow new flag to roll in by @yjbanov in 157061
  - _* Upgrade tests to AGP 8.7/Gradle 8.10.2/Kotlin 1.8.10 by @gmackall in 157032_
- * Temporarily skip SemanticsFlag test to allow new flag to roll in by @yjbanov in 157017
  - _* Roll Packages from bf751e6dff18 to a35f02d79d0e (2 revisions) by @engine-flutter-autoroll in 156983_

**Performance Improvement** (11)

- * git ignore .ccls-cache by @flar in 161340
  - _* Reverts "[SwiftPM] Turn on by default (#161275)" by @auto-submit[bot] in 161339_
- * [Impeller] reland: fix porterduff shader and handle optimized out texture binding in GLES backend. by @jonahwilliams in 161326
  - _* Reverts "[Impeller] porter duff workarounds for Adreno GPU. (#161273)" by @auto-submit[bot] in 161318_
- * Improve Plugins That Reference V1 Embedding Error Message by @jesswrd in 160890
  - _* Clarify where `gclient` is run from. by @chunhtai in 160889_
- * Annotate entrypoints in the "isolate spawner" files generated by `flutter test --experimental-faster-testing` by @derekxu16 in 160694
  - _* [Impeller] move barrier setting out of render pass builder. by @jonahwilliams in 160693_
- * Improve UI-thread animation performance by @bernaferrari in 159288
  - _* Add `columnWidth` Property to `DataTable` for Customizable Column Widths by @lamnhan066 in 159279_
- * Cleanup MenuAnchor and Improve DropdownMenu tests readability by @bleroux in 158175
  - _* Make native asset integration test more robust, thereby allowing smooth auto-update of packages via `flutter update-packages` by @mkustermann in 158170_
- * Improve consistency of code snippets in basic.dart by @loic-sharma in 158015
  - _* Make SwiftPM integration tests even MORE idiomatic by @loic-sharma in 158014_
- * improve `ContainerRenderObjectMixin` error message when `parentData` is not set up properly by @PurplePolyhedron in 157846
  - _* Update CHANGELOG.md to correct ios vs macos issue by @reidbaker in 157822_
- * iOS Selection Handle Improvements by @Renzo-Olivares in 157815
  - _* Roll Packages from e0c4f55cd355 to 028027e6b1f1 (8 revisions) by @engine-flutter-autoroll in 157813_
- * Readability change to `flutter.groovy`, align on null assignment, reduce unused scope for some methods, apply static where possible by @AbdeMohlbi in 157471
  - _* Turn `brieflyShowPassword` back on on iOS by @LongCatIsLooong in 157466_
- * Allow requesting a reduced widget tree with `getRootWidgetTree` service extension by @elliette in 157309
  - _* [CP-beta] Fix flavor-conditional asset bundling for path dependencies by @andrewkolos in 157306_

**Replacement / Migration** (6)

- * Revert "use uuid from package:uuid instead of from package:usage" by @jiahaog in 161292
  - _* [Impeller] re-enable Adreno 630 by @jonahwilliams in 161287_
- * use uuid from package:uuid instead of from package:usage by @devoncarew in 161102
  - _* update repo to be forward compatible with shelf_web_socket v3.0 by @devoncarew in 161101_
- * Use `flutter` repo for engine golds instead of `flutter-engine`. by @matanlurey in 160556
  - _* Turn deprecation message analyze tests back on by @LongCatIsLooong in 160554_
- * Allow integration test helpers to work on substrings instead of whole strings by @mkustermann in 160437
  - _* [native_assets] Preparation existing tests for future of other (i.e. non-Code) assets by @mkustermann in 160436_
- * [native assets] Create `NativeAssetsManifest.json` instead of kernel embedding by @dcharkes in 159322
  - _* [tool] Removes deprecated --web-renderer parameter. by @ditman in 159314_
- * Fix JS compilation to use the command 'compile js' instead of using snapshot names to invoke dart2js by @a-siva in 156735
  - _* Roll Packages from 67401e169e5c to 1e670f27a620 (7 revisions) by @engine-flutter-autoroll in 156734_

---

### 3.27.0

**Deprecation** (20)

- * Update deprecation policy by @Piinks in [151257](https://github.com/flutter/flutter/pull/151257)
  - _* PinnedHeaderSliver example based on the iOS Settings AppBar by @HansMuller in [151205](https://github.com/flutter/flutter/pull/151205)_
- * Factor out deprecated names in example code by @nate-thegrate in [151374](https://github.com/flutter/flutter/pull/151374)
  - _* Added SliverFloatingHeader.snapMode by @HansMuller in [151289](https://github.com/flutter/flutter/pull/151289)_
- * [tool] Remove some usages of deprecated usage package by @andrewkolos in [151359](https://github.com/flutter/flutter/pull/151359)
  - _* Add Semantics Property `linkUrl` by @mdebbar in [150639](https://github.com/flutter/flutter/pull/150639)_
- * painting: drop deprecated (exported) hashList and hashValues functions by @kevmoo in [151677](https://github.com/flutter/flutter/pull/151677)
  - _* docimports for rendering library by @goderbauer in [151958](https://github.com/flutter/flutter/pull/151958)_
- * Refactor: Deprecate inactiveColor from cupertino checkbox by @rkishan516 in [152981](https://github.com/flutter/flutter/pull/152981)
  - _* Implemented CupertinoButton new styles/sizes (fixes #92525) by @kerberjg in [152845](https://github.com/flutter/flutter/pull/152845)_
- * Deprecate invalid InputDecoration.collapsed parameters by @bleroux in [152486](https://github.com/flutter/flutter/pull/152486)
  - _* Use decoration hint text as the default value for dropdown button hints by @bleroux in [152474](https://github.com/flutter/flutter/pull/152474)_
- * Add xcresulttool --legacy flag for deprecated usage by @jmagman in [152988](https://github.com/flutter/flutter/pull/152988)
  - _* Remove -sdk for watchOS simulator in tool by @jmagman in [152992](https://github.com/flutter/flutter/pull/152992)_
- * Add deprecation warning for "flutter create --ios-language" by @jmagman in [155867](https://github.com/flutter/flutter/pull/155867)
  - _* Roll pub packages by @flutter-pub-roller-bot in [156114](https://github.com/flutter/flutter/pull/156114)_
- * [tool] Emit a deprecation warning for some values of --web-renderer. by @ditman in [156376](https://github.com/flutter/flutter/pull/156376)
  - _* Migrator for android 35/16kb page size cmake flags for plugin_ffi by @dcharkes in [156221](https://github.com/flutter/flutter/pull/156221)_
- * Add `SurfaceProducer#onSurfaceAvailable`, deprecate `onSurfaceCreated`. by @matanlurey in [55418](https://github.com/flutter/engine/pull/55418)
  - _* Add a boolean that exposes rotation/crop metadata capability. by @matanlurey in [55434](https://github.com/flutter/engine/pull/55434)_
- * Reverts "Add `SurfaceProducer#onSurfaceAvailable`, deprecate `onSurfaceCreated`. (#55418)" by @auto-submit in [55450](https://github.com/flutter/engine/pull/55450)
  - _* Reverts "Reverts "Add `SurfaceProducer#onSurfaceAvailable`, deprecate `onSurfaceCreated`. (#55418)" (#55450)" by @auto-submit in [55463](https://github.com/flutter/engine/pull/55463)_
- * Reverts "Reverts "Add `SurfaceProducer#onSurfaceAvailable`, deprecate `onSurfaceCreated`. (#55418)" (#55450)" by @auto-submit in [55463](https://github.com/flutter/engine/pull/55463)
  - _* Release`onTrimMemoryListener` after `ImageReaderSurfaceProducer` released. by @matanlurey in [55760](https://github.com/flutter/engine/pull/55760)_
- * Drop deprecated hash_code functions by @kevmoo in [54000](https://github.com/flutter/engine/pull/54000)
  - _* Reverts "Drop deprecated hash_code functions (#54000)" by @auto-submit in [54002](https://github.com/flutter/engine/pull/54002)_
- * Reverts "Drop deprecated hash_code functions (#54000)" by @auto-submit in [54002](https://github.com/flutter/engine/pull/54002)
  - _* Reverts "Reverts "Drop deprecated hash_code functions (#54000)" (#54002)" by @auto-submit in [54004](https://github.com/flutter/engine/pull/54004)_
- * Reverts "Reverts "Drop deprecated hash_code functions (#54000)" (#54002)" by @auto-submit in [54004](https://github.com/flutter/engine/pull/54004)
  - _* [canvaskit] Decode images using  tag decoding by @harryterkelsen in [53201](https://github.com/flutter/engine/pull/53201)_
- * [web] Warn users when picking a deprecated renderer. by @ditman in [55709](https://github.com/flutter/engine/pull/55709)
  - _* [canvaskit] Fix incorrect clipping with Opacity scene layer by @harryterkelsen in [55751](https://github.com/flutter/engine/pull/55751)_
- * dart:ui - drop deprecated hash functions by @kevmoo in [53787](https://github.com/flutter/engine/pull/53787)
  - _* Impeller really wants premultiplied alpha by @jtmcdole in [53770](https://github.com/flutter/engine/pull/53770)_
- * Reverts "dart:ui - drop deprecated hash functions (#53787)" by @auto-submit in [53794](https://github.com/flutter/engine/pull/53794)
  - _* Add instructions for source debugging with Xcode when using RBE. by @chinmaygarde in [53822](https://github.com/flutter/engine/pull/53822)_
- * Prepare engine for deprecation of async_minitest.dart by @lrhn in [53560](https://github.com/flutter/engine/pull/53560)
  - _* Align `tools/android_sdk/packages.txt` with what is uploaded to CIPD by @gmackall in [53921](https://github.com/flutter/engine/pull/53921)_
- * [Fuchsia] Remove deprecated and unnecessary parameters from fuchsia*archive by @zijiehe-google-com in [55324](https://github.com/flutter/engine/pull/55324)
  - _* [Flutter GPU] Add setStencilReference to RenderPass. by @bdero in [55270](https://github.com/flutter/engine/pull/55270)_

**New Feature / API** (1)

- * added functionality to where SR will communicate button clicked by @DBowen33 in [152185](https://github.com/flutter/flutter/pull/152185)
  - _* Implement `on` clauses by @nate-thegrate in [152706](https://github.com/flutter/flutter/pull/152706)_

**Performance Improvement** (45)

- * Improve `CupertinoCheckbox` fidelity by @victorsanni in [151441](https://github.com/flutter/flutter/pull/151441)
  - _* [CupertinoActionSheet] Make `_ActionSheetButtonBackground` stateless by @dkwingsmt in [152283](https://github.com/flutter/flutter/pull/152283)_
- * [CupertinoActionSheet & AlertDialog] Improve documentation and type for `scrollController` parameters by @dkwingsmt in [152647](https://github.com/flutter/flutter/pull/152647)
  - _* Explain that predictive back doesn't work with WillPopScope by @justinmc in [152116](https://github.com/flutter/flutter/pull/152116)_
- * Improve `CupertinoRadio` fidelity by @victorsanni in [149703](https://github.com/flutter/flutter/pull/149703)
  - _* Introduce `double` `Flex.spacing` parameter for `Row`/`Column` spacing by @TahaTesser in [152472](https://github.com/flutter/flutter/pull/152472)_
- * Improve asserts on Element.mount by @gspencergoog in [153477](https://github.com/flutter/flutter/pull/153477)
  - _* Design-Documents.md incorrect link by @justinmc in [153509](https://github.com/flutter/flutter/pull/153509)_
- * Optimize out LayoutBuilder from ReorderableList children by @moffatman in [153987](https://github.com/flutter/flutter/pull/153987)
  - _* fix `getFullHeightForCaret` when strut is disabled. by @LongCatIsLooong in [154039](https://github.com/flutter/flutter/pull/154039)_
- * Improve Documentation for ResizeImage Dimensions and Usage by @RamonFarizel in [154212](https://github.com/flutter/flutter/pull/154212)
  - _* Test of AppBarMediumApp and AppBarLargeApp by @miechoo in [153973](https://github.com/flutter/flutter/pull/153973)_
- * Improve CupertinoPopupSurface appearance by @davidhicks980 in [151430](https://github.com/flutter/flutter/pull/151430)
  - _* Roll Flutter Engine from c50eb8a65097 to 419fb8c0ab3e by @a-siva in [154734](https://github.com/flutter/flutter/pull/154734)_
- * Revert "Improve CupertinoPopupSurface appearance" by @davidhicks980 in [154893](https://github.com/flutter/flutter/pull/154893)
  - _* `CupertinoSlidingSegmentedControl` update by @QuncCccccc in [152976](https://github.com/flutter/flutter/pull/152976)_
- * Migrate Color.toString() test, improves `equalsIgnoringHashCodes` by @gaaclarke in [154934](https://github.com/flutter/flutter/pull/154934)
  - _* Move (`dev/tools`), complete v0 of `native_driver` (Android) by @matanlurey in [154843](https://github.com/flutter/flutter/pull/154843)_
- * `RenderParagraph` should invalidate its `_SelectableFragment`s cached rects on window size updates by @Renzo-Olivares in [155719](https://github.com/flutter/flutter/pull/155719)
  - _* Roll packages manually by @gmackall in [155786](https://github.com/flutter/flutter/pull/155786)_
- * Optimize `Overlay` sample to avoid overflow by @TahaTesser in [155861](https://github.com/flutter/flutter/pull/155861)
  - _* Fixes column text width calculation in CupertinoDatePicker by @Mairramer in [151128](https://github.com/flutter/flutter/pull/151128)_
- * reduce warnings inside flutter.groovy file by @AbdeMohlbi in [152073](https://github.com/flutter/flutter/pull/152073)
  - _* [tool] Guard process writes to frontend server in `ResidentCompiler` by @andrewkolos in [152358](https://github.com/flutter/flutter/pull/152358)_
- * Re-land "Ensure flutter build apk --release optimizes+shrinks platform code" by @gmackall in [153868](https://github.com/flutter/flutter/pull/153868)
  - _* Android analyze command should run pub by @chunhtai in [153953](https://github.com/flutter/flutter/pull/153953)_
- * [Windows] Improve symlink ERROR_ACCESS_DENIED error message by @loic-sharma in [154030](https://github.com/flutter/flutter/pull/154030)
  - _* Update `flutter build apk -h` to indicate that target arch is not supported in debug mode. by @reidbaker in [154111](https://github.com/flutter/flutter/pull/154111)_
- * Improve 'flutter downgrade' error message by @loic-sharma in [154434](https://github.com/flutter/flutter/pull/154434)
  - _* Add proguard rule to keep the class for all implementations of FlutterPlugin by @gmackall in [154677](https://github.com/flutter/flutter/pull/154677)_
- * Improve iOS unpack target's error messages by @loic-sharma in [154649](https://github.com/flutter/flutter/pull/154649)
  - _* [tool] Add `dartFileName` setting for platform plugins by @Sameri11 in [153099](https://github.com/flutter/flutter/pull/153099)_
- * Remove allowoptimization modifier from FlutterPlugin proguard rules by @rajveermalviya in [154715](https://github.com/flutter/flutter/pull/154715)
  - _* Handle `ProcessException`s due to `git` missing on the host by @andrewkolos in [154445](https://github.com/flutter/flutter/pull/154445)_
- * Improve tracing and fix packages_autoroller by @christopherfujino in [154841](https://github.com/flutter/flutter/pull/154841)
  - _* Fix `flutter build aar` for modules that use a plugin by @gmackall in [154757](https://github.com/flutter/flutter/pull/154757)_
- * reduce warnings inside flutter.groovy file #2 by @AbdeMohlbi in [155628](https://github.com/flutter/flutter/pull/155628)
  - _* [flutter_tools] Cleanup of native asset related code (removes around 50% of the native asset related code) by @mkustermann in [155430](https://github.com/flutter/flutter/pull/155430)_
- * iOS: Update codesigned binaries list to match cache by @cbracken in [154027](https://github.com/flutter/flutter/pull/154027)
  - _* iOS: Remove simulator dSYMs from codesign test by @cbracken in [154041](https://github.com/flutter/flutter/pull/154041)_
- * improve trace logging in packages autoroller by @christopherfujino in [154441](https://github.com/flutter/flutter/pull/154441)
  - _* Revert "improve trace logging in packages autoroller" by @zanderso in [154555](https://github.com/flutter/flutter/pull/154555)_
- * Revert "improve trace logging in packages autoroller" by @zanderso in [154555](https://github.com/flutter/flutter/pull/154555)
  - _* Improve microbenchmarks a smidge by @jtmcdole in [154461](https://github.com/flutter/flutter/pull/154461)_
- * Improve microbenchmarks a smidge by @jtmcdole in [154461](https://github.com/flutter/flutter/pull/154461)
  - _* Adds wide gamut framework test by @gaaclarke in [153319](https://github.com/flutter/flutter/pull/153319)_
- * [Impeller] Implement draw order optimization. by @bdero in [54067](https://github.com/flutter/engine/pull/54067)
  - _* Reverts "[Impeller] Implement draw order optimization. (#54067)" by @auto-submit in [54136](https://github.com/flutter/engine/pull/54136)_
- * Reverts "[Impeller] Implement draw order optimization. (#54067)" by @auto-submit in [54136](https://github.com/flutter/engine/pull/54136)
  - _* Revert "[Impeller] Use downsample shader for blur instead of mip levels. (#53760)" by @gaaclarke in [54148](https://github.com/flutter/engine/pull/54148)_
- * [Impeller] Reland: Implement draw order optimization. by @bdero in [54215](https://github.com/flutter/engine/pull/54215)
  - _* Reverts "[Impeller] Reland: Implement draw order optimization. (#54215)" by @auto-submit in [54261](https://github.com/flutter/engine/pull/54261)_
- * Reverts "[Impeller] Reland: Implement draw order optimization. (#54215)" by @auto-submit in [54261](https://github.com/flutter/engine/pull/54261)
  - _* [Impeller] move more aiks tests to DL. by @jonahwilliams in [54260](https://github.com/flutter/engine/pull/54260)_
- * [Impeller] Reland 2: Implement draw order optimization. by @bdero in [54268](https://github.com/flutter/engine/pull/54268)
  - _* [Impeller] migrate more AIKS test to DL. by @jonahwilliams in [54267](https://github.com/flutter/engine/pull/54267)_
- * Revert "[Impeller] Reland 2: Implement draw order optimization. (#54268) by @bdero in [54325](https://github.com/flutter/engine/pull/54325)
  - _* [Impeller] ensure precision matches for buggy vulkan drivers. by @jonahwilliams in [54372](https://github.com/flutter/engine/pull/54372)_
- * [Impeller] Reland 3: Implement draw order optimization. by @bdero in [54673](https://github.com/flutter/engine/pull/54673)
  - _* [Impeller] more test migration. by @jonahwilliams in [54763](https://github.com/flutter/engine/pull/54763)_
- * [canvaskit] Improve how overlays are optimized by @harryterkelsen in [54547](https://github.com/flutter/engine/pull/54547)
  - _* [skwasm] Fix skwasm clip coverage algorithm. by @eyebrowsoffire in [54572](https://github.com/flutter/engine/pull/54572)_
- * [skwasm] Scene builder optimizations for platform view placement by @eyebrowsoffire in [54949](https://github.com/flutter/engine/pull/54949)
  - _* Reverts "[skwasm] Scene builder optimizations for platform view placement (#54949)" by @auto-submit in [55193](https://github.com/flutter/engine/pull/55193)_
- * Reverts "[skwasm] Scene builder optimizations for platform view placement (#54949)" by @auto-submit in [55193](https://github.com/flutter/engine/pull/55193)
  - _* Reland: Update Color to do all calculations with floating point components by @gaaclarke in [55231](https://github.com/flutter/engine/pull/55231)_
- * [canvaskit] Further improve overlay optimization by splitting pictures by @harryterkelsen in [54878](https://github.com/flutter/engine/pull/54878)
  - _* Revert "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55401](https://github.com/flutter/engine/pull/55401)_
- * Revert "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55401](https://github.com/flutter/engine/pull/55401)
  - _* Reland "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55402](https://github.com/flutter/engine/pull/55402)_
- * Reland "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55402](https://github.com/flutter/engine/pull/55402)
  - _* Reverts "Reland "[canvaskit] Further improve overlay optimization by splitting pictures" (#55402)" by @auto-submit in [55456](https://github.com/flutter/engine/pull/55456)_
- * Reverts "Reland "[canvaskit] Further improve overlay optimization by splitting pictures" (#55402)" by @auto-submit in [55456](https://github.com/flutter/engine/pull/55456)
  - _* Reland "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55464](https://github.com/flutter/engine/pull/55464)_
- * Reland "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55464](https://github.com/flutter/engine/pull/55464)
  - _* [web] Update builder json generator to reflect recent changes by @mdebbar in [55307](https://github.com/flutter/engine/pull/55307)_
- * Revert "Reland "[canvaskit] Further improve overlay optimization by splitting pictures"" by @harryterkelsen in [55501](https://github.com/flutter/engine/pull/55501)
  - _* Reland [skwasm] Scene builder optimizations for platform view placement by @eyebrowsoffire in [55468](https://github.com/flutter/engine/pull/55468)_
- * Reland [skwasm] Scene builder optimizations for platform view placement by @eyebrowsoffire in [55468](https://github.com/flutter/engine/pull/55468)
  - _* Reland "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55563](https://github.com/flutter/engine/pull/55563)_
- * Reland "[canvaskit] Further improve overlay optimization by splitting pictures" by @harryterkelsen in [55563](https://github.com/flutter/engine/pull/55563)
  - _* Revert "Reland [skwasm] Scene builder optimizations for platform view placement (#55468)" by @eyebrowsoffire in [55715](https://github.com/flutter/engine/pull/55715)_
- * Revert "Reland [skwasm] Scene builder optimizations for platform view placement (#55468)" by @eyebrowsoffire in [55715](https://github.com/flutter/engine/pull/55715)
  - _* [web] Warn users when picking a deprecated renderer. by @ditman in [55709](https://github.com/flutter/engine/pull/55709)_
- * [Windows] Improve texture format logic by @loic-sharma in [54329](https://github.com/flutter/engine/pull/54329)
  - _* macOS: Fix crash in attributedSubstringForProposedRange with out of bounds range by @knopp in [54469](https://github.com/flutter/engine/pull/54469)_
- * [DisplayList] Optimize ClipRRect and ClipPath to ClipOval when appropriate by @flar in [54088](https://github.com/flutter/engine/pull/54088)
  - _* Split up mac_host_engine builds by @zanderso in [53571](https://github.com/flutter/engine/pull/53571)_
- * Improved description for ios_debug_sim_unopt_arm64 by @cbracken in [55498](https://github.com/flutter/engine/pull/55498)
  - _* Fix npe during skia dispatch of drawAtlas by @jonahwilliams in [55497](https://github.com/flutter/engine/pull/55497)_

**Replacement / Migration** (16)

- * Update fake_codec.dart to use Future.value instead of SynchronousFuture by @biggs0125 in [152182](https://github.com/flutter/flutter/pull/152182)
  - _* Add a more typical / concrete example to IntrinsicHeight / IntrinsicWidth by @LongCatIsLooong in [152246](https://github.com/flutter/flutter/pull/152246)_
- * [web] Pass `--no-source-maps` instead of `--extra-compiler-option=--no-source-maps` to `dart compile wasm` by @mkustermann in [153417](https://github.com/flutter/flutter/pull/153417)
  - _* [Swift Package Manager] Test removing the last Flutter plugin by @loic-sharma in [153519](https://github.com/flutter/flutter/pull/153519)_
- * [Impeller] Use downsample shader for blur instead of mip levels. by @jonahwilliams in [53760](https://github.com/flutter/engine/pull/53760)
  - _* Avoid using a private GTest macro to skip tests. by @chinmaygarde in [53782](https://github.com/flutter/engine/pull/53782)_
- * [iOS] Switch to FlutterMetalLayer by default. by @jonahwilliams in [54086](https://github.com/flutter/engine/pull/54086)
  - _* [Impeller] Implement draw order optimization. by @bdero in [54067](https://github.com/flutter/engine/pull/54067)_
- * Revert "[Impeller] Use downsample shader for blur instead of mip levels. (#53760)" by @gaaclarke in [54148](https://github.com/flutter/engine/pull/54148)
  - _* [impeller] adds test for catching shimmer in gaussian blur by @gaaclarke in [54116](https://github.com/flutter/engine/pull/54116)_
- * Reland: [Impeller] Use downsample shader for blur instead of mip levels. by @gaaclarke in [54149](https://github.com/flutter/engine/pull/54149)
  - _* [engine] Split encode and submit into two different surface frame callbacks. by @jonahwilliams in [54200](https://github.com/flutter/engine/pull/54200)_
- * [Impeller] Switch from AIKS canvas to DL based canvas implementation. by @jonahwilliams in [53781](https://github.com/flutter/engine/pull/53781)
  - _* [Impeller] add support for superellipse. by @jonahwilliams in [54562](https://github.com/flutter/engine/pull/54562)_
- * [Impeller] use paragraphs instead of bullet points in the FAQ. by @chinmaygarde in [54622](https://github.com/flutter/engine/pull/54622)
  - _* [Impeller] Add a note about Graphite to the FAQ. by @chinmaygarde in [54623](https://github.com/flutter/engine/pull/54623)_
- * [Impeller] Pack impeller:Path into 2 vecs instead of 3. by @jonahwilliams in [55028](https://github.com/flutter/engine/pull/55028)
  - _* [Impeller] add basic culling checks during text frame dispatcher. by @jonahwilliams in [55168](https://github.com/flutter/engine/pull/55168)_
- * Directly use 4x4 matrices with surface textures instead of converting to and from the 3x3 variants. by @chinmaygarde in [54126](https://github.com/flutter/engine/pull/54126)
  - _* [Impeller] Enable on-by-default on Android. by @chinmaygarde in [54156](https://github.com/flutter/engine/pull/54156)_
- * [engine] reland weaken affinity of raster/ui to non-e core instead of only fast core by @jonahwilliams in [54616](https://github.com/flutter/engine/pull/54616)
  - _* Remove spammy warning message on `FlutterView` by @matanlurey in [54686](https://github.com/flutter/engine/pull/54686)_
- * [web] switch to SemanticsAction.focus (attempt 3) by @yjbanov in [53689](https://github.com/flutter/engine/pull/53689)
  - _* [web] fix unexpected scrolling in semantics by @yjbanov in [53922](https://github.com/flutter/engine/pull/53922)_
- * [web:canvaskit] switch to temporary SkPaint objects by @yjbanov in [54818](https://github.com/flutter/engine/pull/54818)
  - _* Add `crossOrigin` property to  tag used for decoding by @harryterkelsen in [54961](https://github.com/flutter/engine/pull/54961)_
- * [fuchsia][sysmem2] move to sysmem2 protocols by @dustingreen in [53138](https://github.com/flutter/engine/pull/53138)
  - _* Revert 4 Dart rolls (726cb2467 -> ffc8bb004) to recover engine roll by @bdero in [53778](https://github.com/flutter/engine/pull/53778)_
- * Use GNI group instead of hardcoding PNG codecs source files. by @anforowicz in [54781](https://github.com/flutter/engine/pull/54781)
  - _* macOS: Do not archive/upload FlutterMacOS.dSYM to cloud by @cbracken in [54787](https://github.com/flutter/engine/pull/54787)_
- * [Flutter GPU] Use vm.Vector4 for clear color instead of ui.Color. by @bdero in [55416](https://github.com/flutter/engine/pull/55416)
  - _* [scenario_app] delete get bitmap activity. by @jonahwilliams in [55436](https://github.com/flutter/engine/pull/55436)_

---

### 3.24.0

**Deprecation** (8)

- * Deprecate `ButtonBar`, `ButtonBarThemeData`, and `ThemeData.buttonBarTheme` by @TahaTesser in [145523](https://github.com/flutter/flutter/pull/145523)
  - _* Fix `MenuItemButton` overflow by @TahaTesser in [143932](https://github.com/flutter/flutter/pull/143932)_
- * Replace CocoaPods deprecated `exists?` with `exist?` by @vashworth in [147056](https://github.com/flutter/flutter/pull/147056)
  - _* Update docs around ga3 ga4 mismatch by @eliasyishak in [147075](https://github.com/flutter/flutter/pull/147075)_
- * Fixes `flutter build ipa` failure: Command line name "app-store" is deprecated. Use "app-store-connect" by @LouiseHsu in [150407](https://github.com/flutter/flutter/pull/150407)
  - _* Have flutter.js load local canvaskit instead of the CDN when appropriate by @eyebrowsoffire in [150806](https://github.com/flutter/flutter/pull/150806)_
- * Remove outdated `deprecated_member_use` ignores by @goderbauer in [51836](https://github.com/flutter/engine/pull/51836)
  - _* Revert "Prevent `solo: true` from being committed" by @zanderso in [51858](https://github.com/flutter/engine/pull/51858)_
- * Use non-deprecated replacements for Android JUnit and test instrumentation by @matanlurey in [51854](https://github.com/flutter/engine/pull/51854)
  - _* [scenarios] dont do a weird invalidate on TextView. by @jonahwilliams in [51866](https://github.com/flutter/engine/pull/51866)_
- * Remove TODO I will never do: `runIfNot` is deprecated. by @matanlurey in [52308](https://github.com/flutter/engine/pull/52308)
  - _* Document the new binding hooks for SceneBuilder, PictureRecorder, Canvas by @Hixie in [52374](https://github.com/flutter/engine/pull/52374)_
- * Migrate off deprecated GrVkBackendContext fields by @kjlubick in [53122](https://github.com/flutter/engine/pull/53122)
  - _* [Impeller] fix NPE caused by implicit sk_sp to fml::Status conversion. by @jonahwilliams in [53177](https://github.com/flutter/engine/pull/53177)_
- * Update uses of GrVkBackendContext and other deprecated type names by @kjlubick in [53491](https://github.com/flutter/engine/pull/53491)
  - _* [fuchsia] Update Fuchsia API level to 19 by @jrwang in [53494](https://github.com/flutter/engine/pull/53494)_

**Breaking Change** (4)

- * Fix TwoDimensionalViewport's keep alive child not always removed (when no longer should be kept alive) by @gawi151 in [148298](https://github.com/flutter/flutter/pull/148298)
  - _* Add test for text_editing_controller.0.dart API example. by @ksokolovskyi in [148872](https://github.com/flutter/flutter/pull/148872)_
- * Fix some links in the "Handling breaking change" section by @mdebbar in [149821](https://github.com/flutter/flutter/pull/149821)
  - _* Fix leaky test. by @polina-c in [149822](https://github.com/flutter/flutter/pull/149822)_
- * Removed brand references from MenuAnchor.dart by @davidhicks980 in [148760](https://github.com/flutter/flutter/pull/148760)
  - _* `switch` expressions: finale by @nate-thegrate in [148711](https://github.com/flutter/flutter/pull/148711)_
- * [Impeller] removed old blur detritus by @gaaclarke in [51779](https://github.com/flutter/engine/pull/51779)
  - _* [Impeller] Set RGBA8888 as the default Vulkan color format before the app acquires a surface by @jason-simmons in [51770](https://github.com/flutter/engine/pull/51770)_

**Performance Improvement** (25)

- * Improved documentation for SpringSimulation by @drown0315 in [146674](https://github.com/flutter/flutter/pull/146674)
  - _* Fix memory leaks in `CupertinoSwitch` by @ValentinVignal in [147821](https://github.com/flutter/flutter/pull/147821)_
- * improve focus example by @NobodyForNothing in [147464](https://github.com/flutter/flutter/pull/147464)
  - _* Implement `RenderEditable.computeDryBaseline` by @LongCatIsLooong in [147911](https://github.com/flutter/flutter/pull/147911)_
- * Improve the behavior of scrollbar drag-scrolls triggered by the trackpad by @HansMuller in [150275](https://github.com/flutter/flutter/pull/150275)
  - _* Copy any previous `IconThemeData` instead of overwriting it in CupertinoButton by @ricardoboss in [149777](https://github.com/flutter/flutter/pull/149777)_
- * Reduce the depth used in a test that applies finders to deep widget trees by @jason-simmons in [151049](https://github.com/flutter/flutter/pull/151049)
  - _* More docimports for animation library by @goderbauer in [151011](https://github.com/flutter/flutter/pull/151011)_
- * [Doctor] Improve CocoaPods messages by @loic-sharma in [146701](https://github.com/flutter/flutter/pull/146701)
  - _* Roll pub packages by @flutter-pub-roller-bot in [146929](https://github.com/flutter/flutter/pull/146929)_
- * Improve Android SDK and NDK mistmatch warning message by @bartekpacia in [147809](https://github.com/flutter/flutter/pull/147809)
  - _* Add kotlinOptions jvmTarget to templates by @gmackall in [147326](https://github.com/flutter/flutter/pull/147326)_
- * Improve build time when using SwiftPM by @vashworth in [150052](https://github.com/flutter/flutter/pull/150052)
  - _* Suppress Flutter update check if `--machine` is present at all. by @matanlurey in [150138](https://github.com/flutter/flutter/pull/150138)_
- * [CLI tool] in `flutter test`, consider `--flavor` when validating the cached asset bundle by @andrewkolos in [150461](https://github.com/flutter/flutter/pull/150461)
  - _* [flutter_tools] un-hide the --dds flag by @christopherfujino in [150280](https://github.com/flutter/flutter/pull/150280)_
- * Refactor fuchsia_precache by @sealesj in [145978](https://github.com/flutter/flutter/pull/145978)
  - _* Update ownership to GitHub handles by @keyonghan in [146221](https://github.com/flutter/flutter/pull/146221)_
- * [Impeller] Optimize away intersect clips that cover the entire pass target. by @bdero in [51736](https://github.com/flutter/engine/pull/51736)
  - _* Reland: [Impeller] adds a plus advanced blend for f16 pixel formats by @gaaclarke in [51756](https://github.com/flutter/engine/pull/51756)_
- * [Impeller] reland foreground blend optimizaiton, fix advanced blend optimization. by @jonahwilliams in [51938](https://github.com/flutter/engine/pull/51938)
  - _* [Impeller] handle fill polylines with zero area. by @jonahwilliams in [51945](https://github.com/flutter/engine/pull/51945)_
- * Various documentation improvements by @Hixie in [52600](https://github.com/flutter/engine/pull/52600)
  - _* Reverts "Various documentation improvements (#52600)" by @auto-submit in [52607](https://github.com/flutter/engine/pull/52607)_
- * Reverts "Various documentation improvements (#52600)" by @auto-submit in [52607](https://github.com/flutter/engine/pull/52607)
  - _* [Impeller] allow cloning a rectangle packer with an increased size. by @jonahwilliams in [52563](https://github.com/flutter/engine/pull/52563)_
- * Various documentation improvements (#52600) by @Hixie in [52623](https://github.com/flutter/engine/pull/52623)
  - _* Revert "Various documentation improvements (#52600)" by @zanderso in [52709](https://github.com/flutter/engine/pull/52709)_
- * Revert "Various documentation improvements (#52600)" by @zanderso in [52709](https://github.com/flutter/engine/pull/52709)
  - _* [impeller] adds experimental canvas docstring by @gaaclarke in [52710](https://github.com/flutter/engine/pull/52710)_
- * [Impeller] leave glyph atlas in transfer dst to improve vulkan throughput. by @jonahwilliams in [52908](https://github.com/flutter/engine/pull/52908)
  - _* [Impeller] Fix use-after-move in SwapchainVK. by @bdero in [52933](https://github.com/flutter/engine/pull/52933)_
- * [Impeller] disabling the color write mask seems to improve performance on iOS compared to just the blend options. by @jonahwilliams in [53322](https://github.com/flutter/engine/pull/53322)
  - _* 'Starter Project': port planet fragment shader to impeller tests by @jtmcdole in [53362](https://github.com/flutter/engine/pull/53362)_
- * [DisplayList] Add support for clipOval to leverage Impeller optimization by @flar in [53622](https://github.com/flutter/engine/pull/53622)
  - _* Revert "[DisplayList] Add support for clipOval to leverage Impeller optimization" by @flar in [53629](https://github.com/flutter/engine/pull/53629)_
- * Revert "[DisplayList] Add support for clipOval to leverage Impeller optimization" by @flar in [53629](https://github.com/flutter/engine/pull/53629)
  - _* [Impeller] experimental canvas bdf support. by @jonahwilliams in [53597](https://github.com/flutter/engine/pull/53597)_
- * Reland [DisplayList] Add support for clipOval to leverage Impeller optimization by @flar in [53642](https://github.com/flutter/engine/pull/53642)
  - _* [Impeller] track the sizes of all outstanding MTLTexture allocations and report per frame in MB, matching Vulkan implementation. by @jonahwilliams in [53618](https://github.com/flutter/engine/pull/53618)_
- * Revert "Reland [DisplayList] Add support for clipOval to leverage Impeller optimization" by @jiahaog in [53705](https://github.com/flutter/engine/pull/53705)
- * Migrate FlutterCallbackCache and FlutterKeyboardManager to ARC by @jmagman in [51983](https://github.com/flutter/engine/pull/51983)
  - _* Migrate FlutterDartVMServicePublisher to ARC by @jmagman in [52081](https://github.com/flutter/engine/pull/52081)_
- * [Impeller] while we still have benchmarks, see if we're efficient enough for this to be faster. by @jonahwilliams in [52398](https://github.com/flutter/engine/pull/52398)
  - _* Remove "gclient sync" warning call during pre-rebase by @jmagman in [52342](https://github.com/flutter/engine/pull/52342)_
- * Reduce rebuild times when invoking 'et run' by @johnmccutchan in [52883](https://github.com/flutter/engine/pull/52883)
  - _* Rename Skia specific TUs. by @chinmaygarde in [52855](https://github.com/flutter/engine/pull/52855)_
- * Add an unoptimized Android debug config to local_engine.json. by @chinmaygarde in [53057](https://github.com/flutter/engine/pull/53057)
  - _* Remove use of --nnbd-agnostic by @johnniwinther in [53055](https://github.com/flutter/engine/pull/53055)_

**Replacement / Migration** (31)

- * Make goldenFileComparator a field instead of a trivial property by @Hixie in [146800](https://github.com/flutter/flutter/pull/146800)
  - _* Bump meta to 1.14.0 by @goderbauer in [146925](https://github.com/flutter/flutter/pull/146925)_
- * Use super.key instead of manually passing the Key parameter to the parent class by @EchoEllet in [147621](https://github.com/flutter/flutter/pull/147621)
  - _* test material text field example by @NobodyForNothing in [147864](https://github.com/flutter/flutter/pull/147864)_
- * Switch to `Iterable.cast` instance method by @parlough in [150185](https://github.com/flutter/flutter/pull/150185)
  - _* Add tests for navigator.0.dart by @ValentinVignal in [150034](https://github.com/flutter/flutter/pull/150034)_
- * Copy any previous `IconThemeData` instead of overwriting it in CupertinoButton by @ricardoboss in [149777](https://github.com/flutter/flutter/pull/149777)
  - _* Manual engine roll to ddd4814 by @gmackall in [150952](https://github.com/flutter/flutter/pull/150952)_
- * Switch to FilterQuality.medium for images by @goderbauer in [148799](https://github.com/flutter/flutter/pull/148799)
  - _* Fix InputDecorator default hint text style on M3 by @bleroux in [148944](https://github.com/flutter/flutter/pull/148944)_
- * Switch to more reliable flutter.dev link destinations in the tool by @parlough in [150587](https://github.com/flutter/flutter/pull/150587)
  - _* [tool] when writing to openssl as a part of macOS/iOS code-signing, flush the stdin stream before closing it by @andrewkolos in [150120](https://github.com/flutter/flutter/pull/150120)_
- * Use --(no-)strip-wams instead of --(no-)-name-section in `dart compile wasm` by @mkustermann in [150180](https://github.com/flutter/flutter/pull/150180)
  - _* Reland "Identify and re-throw our dependency checking errors in flutter.groovy" by @gmackall in [150128](https://github.com/flutter/flutter/pull/150128)_
- * Use --(no-)strip-wams instead of --(no-)-name-section in `dart compile wasm` by @mkustermann in [149641](https://github.com/flutter/flutter/pull/149641)
  - _* Roll pub packages by @flutter-pub-roller-bot in [150206](https://github.com/flutter/flutter/pull/150206)_
- * Have flutter.js load local canvaskit instead of the CDN when appropriate by @eyebrowsoffire in [150806](https://github.com/flutter/flutter/pull/150806)
  - _* [tool] make the `systemTempDirectory` getter on `ErrorHandlingFileSystem` wrap the underlying filesystem's temp directory in a`ErrorHandlingDirectory` by @andrewkolos in [150876](https://github.com/flutter/flutter/pull/150876)_
- * Switch to relevant `Remote` constructors by @nate-thegrate in [146773](https://github.com/flutter/flutter/pull/146773)
  - _* Create web tests suite & update utils by @sealesj in [146592](https://github.com/flutter/flutter/pull/146592)_
- * Switch to triage-* labels for platform package triage by @stuartmorgan in [149614](https://github.com/flutter/flutter/pull/149614)
  - _* Bump github/codeql-action from 3.25.7 to 3.25.8 by @dependabot in [149691](https://github.com/flutter/flutter/pull/149691)_
- * Use `fml::ScopedCleanupClosure` instead of `DeathRattle`. by @matanlurey in [51834](https://github.com/flutter/engine/pull/51834)
  - _* Return an empty optional in HardwareBuffer::GetSystemUniqueID if the underlying NDK API is unavailable by @jason-simmons in [51839](https://github.com/flutter/engine/pull/51839)_
- * [Impeller] make color source a variant instead of a closure. by @jonahwilliams in [51853](https://github.com/flutter/engine/pull/51853)
  - _* [Impeller] eliminate sub-render pass for blended color + texture vertices. by @jonahwilliams in [51778](https://github.com/flutter/engine/pull/51778)_
- * [Impeller] moved to bgra10_xr by @gaaclarke in [52019](https://github.com/flutter/engine/pull/52019)
  - _* Reverts "[Impeller] moved to bgra10_xr (#52019)" by @auto-submit in [52140](https://github.com/flutter/engine/pull/52140)_
- * Reverts "[Impeller] moved to bgra10_xr (#52019)" by @auto-submit in [52140](https://github.com/flutter/engine/pull/52140)
  - _* [Impeller] Update the readme to reflect current guidance on how to try Impeller. by @chinmaygarde in [52135](https://github.com/flutter/engine/pull/52135)_
- * Relands "[Impeller] moved to bgra10_xr (#52019)" by @gaaclarke in [52142](https://github.com/flutter/engine/pull/52142)
  - _* [Impeller] remove most temporary allocation during polyline generation. by @jonahwilliams in [52131](https://github.com/flutter/engine/pull/52131)_
- * [Impeller] Use booleans instead of counting backdrop reads. by @bdero in [52181](https://github.com/flutter/engine/pull/52181)
  - _* [Impeller] Remove old clip height tracking from Entity. by @bdero in [52178](https://github.com/flutter/engine/pull/52178)_
- * [Impeller] Update BlitPass::AddCopy to use destination_region instead of origin for buffer to texture copies. by @jonahwilliams in [52555](https://github.com/flutter/engine/pull/52555)
  - _* [Impeller] require and use backpressure for AHB swapchain. by @jonahwilliams in [52676](https://github.com/flutter/engine/pull/52676)_
- * [Impeller] Create framebuffer blend vertices based on the snapshot's texture size instead of coverage by @jason-simmons in [52790](https://github.com/flutter/engine/pull/52790)
  - _* [Impeller] migrated one test over from aiks to dl by @gaaclarke in [52786](https://github.com/flutter/engine/pull/52786)_
- * [Impeller] grow glyph atlas instead of resizing when rect packer is full. by @jonahwilliams in [52849](https://github.com/flutter/engine/pull/52849)
  - _* [Impeller] fix colr/bitmap font color drawing. by @jonahwilliams in [52871](https://github.com/flutter/engine/pull/52871)_
- * [DisplayList] Switch to recording DrawVertices objects by reference by @flar in [53548](https://github.com/flutter/engine/pull/53548)
  - _* [Impeller] blur - cropped the downsample pass for backdrop filters by @gaaclarke in [53562](https://github.com/flutter/engine/pull/53562)_
- * Issue an`ERROR` instead of an `INFO` for a non-working API. by @matanlurey in [52892](https://github.com/flutter/engine/pull/52892)
  - _* Fix another instance of platform view breakage on Android 14 by @johnmccutchan in [52980](https://github.com/flutter/engine/pull/52980)_
- * [web:tests] switch to new HTML DOM matcher by @yjbanov in [52354](https://github.com/flutter/engine/pull/52354)
  - _* Make SkUnicode explicitly instead of relying on SkParagraph to make it for us by @kjlubick in [52086](https://github.com/flutter/engine/pull/52086)_
- * Make SkUnicode explicitly instead of relying on SkParagraph to make it for us by @kjlubick in [52086](https://github.com/flutter/engine/pull/52086)
  - _* [skwasm] Change default `FilterQuality` to `None` for image shaders. by @eyebrowsoffire in [52468](https://github.com/flutter/engine/pull/52468)_
- * Move pictures from deleted canvases to second-to-last canvas instead of last. by @harryterkelsen in [51397](https://github.com/flutter/engine/pull/51397)
  - _* Allow unsetting `TextStyle.height` by @LongCatIsLooong in [52940](https://github.com/flutter/engine/pull/52940)_
- * Switch to FilterQuality.medium for images by @goderbauer in [52984](https://github.com/flutter/engine/pull/52984)
  - _* Replace several calls to GrGLMakeNativeInterface with more direct APIs by @kjlubick in [53064](https://github.com/flutter/engine/pull/53064)_
- * [web] switch from .didGain/LoseAccessibilityFocus to .focus by @yjbanov in [53134](https://github.com/flutter/engine/pull/53134)
  - _* Fix character getter API usage in stripLeftSlashes/stripRightSlashes by @jason-simmons in [53299](https://github.com/flutter/engine/pull/53299)_
- * [web] switch from .didGain/LoseAccessibilityFocus to .focus by @yjbanov in [53360](https://github.com/flutter/engine/pull/53360)
  - _* [web] Fixes drag scrolling in embedded mode. by @ditman in [53647](https://github.com/flutter/engine/pull/53647)_
- * Revert "[web] switch from .didGain/LoseAccessibilityFocus to .focus" by @jiahaog in [53679](https://github.com/flutter/engine/pull/53679)
  - _* Reland "Output .js files as ES6 modules. (#52023)" by @eyebrowsoffire in [53688](https://github.com/flutter/engine/pull/53688)_
- * [macOS] Move to new present callback by @dkwingsmt in [51436](https://github.com/flutter/engine/pull/51436)
  - _* [Windows] Fix EGL surface destruction race by @loic-sharma in [51781](https://github.com/flutter/engine/pull/51781)_
- * Revert "[web] switch from .didGain/LoseAccessibilityFocus to .focus (… by @yjbanov in [53342](https://github.com/flutter/engine/pull/53342)
  - _* [Impeller] makes bgra10xr test more comprehensive by @gaaclarke in [53320](https://github.com/flutter/engine/pull/53320)_

---

### 3.22.0

**Deprecation** (22)

- * Deprecate redundant itemExtent in RenderSliverFixedExtentBoxAdaptor methods by @Piinks in [143412](https://github.com/flutter/flutter/pull/143412)
  - _* Disable color filter sepia test for Impeller. by @jonahwilliams in [143861](https://github.com/flutter/flutter/pull/143861)_
- * Remove deprecated FlutterDriver.enableAccessibility by @Piinks in [143979](https://github.com/flutter/flutter/pull/143979)
  - _* Remove deprecated MediaQuery.boldTextOverride by @goderbauer in [143960](https://github.com/flutter/flutter/pull/143960)_
- * Remove deprecated MediaQuery.boldTextOverride by @goderbauer in [143960](https://github.com/flutter/flutter/pull/143960)
  - _* Remove deprecated TimelineSummary.writeSummaryToFile by @Piinks in [143983](https://github.com/flutter/flutter/pull/143983)_
- * Remove deprecated TimelineSummary.writeSummaryToFile by @Piinks in [143983](https://github.com/flutter/flutter/pull/143983)
  - _* Remove deprecated AnimatedListItemBuilder, AnimatedListRemovedItemBuilder by @goderbauer in [143974](https://github.com/flutter/flutter/pull/143974)_
- * Remove deprecated AnimatedListItemBuilder, AnimatedListRemovedItemBuilder by @goderbauer in [143974](https://github.com/flutter/flutter/pull/143974)
  - _* Remove deprecated `KeepAliveHandle.release` by @LongCatIsLooong in [143961](https://github.com/flutter/flutter/pull/143961)_
- * Remove deprecated `KeepAliveHandle.release` by @LongCatIsLooong in [143961](https://github.com/flutter/flutter/pull/143961)
  - _* Remove deprecated `InteractiveViewer.alignPanAxis` by @LongCatIsLooong in [142500](https://github.com/flutter/flutter/pull/142500)_
- * Remove deprecated `InteractiveViewer.alignPanAxis` by @LongCatIsLooong in [142500](https://github.com/flutter/flutter/pull/142500)
  - _* disable debug banner in m3 page test apps. by @jonahwilliams in [143857](https://github.com/flutter/flutter/pull/143857)_
- * Remove deprecated `CupertinoContextMenu.previewBuilder` by @LongCatIsLooong in [143990](https://github.com/flutter/flutter/pull/143990)
  - _* Clean up lint ignores by @eliasyishak in [144229](https://github.com/flutter/flutter/pull/144229)_
- * Add WidgetsApp.debugShowWidgetInspectorOverride again (deprecated) by @passsy in [145334](https://github.com/flutter/flutter/pull/145334)
  - _* `flutter test --wasm` support by @eyebrowsoffire in [145347](https://github.com/flutter/flutter/pull/145347)_
- * Deprecate M2 curves by @guidezpl in [134417](https://github.com/flutter/flutter/pull/134417)
  - _* Reland "Remove hack from PageView." by @polina-c in [141533](https://github.com/flutter/flutter/pull/141533)_
- * cleanup now-irrelevant ignores for `deprecated_member_use` by @goderbauer in [143403](https://github.com/flutter/flutter/pull/143403)
  - _* [a11y] Fix date picker cannot focus on the edit field by @hangyujin in [143117](https://github.com/flutter/flutter/pull/143117)_
- * Remove deprecated `backgroundColor` from `ThemeData` by @QuncCccccc in [144079](https://github.com/flutter/flutter/pull/144079)
  - _* Reland [a11y] Fix date picker cannot focus on the edit field by @hangyujin in [144198](https://github.com/flutter/flutter/pull/144198)_
- * Remove deprecated `errorColor` from `ThemeData` by @QuncCccccc in [144078](https://github.com/flutter/flutter/pull/144078)
  - _* [flutter_test] Change KeyEventSimulator default transit mode by @bleroux in [143847](https://github.com/flutter/flutter/pull/143847)_
- * Remove deprecated `TextTheme` members by @Renzo-Olivares in [139255](https://github.com/flutter/flutter/pull/139255)
  - _* Update `TabBar` and `TabBar.secondary` to use indicator height/color M3 tokens by @TahaTesser in [145753](https://github.com/flutter/flutter/pull/145753)_
- * Replace deprecated `exists` in podhelper.rb by @stuartmorgan in [141169](https://github.com/flutter/flutter/pull/141169)
  - _* Unpin package:vm_service by @derekxu16 in [141279](https://github.com/flutter/flutter/pull/141279)_
- * Remove unused deprecated autoroll mirror-remote flag by @jmagman in [142738](https://github.com/flutter/flutter/pull/142738)
  - _* Fix gen_defaults test randomness by @davidmartos96 in [142743](https://github.com/flutter/flutter/pull/142743)_
- * Allow deprecated members from the Dart SDK and Flutter Engine to roll in by @matanlurey in [143347](https://github.com/flutter/flutter/pull/143347)
  - _* Bump github/codeql-action from 3.24.0 to 3.24.1 by @dependabot in [143395](https://github.com/flutter/flutter/pull/143395)_
- * Disable deprecation warnings for mega_gallery by @goderbauer in [143466](https://github.com/flutter/flutter/pull/143466)
  - _* Remove certs installation from win_arm builds. by @godofredoc in [143487](https://github.com/flutter/flutter/pull/143487)_
- * Migrate use of deprecated GrDirectContext::MakeMetal by @kjlubick in [51537](https://github.com/flutter/engine/pull/51537)
  - _* Move //buildtools to //flutter/buildtools by @jason-simmons in [51526](https://github.com/flutter/engine/pull/51526)_
- * Allow deprecated members from the Dart SDK to roll in. by @matanlurey in [50575](https://github.com/flutter/engine/pull/50575)
  - _* [engine_build_configs] Use dart:ffi Abi to determine the host cpu by @zanderso in [50604](https://github.com/flutter/engine/pull/50604)_
- * [Fuchsia] Create dedicated testers to run tests and deprecate femu_test by @zijiehe-google-com in [50697](https://github.com/flutter/engine/pull/50697)
  - _* [et] Adds a .bat entrypoint for Windows by @zanderso in [50784](https://github.com/flutter/engine/pull/50784)_
- * Update one more use of deprecated GrDirectContext::MakeMetal by @kjlubick in [51619](https://github.com/flutter/engine/pull/51619)
  - _* [Embedder API] Add helper to create viewport metrics by @loic-sharma in [51562](https://github.com/flutter/engine/pull/51562)_

**Breaking Change** (4)

- * Remove deprecated AnimatedListItemBuilder, AnimatedListRemovedItemBuilder by @goderbauer in [143974](https://github.com/flutter/flutter/pull/143974)
  - _* Remove deprecated `KeepAliveHandle.release` by @LongCatIsLooong in [143961](https://github.com/flutter/flutter/pull/143961)_
- * [Impeller] blur: removed ability to request out of bounds mip_counts by @gaaclarke in [50290](https://github.com/flutter/engine/pull/50290)
  - _* [Impeller] Allow playgrounds to use SwiftShader via a flag. by @chinmaygarde in [50298](https://github.com/flutter/engine/pull/50298)_
- * [Impeller] cleaned up StrokePathGeometry and removed runtime polymorphism by @gaaclarke in [50506](https://github.com/flutter/engine/pull/50506)
  - _* [Impeller] Call vkQueuePresentKHR through the ContextVK's synchronized graphics queue wrapper by @jason-simmons in [50509](https://github.com/flutter/engine/pull/50509)_
- * [Impeller] cleaned up and removed golden test exceptions by @gaaclarke in [50572](https://github.com/flutter/engine/pull/50572)
  - _* [Impeller] replaced playground macros with functions by @gaaclarke in [50602](https://github.com/flutter/engine/pull/50602)_

**New Feature / API** (2)

- * [New feature]Introduce iOS multi-touch drag behavior by @xu-baolin in [141355](https://github.com/flutter/flutter/pull/141355)
  - _* Set cacheExtent for SliverFillRemaining widget by @vashworth in [143612](https://github.com/flutter/flutter/pull/143612)_
- * Introduce methods for computing the baseline location of a RenderBox without affecting the current layout by @LongCatIsLooong in [144655](https://github.com/flutter/flutter/pull/144655)
  - _* Fix for issue 140372 by @prasadsunny1 in [144947](https://github.com/flutter/flutter/pull/144947)_

**Performance Improvement** (59)

- * Improve testing for leak tracking. by @polina-c in [140553](https://github.com/flutter/flutter/pull/140553)
  - _* Fix mechanism to pass flag for leak tracking. by @polina-c in [141226](https://github.com/flutter/flutter/pull/141226)_
- * Add covariants to reduce subclass casts in 2D APIs by @Piinks in [141318](https://github.com/flutter/flutter/pull/141318)
  - _* Fix a leak. by @polina-c in [141312](https://github.com/flutter/flutter/pull/141312)_
- * PopScope example improvements by @justinmc in [142163](https://github.com/flutter/flutter/pull/142163)
  - _* Implementing `switch` expressions in the `cupertino/` directory by @nate-thegrate in [141591](https://github.com/flutter/flutter/pull/141591)_
- * Dispose precached image info by @dnfield in [143017](https://github.com/flutter/flutter/pull/143017)
  - _* Handle transitions to AppLifecycleState.detached in lifecycle state generation by @maRci002 in [142523](https://github.com/flutter/flutter/pull/142523)_
- * Fix: performance improvement on golden test comparison by @krispypen in [142913](https://github.com/flutter/flutter/pull/142913)
  - _* Upgrade leak_tracker. by @polina-c in [143236](https://github.com/flutter/flutter/pull/143236)_
- * Cache `FocusNode.enclosingScope`, clean up `descendantsAreFocusable` by @LongCatIsLooong in [144207](https://github.com/flutter/flutter/pull/144207)
  - _* Remove deprecated `CupertinoContextMenu.previewBuilder` by @LongCatIsLooong in [143990](https://github.com/flutter/flutter/pull/143990)_
- * Reverts "Cache `FocusNode.enclosingScope`, clean up `descendantsAreFocusable` (#144207)" by @auto-submit in [144292](https://github.com/flutter/flutter/pull/144292)
  - _* Remove irrelevant comment in TextPainter by @tgucio in [144308](https://github.com/flutter/flutter/pull/144308)_
- * Reland "Cache FocusNode.enclosingScope, clean up descendantsAreFocusable (#144207)" by @LongCatIsLooong in [144330](https://github.com/flutter/flutter/pull/144330)
  - _* Use robolectric/AndroidJUnit4 for integration test tests by @dnfield in [144348](https://github.com/flutter/flutter/pull/144348)_
- * [web][docs] Improve HtmlElementView widget docs. by @ditman in [145192](https://github.com/flutter/flutter/pull/145192)
  - _* Fix typo in hitTest docs by @ksokolovskyi in [145677](https://github.com/flutter/flutter/pull/145677)_
- * Style correctness improvements for toStrings and related fixes by @Hixie in [142485](https://github.com/flutter/flutter/pull/142485)
  - _* M3 - Fix Chip icon and label colors by @davidmartos96 in [140573](https://github.com/flutter/flutter/pull/140573)_
- * Various improvements to text-editing-related documentation. by @Hixie in [142561](https://github.com/flutter/flutter/pull/142561)
  - _* Fixed cursor blinking during selection. by @yiiim in [141380](https://github.com/flutter/flutter/pull/141380)_
- * Improve some scrollbar error messages by @loic-sharma in [143279](https://github.com/flutter/flutter/pull/143279)
  - _* InputDecorator M3 test migration step2 by @bleroux in [143369](https://github.com/flutter/flutter/pull/143369)_
- * Add missing parameter to `TableBorder.symmetric`, and improve class constructors by @nate-thegrate in [144279](https://github.com/flutter/flutter/pull/144279)
  - _* Revert "_DefaultTabControllerState should dispose all created TabContoller instances. (#136608)" by @goderbauer in [144579](https://github.com/flutter/flutter/pull/144579)_
- * improve error message when `--base-href` argument does not start with `/` by @andrewkolos in [142667](https://github.com/flutter/flutter/pull/142667)
  - _* Wasm/JS Dual Compile with the flutter tool by @eyebrowsoffire in [141396](https://github.com/flutter/flutter/pull/141396)_
- * Improve build output for all platforms by @guidezpl in [128236](https://github.com/flutter/flutter/pull/128236)
  - _* Reverts "Improve build output for all platforms" by @auto-submit in [143125](https://github.com/flutter/flutter/pull/143125)_
- * Reverts "Improve build output for all platforms" by @auto-submit in [143125](https://github.com/flutter/flutter/pull/143125)
  - _* Pass along web renderer into debugging options in the test command. by @eyebrowsoffire in [143128](https://github.com/flutter/flutter/pull/143128)_
- * Flutter Web Bootstrapping Improvements by @eyebrowsoffire in [144434](https://github.com/flutter/flutter/pull/144434)
  - _* Update proxied devices to handle connection interface and diagnostics. by @chingjun in [145061](https://github.com/flutter/flutter/pull/145061)_
- * Reland #128236 "Improve build output for all platforms" by @guidezpl in [143166](https://github.com/flutter/flutter/pull/143166)
  - _* Reverts "Reland #128236 "Improve build output for all platforms" (#143166)" by @auto-submit in [145261](https://github.com/flutter/flutter/pull/145261)_
- * Reverts "Reland #128236 "Improve build output for all platforms" (#143166)" by @auto-submit in [145261](https://github.com/flutter/flutter/pull/145261)
  - _* Roll pub packages + update DAP tests by @DanTup in [145349](https://github.com/flutter/flutter/pull/145349)_
- * Reland #128236 "Improve build output for all platforms" by @guidezpl in [145376](https://github.com/flutter/flutter/pull/145376)
  - _* Reverts "Reland #128236 "Improve build output for all platforms" (#145376)" by @auto-submit in [145487](https://github.com/flutter/flutter/pull/145487)_
- * Reverts "Reland #128236 "Improve build output for all platforms" (#145376)" by @auto-submit in [145487](https://github.com/flutter/flutter/pull/145487)
  - _* Remove embedding v1 code in framework by @gmackall in [144726](https://github.com/flutter/flutter/pull/144726)_
- * Reland #128236 "Improve build output for all platforms" by @guidezpl in [145495](https://github.com/flutter/flutter/pull/145495)
  - _* make hot reload reflect changes to asset transformer configurations by @andrewkolos in [144660](https://github.com/flutter/flutter/pull/144660)_
- * Reduce Windows_arm64 plugin_test_windows test timeout by @loic-sharma in [145110](https://github.com/flutter/flutter/pull/145110)
  - _* Run gradle_plugin_*_apk_test on presubmit on flutter_tool changes. by @eyebrowsoffire in [142090](https://github.com/flutter/flutter/pull/142090)_
- * [Flutter GPU] Shader bundle improvements: Uniform structs & member offset reflection, GLES metadata, separate from runtime stage. by @bdero in [49485](https://github.com/flutter/engine/pull/49485)
  - _* [Impeller] Start and end a frame in the RenderTargetCache for each rendering of an entity in the playgrounds by @jason-simmons in [49576](https://github.com/flutter/engine/pull/49576)_
- * [Impeller] Start and end a frame in the RenderTargetCache for each rendering of an entity in the playgrounds by @jason-simmons in [49576](https://github.com/flutter/engine/pull/49576)
  - _* [Impeller] Document mip bias. by @bdero in [49602](https://github.com/flutter/engine/pull/49602)_
- * Optimizations for TLHC frame rate and jank by @johnmccutchan in [50033](https://github.com/flutter/engine/pull/50033)
  - _* winding order from tesellator.h to formats.h by @nikkivirtuoso in [49865](https://github.com/flutter/engine/pull/49865)_
- * [Impeller] Fix advanced blend alpha issue, improve blend goldens. by @bdero in [50035](https://github.com/flutter/engine/pull/50035)
  - _* Finish landing missing/incorrect header guards across `flutter/engine` by @matanlurey in [50069](https://github.com/flutter/engine/pull/50069)_
- * [Android] Cache GPU resources using HardwareBuffer's id as key by @jonahwilliams in [50028](https://github.com/flutter/engine/pull/50028)
  - _* [Impeller] add missing barrier to compute tessellator. by @jonahwilliams in [50108](https://github.com/flutter/engine/pull/50108)_
- * Cache Impeller paths in the DisplayList to amortize conversion by @flar in [50076](https://github.com/flutter/engine/pull/50076)
  - _* [Impeller] Fix alpha management issues for advanced blends. by @bdero in [50070](https://github.com/flutter/engine/pull/50070)_
- * [Impeller] Cache RenderPass/Framebuffer objects on the resolve texture sources. by @jonahwilliams in [50142](https://github.com/flutter/engine/pull/50142)
  - _* [Impeller] Specify if Angle or SwiftShader is being used in the title. by @chinmaygarde in [50376](https://github.com/flutter/engine/pull/50376)_
- * [Impeller] improve performance of polyline and stroke generation by reducing allocation and lambda usage. by @jonahwilliams in [50379](https://github.com/flutter/engine/pull/50379)
  - _* [Impeller] cleaned up StrokePathGeometry and removed runtime polymorphism by @gaaclarke in [50506](https://github.com/flutter/engine/pull/50506)_
- * [Impeller] add additional setup method that caches more pipelines, warms internal shader code by @jonahwilliams in [50521](https://github.com/flutter/engine/pull/50521)
  - _* [Impeller] Fix golden flake due to rand use. by @bdero in [50743](https://github.com/flutter/engine/pull/50743)_
- * [Impeller] cache onscreen render targets. by @jonahwilliams in [50751](https://github.com/flutter/engine/pull/50751)
  - _* [Impeller] applied the lerp hack to blur (roughly 2x speedup?) by @gaaclarke in [50790](https://github.com/flutter/engine/pull/50790)_
- * Reverts "[Impeller] cache onscreen render targets. (#50751)" by @auto-submit in [50871](https://github.com/flutter/engine/pull/50871)
  - _* [Impeller] Add stroke benchmarks that create UVs with no transform by @flar in [50847](https://github.com/flutter/engine/pull/50847)_
- * [Impeller] Cache entire render target and not just allocations. by @jonahwilliams in [50990](https://github.com/flutter/engine/pull/50990)
  - _* Prefix flutter in flutter_vma.h import by @CaseyHillers in [51065](https://github.com/flutter/engine/pull/51065)_
- * [Impeller] Create a new render target with the specified attachment configs when reusing cached render target textures by @jason-simmons in [51208](https://github.com/flutter/engine/pull/51208)
  - _* [Impeller] Apply padding for alignment when doing HostBuffer::Emplace with a callback by @jason-simmons in [51221](https://github.com/flutter/engine/pull/51221)_
- * [Impeller] More efficient usage of transient onscreen attachments. by @jonahwilliams in [51206](https://github.com/flutter/engine/pull/51206)
  - _* [Impeller] Add the KHR prefix to existing swapchain utilities. by @chinmaygarde in [51295](https://github.com/flutter/engine/pull/51295)_
- * [Impeller] Check for empty sizes when creating render targets in RenderTargetCache by @jason-simmons in [51597](https://github.com/flutter/engine/pull/51597)
  - _* [Impeller] fix unbalanced restores. by @jonahwilliams in [51648](https://github.com/flutter/engine/pull/51648)_
- * [Impeller] revert usage of foreground blend optimization. by @jonahwilliams in [51679](https://github.com/flutter/engine/pull/51679)
  - _* [Impeller] Simplify calculation of Matrix::GetMaxBasisXY() by @flar in [51664](https://github.com/flutter/engine/pull/51664)_
- * Reverts "Optimizations for TLHC frame rate and jank" by @auto-submit in [50062](https://github.com/flutter/engine/pull/50062)
  - _* Reland Optimizations for TLHC frame rate and jank by @johnmccutchan in [50065](https://github.com/flutter/engine/pull/50065)_
- * Reland Optimizations for TLHC frame rate and jank by @johnmccutchan in [50065](https://github.com/flutter/engine/pull/50065)
  - _* Use clamp sampling mode in external texture. by @jonahwilliams in [50063](https://github.com/flutter/engine/pull/50063)_
- * Reverts "[Android] Cache GPU resources using HardwareBuffer's id as key" by @auto-submit in [50114](https://github.com/flutter/engine/pull/50114)
  - _* Manually revert TLHC optimizations, holding on to width/height changes. by @matanlurey in [50144](https://github.com/flutter/engine/pull/50144)_
- * Manually revert TLHC optimizations, holding on to width/height changes. by @matanlurey in [50144](https://github.com/flutter/engine/pull/50144)
  - _* Re-Re-land Manually revert TLHC optimizations by @johnmccutchan in [50155](https://github.com/flutter/engine/pull/50155)_
- * Re-Re-land Manually revert TLHC optimizations by @johnmccutchan in [50155](https://github.com/flutter/engine/pull/50155)
  - _* Revert: "Change how OpenGL textures are flipped in the Android embedder" by @matanlurey in [50158](https://github.com/flutter/engine/pull/50158)_
- * Optimize overlays in CanvasKit by @harryterkelsen in [47317](https://github.com/flutter/engine/pull/47317)
  - _* Mark the Flutter Views as focusable by setting a tabindex value. by @tugorez in [50876](https://github.com/flutter/engine/pull/50876)_
- * [Windows] Reduce Visual Studio build errors caused by keyboard unit tests by @loic-sharma in [49814](https://github.com/flutter/engine/pull/49814)
  - _* [Windows] Refactor logic when window resize completes by @loic-sharma in [49872](https://github.com/flutter/engine/pull/49872)_
- * [Windows] Improve `FlutterWindow` unit tests by @loic-sharma in [50676](https://github.com/flutter/engine/pull/50676)
  - _* [Windows] Make the engine create the view by @loic-sharma in [50673](https://github.com/flutter/engine/pull/50673)_
- * [Windows] Reduce log level of unsupported accessibility event message by @loic-sharma in [51024](https://github.com/flutter/engine/pull/51024)
  - _* [Windows] Add view ID runner APIs by @loic-sharma in [51020](https://github.com/flutter/engine/pull/51020)_
- * Move mac cache builder to bringup. by @godofredoc in [49843](https://github.com/flutter/engine/pull/49843)
  - _* Reverts "Manual roll Dart SDK from d6c08fa9bb54 to 6ff69d6b7f59 (15 revisions)" by @auto-submit in [49852](https://github.com/flutter/engine/pull/49852)_
- * Adding ignore paths to cache test by @ricardoamador in [49874](https://github.com/flutter/engine/pull/49874)
  - _* Reverts "[Fuchsia] Redo - Use chromium test-scripts to download images and execute tests" by @auto-submit in [49908](https://github.com/flutter/engine/pull/49908)_
- * Exclude prebuilts/Library from Mac builder_cache by @zanderso in [49971](https://github.com/flutter/engine/pull/49971)
  - _* Roll buildroot to 5d969bd98e31ec90c23ccb982666ace80559f442 by @zanderso in [49956](https://github.com/flutter/engine/pull/49956)_
- * Move Mac builder_cache to prod by @keyonghan in [50044](https://github.com/flutter/engine/pull/50044)
  - _* Revert Dart to Version 3.4.0-82.0.dev by @zanderso in [50131](https://github.com/flutter/engine/pull/50131)_
- * Remove/reduce unused or private methods and add tests to `SkiaGoldClient` by @matanlurey in [50844](https://github.com/flutter/engine/pull/50844)
  - _* Add a similar `runIf` guard to `web_engine` as web framework. by @matanlurey in [50846](https://github.com/flutter/engine/pull/50846)_
- * Move ban-plugin-java script into separate file and improve testing. by @matanlurey in [50875](https://github.com/flutter/engine/pull/50875)
  - _* Replace SkColorSpace::filterColor with filterColor4f by @brianosman in [50821](https://github.com/flutter/engine/pull/50821)_
- * [et] Improve the logger for the ninja build, adds a spinner by @zanderso in [50952](https://github.com/flutter/engine/pull/50952)
  - _* Better filtering for Android `scenario_app` runner. by @matanlurey in [50937](https://github.com/flutter/engine/pull/50937)_
- * Improve, test, and fix a bug related to `adb logcat` filtering. by @matanlurey in [51012](https://github.com/flutter/engine/pull/51012)
  - _* Remove rewrapper prefix from compiler commands for clang-tidy by @zanderso in [51001](https://github.com/flutter/engine/pull/51001)_
- * The `adb logcat` filtering will continue until morale improves. by @matanlurey in [51069](https://github.com/flutter/engine/pull/51069)
  - _* Use RBE for mac_clang_tidy by @zanderso in [51083](https://github.com/flutter/engine/pull/51083)_
- * Small improvements to et lint command by @johnmccutchan in [51372](https://github.com/flutter/engine/pull/51372)
  - _* [Embedder API] Add multi-view present callback by @loic-sharma in [51267](https://github.com/flutter/engine/pull/51267)_
- * Reduce code-duplication a bit and add more error context across `SkiaGoldClient`. by @matanlurey in [51426](https://github.com/flutter/engine/pull/51426)
  - _* Add DisplayList Region and Transform benchmarks to CI by @flar in [51429](https://github.com/flutter/engine/pull/51429)_

**Replacement / Migration** (12)

- * Fix chips use square delete button `InkWell` shape instead of circular by @TahaTesser in [144319](https://github.com/flutter/flutter/pull/144319)
  - _* Fix `CalendarDatePicker` day selection shape and overlay by @TahaTesser in [144317](https://github.com/flutter/flutter/pull/144317)_
- * Use Integer instead of int in map in flutter.groovy by @reidbaker in [141895](https://github.com/flutter/flutter/pull/141895)
  - _* Adjust the position of require File.expand_path by @LinXunFeng in [141521](https://github.com/flutter/flutter/pull/141521)_
- * instead of exiting the tool, print a warning when using --flavor with an incompatible device by @andrewkolos in [143735](https://github.com/flutter/flutter/pull/143735)
  - _* [flutter_tools] enable wasm compile on beta channel by @kevmoo in [143779](https://github.com/flutter/flutter/pull/143779)_
- * Fix frameworks added to bundle multiple times instead of lipo by @knopp in [144688](https://github.com/flutter/flutter/pull/144688)
  - _* [flutter_tools] add custom tool analysis to analyze.dart, lint Future.catchError by @christopherfujino in [140122](https://github.com/flutter/flutter/pull/140122)_
- * Reland "[Windows] Move to FlutterCompositor for rendering" by @loic-sharma in [49726](https://github.com/flutter/engine/pull/49726)
  - _* [Impeller] Fix a race between SwapchainImplVK::Present and WaitForFence by @jason-simmons in [49777](https://github.com/flutter/engine/pull/49777)_
- * [Impeller] Switch from transient stencil-only to depth+stencil buffer. by @bdero in [47987](https://github.com/flutter/engine/pull/47987)
  - _* Flutter GPU: Add GpuContext.createHostBuffer by @bdero in [49822](https://github.com/flutter/engine/pull/49822)_
- * Reverts "[Impeller] Switch from transient stencil-only to depth+stencil buffer." by @auto-submit in [49832](https://github.com/flutter/engine/pull/49832)
  - _* [Impeller] disabled misleading vulkan golden image tests by @gaaclarke in [49836](https://github.com/flutter/engine/pull/49836)_
- * [Impeller] Reland: Switch from transient stencil-only to depth+stencil buffer. by @bdero in [49838](https://github.com/flutter/engine/pull/49838)
  - _* [Impeller] fixed CanRenderClippedRuntimeEffects for vulkan by @gaaclarke in [49912](https://github.com/flutter/engine/pull/49912)_
- * [Impeller] Transform geometry to safe depth ranges instead of forcing discrete depth values. by @bdero in [51673](https://github.com/flutter/engine/pull/51673)
  - _* [Impeller] fix remaining Validation errors. by @jonahwilliams in [51692](https://github.com/flutter/engine/pull/51692)_
- * [ios]ignore single edge pixel instead of rounding by @hellohuanlin in [51687](https://github.com/flutter/engine/pull/51687)
- * [Windows] Move to new present callback by @loic-sharma in [51293](https://github.com/flutter/engine/pull/51293)
  - _* Regenerate FlutterMacOS.xcframework when sources of dependencies change by @vashworth in [51396](https://github.com/flutter/engine/pull/51396)_
- * Use top-level GN arg for Skottie instead of CanvasKit-specific arg. by @johnstiles-google in [50019](https://github.com/flutter/engine/pull/50019)
  - _* [Fuchsia] Redo - Use chromium test-scripts to download images and execute tests by @zijiehe-google-com in [49940](https://github.com/flutter/engine/pull/49940)_

---

### 3.19.0

**Deprecation** (16)

- * Change some usage of RawKeyEvent to KeyEvent in preparation for deprecation by @gspencergoog in [136420](https://github.com/flutter/flutter/pull/136420)
  - _* Test cover cupertino for memory leaks tracking -2 by @droidbg in [136577](https://github.com/flutter/flutter/pull/136577)_
- * [Android] Fix `FlutterTestRunner.java` deprecations by @camsim99 in [138093](https://github.com/flutter/flutter/pull/138093)
  - _* Remove physicalGeometry by @goderbauer in [138103](https://github.com/flutter/flutter/pull/138103)_
- * Removed deprecated NavigatorState.focusScopeNode by @Piinks in [139260](https://github.com/flutter/flutter/pull/139260)
  - _* Roll dependencies by @Hixie in [139606](https://github.com/flutter/flutter/pull/139606)_
- * Reset deprecation period for setPubRootDirectories by @Piinks in [139592](https://github.com/flutter/flutter/pull/139592)
  - _* [Android] Bump template & integration test Gradle version to 7.6.4 by @camsim99 in [139276](https://github.com/flutter/flutter/pull/139276)_
- * Fix some deprecation details by @Piinks in [136385](https://github.com/flutter/flutter/pull/136385)
  - _* SearchBar should listen to changes to the SearchController and update suggestions on change by @bryanoli in [134337](https://github.com/flutter/flutter/pull/134337)_
- * Deprecates onWillAccept and onAccept callbacks in DragTarget. by @chinmoy12c in [133691](https://github.com/flutter/flutter/pull/133691)
  - _* Docs typo: comprised -> composed by @EnduringBeta in [137896](https://github.com/flutter/flutter/pull/137896)_
- * Remove deprecated `PlatformMenuBar.body` by @gspencergoog in [138509](https://github.com/flutter/flutter/pull/138509)
  - _* Refactor to use Apple system fonts by @MitchellGoodwin in [137275](https://github.com/flutter/flutter/pull/137275)_
- * Remove deprecated parameters from `ElevatedButton.styleFrom()`, `OutlinedButton.styleFrom()`, and `TextButton.styleFrom()` by @QuncCccccc in [139267](https://github.com/flutter/flutter/pull/139267)
  - _* Implement `SubmenuButton.onFocusChange` by @QuncCccccc in [139678](https://github.com/flutter/flutter/pull/139678)_
- * Deprecate `RawKeyEvent`, `RawKeyboard`, et al. by @gspencergoog in [136677](https://github.com/flutter/flutter/pull/136677)
  - _* Fix dayPeriodColor handling of non-MaterialStateColors by @gspencergoog in [139845](https://github.com/flutter/flutter/pull/139845)_
- * Remove deprecated `ThemeData.selectedRowColor` by @Renzo-Olivares in [139080](https://github.com/flutter/flutter/pull/139080)
  - _* Overlay supports unconstrained environments by @goderbauer in [139513](https://github.com/flutter/flutter/pull/139513)_
- * Revert automated changes made to deprecated settings.gradle (plugins.each) by @Gustl22 in [140037](https://github.com/flutter/flutter/pull/140037)
  - _* Part 1/n migration steps for kotlin migration by @reidbaker in [140452](https://github.com/flutter/flutter/pull/140452)_
- * Remove deprecated bitcode stripping from tooling by @jmagman in [140903](https://github.com/flutter/flutter/pull/140903)
  - _* Fix local engine use in macOS plugins by @stuartmorgan in [140222](https://github.com/flutter/flutter/pull/140222)_
- * [cp] Replace deprecated `exists` in podhelper.rb by @stuartmorgan in [141381](https://github.com/flutter/flutter/pull/141381)
  - _* CP: [Beta] Update DWDS to version 23.0.0+1 by @elliette in [142168](https://github.com/flutter/flutter/pull/142168)_
- * [Impeller] Deprecate the exposed Rect fields by @flar in [47592](https://github.com/flutter/engine/pull/47592)
  - _* [Impeller] Use specialization constant for blur pipelines decal feature. by @jonahwilliams in [47617](https://github.com/flutter/engine/pull/47617)_
- * Fix forward declare and some deprecated enums by @kjlubick in [46882](https://github.com/flutter/engine/pull/46882)
  - _* Reland - [Android] Add support for text processing actions by @bleroux in [46817](https://github.com/flutter/engine/pull/46817)_
- * Replace deprecated [UIScreen mainScreen] in FlutterView.mm by @mossmana in [46802](https://github.com/flutter/engine/pull/46802)
  - _* Don't respond to the `insertionPointColor` selector on iOS 17+ by @LongCatIsLooong in [46373](https://github.com/flutter/engine/pull/46373)_

**Breaking Change** (6)

- * InheritedElement.removeDependent() by @s0nerik in [129210](https://github.com/flutter/flutter/pull/129210)
  - _* Cover text_selection tests with leak tracking. by @ksokolovskyi in [137009](https://github.com/flutter/flutter/pull/137009)_
- * Removed deprecated NavigatorState.focusScopeNode by @Piinks in [139260](https://github.com/flutter/flutter/pull/139260)
  - _* Roll dependencies by @Hixie in [139606](https://github.com/flutter/flutter/pull/139606)_
- * Removed TBD translations for optional remainingTextFieldCharacterCounZero message by @HansMuller in [136684](https://github.com/flutter/flutter/pull/136684)
  - _* Fixed : Empty Rows shown at last page in Paginated data table by @aakash-pamnani in [132646](https://github.com/flutter/flutter/pull/132646)_
- * Fix scrollable `TabBar` expands to full width when the divider is removed by @TahaTesser in [140963](https://github.com/flutter/flutter/pull/140963)
  - _* Fix refresh cancelation by @lukehutch in [139535](https://github.com/flutter/flutter/pull/139535)_
- * [Impeller] removed operator overload (c++ style violation) by @gaaclarke in [47658](https://github.com/flutter/engine/pull/47658)
  - _* [Impeller] Remove Rect field accesses from aiks subdirectory by @flar in [47628](https://github.com/flutter/engine/pull/47628)_
- * Use GdkEvent methods to access values, direct access is removed in GTK4. by @robert-ancell in [46526](https://github.com/flutter/engine/pull/46526)
  - _* Replace use of Skia's Base64 Encoding/Decoding logic with a copy of the equivalent code by @kjlubick in [46543](https://github.com/flutter/engine/pull/46543)_

**New Feature / API** (1)

- * Added Features requested in #137530 by @mhbdev in [137532](https://github.com/flutter/flutter/pull/137532)
  - _* Fix Chips with Tooltip throw an assertion when enabling or disabling by @TahaTesser in [138799](https://github.com/flutter/flutter/pull/138799)_

**Performance Improvement** (31)

- * Tiny improve code style by using records instead of lists by @fzyzcjy in [135886](https://github.com/flutter/flutter/pull/135886)
  - _* RenderEditable should dispose created layers. by @polina-c in [135942](https://github.com/flutter/flutter/pull/135942)_
- * Use `coverage.collect`'s `coverableLineCache` param to speed up coverage by @liamappelbe in [136851](https://github.com/flutter/flutter/pull/136851)
  - _* CustomPainterSemantics doc typo by @EnduringBeta in [137081](https://github.com/flutter/flutter/pull/137081)_
- * Reduce animations further when --no-cli-animations is set. by @Hixie in [133598](https://github.com/flutter/flutter/pull/133598)
  - _* Fix sliver persistent header expand animation by @feduke-nukem in [137913](https://github.com/flutter/flutter/pull/137913)_
- * Fix dislocated doc and comment on ThemeData localize cache by @gnprice in [137315](https://github.com/flutter/flutter/pull/137315)
  - _* AnimationController should dispatch creation in constructor. by @ksokolovskyi in [134839](https://github.com/flutter/flutter/pull/134839)_
- * Improve documentation of CardTheme.shape by @dumazy in [139096](https://github.com/flutter/flutter/pull/139096)
  - _* Remove deprecated `PlatformMenuBar.body` by @gspencergoog in [138509](https://github.com/flutter/flutter/pull/138509)_
- * Optimize the display of the Overlay on the Slider by @hgraceb in [139021](https://github.com/flutter/flutter/pull/139021)
  - _* Convert some usage of `RawKeyEvent`, et al to `KeyEvent` by @gspencergoog in [139329](https://github.com/flutter/flutter/pull/139329)_
- * Improve slider's value indicator display test by @hgraceb in [139198](https://github.com/flutter/flutter/pull/139198)
  - _* Use dart analyze package for `num.clamp` by @LongCatIsLooong in [139867](https://github.com/flutter/flutter/pull/139867)_
- * improve comment doc in tabs.dart by @shirne in [140568](https://github.com/flutter/flutter/pull/140568)
  - _* Add key to BottomNavigationBarItem by @Gibbo97 in [139617](https://github.com/flutter/flutter/pull/139617)_
- * Reverts "Use `coverage.collect`'s `coverableLineCache` param to speed up coverage" by @auto-submit in [137121](https://github.com/flutter/flutter/pull/137121)
  - _* [macOS] Refactor macOS build/codesize analysis by @cbracken in [137164](https://github.com/flutter/flutter/pull/137164)_
- * Ensure `flutter build apk --release` optimizes+shrinks platform code by @mkustermann in [136880](https://github.com/flutter/flutter/pull/136880)
  - _* Reverts "Ensure `flutter build apk --release` optimizes+shrinks platform code" by @auto-submit in [137433](https://github.com/flutter/flutter/pull/137433)_
- * Reverts "Ensure `flutter build apk --release` optimizes+shrinks platform code" by @auto-submit in [137433](https://github.com/flutter/flutter/pull/137433)
  - _* [web] Add 'nonce' prop to flutter.js loadEntrypoint by @ditman in [137204](https://github.com/flutter/flutter/pull/137204)_
- * [web] cache the base URL as root index.html by @p-mazhnik in [136594](https://github.com/flutter/flutter/pull/136594)
  - _* Fix formatting by @dcharkes in [137613](https://github.com/flutter/flutter/pull/137613)_
- * Improved Java version parsing by @reidbaker in [138155](https://github.com/flutter/flutter/pull/138155)
  - _* Roll pub packages by @flutter-pub-roller-bot in [138163](https://github.com/flutter/flutter/pull/138163)_
- * Improves output file path logic in Android analyze by @chunhtai in [136981](https://github.com/flutter/flutter/pull/136981)
  - _* Fix file deletion crash in BuildIOSArchiveCommand.runCommand by @vashworth in [138734](https://github.com/flutter/flutter/pull/138734)_
- * Optimize file transfer when using proxied devices. by @chingjun in [139968](https://github.com/flutter/flutter/pull/139968)
  - _* [deps] update Android SDK to 34 by @dcharkes in [138183](https://github.com/flutter/flutter/pull/138183)_
- * Migrate fuchsia_precache to shard tests. by @godofredoc in [139202](https://github.com/flutter/flutter/pull/139202)
  - _* Use the correct recipe on fuchsia_precache. by @godofredoc in [139279](https://github.com/flutter/flutter/pull/139279)_
- * Make improvements to existing new issue templates by @huycozy in [140142](https://github.com/flutter/flutter/pull/140142)
  - _* Bump actions/upload-artifact from 3.1.3 to 4.0.0 by @dependabot in [140177](https://github.com/flutter/flutter/pull/140177)_
- * [Impeller] fix clear color optimization for large subpasses. by @jonahwilliams in [46887](https://github.com/flutter/engine/pull/46887)
  - _* [Impeller] Add GPU frame time to Vulkan backend using timestamp queries. by @jonahwilliams in [46796](https://github.com/flutter/engine/pull/46796)_
- * [Impeller] Cache location in metadata. by @jonahwilliams in [46640](https://github.com/flutter/engine/pull/46640)
  - _* [Impeller] Improved documentation of the gaussian blur. by @gaaclarke in [47283](https://github.com/flutter/engine/pull/47283)_
- * [Impeller] Improved documentation of the gaussian blur. by @gaaclarke in [47283](https://github.com/flutter/engine/pull/47283)
  - _* [Impeller] added missing openplayground by @gaaclarke in [47338](https://github.com/flutter/engine/pull/47338)_
- * [Impeller] Fix the transform and geometry criteria for an optimization in TiledTextureContents by @jason-simmons in [47341](https://github.com/flutter/engine/pull/47341)
  - _* [Impeller] Add FilterContents::GetSourceCoverage to enable filtered saveLayer clipping. by @flar in [47183](https://github.com/flutter/engine/pull/47183)_
- * [Impeller] Reduce allocations for polyline generation by @dnfield in [47837](https://github.com/flutter/engine/pull/47837)
  - _* [Impeller] implement Canvas::DrawLine to tesselate lines directly by @flar in [47846](https://github.com/flutter/engine/pull/47846)_
- * [Impeller] Dont copy the paint until we're sure that the RRect blur optimization will apply. by @jonahwilliams in [48298](https://github.com/flutter/engine/pull/48298)
  - _* [Impeller] make host buffer state internally ref counted. by @jonahwilliams in [48303](https://github.com/flutter/engine/pull/48303)_
- * [Impeller] cache render target properties on Render Pass. by @jonahwilliams in [48323](https://github.com/flutter/engine/pull/48323)
  - _* Reverts "[Impeller] pass const ref to binding helpers." by @auto-submit in [48330](https://github.com/flutter/engine/pull/48330)_
- * [Impeller] revert non-zero tessellation optimization. by @jonahwilliams in [48234](https://github.com/flutter/engine/pull/48234)
  - _* [Impeller] add explainer for Android CPU profiling. by @jonahwilliams in [48407](https://github.com/flutter/engine/pull/48407)_
- * [Impeller] Provide the clear color to an advanced blend if it was optimized out by @jason-simmons in [48646](https://github.com/flutter/engine/pull/48646)
  - _* [Impeller] Store Buffer/Texture bindings in vector instead of map. by @jonahwilliams in [48719](https://github.com/flutter/engine/pull/48719)_
- * Revert "[Impeller] Provide the clear color to an advanced blend if it was optimized out" by @jason-simmons in [49064](https://github.com/flutter/engine/pull/49064)
  - _* [Impeller] Turn off Aiks bounds tracking for filtered SaveLayers. by @bdero in [49076](https://github.com/flutter/engine/pull/49076)_
- * Reduce number of surfaces required when presenting platform views by @knopp in [43301](https://github.com/flutter/engine/pull/43301)
  - _* Fix new lint from android 14 upgrade, and remove it from the baseline by @gmackall in [47817](https://github.com/flutter/engine/pull/47817)_
- * [Windows] Reduce warnings produced by unit tests by @loic-sharma in [47724](https://github.com/flutter/engine/pull/47724)
  - _* [testing] Extract StreamCapture test utility by @cbracken in [47774](https://github.com/flutter/engine/pull/47774)_
- * [fml][embedder] Improve thread-check logging by @cbracken in [47020](https://github.com/flutter/engine/pull/47020)
  - _* Roll buildroot to pull in removal of //tools. by @chinmaygarde in [47032](https://github.com/flutter/engine/pull/47032)_
- * Protect sdk upload script from missing ndk, add documentation for checking write access, improve comments to add context by @reidbaker in [47989](https://github.com/flutter/engine/pull/47989)
  - _* [Impeller] Write a text-decoration test at the `dart:ui` layer by @matanlurey in [48101](https://github.com/flutter/engine/pull/48101)_

**Replacement / Migration** (20)

- * Tiny improve code style by using records instead of lists by @fzyzcjy in [135886](https://github.com/flutter/flutter/pull/135886)
  - _* RenderEditable should dispose created layers. by @polina-c in [135942](https://github.com/flutter/flutter/pull/135942)_
- * Changes to use valuenotifier instead of a force rebuild for WidgetInspector by @CoderDake in [131634](https://github.com/flutter/flutter/pull/131634)
  - _* [Impeller] GPU frame timings summarization. by @jonahwilliams in [136408](https://github.com/flutter/flutter/pull/136408)_
- * fix typo of 'not' instead of 'now' for `useInheritedMediaQuery` by @timmaffett in [139940](https://github.com/flutter/flutter/pull/139940)
  - _* [Docs] Added missing `CupertinoApp.showSemanticsDebugger` by @piedcipher in [139913](https://github.com/flutter/flutter/pull/139913)_
- * `OverlayPortal.overlayChild` contributes semantics to `OverlayPortal` instead of `Overlay` by @LongCatIsLooong in [134921](https://github.com/flutter/flutter/pull/134921)
  - _* Update `ColorScheme.fromSwatch` docs for Material 3 by @TahaTesser in [136816](https://github.com/flutter/flutter/pull/136816)_
- * Switch to Chrome for Testing instead of vanilla Chromium. by @eyebrowsoffire in [136214](https://github.com/flutter/flutter/pull/136214)
  - _* [Windows Arm64] Add the 'platform_channel_sample_test_windows' Devicelab test by @loic-sharma in [136401](https://github.com/flutter/flutter/pull/136401)_
- * [Impeller] Switch from `glBlitFramebuffer` to implicit MSAA resolution. by @matanlurey in [47282](https://github.com/flutter/engine/pull/47282)
  - _* [Impeller] Restore GLES GPU query times. by @jonahwilliams in [47511](https://github.com/flutter/engine/pull/47511)_
- * [Impeller] stencil buffer record/replay instead of MSAA storage. by @jonahwilliams in [47397](https://github.com/flutter/engine/pull/47397)
  - _* [Impeller] OpenGLES: Ensure frag/vert textures are bound with unique texture units. by @bdero in [47218](https://github.com/flutter/engine/pull/47218)_
- * [Impeller] add example of testing entity with "real" HAL instead of mocking. by @jonahwilliams in [47631](https://github.com/flutter/engine/pull/47631)
  - _* [Impeller] removed operator overload (c++ style violation) by @gaaclarke in [47658](https://github.com/flutter/engine/pull/47658)_
- * [Impeller] Prefer moving vertex buffer, place on command instead of binding object. by @jonahwilliams in [48630](https://github.com/flutter/engine/pull/48630)
  - _* [Impeller] Declare specialization constants as floats. by @jason-simmons in [48644](https://github.com/flutter/engine/pull/48644)_
- * [Impeller] Store Buffer/Texture bindings in vector instead of map. by @jonahwilliams in [48719](https://github.com/flutter/engine/pull/48719)
  - _* Revert "Replace use of Fontmgr::RefDefault with explicit creation calls" by @jason-simmons in [48755](https://github.com/flutter/engine/pull/48755)_
- * [Impeller] Compute ContextContentOptions key via bit manipulating (instead of hashing each property). by @jonahwilliams in [48902](https://github.com/flutter/engine/pull/48902)
  - _* [Impeller] Made the new blur work on devices without the decal address mode by @gaaclarke in [48899](https://github.com/flutter/engine/pull/48899)_
- * [Windows] Move to `FlutterCompositor` for rendering by @loic-sharma in [48849](https://github.com/flutter/engine/pull/48849)
  - _* [Flutter GPU] Runtime shader import. by @bdero in [48875](https://github.com/flutter/engine/pull/48875)_
- * Reverts "[Windows] Move to `FlutterCompositor` for rendering" by @auto-submit in [49015](https://github.com/flutter/engine/pull/49015)
  - _* [Impeller] Round rects with circular ends should not generate ellipses by @flar in [49021](https://github.com/flutter/engine/pull/49021)_
- * Reland "[Windows] Move to FlutterCompositor for rendering" by @loic-sharma in [49262](https://github.com/flutter/engine/pull/49262)
  - _* [Impeller] Make IPLR files multi-platform by @dnfield in [49253](https://github.com/flutter/engine/pull/49253)_
- * Revert "Reland "[Windows] Move to FlutterCompositor for rendering" by @loic-sharma in [49461](https://github.com/flutter/engine/pull/49461)
  - _* [Impeller] add doc on iOS flamegraph capture. by @jonahwilliams in [49469](https://github.com/flutter/engine/pull/49469)_
- * [Impeller] Switched to static linked libc++ in vulkan validation layers. by @gaaclarke in [48290](https://github.com/flutter/engine/pull/48290)
  - _* Finish making `shell/platform/android/...` compatible with `.clang-tidy`. by @matanlurey in [48296](https://github.com/flutter/engine/pull/48296)_
- * Switch to Chrome For Testing instead of Chromium by @eyebrowsoffire in [46683](https://github.com/flutter/engine/pull/46683)
  - _* [web] Stop using `flutterViewEmbedder` for platform views by @mdebbar in [46046](https://github.com/flutter/engine/pull/46046)_
- * Use --timeline_recorder=systrace instead of --systrace_timeline by @derekxu16 in [46884](https://github.com/flutter/engine/pull/46884)
  - _* [Impeller] Only allow Impeller in flutter_tester if vulkan is enabled. by @dnfield in [46895](https://github.com/flutter/engine/pull/46895)_
- * Switch to Android 14 for physical device firebase tests by @gmackall in [47016](https://github.com/flutter/engine/pull/47016)
  - _* Move window state update to window realize callback by @gspencergoog in [47713](https://github.com/flutter/engine/pull/47713)_
- * Use flutter mirrors for non-google origin deps instead of fuchsia by @sealesj in [48735](https://github.com/flutter/engine/pull/48735)
  - _* Run tests on macOS 13 exclusively by @vashworth in [49099](https://github.com/flutter/engine/pull/49099)_

---

### 3.16.0

**Deprecation** (16)

- * Deprecate `useMaterial3` parameter in `ThemeData.copyWith()` by @QuncCccccc in [131455](https://github.com/flutter/flutter/pull/131455)
  - _* Update `BottomSheet.enableDrag` & `BottomSheet.showDragHandle` docs for animation controller by @TahaTesser in [131484](https://github.com/flutter/flutter/pull/131484)_
- * Adds more documentations around ignoreSemantics deprecations. by @chunhtai in [131287](https://github.com/flutter/flutter/pull/131287)
  - _* Revert "Replace TextField.canRequestFocus with TextField.focusNode.canRequestFocus" by @Jasguerrero in [132104](https://github.com/flutter/flutter/pull/132104)_
- * Deprecate `describeEnum`. by @bernaferrari in [125016](https://github.com/flutter/flutter/pull/125016)
  - _* Remove shrinkWrap from flexible_space_bar_test.dart by @thkim1011 in [132173](https://github.com/flutter/flutter/pull/132173)_
- * Add missing `ignore: deprecated_member_use` to unblock the engine roller by @LongCatIsLooong in [132280](https://github.com/flutter/flutter/pull/132280)
  - _* Keep alive support for 2D scrolling by @Piinks in [131641](https://github.com/flutter/flutter/pull/131641)_
- * Remove deprecated *TestValues from TestWindow by @goderbauer in [131098](https://github.com/flutter/flutter/pull/131098)
  - _* Enable literal_only_boolean_expressions by @goderbauer in [133186](https://github.com/flutter/flutter/pull/133186)_
- * Remove deprecated MaterialButtonWithIconMixin by @Piinks in [133173](https://github.com/flutter/flutter/pull/133173)
  - _* Remove deprecated PlatformViewsService.synchronizeToNativeViewHierarchy by @Piinks in [133175](https://github.com/flutter/flutter/pull/133175)_
- * Remove deprecated PlatformViewsService.synchronizeToNativeViewHierarchy by @Piinks in [133175](https://github.com/flutter/flutter/pull/133175)
  - _* Remove `ImageProvider.load`, `DecoderCallback` and `PaintingBinding.instantiateImageCodec` by @LongCatIsLooong in [132679](https://github.com/flutter/flutter/pull/132679)_
- * Remove deprecated androidOverscrollIndicator from ScrollBehaviors by @Piinks in [133181](https://github.com/flutter/flutter/pull/133181)
  - _* Remove deprecated onPlatformMessage from TestWindow and TestPlatformDispatcher by @Piinks in [133183](https://github.com/flutter/flutter/pull/133183)_
- * Remove deprecated onPlatformMessage from TestWindow and TestPlatformDispatcher by @Piinks in [133183](https://github.com/flutter/flutter/pull/133183)
  - _* Adds callback onWillAcceptWithDetails in DragTarget. by @chinmoy12c in [131545](https://github.com/flutter/flutter/pull/131545)_
- * Remove deprecated TestWindow.textScaleFactorTestValue/TestWindow.clearTextScaleFactorTestValue by @Renzo-Olivares in [133176](https://github.com/flutter/flutter/pull/133176)
  - _* Remove deprecated TestWindow.platformBrightnessTestValue/TestWindow.clearPlatformBrightnessTestValue by @Renzo-Olivares in [133178](https://github.com/flutter/flutter/pull/133178)_
- * Remove deprecated TestWindow.platformBrightnessTestValue/TestWindow.clearPlatformBrightnessTestValue by @Renzo-Olivares in [133178](https://github.com/flutter/flutter/pull/133178)
  - _* Mark leak in _DayPickerState. by @polina-c in [133863](https://github.com/flutter/flutter/pull/133863)_
- * Remove deprecated TextSelectionOverlay.fadeDuration by @Piinks in [134485](https://github.com/flutter/flutter/pull/134485)
  - _* Remove chip tooltip deprecations by @Piinks in [134486](https://github.com/flutter/flutter/pull/134486)_
- * Remove chip tooltip deprecations by @Piinks in [134486](https://github.com/flutter/flutter/pull/134486)
  - _* Enable private field promotion for examples by @goderbauer in [134478](https://github.com/flutter/flutter/pull/134478)_
- * [Android] Deletes deprecated splash screen meta-data element by @camsim99 in [130744](https://github.com/flutter/flutter/pull/130744)
  - _* Relax syntax for gen-l10n by @thkim1011 in [130736](https://github.com/flutter/flutter/pull/130736)_
- * Remove deprecated MOCK_METHODx calls by @dkwingsmt in [45307](https://github.com/flutter/engine/pull/45307)
  - _* Adds a comment on clang_arm64_apilevel26 toolchain usage by @zanderso in [45467](https://github.com/flutter/engine/pull/45467)_
- * Replace deprecated [UIScreen mainScreen] in FlutterViewController.mm and FlutterViewControllerTest.mm by @mossmana in [43690](https://github.com/flutter/engine/pull/43690)
  - _* Uncap framerate for `iOSAppOnMac` by @moffatman in [43840](https://github.com/flutter/engine/pull/43840)_

**Breaking Change** (9)

- * Allow `OverlayPortal` to be added/removed from the tree in a layout callback by @LongCatIsLooong in [130670](https://github.com/flutter/flutter/pull/130670)
  - _* `_RenderScaledInlineWidget` constrains child size by @LongCatIsLooong in [130648](https://github.com/flutter/flutter/pull/130648)_
- * Handle breaking changes in leak_tracker. by @polina-c in [131998](https://github.com/flutter/flutter/pull/131998)
  - _* More documentation about warm-up frames by @Hixie in [132085](https://github.com/flutter/flutter/pull/132085)_
- * Revert "Handle breaking changes in leak_tracker." by @zanderso in [132223](https://github.com/flutter/flutter/pull/132223)
  - _* Reland "[web] Migrate framework to fully use package:web (#128901)" by @mdebbar in [132092](https://github.com/flutter/flutter/pull/132092)_
- * Unpin leak_tracker and handle breaking changes in API. by @polina-c in [132352](https://github.com/flutter/flutter/pull/132352)
  - _* Update menu examples for `SafeArea` by @TahaTesser in [132390](https://github.com/flutter/flutter/pull/132390)_
- * removed unused variable in the example code of semantic event by @chrisdlangham in [134551](https://github.com/flutter/flutter/pull/134551)
  - _* Cover more test/widgets tests with leak tracking #4 by @ksokolovskyi in [134663](https://github.com/flutter/flutter/pull/134663)_
- * Resolve breaking change of adding a method to ChangeNotifier. by @polina-c in [134953](https://github.com/flutter/flutter/pull/134953)
  - _* Reland Resolve breaking change of adding a method to ChangeNotifier. by @polina-c in [134983](https://github.com/flutter/flutter/pull/134983)_
- * Reland Resolve breaking change of adding a method to ChangeNotifier. by @polina-c in [134983](https://github.com/flutter/flutter/pull/134983)
  - _* Remove 'must be non-null' and 'must not be null' comments from non-framework libraries by @gspencergoog in [134994](https://github.com/flutter/flutter/pull/134994)_
- * Handle breaking changes in leak_tracker. by @polina-c in [135185](https://github.com/flutter/flutter/pull/135185)
  - _* Add RestorationManager disposals in test/services/restoration_test.dart. by @ksokolovskyi in [135218](https://github.com/flutter/flutter/pull/135218)_
- * Pin leak_tracker before publishing breaking change. by @polina-c in [135720](https://github.com/flutter/flutter/pull/135720)
  - _* [flutter_tools] remove VmService screenshot for native devices. by @jonahwilliams in [135462](https://github.com/flutter/flutter/pull/135462)_

**New Feature / API** (4)

- * added option to change color of heading row(flutter#132428) by @salmanulfarisi in [132728](https://github.com/flutter/flutter/pull/132728)
  - _* Fix stuck predictive back platform channel calls by @justinmc in [133368](https://github.com/flutter/flutter/pull/133368)_
- * [New feature] Allowing the `ListView` slivers to have different extents while still having scrolling performance by @xu-baolin in [131393](https://github.com/flutter/flutter/pull/131393)
  - _* Revert "Adds a parent scope TraversalEdgeBehavior and fixes modal rou… by @chunhtai in [134550](https://github.com/flutter/flutter/pull/134550)_
- * Added option to disable [NavigationDrawerDestination]s by @matheus-kirchesch-btor in [132349](https://github.com/flutter/flutter/pull/132349)
  - _* _RenderChip should not create OpacityLayer without disposing. by @polina-c in [134708](https://github.com/flutter/flutter/pull/134708)_
- * Added option to disable [NavigationDestination]s ([NavigationBar] destination widget) by @matheus-kirchesch-btor in [132361](https://github.com/flutter/flutter/pull/132361)
  - _* Fix TabBarView.viewportFraction change is ignored by @bleroux in [135590](https://github.com/flutter/flutter/pull/135590)_

**New Parameter / Option** (3)

- * added option to change color of heading row(flutter#132428) by @salmanulfarisi in [132728](https://github.com/flutter/flutter/pull/132728)
  - _* Fix stuck predictive back platform channel calls by @justinmc in [133368](https://github.com/flutter/flutter/pull/133368)_
- * Added option to disable [NavigationDrawerDestination]s by @matheus-kirchesch-btor in [132349](https://github.com/flutter/flutter/pull/132349)
  - _* _RenderChip should not create OpacityLayer without disposing. by @polina-c in [134708](https://github.com/flutter/flutter/pull/134708)_
- * Added option to disable [NavigationDestination]s ([NavigationBar] destination widget) by @matheus-kirchesch-btor in [132361](https://github.com/flutter/flutter/pull/132361)
  - _* Fix TabBarView.viewportFraction change is ignored by @bleroux in [135590](https://github.com/flutter/flutter/pull/135590)_

**Performance Improvement** (21)

- * Super tiny code optimization: No need to redundantly check whether value has changed by @fzyzcjy in [130050](https://github.com/flutter/flutter/pull/130050)
  - _* Revert "fix a bug when android uses CupertinoPageTransitionsBuilder..." by @HansMuller in [130144](https://github.com/flutter/flutter/pull/130144)_
- * Improve handling of certain icons in RTL by @guidezpl in [130979](https://github.com/flutter/flutter/pull/130979)
  - _* Upgrade to newer leak_tracker. by @polina-c in [131085](https://github.com/flutter/flutter/pull/131085)_
- * Optimize SliverMainAxisGroup/SliverCrossAxisGroup paint function by @thkim1011 in [129310](https://github.com/flutter/flutter/pull/129310)
  - _* Update link to unbounded constraints error by @goderbauer in [131205](https://github.com/flutter/flutter/pull/131205)_
- * CupertinoContextMenu improvement by @xhzq233 in [131030](https://github.com/flutter/flutter/pull/131030)
  - _* Android context menu theming and visual update by @justinmc in [131816](https://github.com/flutter/flutter/pull/131816)_
- * PaginatedDataTable improvements by @Hixie in [131374](https://github.com/flutter/flutter/pull/131374)
  - _* Further clarification of the TextSelectionControls migration by @Hixie in [132539](https://github.com/flutter/flutter/pull/132539)_
- * Improvements to EditableText documentation by @Hixie in [132532](https://github.com/flutter/flutter/pull/132532)
  - _* Fix lower bound of children from TwoDimensionalChildBuilderDelegate by @Piinks in [132713](https://github.com/flutter/flutter/pull/132713)_
- * Improve and optimize non-uniform Borders. by @bernaferrari in [124417](https://github.com/flutter/flutter/pull/124417)
  - _* Disable test order randomization on some leak tracker tests that are failing with today's seed by @jason-simmons in [132766](https://github.com/flutter/flutter/pull/132766)_
- * l10n-related documentation improvements by @Hixie in [133114](https://github.com/flutter/flutter/pull/133114)
  - _* Update the tool to know about all our new platforms by @Hixie in [132423](https://github.com/flutter/flutter/pull/132423)_
- * Update & improve `TabBar.labelColor` tests by @TahaTesser in [133668](https://github.com/flutter/flutter/pull/133668)
  - _* Reland "Remove ImageProvider.load, DecoderCallback and `PaintingBinding.instantiateImageCodec` (#132679) (reverted in #133482) by @LongCatIsLooong in [133605](https://github.com/flutter/flutter/pull/133605)_
- * [framework] reduce ink sparkle uniform count. by @jonahwilliams in [133897](https://github.com/flutter/flutter/pull/133897)
  - _* Dispose routes in navigator when throwing exception by @hangyujin in [134596](https://github.com/flutter/flutter/pull/134596)_
- * Improve DropdownMenu sample code for requestFocusOnTap on mobile platforms by @huycozy in [134867](https://github.com/flutter/flutter/pull/134867)
  - _* Fix memory leak in _DarwinViewState. by @ksokolovskyi in [134938](https://github.com/flutter/flutter/pull/134938)_
- * Make PollingDeviceDiscovery start the initial poll faster. by @chingjun in [130755](https://github.com/flutter/flutter/pull/130755)
  - _* Migrate more integration tests to process result matcher by @christopherfujino in [130994](https://github.com/flutter/flutter/pull/130994)_
- * Reduce usage of testUsingContext by @christopherfujino in [131078](https://github.com/flutter/flutter/pull/131078)
  - _* 🐛 Only format Dart files for `gen-l10n` by @AlexV525 in [131232](https://github.com/flutter/flutter/pull/131232)_
- * [flutter_tools/dap] Improve rendering of structured errors via DAP by @DanTup in [131251](https://github.com/flutter/flutter/pull/131251)
  - _* Upgrade compile and target sdk versions in tests and benchmarks by @gmackall in [131428](https://github.com/flutter/flutter/pull/131428)_
- * Improve doctor output on incomplete Visual Studio installation by @loic-sharma in [133390](https://github.com/flutter/flutter/pull/133390)
  - _* Removes ios universal link vmservices and let xcodeproject to dump js… by @chunhtai in [133709](https://github.com/flutter/flutter/pull/133709)_
- * Speed up native assets target by @dcharkes in [134523](https://github.com/flutter/flutter/pull/134523)
  - _* Makes scheme and target optional parameter when getting universal lin… by @chunhtai in [134571](https://github.com/flutter/flutter/pull/134571)_
- * [macOS,iOS] Improve CocoaPods upgrade instructions by @cbracken in [135453](https://github.com/flutter/flutter/pull/135453)
  - _* Wait for CONFIGURATION_BUILD_DIR to update when debugging with Xcode by @vashworth in [135444](https://github.com/flutter/flutter/pull/135444)_
- * Optimizing performance by avoiding multiple GC operations caused by multiple surface destruction notifications by @0xZOne in [43587](https://github.com/flutter/engine/pull/43587)
  - _* Add a PlatformViewRenderTarget abstraction by @johnmccutchan in [43813](https://github.com/flutter/engine/pull/43813)_
- * [web] More efficient fallback font selection by @rakudrama in [44526](https://github.com/flutter/engine/pull/44526)
  - _* Update deps on DDC build targets by @nshahan in [45404](https://github.com/flutter/engine/pull/45404)_
- * [macOS] Improve engine retain cycle testing by @cbracken in [44509](https://github.com/flutter/engine/pull/44509)
  - _* [Windows] Return keyboard pressed state by @bleroux in [43998](https://github.com/flutter/engine/pull/43998)_
- * [Windows] Improve logic to update swap intervals by @loic-sharma in [46172](https://github.com/flutter/engine/pull/46172)
  - _* [macOS] performKeyEquivalent cleanup by @knopp in [45946](https://github.com/flutter/engine/pull/45946)_

**Replacement / Migration** (5)

- * Use utf8.encode() instead of longer const Utf8Encoder.convert() by @mkustermann in [130567](https://github.com/flutter/flutter/pull/130567)
  - _* Fix material date picker behavior when changing year by @Lexycon in [130486](https://github.com/flutter/flutter/pull/130486)_
- * Add `--local-engine-host`, which if specified, is used instead of being inferred by @matanlurey in [132180](https://github.com/flutter/flutter/pull/132180)
  - _* Fix flutter attach local engine by @christopherfujino in [131825](https://github.com/flutter/flutter/pull/131825)_
- * Use utf8.encode() instead of longer const Utf8Encoder.convert() by @mkustermann in [43675](https://github.com/flutter/engine/pull/43675)
  - _* [web] always add secondary role managers by @yjbanov in [43663](https://github.com/flutter/engine/pull/43663)_
- * Implement JSObject instead of extending by @srujzs in [46070](https://github.com/flutter/engine/pull/46070)
  - _* Enable strict-inference by @goderbauer in [46062](https://github.com/flutter/engine/pull/46062)_
- * Use `start` instead of `extent` for Windows IME cursor position by @yaakovschectman in [45667](https://github.com/flutter/engine/pull/45667)
  - _* Handle external window's `WM_CLOSE` in lifecycle manager by @yaakovschectman in [45840](https://github.com/flutter/engine/pull/45840)_

---

### 3.13.0

**Deprecation** (13)

- * Migrate away from deprecated BinaryMessenger API by @goderbauer in [124348](https://github.com/flutter/flutter/pull/124348)
  - _* Fix InkWell ripple visible on right click when not expected by @bleroux in [124386](https://github.com/flutter/flutter/pull/124386)_
- * Remove deprecations from TextSelectionHandleControls instances by @justinmc in [124611](https://github.com/flutter/flutter/pull/124611)
  - _* DraggableScrollableSheet & NestedScrollView should respect NeverScrollableScrollPhysics by @xu-baolin in [123109](https://github.com/flutter/flutter/pull/123109)_
- * Improve the docs around the TextSelectionHandleControls deprecations by @justinmc in [123827](https://github.com/flutter/flutter/pull/123827)
  - _* Refactor `SliverAppBar.medium` & `SliverAppBar.large` to fix several issues by @TahaTesser in [122542](https://github.com/flutter/flutter/pull/122542)_
- * Deprecates string for reorderable list in material_localizations by @chunhtai in [124711](https://github.com/flutter/flutter/pull/124711)
  - _* Fix Chip highlight color isn't drawn on top of the background color by @TahaTesser in [124673](https://github.com/flutter/flutter/pull/124673)_
- * Remove uses of deprecated test_api imports by @natebosch in [124732](https://github.com/flutter/flutter/pull/124732)
  - _* Toolbar should re-appear on drag end by @Renzo-Olivares in [125165](https://github.com/flutter/flutter/pull/125165)_
- * Remove some ignores for un-deprecated imports by @natebosch in [125261](https://github.com/flutter/flutter/pull/125261)
  - _* Adjust selection rects inclusion criteria by @moffatman in [125022](https://github.com/flutter/flutter/pull/125022)_
- * Remove deprecated fixTextFieldOutlineLabel by @Renzo-Olivares in [125893](https://github.com/flutter/flutter/pull/125893)
  - _* Remove obsolete drawShadow bounds workaround by @flar in [127052](https://github.com/flutter/flutter/pull/127052)_
- * Remove deprecated `primaryVariant` and `secondaryVariant` from `ColorScheme` by @QuncCccccc in [127124](https://github.com/flutter/flutter/pull/127124)
  - _* Properly cleans up routes by @chunhtai in [126453](https://github.com/flutter/flutter/pull/126453)_
- * Remove deprecated OverscrollIndicatorNotification.disallowGlow by @Piinks in [127050](https://github.com/flutter/flutter/pull/127050)
  - _* fixes to anticipate next Dart linter release by @pq in [127211](https://github.com/flutter/flutter/pull/127211)_
- * Remove scrollbar deprecations isAlwaysShown and hoverThickness by @Piinks in [127351](https://github.com/flutter/flutter/pull/127351)
  - _* [framework] attempt non-key solution by @jonahwilliams in [128273](https://github.com/flutter/flutter/pull/128273)_
- * Remove AbstractNode from RenderObject and deprecate it by @goderbauer in [128973](https://github.com/flutter/flutter/pull/128973)
  - _* Accept Diagnosticable as input in inspector API. by @polina-c in [128962](https://github.com/flutter/flutter/pull/128962)_
- * Removes deprecated APIs from v2.6 in `binding.dart` and `widget_tester.dart` by @pdblasi-google in [129663](https://github.com/flutter/flutter/pull/129663)
  - _* Reland Fix AnimatedList & AnimatedGrid doesn't apply MediaQuery padding #129556 by @HansMuller in [129860](https://github.com/flutter/flutter/pull/129860)_
- * Remove some trivial deprecated symbol usages in iOS Embedder by @cyanglaz in [42711](https://github.com/flutter/engine/pull/42711)
  - _* [ios] view controller based status bar by @cyanglaz in [42643](https://github.com/flutter/engine/pull/42643)_

**Breaking Change** (5)

- * Address leak tracker breaking changes. by @polina-c in [128623](https://github.com/flutter/flutter/pull/128623)
  - _* Fix RangeSlider notifies start and end twice when participates in gesture arena by @nt4f04uNd in [128674](https://github.com/flutter/flutter/pull/128674)_
- * [CP] Allow `OverlayPortal` to be added/removed from the tree in a layout callback (#130670) by @LongCatIsLooong in [131290](https://github.com/flutter/flutter/pull/131290)
  - _* [CP] `_RenderScaledInlineWidget` constrains child size (#130648) by @LongCatIsLooong in [131289](https://github.com/flutter/flutter/pull/131289)_
- * Allow .xcworkspace and .xcodeproj to be renamed from default name 'Runner' by @LouiseHsu in [124533](https://github.com/flutter/flutter/pull/124533)
  - _* Adding printOnFailure for result of process by @eliasyishak in [125910](https://github.com/flutter/flutter/pull/125910)_
- * improvement : removed required kotlin dependency by @albertoazinar in [125002](https://github.com/flutter/flutter/pull/125002)
  - _* Rename iosdeeplinksettings to iosuniversallinksettings by @chunhtai in [126173](https://github.com/flutter/flutter/pull/126173)_
- * [platform_view] Only dispose view when it is removed from the composition order by @cyanglaz in [41521](https://github.com/flutter/engine/pull/41521)
  - _* Disable flaky tests on arm64 by @dnfield in [41740](https://github.com/flutter/engine/pull/41740)_

**New Feature / API** (1)

- * [CupertinoListSection] adds new property separatorColor by @piedcipher in [124803](https://github.com/flutter/flutter/pull/124803)
  - _* iOS context menu shadow by @justinmc in [122429](https://github.com/flutter/flutter/pull/122429)_

**New Parameter / Option** (2)

- * [CupertinoListSection] adds new property separatorColor by @piedcipher in [124803](https://github.com/flutter/flutter/pull/124803)
  - _* iOS context menu shadow by @justinmc in [122429](https://github.com/flutter/flutter/pull/122429)_
- * [tools] allow explicitly specifying the JDK to use via a new config setting by @andrewkolos in [128264](https://github.com/flutter/flutter/pull/128264)
  - _* Adds vmservices to retrieve android applink settings by @chunhtai in [125998](https://github.com/flutter/flutter/pull/125998)_

**Performance Improvement** (19)

- * Reduce macOS overscroll friction by @moffatman in [122142](https://github.com/flutter/flutter/pull/122142)
  - _* ExpansionTile audit by @chunhtai in [124281](https://github.com/flutter/flutter/pull/124281)_
- * Improve the docs around the TextSelectionHandleControls deprecations by @justinmc in [123827](https://github.com/flutter/flutter/pull/123827)
  - _* Refactor `SliverAppBar.medium` & `SliverAppBar.large` to fix several issues by @TahaTesser in [122542](https://github.com/flutter/flutter/pull/122542)_
- * [cupertino] improve cupertino picker performance by using at most one opacity layer by @jonahwilliams in [124719](https://github.com/flutter/flutter/pull/124719)
  - _* Revert "[framework] use shader tiling instead of repeated calls to drawImage" by @jonahwilliams in [124640](https://github.com/flutter/flutter/pull/124640)_
- * Improve the format in `asset_bundle.dart` by @AlexV525 in [126229](https://github.com/flutter/flutter/pull/126229)
  - _* fix AppBar's docs for backgroundColor by @werainkhatri in [126194](https://github.com/flutter/flutter/pull/126194)_
- * Improve defaults generation with logging, stats, and token validation by @guidezpl in [128244](https://github.com/flutter/flutter/pull/128244)
  - _* Updated material button theme tests for Material3 by @HansMuller in [128543](https://github.com/flutter/flutter/pull/128543)_
- * Improve the error message for non-normalized constraints by @Hixie in [127906](https://github.com/flutter/flutter/pull/127906)
  - _* Update getChildrenSummaryTree to handle Diagnosticable as input. by @polina-c in [128833](https://github.com/flutter/flutter/pull/128833)_
- * Improve documentation for `ColorSheme.fromImageProvider` by @guidezpl in [129952](https://github.com/flutter/flutter/pull/129952)
  - _* fix a bug when android uses CupertinoPageTransitionsBuilder... by @ipcjs in [114303](https://github.com/flutter/flutter/pull/114303)_
- * [tool] Improve help info with build web --wasm flags by @kevmoo in [125907](https://github.com/flutter/flutter/pull/125907)
  - _* [tool] consistently use environment (not globals) in targets/web.dart by @kevmoo in [125937](https://github.com/flutter/flutter/pull/125937)_
- * improvement : removed required kotlin dependency by @albertoazinar in [125002](https://github.com/flutter/flutter/pull/125002)
  - _* Rename iosdeeplinksettings to iosuniversallinksettings by @chunhtai in [126173](https://github.com/flutter/flutter/pull/126173)_
- * [Windows] Improve version migration message by @loic-sharma in [127048](https://github.com/flutter/flutter/pull/127048)
  - _* Migrate benchmarks to package:web by @joshualitt in [126848](https://github.com/flutter/flutter/pull/126848)_
- * [flutter_tools] Precache after channel switch by @christopherfujino in [118129](https://github.com/flutter/flutter/pull/118129)
  - _* [flutter_tools] [DAP] Don't try to restart/reload if app hasn't started yet by @DanTup in [128267](https://github.com/flutter/flutter/pull/128267)_
- * [flutter_tools] cache flutter sdk version to disk by @christopherfujino in [124558](https://github.com/flutter/flutter/pull/124558)
  - _* flutter update-packages --cherry-pick-package by @Hixie in [128917](https://github.com/flutter/flutter/pull/128917)_
- * Fix dart pub cache clean command on pub.dart by @deryrahman in [128171](https://github.com/flutter/flutter/pull/128171)
  - _* [flutter_tools] Add support for vmServiceFileInfo when attaching by @DanTup in [128503](https://github.com/flutter/flutter/pull/128503)_
- * [flutter_tools] add a gradle error handler for could not open cache directory by @christopherfujino in [129222](https://github.com/flutter/flutter/pull/129222)
  - _* Prevent crashes on range errors when selecting device by @eliasyishak in [129290](https://github.com/flutter/flutter/pull/129290)_
- * [rotation_distortion] Use "delayed swap" solution to reduce rotation distortion by @hellohuanlin in [40730](https://github.com/flutter/engine/pull/40730)
  - _* [Impeller] Turned on wide gamut support by default. by @gaaclarke in [39801](https://github.com/flutter/engine/pull/39801)_
- * Improve getting non-overlapping rectangles from RTree by @knopp in [42399](https://github.com/flutter/engine/pull/42399)
  - _* [iOS] Fix TextInputAction.continueAction sends wrong action to framework by @bleroux in [42615](https://github.com/flutter/engine/pull/42615)_
- * Improve Wasm Debugging. by @eyebrowsoffire in [41054](https://github.com/flutter/engine/pull/41054)
  - _* `SemanticsAction` / `SemanticsFlag` cleanup part 5 by @bernaferrari in [41126](https://github.com/flutter/engine/pull/41126)_
- * [web:canvaskit] clean up the rest of skia_object_cache usages by @yjbanov in [41259](https://github.com/flutter/engine/pull/41259)
  - _* [web:canvaskit] remove unnecessary instrumentation from picture by @yjbanov in [41313](https://github.com/flutter/engine/pull/41313)_
- * [web] Improve null safety for color->css by @mdebbar in [41699](https://github.com/flutter/engine/pull/41699)
  - _* Remove physical model layer by @jonahwilliams in [41593](https://github.com/flutter/engine/pull/41593)_

**Replacement / Migration** (14)

- * Revert "[framework] use shader tiling instead of repeated calls to drawImage" by @jonahwilliams in [124640](https://github.com/flutter/flutter/pull/124640)
  - _* Customize color and thickness of connected lines in Stepper.dart by @mub-pro in [122485](https://github.com/flutter/flutter/pull/122485)_
- * Advise developers to use OverflowBar instead of ButtonBar by @leighajarett in [128437](https://github.com/flutter/flutter/pull/128437)
  - _* Sliver Main Axis Group by @thkim1011 in [126596](https://github.com/flutter/flutter/pull/126596)_
- * Use term wireless instead of network by @vashworth in [124232](https://github.com/flutter/flutter/pull/124232)
  - _* [flutter_tools] add todo for userMessages by @andrewkolos in [125156](https://github.com/flutter/flutter/pull/125156)_
- * tool-web-wasm: make wasm-opt an "option" instead of a "flag" by @kevmoo in [126035](https://github.com/flutter/flutter/pull/126035)
  - _* Adding vmservice to get iOS app settings by @chunhtai in [123156](https://github.com/flutter/flutter/pull/123156)_
- * Suggest that people move to "beta" when they upgrade on "master" by @Hixie in [127146](https://github.com/flutter/flutter/pull/127146)
  - _* Show warning when attempting to flutter run on an ios device with developer mode turned off by @LouiseHsu in [125710](https://github.com/flutter/flutter/pull/125710)_
- * Give channel descriptions in `flutter channel`, use branch instead of upstream for channel name by @Hixie in [126936](https://github.com/flutter/flutter/pull/126936)
  - _* Revert "Replace rsync when unzipping artifacts on a Mac (#126703)" by @vashworth in [127430](https://github.com/flutter/flutter/pull/127430)_
- * [flutter_tools] modify Skeleton template to use ListenableBuilder instead of AnimatedBuilder by @fabiancrx in [128810](https://github.com/flutter/flutter/pull/128810)
  - _* [CP] Fix ConcurrentModificationError in DDS by @christopherfujino in [130740](https://github.com/flutter/flutter/pull/130740)_
- * [Android] Lifecycle defaults to focused instead of unfocused by @gspencergoog in [41875](https://github.com/flutter/engine/pull/41875)
  - _* [Impeller] [Android] Refactor the Android context/surface implementation to work more like Skia. by @dnfield in [41059](https://github.com/flutter/engine/pull/41059)_
- * [Impeller] Added a switch to turn on vulkan by @gaaclarke in [42585](https://github.com/flutter/engine/pull/42585)
  - _* Revert "[Impeller] Added a switch to turn on vulkan" by @zanderso in [42660](https://github.com/flutter/engine/pull/42660)_
- * Revert "[Impeller] Added a switch to turn on vulkan" by @zanderso in [42660](https://github.com/flutter/engine/pull/42660)
  - _* Platform channel for predictive back by @justinmc in [39208](https://github.com/flutter/engine/pull/39208)_
- * [Impeller] Reland: Added a switch to turn on vulkan by @gaaclarke in [42669](https://github.com/flutter/engine/pull/42669)
  - _* Predictive back breakage fix by @justinmc in [42789](https://github.com/flutter/engine/pull/42789)_
- * Remove package:js references and move to dart:js_interop by @srujzs in [41212](https://github.com/flutter/engine/pull/41212)
  - _* Turn @staticInterop tear-off into closure by @srujzs in [41643](https://github.com/flutter/engine/pull/41643)_
- * [web] Update a11y announcements to append divs instead of setting content. by @marcianx in [42258](https://github.com/flutter/engine/pull/42258)
  - _* [web] Hide JS types from dart:ui_web by @mdebbar in [42252](https://github.com/flutter/engine/pull/42252)_
- * [web] Move announcement live elements to the end of the DOM and make them `div`s instead of `label`s. by @marcianx in [42432](https://github.com/flutter/engine/pull/42432)
  - _* [web] New platform view API to get view by ID by @mdebbar in [41784](https://github.com/flutter/engine/pull/41784)_

---

### 3.10.0

**Deprecation** (26)

- * Remove doc reference to the deprecated ui.FlutterWindow API by @jason-simmons in [118064](https://github.com/flutter/flutter/pull/118064)
  - _* Added expandIconColor property on ExpansionPanelList Widget by @M97Chahboun in [115950](https://github.com/flutter/flutter/pull/115950)_
- * Remove deprecated AppBar/SliverAppBar/AppBarTheme.textTheme member by @Renzo-Olivares in [119253](https://github.com/flutter/flutter/pull/119253)
  - _* Migrate EditableTextState from addPostFrameCallbacks to compositionCallbacks by @LongCatIsLooong in [119359](https://github.com/flutter/flutter/pull/119359)_
- * Remove deprecated AnimatedSize.vsync parameter by @goderbauer in [119186](https://github.com/flutter/flutter/pull/119186)
  - _* Add debug diagnostics to channels integration test by @goderbauer in [119579](https://github.com/flutter/flutter/pull/119579)_
- * Remove deprecated SystemNavigator.routeUpdated method by @goderbauer in [119187](https://github.com/flutter/flutter/pull/119187)
  - _* Deprecate MediaQuery[Data].fromWindow by @goderbauer in [119647](https://github.com/flutter/flutter/pull/119647)_
- * Deprecate MediaQuery[Data].fromWindow by @goderbauer in [119647](https://github.com/flutter/flutter/pull/119647)
  - _* Update a test expectation that depended on an SkParagraph fix by @jason-simmons in [119756](https://github.com/flutter/flutter/pull/119756)_
- * Remove deprecated kind in GestureRecognizer et al by @Piinks in [119572](https://github.com/flutter/flutter/pull/119572)
  - _* [framework] use shader tiling instead of repeated calls to drawImage by @jonahwilliams in [119495](https://github.com/flutter/flutter/pull/119495)_
- * Remove deprecated accentTextTheme and accentIconTheme members from ThemeData by @Renzo-Olivares in [119360](https://github.com/flutter/flutter/pull/119360)
  - _* fix a [SelectableRegion] crash bug by @xu-baolin in [120076](https://github.com/flutter/flutter/pull/120076)_
- * Remove deprecated SystemChrome.setEnabledSystemUIOverlays by @Piinks in [119576](https://github.com/flutter/flutter/pull/119576)
  - _* Revert "Fix BottomAppBar & BottomSheet M3 shadow" by @CaseyHillers in [120492](https://github.com/flutter/flutter/pull/120492)_
- * Remove deprecated accentColorBrightness member from ThemeData by @QuncCccccc in [120577](https://github.com/flutter/flutter/pull/120577)
  - _* Remove references to Observatory by @bkonyi in [118577](https://github.com/flutter/flutter/pull/118577)_
- * Remove deprecated `AppBar.color` & `AppBar.backwardsCompatibility` by @LongCatIsLooong in [120618](https://github.com/flutter/flutter/pull/120618)
  - _* Revert "Fix error when resetting configurations in tear down phase" by @loic-sharma in [120739](https://github.com/flutter/flutter/pull/120739)_
- * Remove the deprecated accentColor from ThemeData by @QuncCccccc in [120932](https://github.com/flutter/flutter/pull/120932)
  - _* Remove more references to dart:ui.window by @goderbauer in [120994](https://github.com/flutter/flutter/pull/120994)_
- * [web] stop using deprecated jsonwire web-driver protocol by @yjbanov in [122560](https://github.com/flutter/flutter/pull/122560)
  - _* Reland: Updates `flutter/test/gestures` to no longer reference `TestWindow` by @pdblasi-google in [122619](https://github.com/flutter/flutter/pull/122619)_
- * Deprecates `TestWindow` by @pdblasi-google in [122824](https://github.com/flutter/flutter/pull/122824)
  - _* Bump lower Dart SDK constraints to 3.0 & add class modifiers by @goderbauer in [122546](https://github.com/flutter/flutter/pull/122546)_
- * Deprecate BindingBase.window by @goderbauer in [120998](https://github.com/flutter/flutter/pull/120998)
  - _* Remove indicator from scrolling tab bars by @Piinks in [123057](https://github.com/flutter/flutter/pull/123057)_
- * Fix warning in `flutter create`d project ("package attribute is deprecated" in AndroidManifest) by @bartekpacia in [123426](https://github.com/flutter/flutter/pull/123426)
  - _* Fix off-screen selected text throws exception by @TahaTesser in [123595](https://github.com/flutter/flutter/pull/123595)_
- * Hyperlink dart docs around BinaryMessenger deprecations by @goderbauer in [123798](https://github.com/flutter/flutter/pull/123798)
  - _* Fix docs and error messages for scroll directions + sample code by @Piinks in [123819](https://github.com/flutter/flutter/pull/123819)_
- * Deprecate these old APIs by @Hixie in [116793](https://github.com/flutter/flutter/pull/116793)
  - _* Make tester.startGesture less async, for better stack traces by @gnprice in [123946](https://github.com/flutter/flutter/pull/123946)_
- * TextSelectionHandleControls deprecation deletion timeframe by @justinmc in [124262](https://github.com/flutter/flutter/pull/124262)
  - _* [DropdownMenu] add helperText & errorText to DropdownMenu Widget by @piedcipher in [123775](https://github.com/flutter/flutter/pull/123775)_
- * Use `dart pub` instead of `dart __deprecated pub` by @sigurdm in [121605](https://github.com/flutter/flutter/pull/121605)
  - _* [tool] Proposal to multiple defines for --dart-define-from-file by @ronnnnn in [120878](https://github.com/flutter/flutter/pull/120878)_
- * [fuchsia] Replace deprecated AddLocalChild by @richkadel in [38788](https://github.com/flutter/engine/pull/38788)
  - _* Roll Skia from e1f3980272f3 to dfb838747295 (48 revisions) by @skia-flutter-autoroll in [38790](https://github.com/flutter/engine/pull/38790)_
- * @alwaysThrows is deprecated. Return `Never` instead. by @eyebrowsoffire in [39269](https://github.com/flutter/engine/pull/39269)
  - _* [macOS] Move A11yBridge to FVC by @dkwingsmt in [38855](https://github.com/flutter/engine/pull/38855)_
- * Revert "Remove deprecated TextInputClient scribble method code" by @justinmc in [39516](https://github.com/flutter/engine/pull/39516)
  - _* Roll Skia from 54342413f5c0 to 640fa258fc75 (3 revisions) by @skia-flutter-autoroll in [39544](https://github.com/flutter/engine/pull/39544)_
- * Deprecate WindowPadding by @goderbauer in [39775](https://github.com/flutter/engine/pull/39775)
  - _* Roll Skia from 335cabcf8b99 to 080897012390 (4 revisions) by @skia-flutter-autoroll in [39802](https://github.com/flutter/engine/pull/39802)_
- * Deprecate SingletonFlutterWindow and global window singleton by @goderbauer in [39302](https://github.com/flutter/engine/pull/39302)
  - _* [Impeller] Avoid truncation to zero when resizing threadgroups by @dnfield in [40502](https://github.com/flutter/engine/pull/40502)_
- * Revert "Deprecate SingletonFlutterWindow and global window singleton" by @bdero in [40507](https://github.com/flutter/engine/pull/40507)
  - _* Roll Skia from 6cdd4b3f9b8e to 3e6bfdfea566 (3 revisions) by @skia-flutter-autoroll in [40510](https://github.com/flutter/engine/pull/40510)_
- * Reland "Deprecate SingletonFlutterWindow and global window singleton (#39302)" by @goderbauer in [40511](https://github.com/flutter/engine/pull/40511)
  - _* Fix includes in image_decoder_impeller by @kjlubick in [40533](https://github.com/flutter/engine/pull/40533)_

**Breaking Change** (5)

- * Removed "if" on resolving text color at "SnackBarAction" by @MarchMore in [120050](https://github.com/flutter/flutter/pull/120050)
  - _* Fix BottomAppBar & BottomSheet M3 shadow by @esouthren in [119819](https://github.com/flutter/flutter/pull/119819)_
- * Removed "typically non-null" API doc qualifiers from ScrollMetrics min,max extent getters by @HansMuller in [121572](https://github.com/flutter/flutter/pull/121572)
  - _* showOnScreen does not crash if target node doesn't exist anymore by @goderbauer in [121575](https://github.com/flutter/flutter/pull/121575)_
- * removed forbidden skia include by @gaaclarke in [38761](https://github.com/flutter/engine/pull/38761)
  - _* Roll Dart SDK from 7b4d49402252 to 23cbd61a1327 (1 revision) by @skia-flutter-autoroll in [38764](https://github.com/flutter/engine/pull/38764)_
- * Handle removed shaders more gracefully in malioc_diff.py by @zanderso in [40720](https://github.com/flutter/engine/pull/40720)
  - _* Update ICU dependency to updated build by @yaakovschectman in [40676](https://github.com/flutter/engine/pull/40676)_
- * [Impeller] Removed requirement for multisample buffers from egl setup. by @gaaclarke in [40944](https://github.com/flutter/engine/pull/40944)
  - _* Manual roll Dart SDK from 36ace2c92e0a to 0c85a16bac6d (6 revisions) by @skia-flutter-autoroll in [40974](https://github.com/flutter/engine/pull/40974)_

**New Feature / API** (1)

- * feature/clean-a-specific-scheme: Add this-scheme new flag for clean c… by @EArminjon in [116733](https://github.com/flutter/flutter/pull/116733)
  - _* [tool][web] Makes flutter.js more G3 friendly. by @ditman in [120504](https://github.com/flutter/flutter/pull/120504)_

**New Parameter / Option** (1)

- * feature/clean-a-specific-scheme: Add this-scheme new flag for clean c… by @EArminjon in [116733](https://github.com/flutter/flutter/pull/116733)
  - _* [tool][web] Makes flutter.js more G3 friendly. by @ditman in [120504](https://github.com/flutter/flutter/pull/120504)_

**Performance Improvement** (59)

- * Speed up first asset load by encoding asset manifest in binary rather than JSON by @andrewkolos in [113637](https://github.com/flutter/flutter/pull/113637)
  - _* Improve Flex layout comment by @loic-sharma in [116004](https://github.com/flutter/flutter/pull/116004)_
- * Improve Flex layout comment by @loic-sharma in [116004](https://github.com/flutter/flutter/pull/116004)
  - _* Do not parse stack traces in _findResponsibleMethod on Web platforms that use a different format by @jason-simmons in [115500](https://github.com/flutter/flutter/pull/115500)_
- * Revert "Speed up first asset load by encoding asset manifest in binary rather than JSON" by @CaseyHillers in [116662](https://github.com/flutter/flutter/pull/116662)
  - _* Reland "Use semantics label for backbutton and closebutton for Android" by @chunhtai in [115776](https://github.com/flutter/flutter/pull/115776)_
- * `NavigationBar` improvements by @TahaTesser in [116992](https://github.com/flutter/flutter/pull/116992)
  - _* [reland] Add Material 3 support for `ListTile` \- Part 1 by @TahaTesser in [116963](https://github.com/flutter/flutter/pull/116963)_
- * Improve documentation of `compute()` function by @mkustermann in [116878](https://github.com/flutter/flutter/pull/116878)
  - _* [flutter_tools] tree shake icons from web builds by @christopherfujino in [115886](https://github.com/flutter/flutter/pull/115886)_
- * improve gesture recognizer semantics test cases by @LucasXu0 in [117257](https://github.com/flutter/flutter/pull/117257)
  - _* Fix is canvas kit bool by @alanwutang11 in [116944](https://github.com/flutter/flutter/pull/116944)_
- * Improve CupertinoContextMenu to match native more by @manuthebyte in [117698](https://github.com/flutter/flutter/pull/117698)
  - _* Add `@widgetFactory` annotation by @blaugold in [117455](https://github.com/flutter/flutter/pull/117455)_
- * Speed up first asset load by using the binary-formatted asset manifest for image resolution by @andrewkolos in [118782](https://github.com/flutter/flutter/pull/118782)
  - _* [web] Unify line boundary expectations on web and non-web by @mdebbar in [121006](https://github.com/flutter/flutter/pull/121006)_
- * Revert "Speed up first asset load by using the binary-formatted asset manifest for image resolution" by @CaseyHillers in [121220](https://github.com/flutter/flutter/pull/121220)
  - _* Add padding to DropdownButton by @davidskelly in [115806](https://github.com/flutter/flutter/pull/115806)_
- * Reland "Speed up first asset load by using the binary-formatted asset manifest for image resolution by @andrewkolos in [121322](https://github.com/flutter/flutter/pull/121322)
  - _* Update test font by @LongCatIsLooong in [121306](https://github.com/flutter/flutter/pull/121306)_
- * SystemUiOverlayStyle, add two examples and improve documentation by @bleroux in [122187](https://github.com/flutter/flutter/pull/122187)
  - _* Add one DefaultTextStyle example by @bleroux in [122182](https://github.com/flutter/flutter/pull/122182)_
- * Revert "Reland "Speed up first asset load by using the binary-formatted asset manifest for image resolution" by @jonahwilliams in [122449](https://github.com/flutter/flutter/pull/122449)
  - _* Relocate some tests from scrollable_test.dart by @Piinks in [122426](https://github.com/flutter/flutter/pull/122426)_
- * Reland "Speed up first asset load by using the binary-formatted asset manifest for image resolution" by @andrewkolos in [122505](https://github.com/flutter/flutter/pull/122505)
  - _* DateRangePicker keyboardType by @justinmc in [122353](https://github.com/flutter/flutter/pull/122353)_
- * Documentation improvements by @Hixie in [122787](https://github.com/flutter/flutter/pull/122787)
  - _* Remove 1745 decorative breaks by @goderbauer in [123259](https://github.com/flutter/flutter/pull/123259)_
- * [Shortcuts] Improve documentation by @loic-sharma in [123499](https://github.com/flutter/flutter/pull/123499)
  - _* Add alignmentOffset when menu is positioned on the opposite side by @whiskeyPeak in [122812](https://github.com/flutter/flutter/pull/122812)_
- * Remove mouse tap text drag selection throttling to improve responsiveness by @loune in [123460](https://github.com/flutter/flutter/pull/123460)
  - _* [Docs] Fix Typos by @piedcipher in [124249](https://github.com/flutter/flutter/pull/124249)_
- * reduce pub output from flutter create by @andrewkolos in [118285](https://github.com/flutter/flutter/pull/118285)
  - _* [web] Update build to use generated JS runtime for Dart2Wasm. by @joshualitt in [118359](https://github.com/flutter/flutter/pull/118359)_
- * Fix PathNotFoundException while updating artifact cache by @Jasguerrero in [119748](https://github.com/flutter/flutter/pull/119748)
  - _* Fix `pub get --unknown-flag` by @sigurdm in [119622](https://github.com/flutter/flutter/pull/119622)_
- * Delete Chrome temp cache after closing by @passsy in [119062](https://github.com/flutter/flutter/pull/119062)
  - _* Reland "[web] Move JS content to its own `.js` files" by @mdebbar in [120363](https://github.com/flutter/flutter/pull/120363)_
- * Improve network resources doctor check by @Hixie in [120417](https://github.com/flutter/flutter/pull/120417)
  - _* Temporarily disable info-based analyzer unit tests. by @eyebrowsoffire in [120753](https://github.com/flutter/flutter/pull/120753)_
- * [flutter_tool] advertise the default value for --dart2js-optimization by @kevmoo in [121621](https://github.com/flutter/flutter/pull/121621)
  - _* flutter_tool: DRY up features that are fully enabled by @kevmoo in [121754](https://github.com/flutter/flutter/pull/121754)_
- * Revert "[web:tools] always use CanvasKit from the cache when building web apps (#93002)" by @mdebbar in [117693](https://github.com/flutter/flutter/pull/117693)
  - _* Create configOnly flag for android by @reidbaker in [121904](https://github.com/flutter/flutter/pull/121904)_
- * Improve Dart plugin registration handling by @stuartmorgan in [122046](https://github.com/flutter/flutter/pull/122046)
  - _* [flutter_tools] Add namespace getter in Android project; use namespace as fallback by @navaronbracke in [121416](https://github.com/flutter/flutter/pull/121416)_
- * Always use user-level pub cache by @sigurdm in [121802](https://github.com/flutter/flutter/pull/121802)
  - _* Move target devices logic to its own classes and file by @vashworth in [121903](https://github.com/flutter/flutter/pull/121903)_
- * Notify about existing caches when preloading by @sigurdm in [122592](https://github.com/flutter/flutter/pull/122592)
  - _* Serve DevTools when running flutter test by @bkonyi in [123607](https://github.com/flutter/flutter/pull/123607)_
- * Documentation and other cleanup in dart:ui, plus a small performance improvement by @Hixie in [38047](https://github.com/flutter/engine/pull/38047)
  - _* [web] use a permanent live region for a11y announcements by @yjbanov in [38015](https://github.com/flutter/engine/pull/38015)_
- * License script improvements by @Hixie in [38148](https://github.com/flutter/engine/pull/38148)
  - _* [Windows] Synthesize modifier keys events on pointer events by @bleroux in [38138](https://github.com/flutter/engine/pull/38138)_
- * [Impeller] RRect blur improvements by @bdero in [38417](https://github.com/flutter/engine/pull/38417)
  - _* Roll Fuchsia Mac SDK from ev2n-_c3kgBw1h4RG... to nJJfWIwH5zElheIX8... by @skia-flutter-autoroll in [38424](https://github.com/flutter/engine/pull/38424)_
- * Reduce the size of Overlay FlutterImageView in HC mode by @Nayuta403 in [38393](https://github.com/flutter/engine/pull/38393)
  - _* Consider more `ax::mojom::Role`s as text by @yaakovschectman in [38645](https://github.com/flutter/engine/pull/38645)_
- * [windows] Eliminate unnecessary iostream imports by @cbracken in [38824](https://github.com/flutter/engine/pull/38824)
  - _* Roll Skia from dfb838747295 to 9e51c2c9e231 (26 revisions) by @skia-flutter-autoroll in [38827](https://github.com/flutter/engine/pull/38827)_
- * [web] cache sample and stencil params by @jonahwilliams in [38829](https://github.com/flutter/engine/pull/38829)
  - _* Roll Fuchsia Mac SDK from 21nYb648VWbpxc36t... to w0hr1ZMvYGJnWInwK... by @skia-flutter-autoroll in [38880](https://github.com/flutter/engine/pull/38880)_
- * [web] Reduce code size impact of fallback font data by @mdebbar in [38787](https://github.com/flutter/engine/pull/38787)
  - _* Roll Skia from 6afb97022fa7 to 8ea9b39f7213 (18 revisions) by @skia-flutter-autoroll in [38952](https://github.com/flutter/engine/pull/38952)_
- * Improve crashes if messenger APIs are used incorrectly by @loic-sharma in [39041](https://github.com/flutter/engine/pull/39041)
  - _* Roll Fuchsia Linux SDK from dWbkAZchFHtZE9Wt_... to E9m-Gk382PkB7_Nbp... by @skia-flutter-autoroll in [39107](https://github.com/flutter/engine/pull/39107)_
- * Fix position of ImageFilter layer when raster-cached by @moffatman in [38567](https://github.com/flutter/engine/pull/38567)
  - _* Roll Skia from c4b171fe5668 to 393fb1ec80f4 (9 revisions) by @skia-flutter-autoroll in [39138](https://github.com/flutter/engine/pull/39138)_
- * [Impeller] improve blur performance for Android and iPad Pro. by @jonahwilliams in [39291](https://github.com/flutter/engine/pull/39291)
  - _* [Impeller] let images with opacity and filters passthrough. by @jonahwilliams in [39237](https://github.com/flutter/engine/pull/39237)_
- * Update shader_optimization.md by @HannesGitH in [39497](https://github.com/flutter/engine/pull/39497)
  - _* Roll Skia from 638bfdc9e23c to 1762c093d086 (8 revisions) by @skia-flutter-autoroll in [39507](https://github.com/flutter/engine/pull/39507)_
- * [macOS] Improve TextInputPlugin test readability by @cbracken in [39664](https://github.com/flutter/engine/pull/39664)
  - _* Roll Dart SDK from a594e34e85b6 to ce9397c5fc8f (1 revision) by @skia-flutter-autoroll in [39667](https://github.com/flutter/engine/pull/39667)_
- * Cached DisplayList opacity inheritance fix by @flar in [39690](https://github.com/flutter/engine/pull/39690)
  - _* Roll Dart SDK from 7642080abaf7 to 42829b6f80b1 (1 revision) by @skia-flutter-autoroll in [39707](https://github.com/flutter/engine/pull/39707)_
- * uncomment a DL raster cache unittest enhancement now that it is feasible by @flar in [39845](https://github.com/flutter/engine/pull/39845)
  - _* remove obsolete DisplayListCanvasRecorder and its tests by @flar in [39844](https://github.com/flutter/engine/pull/39844)_
- * [Impeller] drawAtlas performance improvements by @jason-simmons in [39865](https://github.com/flutter/engine/pull/39865)
  - _* [Impeller] dont append to existing atlas if type changed by @jonahwilliams in [39913](https://github.com/flutter/engine/pull/39913)_
- * [Impeller] Improve atlas blending performance by reducing size of subpass. by @jonahwilliams in [39669](https://github.com/flutter/engine/pull/39669)
  - _* [Impeller] Add checkbox for toggling the ColorWheel cache by @bdero in [39986](https://github.com/flutter/engine/pull/39986)_
- * [Impeller] Add checkbox for toggling the ColorWheel cache by @bdero in [39986](https://github.com/flutter/engine/pull/39986)
  - _* add DlCanvas(SkCanvas) vs DlCanvas(Builder) variants to DL rendertests by @flar in [39944](https://github.com/flutter/engine/pull/39944)_
- * Do not end the frame in the raster cache if ScopedFrame::Raster returns kResubmit by @jason-simmons in [40007](https://github.com/flutter/engine/pull/40007)
  - _* [macOS] Add README.md for macOS embedder by @cbracken in [40032](https://github.com/flutter/engine/pull/40032)_
- * Always use integers to hold the size of the performance overlay cache bitmap by @jason-simmons in [40071](https://github.com/flutter/engine/pull/40071)
  - _* Roll Fuchsia Linux SDK from 7zNyN-D58x6wG7HL8... to 4iq5VNjEcZIlrUtDK... by @skia-flutter-autoroll in [40080](https://github.com/flutter/engine/pull/40080)_
- * Optimize search for the default bundle by @jiahaog in [39975](https://github.com/flutter/engine/pull/39975)
  - _* Roll Skia from fd380c7801f8 to 3e38c84ce48e (1 revision) by @skia-flutter-autoroll in [40096](https://github.com/flutter/engine/pull/40096)_
- * [Impeller] Optimize the calculation of interpolant value of linear gradient by @ColdPaleLight in [40085](https://github.com/flutter/engine/pull/40085)
  - _* [Impeller] Replace FML_OS_PHYSICAL_IOS compile check with runtime capabilties check based on metal GPU family. by @jonahwilliams in [40124](https://github.com/flutter/engine/pull/40124)_
- * Improve error messaging when render target cannot be created by @dnfield in [40150](https://github.com/flutter/engine/pull/40150)
  - _* Add missing inputs declaration by @eseidel in [40133](https://github.com/flutter/engine/pull/40133)_
- * Improve Linux texture examples. by @robert-ancell in [40289](https://github.com/flutter/engine/pull/40289)
  - _* [Impeller] Simplify subpass branches; remove unused effect_matrix param by @bdero in [40292](https://github.com/flutter/engine/pull/40292)_
- * [Impeller] Improve performance of CupertinoPicker with opacity peephole by @jonahwilliams in [40101](https://github.com/flutter/engine/pull/40101)
  - _* Reland "Make FlutterTest the default test font" (#40188) by @LongCatIsLooong in [40245](https://github.com/flutter/engine/pull/40245)_
- * [macOS] Eliminate unnecessary dynamic declaration by @cbracken in [40327](https://github.com/flutter/engine/pull/40327)
  - _* [Impeller] fix opacity inheritance test by @jonahwilliams in [40360](https://github.com/flutter/engine/pull/40360)_
- * [Impeller] mark decoded images as optimized for GPU access by @jonahwilliams in [40356](https://github.com/flutter/engine/pull/40356)
  - _* Remove work around for dart 3 compiler bug by @goderbauer in [40350](https://github.com/flutter/engine/pull/40350)_
- * Revert "[Impeller] mark decoded images as optimized for GPU access" by @jonahwilliams in [40387](https://github.com/flutter/engine/pull/40387)
  - _* Wrap the iOS platform message handler in an autorelease pool block by @jason-simmons in [40373](https://github.com/flutter/engine/pull/40373)_
- * Improved readme for impeller golden tests. by @gaaclarke in [40679](https://github.com/flutter/engine/pull/40679)
  - _* Web test reorganization by @eyebrowsoffire in [39984](https://github.com/flutter/engine/pull/39984)_
- * Disable LTO in builds of CanvasKit to reduce binary size by @jason-simmons in [40733](https://github.com/flutter/engine/pull/40733)
  - _* Switch from Noto Emoji to Noto Color Emoji and update font data by @hterkelsen in [40666](https://github.com/flutter/engine/pull/40666)_
- * [web] LRU cache for text segmentation by @mdebbar in [40782](https://github.com/flutter/engine/pull/40782)
  - _* [Impeller] Go back to using MSL compiler backend for Vulkan by @dnfield in [40786](https://github.com/flutter/engine/pull/40786)_
- * [Impeller] reduce advanced blend subpass count for single input with foreground color by @jonahwilliams in [40886](https://github.com/flutter/engine/pull/40886)
  - _* Roll Skia from 57aa7f9475de to ad459a5b8df4 (2 revisions) by @skia-flutter-autoroll in [40900](https://github.com/flutter/engine/pull/40900)_
- * [Impeller] reduce gaussian sampling by 2x by @jonahwilliams in [40871](https://github.com/flutter/engine/pull/40871)
  - _* [Impeller] Respect enable-impeller command line setting over info.plist setting by @dnfield in [40902](https://github.com/flutter/engine/pull/40902)_
- * Revert "[Impeller] reduce advanced blend subpass count for single input with foreground color" by @jonahwilliams in [40914](https://github.com/flutter/engine/pull/40914)
  - _* [web] remove obsolete object caches; simplify native object management by @yjbanov in [40894](https://github.com/flutter/engine/pull/40894)_
- * [CP][Impeller] Improve accuracy of glyph spacing (#41101) by @bdero in [41123](https://github.com/flutter/engine/pull/41123)
  - _* [CP] [Impeller] Allow image rasterization/decoding before/without surface … by @dnfield in [41189](https://github.com/flutter/engine/pull/41189)_

**Replacement / Migration** (22)

- * [framework] use shader tiling instead of repeated calls to drawImage by @jonahwilliams in [119495](https://github.com/flutter/flutter/pull/119495)
  - _* Dispose OverlayEntry in TooltipState. by @polina-c in [117291](https://github.com/flutter/flutter/pull/117291)_
- * Use String.codeUnitAt instead of String.codeUnits[] in ParagraphBoundary by @Renzo-Olivares in [120234](https://github.com/flutter/flutter/pull/120234)
  - _* Fix lerping for `NavigationRailThemeData` icon themes by @guidezpl in [120066](https://github.com/flutter/flutter/pull/120066)_
- * Modify focus traversal policy search to use focus tree instead of widget tree by @gspencergoog in [121186](https://github.com/flutter/flutter/pull/121186)
  - _* Change mouse cursor to be SystemMouseCursors.click when not editable by @QuncCccccc in [121353](https://github.com/flutter/flutter/pull/121353)_
- * implement Iterator and Comparable instead of extending them by @jakemac53 in [123282](https://github.com/flutter/flutter/pull/123282)
  - _* FIX: NavigationDrawer hover/focus/pressed do not use indicatorShape by @rydmike in [123325](https://github.com/flutter/flutter/pull/123325)_
- * Initialize `ThemeData.visualDensity` using `ThemeData.platform` instead of `defaultTargetPlatform` by @gspencergoog in [124357](https://github.com/flutter/flutter/pull/124357)
  - _* Revert "Refactor reorderable list semantics" by @XilaiZhang in [124368](https://github.com/flutter/flutter/pull/124368)_
- * Refactoring to use `ver` command instead of `systeminfo` by @eliasyishak in [119304](https://github.com/flutter/flutter/pull/119304)
  - _* Reland "Add --serve-observatory flag to run, attach, and test (#118402)" by @bkonyi in [119529](https://github.com/flutter/flutter/pull/119529)_
- * 🥅 Produce warning instead of error for storage base url overrides by @AlexV525 in [119595](https://github.com/flutter/flutter/pull/119595)
  - _* Revert "Add --serve-observatory flag to run, attach, and test (#118402)" by @zanderso in [119729](https://github.com/flutter/flutter/pull/119729)_
- * Remove test that verifies we can switch to stateless by @jonahwilliams in [120390](https://github.com/flutter/flutter/pull/120390)
  - _* Resolve dwarf paths to enable source-code mapping of stacktraces by @vaind in [114767](https://github.com/flutter/flutter/pull/114767)_
- * Use `dart pub` instead of `dart __deprecated pub` by @sigurdm in [121605](https://github.com/flutter/flutter/pull/121605)
  - _* [tool] Proposal to multiple defines for --dart-define-from-file by @ronnnnn in [120878](https://github.com/flutter/flutter/pull/120878)_
- * Use variable instead of multiple accesses through a map by @ueman in [122178](https://github.com/flutter/flutter/pull/122178)
  - _* Improve Dart plugin registration handling by @stuartmorgan in [122046](https://github.com/flutter/flutter/pull/122046)_
- * [Impeller] Use DrawPath instead of Rect geometry when the paint style is stroke by @bdero in [38146](https://github.com/flutter/engine/pull/38146)
  - _* Roll Skia from dd3285a80b23 to f84dc9303045 (4 revisions) by @skia-flutter-autoroll in [38123](https://github.com/flutter/engine/pull/38123)_
- * [Impeller] Switch to nearest sampling for the text atlas by @bdero in [39104](https://github.com/flutter/engine/pull/39104)
  - _* Manually roll ANGLE, vulkan-deps, SwiftShader by @loic-sharma in [38650](https://github.com/flutter/engine/pull/38650)_
- * [web] use a render target instead of a new surface for Picture.toImage by @jonahwilliams in [38573](https://github.com/flutter/engine/pull/38573)
  - _* Roll Skia from da5034f9d117 to c4b171fe5668 (1 revision) by @skia-flutter-autoroll in [39127](https://github.com/flutter/engine/pull/39127)_
- * [Windows] Use 'ninja' instead of 'ninja.exe' by @loic-sharma in [39326](https://github.com/flutter/engine/pull/39326)
  - _* [web] Hide autofill overlay by @htoor3 in [39294](https://github.com/flutter/engine/pull/39294)_
- * [Impeller] Return entities from filters instead of snapshots by @bdero in [39560](https://github.com/flutter/engine/pull/39560)
  - _* [Impeller] Fix grammatical issues in faq.md. by @matthiasn in [39582](https://github.com/flutter/engine/pull/39582)_
- * Uses `int64_t` instead of `int` for the |view_id| parameter. by @0xZOne in [39618](https://github.com/flutter/engine/pull/39618)
  - _* [ios] reland "[ios_platform_view] MaskView pool to reuse maskViews. #38989" by @cyanglaz in [39630](https://github.com/flutter/engine/pull/39630)_
- * Use skia_enable_ganesh instead of legacy GN arg by @kjlubick in [40382](https://github.com/flutter/engine/pull/40382)
  - _* disabled the impeller unit tests again by @gaaclarke in [40389](https://github.com/flutter/engine/pull/40389)_
- * [Impeller] Load instead of restore drawing for non-MSAA passes by @bdero in [40436](https://github.com/flutter/engine/pull/40436)
  - _* Roll Skia from 30456d261bd0 to d21c3f85a242 (1 revision) by @skia-flutter-autoroll in [40444](https://github.com/flutter/engine/pull/40444)_
- * Roll buildroot to build CanvasKit for speed instead of code size by @hterkelsen in [40737](https://github.com/flutter/engine/pull/40737)
  - _* [Impeller] Gaussian blur: Add alpha mask specialization by @bdero in [40707](https://github.com/flutter/engine/pull/40707)_
- * [Impeller] Enable playgrounds using a runtime instead of a build time flag. by @chinmaygarde in [40729](https://github.com/flutter/engine/pull/40729)
  - _* Roll Skia from 145d93ee3f4f to 001ba6e28f99 (2 revisions) by @skia-flutter-autoroll in [40754](https://github.com/flutter/engine/pull/40754)_
- * Switch from Noto Emoji to Noto Color Emoji and update font data by @hterkelsen in [40666](https://github.com/flutter/engine/pull/40666)
  - _* [macOS]Support SemanticsService.announce by @hangyujin in [40585](https://github.com/flutter/engine/pull/40585)_
- * Use new SkImages namespace instead of legacy SkImage static functions by @kjlubick in [40761](https://github.com/flutter/engine/pull/40761)
  - _* [Impeller] Un-ifdef vulkan code in impellerc by @zanderso in [40797](https://github.com/flutter/engine/pull/40797)_

---

### 3.7.0

**Deprecation** (20)

- * Removed references to deprecated styleFrom parameters. by @darrenaustin in https://github.com/flutter/flutter/pull/108401
  - _* Add RenderRepaintBoundary.toImageSync() method by @tgucio in https://github.com/flutter/flutter/pull/108280_
- * Deprecate `toggleableActiveColor` by @TahaTesser in https://github.com/flutter/flutter/pull/97972
  - _* Revert "Fix ExpansionTile shows children background when expanded" by @Piinks in https://github.com/flutter/flutter/pull/108844_
- * Deprecate ThemeData.selectedRowColor by @Piinks in https://github.com/flutter/flutter/pull/109070
  - _* Reland: "Add `outlineVariant` and `scrim` colors to `ColorScheme`" by @guidezpl in https://github.com/flutter/flutter/pull/109203_
- * Deprecate 2018 text theme parameters by @Piinks in https://github.com/flutter/flutter/pull/109817
  - _* Fixed leading button size on app bar by @QuncCccccc in https://github.com/flutter/flutter/pull/110043_
- * Fixed some doc typos in OutlinedButton and TextButton.styleFrom deprecations by @darrenaustin in https://github.com/flutter/flutter/pull/110308
  - _* Revert "Update accessibility contrast test coverage" by @CaseyHillers in https://github.com/flutter/flutter/pull/110436_
- * Deprecate `ThemeData` `errorColor` and `backgroundColor` by @guidezpl in https://github.com/flutter/flutter/pull/110162
  - _* Fix Tooltip Issue on Switch by @QuncCccccc in https://github.com/flutter/flutter/pull/110830_
- * Deprecate ThemeData.bottomAppBarColor by @esouthren in https://github.com/flutter/flutter/pull/111080
  - _* Fixed one-frame InkWell overlay color problem on unhover by @HansMuller in https://github.com/flutter/flutter/pull/111112_
- * Add missing deprecation notice for toggleableActiveColor by @Piinks in https://github.com/flutter/flutter/pull/111707
  - _* Reset missing deprecation for ScrollbarThemeData.copyWith(showTrackOnHover) by @Piinks in https://github.com/flutter/flutter/pull/111706_
- * Reset missing deprecation for ScrollbarThemeData.copyWith(showTrackOnHover) by @Piinks in https://github.com/flutter/flutter/pull/111706
  - _* Makes TextBoundary and its subclasses public by @chunhtai in https://github.com/flutter/flutter/pull/110367_
- * Remove deprecated drag anchor by @Piinks in https://github.com/flutter/flutter/pull/111713
  - _* Provide Material 3 defaults for vanilla `Chip` widget. by @darrenaustin in https://github.com/flutter/flutter/pull/111597_
- * Remove deprecated ScrollBehavior.buildViewportChrome by @Piinks in https://github.com/flutter/flutter/pull/111715
  - _* Update token v0.127 to v0.132 by @QuncCccccc in https://github.com/flutter/flutter/pull/111913_
- * Remove Deprecated RenderUnconstrainedBox by @Piinks in https://github.com/flutter/flutter/pull/111711
  - _* Fix an reorderable list animation issue:"Reversed ReorderableListView drop animation moves item one row higher than it should #110949" by @hangyujin in https://github.com/flutter/flutter/pull/111027_
- * Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` by @gspencergoog in https://github.com/flutter/flutter/pull/113131
  - _* `AutomatedTestWidgetsFlutterBinding.pump` provides wrong pump time stamp, probably because of forgetting the precision by @fzyzcjy in https://github.com/flutter/flutter/pull/112609_
- * [framework] add ignores for platformDispatcher deprecation by @jonahwilliams in https://github.com/flutter/flutter/pull/113238
  - _* Minor change type nullability by @fzyzcjy in https://github.com/flutter/flutter/pull/112778_
- * Remove deprecated `updateSemantics` API usage. by @a-wallen in https://github.com/flutter/flutter/pull/113382
  - _* Fix logical error in TimePickerDialog - the RenderObject forgets to update fields by @fzyzcjy in https://github.com/flutter/flutter/pull/112040_
- * Ignore NullThrownError deprecation by @mit-mit in https://github.com/flutter/flutter/pull/116135
  - _* Disable backspace/delete handling on iOS & macOS by @LongCatIsLooong in https://github.com/flutter/flutter/pull/115900_
- * Remove doc for --ignore-deprecation and check for pubspec before v1 embedding check by @GaryQian in https://github.com/flutter/flutter/pull/108523
  - _* [flutter_tools] join flutter specific with home cache by @Jasguerrero in https://github.com/flutter/flutter/pull/105343_
- * Remove deprecated Ruby File.exists? in helper script by @jmagman in https://github.com/flutter/flutter/pull/109428
  - _* Update `flutter.gradle` AGP to 7.2.0 and bump default NDK version by @GaryQian in https://github.com/flutter/flutter/pull/109211_
- * Add bitcode deprecation note for add-to-app iOS developers by @jmagman in https://github.com/flutter/flutter/pull/112900
  - _* Upgrade targetSdkVersion and compileSdkVersion to 33 by @GaryQian in https://github.com/flutter/flutter/pull/112936_
- * [flutter_tools] add deprecation message for "flutter format" by @christopherfujino in https://github.com/flutter/flutter/pull/116145
  - _* [gen_l10n] Improvements to `gen_l10n` by @thkim1011 in https://github.com/flutter/flutter/pull/116202_

**Breaking Change** (8)

- * Removed references to deprecated styleFrom parameters. by @darrenaustin in https://github.com/flutter/flutter/pull/108401
  - _* Add RenderRepaintBoundary.toImageSync() method by @tgucio in https://github.com/flutter/flutter/pull/108280_
- * Fix doc comment line accidentally removed by @kevmoo in https://github.com/flutter/flutter/pull/108654
  - _* [framework] create animation from value listenable by @jonahwilliams in https://github.com/flutter/flutter/pull/108644_
- * fix: removed Widget type from child parameter in OutlinedButton by @alestiago in https://github.com/flutter/flutter/pull/111034
  - _* Started handling messages from background isolates. by @gaaclarke in https://github.com/flutter/flutter/pull/109005_
- * Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` by @gspencergoog in https://github.com/flutter/flutter/pull/113131
  - _* `AutomatedTestWidgetsFlutterBinding.pump` provides wrong pump time stamp, probably because of forgetting the precision by @fzyzcjy in https://github.com/flutter/flutter/pull/112609_
- * Minor change type nullability by @fzyzcjy in https://github.com/flutter/flutter/pull/112778
  - _* Revert "Minor change type nullability" by @jmagman in https://github.com/flutter/flutter/pull/113246_
- * Revert "Minor change type nullability" by @jmagman in https://github.com/flutter/flutter/pull/113246
  - _* Support Material 3 in bottom sheet by @hangyujin in https://github.com/flutter/flutter/pull/112466_
- * Change type in `ImplicitlyAnimatedWidget` to remove type cast to improve performance and style by @fzyzcjy in https://github.com/flutter/flutter/pull/111849
  - _* make ModalBottomSheetRoute public by @The-Redhat in https://github.com/flutter/flutter/pull/108112_
- * Fix wasted memory caused by debug fields - 16 bytes per object (when adding that should-be-removed field crosses double-word alignment) by @fzyzcjy in https://github.com/flutter/flutter/pull/113927
  - _* Fix text field label animation duration and curve by @Pourqavam in https://github.com/flutter/flutter/pull/105966_

**New Feature / API** (1)

- * [New Feature]Support mouse wheel event on the scrollbar widget by @xu-baolin in https://github.com/flutter/flutter/pull/109659
  - _* Adds support for the Material Badge widget, BadgeTheme, BadgeThemeData by @HansMuller in https://github.com/flutter/flutter/pull/114560_

**New Parameter / Option** (1)

- * [flutter_tools] Introducing arg option for specifying the output directory for web by @eliasyishak in https://github.com/flutter/flutter/pull/113076
  - _* Always invoke impeller ios shader target by @jonahwilliams in https://github.com/flutter/flutter/pull/114451_

**Performance Improvement** (23)

- * Use toPictureSync for faster zoom page transition by @jonahwilliams in https://github.com/flutter/flutter/pull/106621
  - _* Allow trackpad inertia cancel events by @moffatman in https://github.com/flutter/flutter/pull/108190_
- * Optimize closure in input_decorator_theme by @hangyujin in https://github.com/flutter/flutter/pull/108379
  - _* Suggest predicate-based formatter in [FilteringTextInputFormatter] docs for whole string matching by @LongCatIsLooong in https://github.com/flutter/flutter/pull/107848_
- * Improve dumpSemanticsTree error when semantics are unavailable by @goderbauer in https://github.com/flutter/flutter/pull/108574
  - _* Update web links for autofill by @kevmoo in https://github.com/flutter/flutter/pull/108640_
- * Improve ShapeDecoration performance. by @bernaferrari in https://github.com/flutter/flutter/pull/108648
  - _* 109638: Windows framework_tests_misc is 2.06% flaky by @pdblasi-google in https://github.com/flutter/flutter/pull/109640_
- * Change type in `ImplicitlyAnimatedWidget` to remove type cast to improve performance and style by @fzyzcjy in https://github.com/flutter/flutter/pull/111849
  - _* make ModalBottomSheetRoute public by @The-Redhat in https://github.com/flutter/flutter/pull/108112_
- * Improve Scrollbar drag behavior by @xu-baolin in https://github.com/flutter/flutter/pull/112434
  - _* Fix `Slider` overlay and value indicator interactive behavior on desktop. by @TahaTesser in https://github.com/flutter/flutter/pull/113543_
- * Cache TextPainter plain text value to improve performance by @tgucio in https://github.com/flutter/flutter/pull/109841
  - _* fix stretch effect with rtl support by @youssefali424 in https://github.com/flutter/flutter/pull/113214_
- * 🎨 Improve exceptions thrown by asset bundle by @AlexV525 in https://github.com/flutter/flutter/pull/114313
  - _* Minor code cleanup: remove redundant return by @fzyzcjy in https://github.com/flutter/flutter/pull/114290_
- * Handle dragging improvements by @justinmc in https://github.com/flutter/flutter/pull/114042
  - _* Add Material 3 Popup Menu example and update existing example by @TahaTesser in https://github.com/flutter/flutter/pull/114228_
- * Improve showSnackBar documentation by @bleroux in https://github.com/flutter/flutter/pull/114612
  - _* Update comments in theme data files by @hangyujin in https://github.com/flutter/flutter/pull/115603_
- * Tiny improvement of RouteSettings display by @fzyzcjy in https://github.com/flutter/flutter/pull/114481
  - _* Add more InkWell tests by @bleroux in https://github.com/flutter/flutter/pull/115634_
- * Improve coverage speed by using new caching option for package:coverage by @jensjoha in https://github.com/flutter/flutter/pull/107395
  - _* Check for analyzer rule names instead of descriptions in a flutter_tools test by @jason-simmons in https://github.com/flutter/flutter/pull/107541_
- * Only show iOS simulators, reduce output spew in verbose by @jmagman in https://github.com/flutter/flutter/pull/108345
  - _* Set Xcode build script phases to always run by @jmagman in https://github.com/flutter/flutter/pull/108331_
- * [flutter_tools] join flutter specific with home cache by @Jasguerrero in https://github.com/flutter/flutter/pull/105343
  - _* Ignore body_might_complete_normally_catch_error violations by @srawlins in https://github.com/flutter/flutter/pull/106563_
- * refactor: strip all local symbols from macOS and iOS App.framework - reduces app size by @vaind in https://github.com/flutter/flutter/pull/111264
  - _* Remove .pub directories from iml templates by @natebosch in https://github.com/flutter/flutter/pull/109622_
- * [flutter_tools] reduce doctor timeout to debug 111686 by @christopherfujino in https://github.com/flutter/flutter/pull/111687
  - _* [flutter_tools] fix AndroidSdk.reinitialize bad state error by @christopherfujino in https://github.com/flutter/flutter/pull/111527_
- * Startup flutter faster (faster wrapper script on Windows) by @jensjoha in https://github.com/flutter/flutter/pull/111465
  - _* Startup `flutter` faster (Only access globals.deviceManager if actually setting something) by @jensjoha in https://github.com/flutter/flutter/pull/111461_
- * Startup `flutter` faster (Only access globals.deviceManager if actually setting something) by @jensjoha in https://github.com/flutter/flutter/pull/111461
  - _* Startup `flutter` faster (use app-jit snapshot) by @jensjoha in https://github.com/flutter/flutter/pull/111459_
- * Startup `flutter` faster (use app-jit snapshot) by @jensjoha in https://github.com/flutter/flutter/pull/111459
  - _* fix for flakey analyze test by @eliasyishak in https://github.com/flutter/flutter/pull/111895_
- * [flutter_tools] cache more directories by @jonahwilliams in https://github.com/flutter/flutter/pull/112651
  - _* [flutter_tools] analyze --suggestions --machine command by @GaryQian in https://github.com/flutter/flutter/pull/112217_
- * improve debugging when dart pub get call fails by @christopherfujino in https://github.com/flutter/flutter/pull/112968
  - _* When updating packages, do not delete the simulated SDK directory until all pub invocations have finished by @jason-simmons in https://github.com/flutter/flutter/pull/112975_
- * Add more supported simulator debugging options and improve tests by @vashworth in https://github.com/flutter/flutter/pull/114628
  - _* [flutter_tools/dap] Add support for forwarding `flutter run --machine` exposeUrl requests to the DAP client by @DanTup in https://github.com/flutter/flutter/pull/114539_
- * [gen_l10n] Improvements to `gen_l10n` by @thkim1011 in https://github.com/flutter/flutter/pull/116202
  - _* Reland "Upgrade targetSdkVersion and compileSdkVersion to 33" by @GaryQian in https://github.com/flutter/flutter/pull/116146_

**Replacement / Migration** (11)

- * Error in docs: `CustomPaint` instead of `CustomPainter` by @0xba1 in https://github.com/flutter/flutter/pull/107836
  - _* Dropdown height large scale text fix by @foongsq in https://github.com/flutter/flutter/pull/107201_
- * Change default value of `effectiveInactivePressedOverlayColor` in Switch to refer to `effectiveInactiveThumbColor` by @QuncCccccc in https://github.com/flutter/flutter/pull/108477
  - _* Guard against usage after async callbacks in RenderAndroidView, unregister listener by @dnfield in https://github.com/flutter/flutter/pull/108496_
- * Fix references to symbols to use brackets instead of backticks by @gspencergoog in https://github.com/flutter/flutter/pull/111331
  - _* Add doc note about when to dispose TextPainter by @dnfield in https://github.com/flutter/flutter/pull/111403_
- * [framework] use Visibility instead of Opacity by @jonahwilliams in https://github.com/flutter/flutter/pull/112191
  - _* Add regression test for TextPainter.getWordBoundary by @LongCatIsLooong in https://github.com/flutter/flutter/pull/112229_
- * Use ScrollbarTheme instead Theme for Scrollbar by @Oleh-Sv in https://github.com/flutter/flutter/pull/113237
  - _* Add `AnimatedIcons` previews and examples by @TahaTesser in https://github.com/flutter/flutter/pull/113700_
- * Use `double.isNaN` instead of `... == double.nan` (which is always false) by @mkustermann in https://github.com/flutter/flutter/pull/115424
  - _* InkResponse highlights can be updated by @bleroux in https://github.com/flutter/flutter/pull/115635_
- * Check for analyzer rule names instead of descriptions in a flutter_tools test by @jason-simmons in https://github.com/flutter/flutter/pull/107541
  - _* [flutter_tools] Catch more general XmlException rather than XmlParserException by @christopherfujino in https://github.com/flutter/flutter/pull/107574_
- * Check device type using platformType instead of type check to support proxied devices. by @chingjun in https://github.com/flutter/flutter/pull/107618
  - _* [Windows] Remove the usage of `SETLOCAL ENABLEDELAYEDEXPANSION` from bat scripts. by @moko256 in https://github.com/flutter/flutter/pull/106861_
- * check for pubspec instead of lib/ by @Jasguerrero in https://github.com/flutter/flutter/pull/107968
  - _* [flutter_tools] add more debugging when pub get fails by @christopherfujino in https://github.com/flutter/flutter/pull/108062_
- * error handling when path to dir provided instead of file by @eliasyishak in https://github.com/flutter/flutter/pull/109796
  - _* [flutter_tools] reduce doctor timeout to debug 111686 by @christopherfujino in https://github.com/flutter/flutter/pull/111687_
- * Use directory exists instead of path.dirname by @Jasguerrero in https://github.com/flutter/flutter/pull/112219
  - _* Treat assets as variants only if they share the same filename by @jason-simmons in https://github.com/flutter/flutter/pull/112602_

---

### 3.3.0

**Deprecation** (13)

- * Remove deprecated RaisedButton by @Piinks in https://github.com/flutter/flutter/pull/98547
  - _* Remove text selection ThemeData deprecations 3 by @Piinks in https://github.com/flutter/flutter/pull/100586_
- * Remove text selection ThemeData deprecations 3 by @Piinks in https://github.com/flutter/flutter/pull/100586
  - _* Configurable padding around FocusNodes in Scrollables by @ds84182 in https://github.com/flutter/flutter/pull/96815_
- * Remove deprecated Scaffold SnackBar API by @Piinks in https://github.com/flutter/flutter/pull/98549
  - _* Migrate common buttons to Material 3 by @darrenaustin in https://github.com/flutter/flutter/pull/100794_
- * Remove deprecated FlatButton by @Piinks in https://github.com/flutter/flutter/pull/98545
  - _* Refactor chip class and move independent chips into separate classes by @TahaTesser in https://github.com/flutter/flutter/pull/101507_
- * Removed required from deprecated API by @Piinks in https://github.com/flutter/flutter/pull/102107
  - _* Expose `ignoringPointer` property for `Draggable` and `LongPressDraggable` by @xu-baolin in https://github.com/flutter/flutter/pull/100475_
- * [framework] remove usage and deprecate physical model layer by @jonahwilliams in https://github.com/flutter/flutter/pull/102274
  - _* Revert "[framework] Reland: use ImageFilter for zoom page transition " by @jonahwilliams in https://github.com/flutter/flutter/pull/102611_
- * Ignore uses of soon-to-be deprecated `NullThrownError`. by @lrhn in https://github.com/flutter/flutter/pull/105693
  - _* Fix `StretchingOverscrollIndicator` clipping and add `clipBehavior` parameter by @TahaTesser in https://github.com/flutter/flutter/pull/105303_
- * Mark use of deprecated type. by @lrhn in https://github.com/flutter/flutter/pull/106282
  - _* [platform_view]Send platform message when platform view is focused by @hellohuanlin in https://github.com/flutter/flutter/pull/105050_
- * Fix BidirectionalIterator deprecation warning and roll engine to a1dd50405992 by @bdero in https://github.com/flutter/flutter/pull/106595
  - _* Fix typo in compute documentation: "captures" -> "capture" by @hacker1024 in https://github.com/flutter/flutter/pull/106624_
- * [flutter_tools] remove assertion for deprecation .packages by @jonahwilliams in https://github.com/flutter/flutter/pull/103729
  - _* [flutter_tools] ensure linux doctor validator finishes when pkg-config is not installed by @christopherfujino in https://github.com/flutter/flutter/pull/103755_
- * Fix deprecation doc comment by @cbracken in https://github.com/flutter/flutter/pull/103776
  - _* [tool] Fix BuildInfo.packagesPath doc comment by @cbracken in https://github.com/flutter/flutter/pull/103785_
- * [tool] Migrate off deprecated coverage parameters by @cbracken in https://github.com/flutter/flutter/pull/104997
  - _* Retry builds when SSL exceptions are thrown by @blasten in https://github.com/flutter/flutter/pull/105078_
- * Remove deprecated Ruby File.exists? in helper script by @jmagman in https://github.com/flutter/flutter/pull/110045

**Breaking Change** (4)

- * removed obsolete timelineArgumentsIndicatingLandmarkEvent by @gaaclarke in https://github.com/flutter/flutter/pull/101382
  - _* [framework] use ImageFilter for zoom page transition by @jonahwilliams in https://github.com/flutter/flutter/pull/101786_
- * Removed extra the by @QuncCccccc in https://github.com/flutter/flutter/pull/101837
  - _* Revert changes to opacity/fade transition repaint boundary and secondary change by @jonahwilliams in https://github.com/flutter/flutter/pull/101844_
- * Removed required from deprecated API by @Piinks in https://github.com/flutter/flutter/pull/102107
  - _* Expose `ignoringPointer` property for `Draggable` and `LongPressDraggable` by @xu-baolin in https://github.com/flutter/flutter/pull/100475_
- * fix: Removed helper method from Scaffold by @albertodev01 in https://github.com/flutter/flutter/pull/99714
  - _* [DataTable]: Add ability to only select row using checkbox by @TahaTesser in https://github.com/flutter/flutter/pull/105123_

**New Feature / API** (4)

- * RawKeyboardMacos accepts a new field "specifiedLogicalKey" by @dkwingsmt in https://github.com/flutter/flutter/pull/100803
  - _* Revert "Add default selection style (#100719)" by @chunhtai in https://github.com/flutter/flutter/pull/101921_
- * Mention that `NavigationBar` is a new widget by @guidezpl in https://github.com/flutter/flutter/pull/104264
  - _* [Keyboard, Windows] Fix that IME events are still dispatched to FocusNode.onKey by @dkwingsmt in https://github.com/flutter/flutter/pull/104244_
- * Added option for Platform Channel statistics and Timeline events by @gaaclarke in https://github.com/flutter/flutter/pull/104531
  - _* Update links to `material` library docs by @guidezpl in https://github.com/flutter/flutter/pull/104392_
- * Add new widget of the week videos by @guidezpl in https://github.com/flutter/flutter/pull/107301
  - _* Reland "Disable cursor opacity animation on macOS, make iOS cursor animation discrete (#104335)" by @LongCatIsLooong in https://github.com/flutter/flutter/pull/106893_

**New Parameter / Option** (2)

- * RawKeyboardMacos accepts a new field "specifiedLogicalKey" by @dkwingsmt in https://github.com/flutter/flutter/pull/100803
  - _* Revert "Add default selection style (#100719)" by @chunhtai in https://github.com/flutter/flutter/pull/101921_
- * Added option for Platform Channel statistics and Timeline events by @gaaclarke in https://github.com/flutter/flutter/pull/104531
  - _* Update links to `material` library docs by @guidezpl in https://github.com/flutter/flutter/pull/104392_

**Performance Improvement** (21)

- * Improve A11Y tests for text contrast by @matasb-google in https://github.com/flutter/flutter/pull/100267
  - _* Fixes `FadeInImage` to follow gapless playback by @werainkhatri in https://github.com/flutter/flutter/pull/94601_
- * made ascii string encoding faster by @gaaclarke in https://github.com/flutter/flutter/pull/101777
  - _* Always finish the timeline event logged by Element.inflateWidget by @jason-simmons in https://github.com/flutter/flutter/pull/101794_
- * Add Material 3 `NavigationRail` example and improve Material 2 example by @TahaTesser in https://github.com/flutter/flutter/pull/101345
  - _* Migrate `ListTile` TextTheme TextStyle references to Material 3 by @TahaTesser in https://github.com/flutter/flutter/pull/101900_
- * Fix a `DataTable` crash and improve some docs by @xu-baolin in https://github.com/flutter/flutter/pull/100959
  - _* Removed required from deprecated API by @Piinks in https://github.com/flutter/flutter/pull/102107_
- * Improve 'NestedScrollView and internal scrolling' test to account for all the inner children layers by @TahaTesser in https://github.com/flutter/flutter/pull/102309
  - _* Adds tooltip to semantics node by @chunhtai in https://github.com/flutter/flutter/pull/87684_
- * Improve efficiency of copying the animation ObserverList in notifyListeners by @jason-simmons in https://github.com/flutter/flutter/pull/102536
  - _* Fix docs re: return value of Navigator's restorable methods by @goderbauer in https://github.com/flutter/flutter/pull/102595_
- * Improvements to SearchDelegate by @prateekmedia in https://github.com/flutter/flutter/pull/91982
  - _* `ToggleButtons`: Add interactive example by @TahaTesser in https://github.com/flutter/flutter/pull/100124_
- * Cupertino examples improvements and clean up by @TahaTesser in https://github.com/flutter/flutter/pull/103044
  - _* Fix DraggableScrollableSheet leaks Ticker by @bleroux in https://github.com/flutter/flutter/pull/102916_
- * Clear the baseline cache when RenderBox is laid out by @xu-baolin in https://github.com/flutter/flutter/pull/101493
  - _* Does not replace the root layer unnecessarily by @xu-baolin in https://github.com/flutter/flutter/pull/101748_
- * Fix an issue that clearing the image cache may cause resource leaks by @Yeatse in https://github.com/flutter/flutter/pull/104527
  - _* [framework] ensure ink sparkle is disposed by @jonahwilliams in https://github.com/flutter/flutter/pull/104569_
- * Improve PlatformMenu `MenuItem` documentation by @ueman in https://github.com/flutter/flutter/pull/104321
  - _* fix a _DraggableScrollableSheetScrollPosition update bug by @xu-baolin in https://github.com/flutter/flutter/pull/103328_
- * Improve `PlatformException#stacktrace` docs for Android by @ueman in https://github.com/flutter/flutter/pull/104331
  - _* Switch debugAssertNotDisposed to be a static by @gspencergoog in https://github.com/flutter/flutter/pull/104772_
- * Improve the `SliverChildBuilderDelegate` docs for folk to troubleshoot. by @xu-baolin in https://github.com/flutter/flutter/pull/103183
  - _* fix a _ScaffoldLayout delegate update bug by @xu-baolin in https://github.com/flutter/flutter/pull/104954_
- * Improve `useMaterial3` documentation by @guidezpl in https://github.com/flutter/flutter/pull/104815
  - _* `CupertinoSlider`: Add clickable cursor for web by @TahaTesser in https://github.com/flutter/flutter/pull/99557_
- * Improve SnackBar error message when shown during build by @bleroux in https://github.com/flutter/flutter/pull/106658
  - _* Fix scrollbar track offset by @Piinks in https://github.com/flutter/flutter/pull/106835_
- * Improve pub root directory interface by @CoderDake in https://github.com/flutter/flutter/pull/106567
  - _* [framework] don't composite with a scale of 0.0 by @jonahwilliams in https://github.com/flutter/flutter/pull/106982_
- * Remove listeners from pending images when clearing cache by @dnfield in https://github.com/flutter/flutter/pull/107276
  - _* `InputDecorator`: Switch hint to Opacity instead of AnimatedOpacity by @markusaksli-nc in https://github.com/flutter/flutter/pull/107156_
- * Provide a flag for controlling the dart2js optimization level when building for web targets by @jason-simmons in https://github.com/flutter/flutter/pull/101945
  - _* Remove trailing spaces in repo by @guidezpl in https://github.com/flutter/flutter/pull/101191_
- * Reduce Gradle log level in verbose output by @blasten in https://github.com/flutter/flutter/pull/102422
  - _* [flutter_tools] remove UWP tooling by @jonahwilliams in https://github.com/flutter/flutter/pull/102174_
- * Use libraryFilters flag to speed up coverage collection by @liamappelbe in https://github.com/flutter/flutter/pull/104122
  - _* [flutter_tools] Upgrade only from flutter update-packages by @christopherfujino in https://github.com/flutter/flutter/pull/103924_
- * [web] [fix] Cache resource data only if the fetching succeed by @dacianf in https://github.com/flutter/flutter/pull/103816
  - _* [flutter_tools] General info project validator by @Jasguerrero in https://github.com/flutter/flutter/pull/103653_

**Replacement / Migration** (7)

- * Update key examples to use `Focus` widgets instead of `RawKeyboardListener` by @gspencergoog in https://github.com/flutter/flutter/pull/101537
  - _* Enable unnecessary_import by @goderbauer in https://github.com/flutter/flutter/pull/101600_
- * switched to a double variant of clamp to avoid boxing by @gaaclarke in https://github.com/flutter/flutter/pull/103559
  - _* Some MacOS control key shortcuts by @justinmc in https://github.com/flutter/flutter/pull/103936_
- * `InputDecorator`: Switch hint to Opacity instead of AnimatedOpacity by @markusaksli-nc in https://github.com/flutter/flutter/pull/107156
  - _* Fix `ListTile` theme shape in a drawer by @TahaTesser in https://github.com/flutter/flutter/pull/106343_
- * Revert "`InputDecorator`: Switch hint to Opacity instead of AnimatedOpacity" by @CaseyHillers in https://github.com/flutter/flutter/pull/107406
  - _* [flutter_releases] Flutter beta 3.3.0-0.2.pre Framework Cherrypicks by @godofredoc in https://github.com/flutter/flutter/pull/108831_
- * Use consistent date instead of DateTime.now() in evaluation tests to avoid flakes by @DanTup in https://github.com/flutter/flutter/pull/103269
  - _* [flutter_tools] stringArg refactor by @Jasguerrero in https://github.com/flutter/flutter/pull/103231_
- * Provide flutter sdk kernel files to dwds launcher instead of dart ones by @annagrin in https://github.com/flutter/flutter/pull/103436
  - _* Add tests for migrate command methods by @GaryQian in https://github.com/flutter/flutter/pull/103466_
- * [flutter_tools] print override storage warning to STDERR instead of STDOUT by @christopherfujino in https://github.com/flutter/flutter/pull/106068
  - _* Add more CMake unit tests by @loic-sharma in https://github.com/flutter/flutter/pull/106076_

---

### 3.0.0

**Deprecation** (19)

- * Deprecate Scrollbar isAlwaysShown -> thumbVisibility by @Piinks in https://github.com/flutter/flutter/pull/96957
  - _* Show keyboard after text input connection restarts by @LongCatIsLooong in https://github.com/flutter/flutter/pull/96541_
- * Deprecate Scrollbar hoverThickness and showTrackOnHover by @Piinks in https://github.com/flutter/flutter/pull/97173
  - _* Add splashRadius to PopupMenuButton by @Moluram in https://github.com/flutter/flutter/pull/91148_
- * Deprecate `useDeleteButtonTooltip` for Chips by @RoyARG02 in https://github.com/flutter/flutter/pull/96174
  - _* `RefreshIndicator`: Add an interactive example by @TahaTesser in https://github.com/flutter/flutter/pull/97254_
- * Remove deprecated RectangularSliderTrackShape.disabledThumbGapWidth by @Piinks in https://github.com/flutter/flutter/pull/98613
  - _* Update stretching overscroll clip behavior by @Piinks in https://github.com/flutter/flutter/pull/97678_
- * Remove deprecated UpdateLiveRegionEvent by @Piinks in https://github.com/flutter/flutter/pull/98615
  - _* Remove `clipBehavior == Clip.none` conditions by @TahaTesser in https://github.com/flutter/flutter/pull/98503_
- * Remove deprecated VelocityTracker constructor by @Piinks in https://github.com/flutter/flutter/pull/98541
  - _* Add more tests to slider to avoid future breakages by @goderbauer in https://github.com/flutter/flutter/pull/98772_
- * Remove deprecated DayPicker and MonthPicker by @Piinks in https://github.com/flutter/flutter/pull/98543
  - _* Adds `onReorderStart` and `onReorderEnd` arguments to `ReorderableList`. by @werainkhatri in https://github.com/flutter/flutter/pull/96049_
- * Deprecate MaterialButtonWithIconMixin by @Piinks in https://github.com/flutter/flutter/pull/99088
  - _* Use `PlatformDispatcher.instance` over `window` where possible by @goderbauer in https://github.com/flutter/flutter/pull/99496_
- * Remove deprecated RenderObjectElement methods by @Piinks in https://github.com/flutter/flutter/pull/98616
  - _* CupertinoTabBar: Add clickable cursor on web by @TahaTesser in https://github.com/flutter/flutter/pull/96996_
- * Remove deprecated Overflow and Stack.overflow by @Piinks in https://github.com/flutter/flutter/pull/98583
  - _* Remove deprecated CupertinoTextField, TextField, TextFormField maxLengthEnforced by @Piinks in https://github.com/flutter/flutter/pull/98539_
- * Remove deprecated CupertinoTextField, TextField, TextFormField maxLengthEnforced by @Piinks in https://github.com/flutter/flutter/pull/98539
  - _* Fix: Date picker interactive sample not loading by @maheshmnj in https://github.com/flutter/flutter/pull/99401_
- * Revert "Remove deprecated CupertinoTextField, TextField, TextFormField maxLengthEnforced" by @Piinks in https://github.com/flutter/flutter/pull/99768
  - _* Update Material tokens to v0.88 by @darrenaustin in https://github.com/flutter/flutter/pull/99568_
- * Remove deprecated OutlineButton by @Piinks in https://github.com/flutter/flutter/pull/98546
  - _* Add the refresh rate fields to perf_test by @cyanglaz in https://github.com/flutter/flutter/pull/99710_
- * Re-land removal of maxLengthEnforced deprecation by @Piinks in https://github.com/flutter/flutter/pull/99787
  - _* Revert "Add the refresh rate fields to perf_test" by @zanderso in https://github.com/flutter/flutter/pull/99801_
- * Remove deprecated RenderEditable.onSelectionChanged by @Piinks in https://github.com/flutter/flutter/pull/98582
  - _* [Material] Create an InkSparkle splash effect that matches the Material 3 ripple effect by @clocksmith in https://github.com/flutter/flutter/pull/99731_
- * Remove expired ThemeData deprecations by @Piinks in https://github.com/flutter/flutter/pull/98578
  - _* Update `NavigationRail` to support Material 3 tokens by @darrenaustin in https://github.com/flutter/flutter/pull/99171_
- * Revert "Remove expired ThemeData deprecations" by @Piinks in https://github.com/flutter/flutter/pull/99920
  - _* Revert "[web] roll Chromium dep to 96.2" by @zanderso in https://github.com/flutter/flutter/pull/99949_
- * Fix `deprecated_new_in_comment_reference` for `material` library by @guidezpl in https://github.com/flutter/flutter/pull/100289
  - _* Fix stretch edge case by @Piinks in https://github.com/flutter/flutter/pull/99365_
- * [flutter_tools] deprecate the dev branch from the feature system by @christopherfujino in https://github.com/flutter/flutter/pull/98689
  - _* Revert "Reland "Enable caching of CPU samples collected at application startup (#89600)"" by @zanderso in https://github.com/flutter/flutter/pull/98803_

**Breaking Change** (3)

- * Removed the date from the Next/Previous month button's semantics for the Date Picker. by @darrenaustin in https://github.com/flutter/flutter/pull/96876
  - _* chore: added YouTube ref to docstring by @albertodev01 in https://github.com/flutter/flutter/pull/96880_
- * Fixed order dependency and removed no-shuffle-tag in build_ios_framew… by @Swiftaxe in https://github.com/flutter/flutter/pull/94699
  - _* Add option in ProxiedDevice to only transfer the delta when deploying. by @chingjun in https://github.com/flutter/flutter/pull/97462_
- * Removed no-shuffle tag and fixed order dependency in daemon_test.dart by @Swiftaxe in https://github.com/flutter/flutter/pull/98970
  - _* Skip `can validate flutter version in parallel` test in `Linux web_tool_tests` by @keyonghan in https://github.com/flutter/flutter/pull/99017_

**New Feature / API** (1)

- * Added optional parameter keyboardType to showDatePicker by @kirolous-nashaat in https://github.com/flutter/flutter/pull/93439
  - _* Fix getOffsetForCaret to return correct value if contains widget span by @chunhtai in https://github.com/flutter/flutter/pull/98542_

**New Parameter / Option** (1)

- * Added optional parameter keyboardType to showDatePicker by @kirolous-nashaat in https://github.com/flutter/flutter/pull/93439
  - _* Fix getOffsetForCaret to return correct value if contains widget span by @chunhtai in https://github.com/flutter/flutter/pull/98542_

**Performance Improvement** (12)

- * Improve iOS fidelity of `barrierColor`s and edge decorations for full-screen Cupertino page transitions by @willlockwood in https://github.com/flutter/flutter/pull/95537
  - _* [Fonts] Update icons by @guidezpl in https://github.com/flutter/flutter/pull/96115_
- * Do not eagerly allocate inherited widget caches when initializing element tree by @jonahwilliams in https://github.com/flutter/flutter/pull/95596
  - _* Revert "feat: added custom padding in PopupMenuButton (#96657)" by @gspencergoog in https://github.com/flutter/flutter/pull/96781_
- * improve docs for testing dart fix by @werainkhatri in https://github.com/flutter/flutter/pull/97493
  - _* PointerDeviceKind and ui.PointerChange forwards-compatibility by @moffatman in https://github.com/flutter/flutter/pull/97350_
- * Invalidate the TextPainter line metrics cache when redoing text layout by @jason-simmons in https://github.com/flutter/flutter/pull/97446
  - _* Fix RouterObserver didPop is not called when reverseTransitionDuratio… by @chunhtai in https://github.com/flutter/flutter/pull/97171_
- * [framework] inline casts on Element.widget getter to improve web performance by @jonahwilliams in https://github.com/flutter/flutter/pull/97822
  - _* [EditableText] honor the "brieflyShowPassword" system setting by @LongCatIsLooong in https://github.com/flutter/flutter/pull/97769_
- * [framework] improve Notification API performance by skipping full Element tree traversal by @jonahwilliams in https://github.com/flutter/flutter/pull/98451
  - _* Remove redundant properties passed to _Editable by @Renzo-Olivares in https://github.com/flutter/flutter/pull/99192_
- * Improve documentation of `EditableText`/`TextField` callbacks by @TahaTesser in https://github.com/flutter/flutter/pull/98414
  - _* complete migration of flutter repo to Object.hash* by @werainkhatri in https://github.com/flutter/flutter/pull/99505_
- * Improve container widget by @r-mzy47 in https://github.com/flutter/flutter/pull/98389
  - _* CupertinoButton: Add clickable cursor on web by @TahaTesser in https://github.com/flutter/flutter/pull/96863_
- * Revert "Do not eagerly allocate inherited widget caches when initializing element tree" by @jonahwilliams in https://github.com/flutter/flutter/pull/100152
  - _* Add 'mouseCursor' to TextFormField by @SahajRana in https://github.com/flutter/flutter/pull/99822_
- * Minor improvements to `ThemeExtension` example by @guidezpl in https://github.com/flutter/flutter/pull/100693
  - _* Fix `LicensePage` too much spacing padding when `applicationVersion` and `applicationLegalese` are empty by @TahaTesser in https://github.com/flutter/flutter/pull/101030_
- * Warm cache with all transitive dependencies in `flutter update-packages` command by @gspencergoog in https://github.com/flutter/flutter/pull/96258
  - _* Hide PII from doctor validators for GitHub template by @jmagman in https://github.com/flutter/flutter/pull/96250_
- * Improve Gradle retry logic by @blasten in https://github.com/flutter/flutter/pull/96554
  - _* [flutter_tools] deprecate the dev branch from the feature system by @christopherfujino in https://github.com/flutter/flutter/pull/98689_

**Replacement / Migration** (3)

- For example, instead of the following:
- * Use strict-raw-types analysis instead of no-implicit-dynamic by @srawlins in https://github.com/flutter/flutter/pull/96296
  - _* [Keyboard] Dispatch solitary synthesized `KeyEvent`s by @dkwingsmt in https://github.com/flutter/flutter/pull/96874_
- * [flutter_tools] increment y instead of m when calling flutter --version on master by @christopherfujino in https://github.com/flutter/flutter/pull/97827
  - _* Include -isysroot -arch and -miphoneos-version-min when creating dummy module App.framework by @jmagman in https://github.com/flutter/flutter/pull/97689_

---

## Dart SDK

### 3.12.0

**Breaking Change** (1)

- - **Breaking Change in extension name of `isA`**: `isA` is moved from
  - _`JSAnyUtilityExtension` to `NullableObjectUtilExtension` to support_

**New Feature / API** (1)

- `loadDeferredModule` where the new function should now expect an array of
  - _module names rather than individual module names. All the module loading_

**Performance Improvement** (1)

- - `dart pub cache repair` now by default only repairs the packages referenced
  - _by the current projects pubspec.lock. For the old behavior of repairing all_

**Replacement / Migration** (1)

- deferred modules. The embedder now takes `loadDeferredModules` instead of
  - _`loadDeferredModule` where the new function should now expect an array of_

---

### 3.11.0

**Deprecation** (3)

- - The `avoid_null_checks_in_equality_operators` lint rule is now deprecated.
  - _- The `prefer_final_parameters` lint rule is now deprecated._
- - The `prefer_final_parameters` lint rule is now deprecated.
  - _- The `use_if_null_to_convert_nulls_to_bools` lint rule is now deprecated._
- - The `use_if_null_to_convert_nulls_to_bools` lint rule is now deprecated.

**Breaking Change** (1)

- - dart2wasm no longer supports `dart:js_util`. Any code that imports
  - _`dart:js_util` will no longer compile with dart2wasm. Consequently, code that_

**New Feature / API** (1)

- - New flag `dart pub publish --dry-run --ignore-warnings`

**New Parameter / Option** (1)

- - New flag `dart pub publish --dry-run --ignore-warnings`

**Performance Improvement** (5)

- - Analysis via analyzer plugins is now faster on subsequent runs, as the
  - _analysis server will now re-use an existing AOT snapshot of the plugins_
- - Improvements to LSP format-on-type, to not format in undesirable cases.
  - _- Various performance improvements._
- - Various performance improvements.
  - _- Fixes to the 'Extract Widget' refactoring._
- - New commmand `dart pub cache gc` for reclaiming disk space from your pub
  - _cache._
- It works by removing packages from your pub cache that are not referenced by
  - _any of your current projects._

**Replacement / Migration** (1)

- but `false` on Windows. Use `FileSystemEntity.typeSync()` instead to get
  - _portable behavior._

---

### 3.10.5

**Deprecation** (3)

- - Fixes several issues with elements that are deprecated with one of the new
  - _"deprecated functionality" annotations, like `@Deprecated.implement`. This_
- "deprecated functionality" annotations, like `@Deprecated.implement`. This
  - _fix directs IDEs to not display such elements (like the `RegExp` class) as_
- fully deprecated (for example, with struck-through text). (issue
  - _[dart-lang/sdk#62013])_

---

### 3.10.1

**Deprecation** (1)

- `@Deprecated.extend()` and the other new deprecated annotations.

---

### 3.10.0

**Deprecation** (20)

- - Support the new `@Deprecated` annotations by reporting warnings when specific
  - _functionality of an element is deprecated._
- functionality of an element is deprecated.
  - _- Offer to import a library for an appropriate extension member when method or_
- - Remove support for the deprecated `@required` annotation.
  - _- Add two assists to bind constructor parameters to an existing or a_
- - Add a new lint rule, `remove_deprecations_in_breaking_versions`, is added to
  - _encourage developers to remove any deprecated members when the containing_
- encourage developers to remove any deprecated members when the containing
  - _package has a "breaking version" number, like `x.0.0` or `0.y.0`._
- - New annotations are offered for deprecating specific functionalities:
  - _- [`@Deprecated.extend()`][] indicates the ability to extend a class is_
- - [`@Deprecated.extend()`][] indicates the ability to extend a class is
  - _deprecated._
- deprecated.
  - _- [`@Deprecated.implement()`][] indicates the ability to implement a class or_
- - [`@Deprecated.implement()`][] indicates the ability to implement a class or
  - _mixin is deprecated._
- mixin is deprecated.
  - _- [`@Deprecated.subclass()`][] indicates the ability to extend a class or_
- - [`@Deprecated.subclass()`][] indicates the ability to extend a class or
  - _implement a class or mixin is deprecated._
- implement a class or mixin is deprecated.
  - _- [`@Deprecated.mixin()`][] indicates the ability to mix in a class is_
- - [`@Deprecated.mixin()`][] indicates the ability to mix in a class is
  - _deprecated._
- - [`@Deprecated.instantiate()`][] indicates the ability to instantiate a
  - _class is deprecated._
- class is deprecated.
  - _- The ability to implement the RegExp class and the RegExpMatch class is_
- [`@Deprecated.extend()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.extend.html
  - _[`@Deprecated.implement()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.implement.html_
- [`@Deprecated.implement()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.implement.html
  - _[`@Deprecated.subclass()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.subclass.html_
- [`@Deprecated.subclass()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.subclass.html
  - _[`@Deprecated.mixin()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.mixin.html_
- [`@Deprecated.mixin()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.mixin.html
  - _[`@Deprecated.instantiate()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.instantiate.html_
- [`@Deprecated.instantiate()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.instantiate.html

**Breaking Change** (5)

- - **Breaking Change** [#61392][]: The `Uri.parseIPv4Address` function
  - _no longer incorrectly allows leading zeros. This also applies to_
- - **Breaking Change** [#56468][]: Marked `IOOverrides` as an `abstract base`
  - _class so it can no longer be implemented._
- - `Uint16ListToJSInt16Array` is renamed to `Uint16ListToJSUint16Array`.
  - _- `JSUint16ArrayToInt16List` is renamed to `JSUint16ArrayToUint16List`._
- - `JSUint16ArrayToInt16List` is renamed to `JSUint16ArrayToUint16List`.
  - _- The dart2wasm implementation of `dartify` now converts JavaScript `Promise`s_
- - dart2wasm no longer supports `dart:js_util` and will throw an
  - _`UnsupportedError` if any API from this library is invoked. This also applies_

**New Feature / API** (1)

- - New annotations are offered for deprecating specific functionalities:
  - _- [`@Deprecated.extend()`][] indicates the ability to extend a class is_

**Replacement / Migration** (2)

- `toJSBox` operation instead of returning true for all objects.
  - _- For object literals created from extension type factories, the `@JS()`_
- original typed array when unwrapped instead of instantiating a new typed array
  - _with the same buffer. This applies to both the `.toJS` conversions and_

---

### 3.9.0

**Deprecation** (1)

- flag! It will be removed in the future.) This flag directs the tool to revert
  - _to the old behavior, using the JIT-compiled analysis server snapshot. To_

**Breaking Change** (2)

- flag! It will be removed in the future.) This flag directs the tool to revert
  - _to the old behavior, using the JIT-compiled analysis server snapshot. To_
- - Breaking change of feature in preview: `dart build -f exe <target>` is now
  - _`dart build cli --target=<target>`. See `dart build cli --help` for more info._

**New Feature / API** (1)

- - Support a new annotation, `@awaitNotRequired`, which is used by the
  - _`discarded_futures` and `unawaited_futures` lint rules._

**Performance Improvement** (8)

- produced. To take advantage of these improvements, set your package's [SDK
  - _constraint][language version] lower bound to 3.9 or greater (`sdk: '^3.9.0'`)._
- - Improve the `avoid_types_as_parameter_names` lint rule to include type
  - _parameters._
- - Many small improvements to the `discarded_futures` and `unawaited_futures`
  - _lint rules._
- improvements.
  - _- A new "Remove async" assist is available._
- - Numerous fixes and improvements are included in the "create method," "create
  - _getter," "create mixin," "add super constructor," and "replace final with_
- - Improvements to type parameters and type arguments in the LSP type hierarchy.
  - _- Folding try/catch/finally blocks is now supported for LSP clients._
- - Improve code completion suggestions with regards to operators, extension
  - _members, named parameters, doc comments, patterns, collection if-elements and_
- - Improve syntax highlighting of escape sequences in string literals.
  - _- Add "library cycle" information to the diagnostic pages._

---

### 3.8.0

**Breaking Change** (4)

- - **Breaking change**: Native classes in `dart:html`, like `HtmlElement`, can no
  - _longer be extended. Long ago, to support custom elements, element classes_
- components. On this release, those constructors have been removed and with
  - _that change, the classes can no longer be extended. In a future change, they_
- earlier breaking change in 3.0.0 that removed the `registerElement` APIs. See
  - _[#53264](https://github.com/dart-lang/sdk/issues/53264) for details._
- Removed the `--experiment-new-rti` and `--use-old-rti` flags.

**Performance Improvement** (2)

- - Code completion is improved to offer more valid suggestions. In particular,
  - _the suggestions are improved when completing text in a comment reference on a_
- the suggestions are improved when completing text in a comment reference on a
  - _documentation comment for an extension, a typedef, or a directive (an import,_

**Replacement / Migration** (1)

- Some users strongly prefer the old behavior where a trailing comma will be
  - _preserved by the formatter and force the surrounding construct to split. That_

---

### 3.7.0

**Deprecation** (8)

- will be removed.
- - `dart:html` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- - `dart:indexed_db` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- - `dart:svg` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- - `dart:web_audio` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- - `dart:web_gl` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- - `dart:js` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop`. See [#59716][]._
- - `dart:js_util` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop`. See [#59716][]._

**Breaking Change** (11)

- - **Breaking Change** [#56893][]: If a field is promoted to the type `Null`
  - _using `is` or `as`, this type promotion is now properly accounted for in_
- will be removed.
- * **Breaking change: Remove support for `dart format --fix`.** Instead, use
  - _`dart fix`. It supports all of the fixes that `dart format --fix` could apply_
- may be removed at some point in the future. You're encouraged to move to
  - _`--page-width`. Use of this option (however it's named) is rare, and will_
- - `dart:html` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- - `dart:indexed_db` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- - `dart:svg` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- - `dart:web_audio` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop` and `package:web`._
- - `dart:web_gl` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop` and `package:web`. See_
- - `dart:js` is marked deprecated and will be removed in an upcoming release.
  - _Users should migrate to using `dart:js_interop`. See [#59716][]._
- - `dart:js_util` is marked deprecated and will be removed in an upcoming
  - _release. Users should migrate to using `dart:js_interop`. See [#59716][]._

**Replacement / Migration** (5)

- constraint in your pubspec to move to 3.7, you are also opting in to the new
  - _style._
- may be removed at some point in the future. You're encouraged to move to
  - _`--page-width`. Use of this option (however it's named) is rare, and will_
- used has been switched to use an AOT snapshot instead of a JIT snapshot.
- The dartdevc compiler and kernel_worker utility have been switched to
  - _use an AOT snapshot instead of a JIT snapshot,_
- use an AOT snapshot instead of a JIT snapshot,
  - _the SDK build still includes a JIT snapshot of these tools as_

---

### 3.6.0

**Deprecation** (1)

- has been deprecated since Dart 3.1.

**Breaking Change** (4)

- - **Breaking Change** [#56065][]: The context used by the compiler and analyzer
  - _to perform type inference on the operand of a `throw` expression has been_
- - **Breaking Change** [#52444][]: Removed the `Platform()` constructor, which
  - _has been deprecated since Dart 3.1._
- - **Breaking Change** [#53618][]: `HttpClient` now responds to a redirect
  - _that is missing a "Location" header by throwing `RedirectException`, instead_
- - **Breaking Change** [#56466][]: The implementation of the UP and
  - _DOWN algorithms in the CFE are changed to match the specification_

**New Feature / API** (1)

- - New flag `dart pub upgrade --unlock-transitive`.

**New Parameter / Option** (1)

- - New flag `dart pub upgrade --unlock-transitive`.

**Replacement / Migration** (2)

- passed into the subtype testing procedure instead of at the very
  - _beginning of the UP and DOWN algorithms._
- dependencies of `pkg` instead of just `pkg`.

---

### 3.5.3

**Replacement / Migration** (1)

- DevTools is opened instead of only the first time (issue[#56607][]).
  - _- Fixes an issue resulting in a missing tab bar when DevTools is_

---

### 3.5.1

**Performance Improvement** (1)

- - Fixes source maps generated by `dart compile wasm` when optimizations are
  - _enabled (issue [#56423][])._

**Replacement / Migration** (1)

- implicit setter for a field of generic type will store `null` instead of the
  - _field value (issue [#56374][])._

---

### 3.5.0

**Deprecation** (1)

- have been removed. These classes were deprecated in Dart 3.4.

**Breaking Change** (12)

- - **Breaking Change** [#55418][]: The context used by the compiler to perform
  - _type inference on the operand of an `await` expression has been changed to_
- - **Breaking Change** [#55436][]: The context used by the compiler to perform
  - _type inference on the right hand side of an "if-null" expression (`e1 ?? e2`)_
- - **Breaking Change** [#44876][]: `DateTime` on the web platform now stores
  - _microseconds. The web implementation is now practically compatible with the_
- - **Breaking Change** [#55786][]: `SecurityContext` is now `final`. This means
  - _that `SecurityContext` can no longer be subclassed. `SecurityContext`_
- - **Breaking Change** [#53785][]: The unmodifiable view classes for typed data
  - _have been removed. These classes were deprecated in Dart 3.4._
- have been removed. These classes were deprecated in Dart 3.4.
- - **Breaking Change** [#55508][]: `importModule` now accepts a `JSAny` instead
  - _of a `String` to support other JS values as well, like `TrustedScriptURL`s._
- - **Breaking Change** [#55267][]: `isTruthy` and `not` now return `JSBoolean`
  - _instead of `bool` to be consistent with the other operators._
- - **Breaking Change** `ExternalDartReference` no longer implements `Object`.
  - _`ExternalDartReference` now accepts a type parameter `T` with a bound of_
- safe code using the option `--no-sound-null-safety` has been removed.
- removed from Dart C API.
- - `Dart_DefaultCanonicalizeUrl` is removed from the Dart C API.

**New Feature / API** (1)

- - New flag `dart pub downgrade --tighten` to restrict lower bounds of
  - _dependencies' constraints to the minimum that can be resolved._

**New Parameter / Option** (1)

- - New flag `dart pub downgrade --tighten` to restrict lower bounds of
  - _dependencies' constraints to the minimum that can be resolved._

**Replacement / Migration** (1)

- instead of `bool` to be consistent with the other operators.

---

### 3.4.0

**Deprecation** (3)

- - Deprecates `FileSystemDeleteEvent.isDirectory`, which always returns
  - _`false`._
- typed data are deprecated.
- The deprecated types will be removed in Dart 3.5.

**Breaking Change** (8)

- - **Breaking Change** [#54640][]: The pattern context type schema for
  - _cast patterns has been changed from `Object?` to `_` (the unknown_
- - **Breaking Change** [#54828][]: The type schema used by the compiler front end
  - _to perform type inference on the operand of a null-aware spread operator_
- - **Breaking change** [#52121][]: `waitFor` is removed in 3.4.
- - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  - _which allows developers to control the line ending used by `stdout` and_
- - **BREAKING CHANGE** [#53218][] [#53785][]: The unmodifiable view classes for
  - _typed data are deprecated._
- The deprecated types will be removed in Dart 3.5.
- - Dart VM no longer supports external strings: `Dart_IsExternalString`,
  - _`Dart_NewExternalLatin1String` and `Dart_NewExternalUTF16String` functions are_
- removed from Dart C API.

**New Feature / API** (3)

- - Added option for `ParallelWaitError` to get some meta-information that
  - _it can expose in its `toString`, and the `Iterable<Future>.wait` and_
- - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  - _which allows developers to control the line ending used by `stdout` and_
- - Support for new annotations introduced in version 1.14.0 of the [meta]
  - _package._

**New Parameter / Option** (2)

- - Added option for `ParallelWaitError` to get some meta-information that
  - _it can expose in its `toString`, and the `Iterable<Future>.wait` and_
- - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  - _which allows developers to control the line ending used by `stdout` and_

**Performance Improvement** (4)

- Dart 3.4 makes improvements to the type analysis of conditional expressions
  - _(`e1 ? e2 : e3`), if-null expressions (`e1 ?? e2`), if-null assignments_
- advantage of these improvements, set your package's
  - _[SDK constraint][language version] lower bound to 3.4 or greater_
- `toExternalReference` and `toDartObject`. This is a faster alternative to
  - _`JSBoxedDartObject`, but with fewer safety guarantees and fewer_
- - Improved code completion. Fixed over 50% of completion correctness bugs,
  - _tagged `analyzer-completion-correctness` in the [issue_

**Replacement / Migration** (1)

- opaque Dart value instead of only externalizing the value. Like the JS
  - _backends, you'll now get a more useful error when trying to use it in another_

---

### 3.3.0

**Deprecation** (4)

- core `Pointer` types are now deprecated.
  - _Migrate to the new `-` and `+` operators instead._
- - The experimental and deprecated `@FfiNative` annotation has been removed.
  - _Usages should be updated to use the `@Native` annotation._
- unmodifiable view classes for typed data are deprecated. Instead of using the
  - _constructors for these classes to create an unmodifiable view, e.g._
- The deprecated types will be removed in a future Dart version.

**Breaking Change** (12)

- - **Breaking Change** [#54056][]: The rules for private field promotion have
  - _been changed so that an abstract getter is considered promotable if there are_
- - The experimental and deprecated `@FfiNative` annotation has been removed.
  - _Usages should be updated to use the `@Native` annotation._
- - **Breaking Change in the representation of JS types** [#52687][]: JS types
  - _like `JSAny` were previously represented using a custom erasure of_
- - **Breaking Change in names of extensions**: Some `dart:js_interop` extension
  - _members are moved to different extensions on the same type or a supertype to_
- - **BREAKING CHANGE** (https://github.com/dart-lang/sdk/issues/53218) The
  - _unmodifiable view classes for typed data are deprecated. Instead of using the_
- The deprecated types will be removed in a future Dart version.
- - **Breaking Change** [#51896][]: The NativeWrapperClasses are marked `base` so
  - _that none of their subtypes can be implemented. Implementing subtypes can lead_
- - **Breaking Change** [#54004][]: `dart:js_util`, `package:js`, and `dart:js`
  - _are now disallowed from being imported when compiling with `dart2wasm`. Prefer_
- - Removed "implements <...>" text from the Chrome custom formatter display for
  - _Dart classes. This information provides little value and keeping it imposes an_
- - **Breaking Change** [#54201][]:
  - _The `Invocation` that is passed to `noSuchMethod` will no longer have a_
- - Removed the `iterable_contains_unrelated_type` and
  - _`list_remove_unrelated_type` lints._
- - Removed various lints that are no longer necessary with sound null safety:
  - _- `always_require_non_null_named_parameters`_

**New Feature / API** (1)

- `JSAnyOperatorExtension` for the new extensions. This shouldn't make a
  - _difference unless the extension names were explicitly used._

**Replacement / Migration** (2)

- members are moved to different extensions on the same type or a supertype to
  - _better organize the API surface. See `JSAnyUtilityExtension` and_
- unmodifiable view classes for typed data are deprecated. Instead of using the
  - _constructors for these classes to create an unmodifiable view, e.g._

---

### 3.2.0

**Deprecation** (2)

- on `waitFor` can enable it by passing `--enable_deprecated_wait_for` flag
  - _to the VM._
- - Deprecated the `Service.getIsolateID` method.
  - _- Added `getIsolateId` method to `Service`._

**Breaking Change** (18)

- - **Breaking Change** [#53167][]: Use a more precise split point for refutable
  - _patterns. Previously, in an if-case statement, if flow analysis could prove_
- - **Breaking change** [#52121][]:
  - _- `waitFor` is disabled by default and slated for removal in 3.4. Attempting_
- - **Breaking change** [#52801][]:
  - _- Changed return types of `utf8.encode()` and `Utf8Codec.encode()` from_
- - Changed return types of `utf8.encode()` and `Utf8Codec.encode()` from
  - _`List<int>` to `Uint8List`._
- - **Breaking change** [#53311][]: `NativeCallable.nativeFunction` now throws an
  - _error if is called after the `NativeCallable` has already been `close`d. Calls_
- - **Breaking change** [#53005][]: The headers returned by
  - _`HttpClientResponse.headers` and `HttpRequest.headers` no longer include_
- - **Breaking change** [#53227][]: Folded headers values returned by
  - _`HttpClientResponse.headers` and `HttpRequest.headers` now have a space_
- - **Breaking Change on JSNumber.toDart and Object.toJS**:
  - _`JSNumber.toDart` is removed in favor of `toDartDouble` and `toDartInt` to_
- `JSNumber.toDart` is removed in favor of `toDartDouble` and `toDartInt` to
  - _make the type explicit. `Object.toJS` is also removed in favor of_
- make the type explicit. `Object.toJS` is also removed in favor of
  - _`Object.toJSBox`. Previously, this function would allow Dart objects to flow_
- `JSExportedDartObject` is renamed to `JSBoxedDartObject` and the extensions
  - _`ObjectToJSExportedDartObject` and `JSExportedDartObjectToObject` are renamed_
- `globalJSObject` is also renamed to `globalContext` and returns the global
  - _context used in the lowerings._
- - **Breaking Change on Types of `dart:js_interop` External APIs**:
  - _External JS interop APIs when using `dart:js_interop` are restricted to a set_
- - **Breaking Change on `dart:js_interop` `isNull` and `isUndefined`**:
  - _`null` and `undefined` can only be discerned in the JS backends. dart2wasm_
- - **Breaking Change on `dart:js_interop` `typeofEquals` and `instanceof`**:
  - _Both APIs now return a `bool` instead of a `JSBoolean`. `typeofEquals` also_
- - **Breaking Change on `dart:js_interop` `JSAny` and `JSObject`**:
  - _These types can only be implemented, and no longer extended, by user_
- - **Breaking Change on `dart:js_interop` `JSArray.withLength`**:
  - _This API now takes in an `int` instead of `JSNumber`._
- - **Breaking change for JS interop with Symbols and BigInts**:
  - _JavaScript `Symbol`s and `BigInt`s are now associated with their own_

**New Feature / API** (1)

- - New option `dart pub upgrade --tighten` which will update dependencies' lower
  - _bounds in `pubspec.yaml` to match the current version._

**New Parameter / Option** (1)

- - New option `dart pub upgrade --tighten` which will update dependencies' lower
  - _bounds in `pubspec.yaml` to match the current version._

**Replacement / Migration** (4)

- instead of `globalThis` to avoid a greater migration. Static interop APIs,
  - _either through `dart:js_interop` or the `@staticInterop` annotation, have used_
- Both APIs now return a `bool` instead of a `JSBoolean`. `typeofEquals` also
  - _now takes in a `String` instead of a `JSString`._
- now takes in a `String` instead of a `JSString`.
  - _- **Breaking Change on `dart:js_interop` `JSAny` and `JSObject`**:_
- This API now takes in an `int` instead of `JSNumber`.

---

### 3.1.2

**Replacement / Migration** (1)

- The fix uses try/catch in lookupAddresses instead of
  - _Future error so that we don't see an unhandled exception_

---

### 3.1.0

**Deprecation** (1)

- - Added a deprecation warning when `Platform` is instantiated.
  - _- Added `Platform.lineTerminator` which exposes the character or characters_

**Breaking Change** (5)

- - **Breaking change** [#52334][]:
  - _- Added the `interface` modifier to purely abstract classes:_
- - **Breaking change** [#51486][]:
  - _- Added `sameSite` to the `Cookie` class._
- - **Breaking change** [#52027][]: `FileSystemEvent` is
  - _[`sealed`](https://dart.dev/language/class-modifiers#sealed). This means_
- `ObjectLiteral` is removed from `dart:js_interop`. It's no longer needed in
  - _order to declare an object literal constructor with inline classes. As long as_
- - **Breaking change to `@staticInterop` and `external` extension members**:
  - _`external` `@staticInterop` members and `external` extension members can no_

**New Feature / API** (1)

- - Added class `SameSite`.
  - _- **Breaking change** [#52027][]: `FileSystemEvent` is_

**Replacement / Migration** (1)

- calls these members, and use that instead.
  - _- **Breaking change to `@staticInterop` and `external` extension members**:_

---

### 3.0.3

**Performance Improvement** (2)

- - Improves linter support (issue [#4195]).
  - _- Fixes an issue in variable patterns preventing users from expressing_
- cache on Windows (issue [#52386]).

---

### 3.0.1

**Performance Improvement** (1)

- - Improve performance on functions with many parameters (issue [#1212]).

---

### 3.0.0

**Deprecation** (25)

- - Removed the deprecated `List` constructor, as it wasn't null safe.
  - _Use list literals (e.g. `[]` for an empty list or `<int>[]` for an empty_
- - Removed the deprecated `onError` argument on [`int.parse`][], [`double.parse`][],
  - _and [`num.parse`][]. Use the [`tryParse`][] method instead._
- - Removed the deprecated [`proxy`][] and [`Provisional`][] annotations.
  - _The original `proxy` annotation has no effect in Dart 2,_
- - Removed the deprecated [`Deprecated.expires`][] getter.
  - _Use [`Deprecated.message`][] instead._
- Use [`Deprecated.message`][] instead.
  - _- Removed the deprecated [`CastError`][] error._
- - Removed the deprecated [`CastError`][] error.
  - _Use [`TypeError`][] instead._
- - Removed the deprecated [`FallThroughError`][] error. The kind of
  - _fall-through previously throwing this error was made a compile-time_
- - Removed the deprecated [`NullThrownError`][] error. This error is never
  - _thrown from null safe code._
- - Removed the deprecated [`AbstractClassInstantiationError`][] error. It was made
  - _a compile-time error to call the constructor of an abstract class in Dart 2.0._
- - Removed the deprecated [`CyclicInitializationError`]. Cyclic dependencies are
  - _no longer detected at runtime in null safe code. Such code will fail in other_
- - Removed the deprecated [`NoSuchMethodError`][] default constructor.
  - _Use the [`NoSuchMethodError.withInvocation`][] named constructor instead._
- - Removed the deprecated [`BidirectionalIterator`][] class.
  - _Existing bidirectional iterators can still work, they just don't have_
- [`Deprecated.expires`]: https://api.dart.dev/stable/2.18.4/dart-core/Deprecated/expires.html
  - _[`Deprecated.message`]: https://api.dart.dev/stable/2.18.4/dart-core/Deprecated/message.html_
- [`Deprecated.message`]: https://api.dart.dev/stable/2.18.4/dart-core/Deprecated/message.html
  - _[`AbstractClassInstantiationError`]: https://api.dart.dev/stable/2.17.4/dart-core/AbstractClassInstantiationError-class.html_
- - Removed the deprecated [`DeferredLibrary`][] class.
  - _Use the [`deferred as`][] import syntax instead._
- - Deprecated the `HasNextIterator` class ([#50883][]).
- * `HasNextIterator` (Also deprecated.)
  - _* `HashMap`_
- - Removed the deprecated [`MAX_USER_TAGS`][] constant.
  - _Use [`maxUserTags`][] instead._
- - Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],
  - _and [`Gauge`][] classes as they have been broken since Dart 2.0._
- - The experimental `@FfiNative` annotation is now deprecated.
  - _Usages should be replaced with the new `@Native` annotation._
- - **Breaking change**: As previously announced, the deprecated `registerElement`
  - _and `registerElement2` methods in `Document` and `HtmlDocument` have been_
- - Deprecate `NetworkInterface.listSupported`. Has always returned true since
  - _Dart 2.3._
- - Removed deprecated command line flags `-k`, `--kernel`, and `--dart-sdk`.
  - _- The compile time flag `--nativeNonNullAsserts`, which ensures web library APIs_
- - add new lint: `deprecated_member_use_from_same_package` which replaces the
  - _soft-deprecated analyzer hint of the same name._
- soft-deprecated analyzer hint of the same name.
  - _- update `public_member_api_docs` to not require docs on enum constructors._

**Breaking Change** (27)

- **Breaking change**: Dart 3.0 interprets [switch cases] as patterns instead of
  - _constant expressions. Most constant expressions found in switch cases are_
- **Breaking change:** Class declarations from libraries that have been upgraded
  - _to Dart 3.0 can no longer be used as mixins by default. If you want the class_
- - **Breaking change** [#50902][]: Dart reports a compile-time error if a
  - _`continue` statement targets a [label] that is not a loop (`for`, `do` and_
- - **Breaking change** [language/#2357][]: Starting in language version 3.0,
  - _Dart reports a compile-time error if a colon (`:`) is used as the_
- - **Breaking Change**: Non-`mixin` classes in the platform libraries
  - _can no longer be mixed in, unless they are explicitly marked as `mixin class`._
- - **Breaking change** [#49529][]:
  - _- Removed the deprecated `List` constructor, as it wasn't null safe._
- - Removed the deprecated `List` constructor, as it wasn't null safe.
  - _Use list literals (e.g. `[]` for an empty list or `<int>[]` for an empty_
- - Removed the deprecated `onError` argument on [`int.parse`][], [`double.parse`][],
  - _and [`num.parse`][]. Use the [`tryParse`][] method instead._
- - Removed the deprecated [`proxy`][] and [`Provisional`][] annotations.
  - _The original `proxy` annotation has no effect in Dart 2,_
- - Removed the deprecated [`Deprecated.expires`][] getter.
  - _Use [`Deprecated.message`][] instead._
- - Removed the deprecated [`CastError`][] error.
  - _Use [`TypeError`][] instead._
- - Removed the deprecated [`FallThroughError`][] error. The kind of
  - _fall-through previously throwing this error was made a compile-time_
- - Removed the deprecated [`NullThrownError`][] error. This error is never
  - _thrown from null safe code._
- - Removed the deprecated [`AbstractClassInstantiationError`][] error. It was made
  - _a compile-time error to call the constructor of an abstract class in Dart 2.0._
- - Removed the deprecated [`CyclicInitializationError`]. Cyclic dependencies are
  - _no longer detected at runtime in null safe code. Such code will fail in other_
- - Removed the deprecated [`NoSuchMethodError`][] default constructor.
  - _Use the [`NoSuchMethodError.withInvocation`][] named constructor instead._
- - Removed the deprecated [`BidirectionalIterator`][] class.
  - _Existing bidirectional iterators can still work, they just don't have_
- - **Breaking change when migrating code to Dart 3.0**:
  - _Some changes to platform libraries only affect code when that code is migrated_
- - Removed the deprecated [`DeferredLibrary`][] class.
  - _Use the [`deferred as`][] import syntax instead._
- - Removed the deprecated [`MAX_USER_TAGS`][] constant.
  - _Use [`maxUserTags`][] instead._
- - **Breaking change** [#50231][]:
  - _- Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],_
- - Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],
  - _and [`Gauge`][] classes as they have been broken since Dart 2.0._
- - **Breaking change**: As previously announced, the deprecated `registerElement`
  - _and `registerElement2` methods in `Document` and `HtmlDocument` have been_
- removed.  See [#49536](https://github.com/dart-lang/sdk/issues/49536) for
  - _details._
- - **Breaking change** [#51035][]:
  - _- Update `NetworkProfiling` to accommodate new `String` ids_
- - Removed deprecated command line flags `-k`, `--kernel`, and `--dart-sdk`.
  - _- The compile time flag `--nativeNonNullAsserts`, which ensures web library APIs_
- The null safety migration tool (`dart migrate`) has been removed.  If you still
  - _have code which needs to be migrated to null safety, please run `dart migrate`_

**New Feature / API** (4)

- - **[Class modifiers]**: New modifiers `final`, `interface`, `base`, and `mixin`
  - _on `class` and `mixin` declarations let you control how the type can be used._
- current flexible defaults, but these new modifiers give you finer-grained
  - _control over how the type can be used._
- - Added extension member `wait` on iterables and 2-9 tuples of futures.
- - Added extension members `nonNulls`, `firstOrNull`, `lastOrNull`,
  - _`singleOrNull`, `elementAtOrNull` and `indexed` on `Iterable`s._

**Performance Improvement** (3)

- The `MapEntry` value class is restricted to enable later optimizations.
  - _The remaining classes are tightly coupled to the platform and not_
- - improve performance for `prefer_const_literals_to_create_immutables`.
  - _- update `use_build_context_synchronously` to check context properties._
- - improve `unnecessary_parenthesis` support for property accesses and method
  - _invocations._

**Replacement / Migration** (7)

- **Breaking change**: Dart 3.0 interprets [switch cases] as patterns instead of
  - _constant expressions. Most constant expressions found in switch cases are_
- Use [`Deprecated.message`][] instead.
  - _- Removed the deprecated [`CastError`][] error._
- Use [`TypeError`][] instead.
  - _- Removed the deprecated [`FallThroughError`][] error. The kind of_
- Use [`maxUserTags`][] instead.
  - _- Callbacks passed to `registerExtension` will be run in the zone from which_
- now takes `Object` instead of `String`.
- - Observatory is no longer served by default and users should instead use Dart
  - _DevTools. Users requiring specific functionality in Observatory should set_
- - On Windows the `PUB_CACHE` has moved to `%LOCALAPPDATA%`, since Dart 2.8 the
  - _`PUB_CACHE` has been created in `%LOCALAPPDATA%` when one wasn't present._

---

## Dart-Code

### 128

**Deprecation** (2)

- * [#5874](https://github.com/Dart-Code/Dart-Code/issues/5874)/[#5882](https://github.com/Dart-Code/Dart-Code/issues/5882): Tasks like `build_runner` are now invoked with `dart run`, preventing a warning about `flutter pub run` being deprecated.
- > There is no immediate problem but is related to a deprecation. Since `flutter pub run` was deprecated in favor of `dart run`, the built in task command in the extension should be updated to use `dart run`.
  - _>_

**Replacement / Migration** (1)

- > **#5728**: Use `flutterRoot` instead of looking for the `flutter` package when reading the sdk path from `.package_config.json` `is enhancement`
  - _> **Is your feature request related to a problem? Please describe.**_

---

### 126

**Deprecation** (1)

- > See https://blog.flutter.dev/whats-new-in-flutter-3-35-c58ef72e3766#:~:text=In%20our%20next%20stable%20release%2C%20Flutter%20SDKs%20before%203.16%20will%20be%20deprecated.

**Breaking Change** (4)

- > Placeholder for release notes.. this version will warn that support for Dart 3.1 / Flutter 3.13 is being removed soon.
  - _>_
- * [#5602](https://github.com/Dart-Code/Dart-Code/issues/5602): `formatOnType` no longer triggers when typing `;` inside an enhanced enum without a constructor, which caused the semicolon to be removed.
- > **#5602**: Writing `;` inside an enhanced enum without the constructor makes it get removed `is bug` `in editor` `relies on sdk changes`
  - _> **Describe the bug**_
- > When writing `;` inside enhanced enum before it contains a constructor, it gets removed.
  - _>_

**New Parameter / Option** (1)

- * [#5840](https://github.com/Dart-Code/Dart-Code/issues/5840)/[#5814](https://github.com/Dart-Code/Dart-Code/issues/5814): To improve startup performance, the widget preview now starts on first access rather than at startup. This can be controlled with a new setting `dart.flutterWidgetPreview` that accepts `"startLazily"` (default), `"startEagerly"` (starts at startup when a Flutter project is present) and `"disabled"`.

**Performance Improvement** (4)

- * [#5840](https://github.com/Dart-Code/Dart-Code/issues/5840)/[#5814](https://github.com/Dart-Code/Dart-Code/issues/5814): To improve startup performance, the widget preview now starts on first access rather than at startup. This can be controlled with a new setting `dart.flutterWidgetPreview` that accepts `"startLazily"` (default), `"startEagerly"` (starts at startup when a Flutter project is present) and `"disabled"`.
- > For now, I'm changing the default to lazy, since it can consume a lot of memory and there have been a few issues - but we can consider switching it to eagerly (to make it load faster the first time if you do use it) if that becomes a better trade-off than it is today (FYI @bkonyi).
- > **#5848**: Add/improve prompts to encourage filing bugs `is enhancement`
  - _> This adds/tweaks prompts to encourage users to file bugs for:_
- * [#5830](https://github.com/Dart-Code/Dart-Code/issues/5830): ~~Updated to LSP client v10.0.0-next.18 and enabled`delayOpenNotifications` for improved performance.~~ This change was reverted pending a fix in the VS Code LSP client.

**Replacement / Migration** (2)

- * [#5831](https://github.com/Dart-Code/Dart-Code/issues/5831)/[#5834](https://github.com/Dart-Code/Dart-Code/issues/5834): Deleting a test no longer sometimes causes the next test marker to move to the incorrect line.
- > **#5830**: Switch to LSP client v10.0.0-next.18 and enable delayOpenNotifications `is performance`
  - _> Fixes https://github.com/Dart-Code/Dart-Code/issues/5176_

---

### 124

**Performance Improvement** (4)

- > I feel it would greatly improve developer experience, since you wouldn't need to either:
- > When https://github.com/microsoft/vscode-copilot-chat/pull/394 ships, we should test excluding the analyze_files tool and check that models will instead use #problems because it will handle unsaved files and be faster (since it doesn't require new analysis).
- > Could the notification be improved by either:
  - _> - adding a progress bar in there (don't think this is possible)_
- > **#5818**: Improve the display of "<unnamed extension>" in breadcrumbs etc. `is enhancement` `in editor` `in lsp/analysis server` `relies on sdk changes`
  - _> For an extension, we could show something like `""` or something instead? Or just "extension on FooClass" (which looks like the declaration)?_

**Replacement / Migration** (6)

- * [#5775](https://github.com/Dart-Code/Dart-Code/issues/5775): The Flutter Widget Preview now works for _all_ projects within a Pub Workspace instead of only the first.
- * [#5776](https://github.com/Dart-Code/Dart-Code/issues/5776): The `flutter/ephemeral`, `.symlinks` and `.plugin_symlinks` folders are now excluded from the explorer and search results by default. The `.dart_tool` folder is also now excluded from search results by default. If you’d prefer these were included, you can add them back by adding them to `files.exclude` and `search.exclude` configuration with a value of `false`.
- > When https://github.com/microsoft/vscode-copilot-chat/pull/394 ships, we should test excluding the analyze_files tool and check that models will instead use #problems because it will handle unsaved files and be faster (since it doesn't require new analysis).
- * [#5801](https://github.com/Dart-Code/Dart-Code/issues/5801)/[#5789](https://github.com/Dart-Code/Dart-Code/issues/5789): Commands like **Get Packages** now show the package name in the output instead of just the folder name (which is usually - but not always - the same).
- > **#5801**: Use "package:foo" instead of foldernames in command execution `is enhancement` `in commands`
  - _> Fixes https://github.com/Dart-Code/Dart-Code/issues/5789_
- * [#5818](https://github.com/Dart-Code/Dart-Code/issues/5818): Breadcrumbs and other UI now show `extension on Foo` instead of just `<unnamed extension>` for unnamed extensions.

---

### 122

**New Feature / API** (1)

- * [#5648](https://github.com/Dart-Code/Dart-Code/issues/5648): E2E tests have been expanded to include testing of the new Widget Preview.

**Performance Improvement** (3)

- * [#5668](https://github.com/Dart-Code/Dart-Code/issues/5668): The new test location tracking is now enabled by default and should improve the locations in the test explorer and gutter icons when using packages like `test_reflective_loader` that register tests dynamically.
- > **#5759**: Exceptions in Watch window are not correctly reduced to the relevant part `is bug` `in debugging`
  - _> We have some failing tests against beta because of this.. We used to strip out the important part of an error so this message was useful, but now it just shows this:_
- > **#5761**: `@FailingTest()` annotation on `test_reflective_loader` test timeouts but fails faster without it `is bug` `in testing` `relies on sdk changes`
  - _> **Describe the bug**_

**Replacement / Migration** (5)

- * [#5744](https://github.com/Dart-Code/Dart-Code/issues/5744): The Flutter Widget Preview sidebar icon now appears after extension activation instead of only after the widget preview server initialises.
- * [#5740](https://github.com/Dart-Code/Dart-Code/issues/5740)/[#5746](https://github.com/Dart-Code/Dart-Code/issues/5746): Progress notifications when running the **Pub Get** command for multiple packages in a batch are now combined into a single notification that updates with the package names, instead of flickering individual notifications.
- * [#5745](https://github.com/Dart-Code/Dart-Code/issues/5745)/[#5746](https://github.com/Dart-Code/Dart-Code/issues/5746): When the **Pub Get** command is being run for multiple packages in a batch, a single cancellation will cancel the entire batch instead of only the current project.
- * [#5759](https://github.com/Dart-Code/Dart-Code/issues/5759): Exceptions shown in the Watch window once again show only the relevant part of the error message instead of prefixes like “Unhandled exception:”
- > **#5730**: Wish to inform the user to prefer USB over WiFi when developing against an iOS 26 device `is enhancement` `in flutter` `in debugging` `relies on sdk changes`
  - _> Related to https://github.com/flutter/flutter/issues/176206_

---

### 120

**Breaking Change** (3)

- > Release notes placeholder for the preview flag that enables new test tracking as a solution towards https://github.com/Dart-Code/Dart-Code/issues/5668 (since that issue will be bumped to a future release when the flag is removed).
- * [#4696](https://github.com/Dart-Code/Dart-Code/issues/4696): Commands related to Dart Observatory are now hidden for Dart SDKs since 3.9 (when Observatory was removed).
- > When observatory is completely removed, we should use that SDK version number as a signal to hide the command so it's not in the palette.

**New Parameter / Option** (2)

- * [#5729](https://github.com/Dart-Code/Dart-Code/issues/5729)/[#5727](https://github.com/Dart-Code/Dart-Code/issues/5727): A new setting `dart.experimentalTestTracking` enables tracking of tests within files. This should improve the reliability of test gutter icons and the “Go to Test” commands for tests that are not discoverable statically (for example dynamic tests, or those using `pkg:test_reflective_loader`). This will be enabled by default in a future release.
- * [#5600](https://github.com/Dart-Code/Dart-Code/issues/5600): A new setting `dart.inlayHints` has been added to control which Inlay Hints are enabled (requires Dart 3.10)

**Performance Improvement** (3)

- * [#5729](https://github.com/Dart-Code/Dart-Code/issues/5729)/[#5727](https://github.com/Dart-Code/Dart-Code/issues/5727): A new setting `dart.experimentalTestTracking` enables tracking of tests within files. This should improve the reliability of test gutter icons and the “Go to Test” commands for tests that are not discoverable statically (for example dynamic tests, or those using `pkg:test_reflective_loader`). This will be enabled by default in a future release.
- * [#5683](https://github.com/Dart-Code/Dart-Code/issues/5683): The extension now starts up faster when running in Firebase Studio.
- Several improvements have been made to the integration with the Widget Preview functionality (which currently requires the Flutter `master` branch).

**Replacement / Migration** (4)

- > When I click "run tests with coverage" in VS Code, the resulting coverage pane shows coverage for some (apparently random) flutter library files, instead of for my code. See screenshot below.
  - _>_
- > We should prefer to look at the package map for the project containing the source file, and only fall back to finding another match if there isn't one.
- * [#5712](https://github.com/Dart-Code/Dart-Code/issues/5712): The **Debug: Attach to Dart Process** command now makes it clearer that a port number can be provided instead of a full URL.
- > It appears that after completing this code, the selection is just at the end of the `throw UnimplementedError()` instead of selecting it:

---

### 118

**Deprecation** (4)

- [#5667](https://github.com/Dart-Code/Dart-Code/issues/5667): Support for SDKs prior to Dart 3.1 and Flutter 3.13 is being deprecated. If you are using affected versions you will be shown a one-time warning advising you to upgrade.
- > **#5667**: Warn that Dart / Flutter SDKs prior to Dart 3.1 / Flutter 3.13 are deprecated and support will be removed soon `in flutter` `in dart`
  - _> With the recent Flutter stable release, it was announced that IDE support for SDKs prior to 3.13 is deprecated:_
- > With the recent Flutter stable release, it was announced that IDE support for SDKs prior to 3.13 is deprecated:
  - _>_
- > > With this release, we are deprecating IDE support for Flutter SDKs before 3.13.
  - _>_

**Breaking Change** (1)

- > **#5667**: Warn that Dart / Flutter SDKs prior to Dart 3.1 / Flutter 3.13 are deprecated and support will be removed soon `in flutter` `in dart`
  - _> With the recent Flutter stable release, it was announced that IDE support for SDKs prior to 3.13 is deprecated:_

**New Parameter / Option** (3)

- * [#5651](https://github.com/Dart-Code/Dart-Code/issues/5651)/[#5653](https://github.com/Dart-Code/Dart-Code/issues/5653): A new setting `dart.useFlutterDev` allows use of `flutter-dev` instead of `flutter`. This script is intended for use by contributors to the `flutter` tool to avoid having to manually rebuild the tool when making local changes.
- * [#5639](https://github.com/Dart-Code/Dart-Code/issues/5639): A new setting `dart.mcpServerTools` allows excluding some of the Dart MCP servers tools from registration with VS Code/Copilot. By default the `runTests` tool is excluded because it overlaps with an equivalent tool provided by VS Code.
- * [#5630](https://github.com/Dart-Code/Dart-Code/issues/5630): A new setting `dart.coverageExcludePatterns` allows excluding coverage from files/folders using globs. For example you could exclude `**/generated/**` or `**/*.g.dart`.

**Performance Improvement** (3)

- > Dart-Code should provide support for using `flutter-dev` to reduce some friction for `flutter_tools` developers.
  - _>_
- > @liamappelbe what are your thoughts on (3)? It would be nicer (and perhaps faster) if we this coverage wasn't collected for these files in the first place, but it might be that the difference is negligible and we should just drop it in Dart-Code.
- >     --[no-]offline       Use cached packages instead of accessing the network.
  - _> -n, --dry-run            Report what dependencies would change but don't change_

**Replacement / Migration** (7)

- * [#5651](https://github.com/Dart-Code/Dart-Code/issues/5651)/[#5653](https://github.com/Dart-Code/Dart-Code/issues/5653): A new setting `dart.useFlutterDev` allows use of `flutter-dev` instead of `flutter`. This script is intended for use by contributors to the `flutter` tool to avoid having to manually rebuild the tool when making local changes.
- > `flutter-dev` is a version of `flutter` used by developers working on `flutter_tools` that runs the tool from source instead of precompiling the tool as a snapshot on first run and using the precompiled snapshot for subsequent runs.
  - _>_
- > From some local experimentation where I renamed `flutter-dev` to `flutter` and updated `bin/internal/shared.sh` to not try to build a snapshot for `flutter` instead of `flutter-dev`, it looks like Dart-Code does make use of the existence of `bin/cache/flutter_tools.snapshot` to determine if the tool is initialized:
  - _>_
- > **#5665**: Support space separators in `Dart: Add Dependency` instead of only commas `is enhancement` `in commands`
  - _> **Describe the bug**_
- >     --[no-]offline       Use cached packages instead of accessing the network.
  - _> -n, --dry-run            Report what dependencies would change but don't change_
- > - ~~Add support for multiple Flutter projects (currently we just pick the first one in the workspace)~~ moved to https://github.com/Dart-Code/Dart-Code/issues/5671
  - _> - [x] Pass DevTools and DTD server URIs so the preview doesn't start its own_
- > - ~~Add new icon for Sidebar version (this is in two places - container + view)~~ moved to https://github.com/Dart-Code/Dart-Code/issues/5672

---

### 116

**Deprecation** (1)

- * [#5008](https://github.com/Dart-Code/Dart-Code/issues/5008)/[#5583](https://github.com/Dart-Code/Dart-Code/issues/5583)/[#5595](https://github.com/Dart-Code/Dart-Code/issues/5595)/[#5601](https://github.com/Dart-Code/Dart-Code/issues/5601): New APIs are now exported by the extension to allow other VS Code extensions to reuse some of Dart-Code’s functionality. The internal private APIs that were intended only for testing (but had been adopted by some extensions) will be removed in an upcoming release. If you maintain a VS Code extension that uses these APIs, please see https://github.com/Dart-Code/Dart-Code/issues/5587 and ensure your extension is migrated.

**Breaking Change** (5)

- * [#5591](https://github.com/Dart-Code/Dart-Code/issues/5591): The **Flutter: New Project** command no longer shows the “Skeleton” option that was removed in Flutter 3.29.
- > When creating a Flutter project, there are several options as for the template. One of them is "Skeleton Application". However, this template has been removed from `flutter create` at the end of 2024 (see [skeleton template removal](https://github.com/flutter/flutter/issues/160673)).
  - _>_
- > As this option doesn't exist in `flutter create` anymore, it should probably be removed from the choices in project creation from the Flutter plugin as well.
  - _>_
- * [#5008](https://github.com/Dart-Code/Dart-Code/issues/5008)/[#5583](https://github.com/Dart-Code/Dart-Code/issues/5583)/[#5595](https://github.com/Dart-Code/Dart-Code/issues/5595)/[#5601](https://github.com/Dart-Code/Dart-Code/issues/5601): New APIs are now exported by the extension to allow other VS Code extensions to reuse some of Dart-Code’s functionality. The internal private APIs that were intended only for testing (but had been adopted by some extensions) will be removed in an upcoming release. If you maintain a VS Code extension that uses these APIs, please see https://github.com/Dart-Code/Dart-Code/issues/5587 and ensure your extension is migrated.
- > In the latest release, we removed the code that forced the SDK repo to always run tests through `dart` instead of the test runner. It turns out there are quite a few tests in the SDK that fail when run through the runner.
  - _>_

**New Feature / API** (1)

- * [#5008](https://github.com/Dart-Code/Dart-Code/issues/5008)/[#5583](https://github.com/Dart-Code/Dart-Code/issues/5583)/[#5595](https://github.com/Dart-Code/Dart-Code/issues/5595)/[#5601](https://github.com/Dart-Code/Dart-Code/issues/5601): New APIs are now exported by the extension to allow other VS Code extensions to reuse some of Dart-Code’s functionality. The internal private APIs that were intended only for testing (but had been adopted by some extensions) will be removed in an upcoming release. If you maintain a VS Code extension that uses these APIs, please see https://github.com/Dart-Code/Dart-Code/issues/5587 and ensure your extension is migrated.

**New Parameter / Option** (1)

- * [#5556](https://github.com/Dart-Code/Dart-Code/issues/5556)/[#5577](https://github.com/Dart-Code/Dart-Code/issues/5577): A new setting `dart.mcpServerLogFile` allows logging communication with the Dart SDK MCP server.

**Performance Improvement** (1)

- * [#5581](https://github.com/Dart-Code/Dart-Code/issues/5581): An improved error message is shown if you try to use a Dart SDK built for a different architecture.

**Replacement / Migration** (5)

- * [#5612](https://github.com/Dart-Code/Dart-Code/issues/5612)/[#5617](https://github.com/Dart-Code/Dart-Code/issues/5617): Adding a Flutter project to a workspace that previously contained only Dart projects will now prompt to reload in order to switch to a Flutter SDK and start required Flutter services.
- * [#5606](https://github.com/Dart-Code/Dart-Code/issues/5606)/[#5610](https://github.com/Dart-Code/Dart-Code/issues/5610): Interaction with Flutter’s device daemon has been switched to newer APIs, avoiding “No devices found” on Flutter’s `master` branch.
- > It could also be synched with the removal of the [skeleton] template option from the `flutter create` command, which is still present (but only shows a message instead of creating a project).
- * [#5621](https://github.com/Dart-Code/Dart-Code/issues/5621)/[#5622](https://github.com/Dart-Code/Dart-Code/issues/5622): The `autolaunch.json` functionality now supports watching for modifications to the autolaunch file instead of only creation.
  - _* [#5613](https://github.com/Dart-Code/Dart-Code/issues/5613): An environment variable `DART_CODE_SERVICE_ACTIVATION_DELAY` can now be used to delay the activation of background services like the Dart Tooling Daemon._
- > In the latest release, we removed the code that forced the SDK repo to always run tests through `dart` instead of the test runner. It turns out there are quite a few tests in the SDK that fail when run through the runner.
  - _>_

---

### 114

**Breaking Change** (1)

- > **#4678**: Breakpoints flicker as they are removed/re-added when breakpoints are added/removed `is bug` `in debugging` `relies on sdk changes`
  - _> Because we mark breakpoints as unverified initially now, and we delete/re-create them when anything changes (because VS Code just gives us a whole new set), there's a noticable flicker._

**Performance Improvement** (1)

- * [#5532](https://github.com/Dart-Code/Dart-Code/issues/5532): Lists inspected in the debugger at the top level (for example by hovering) are now paged in the same way as child fields which improves performance and avoids stalls for very large lists.

**Replacement / Migration** (4)

- * [#5553](https://github.com/Dart-Code/Dart-Code/issues/5553): Setting `"dart.hotReloadProgress": "statusBar"` now correctly shows Flutter hot reload progress in the status bad instead of toast notifications.
- * [#5520](https://github.com/Dart-Code/Dart-Code/issues/5520): It’s now possible to specify `emulatorId` instead of `deviceId` in a launch configuration. This will automatically be mapped to the correct `deviceId` during launch, and if the emulator is not already running it will first be started.
- * [#5502](https://github.com/Dart-Code/Dart-Code/issues/5502): The **Add Dependency** command will now allow selecting which projects to add the dependency to, with the project for the active file pre-selected, instead of just automatically adding to the project for the active file.
- > Inline values show for parameters but not for pattern destruction blocks. This forces me to hover the assigned variable instead of simply looking at the value.
  - _>_

---

### 112

**Breaking Change** (1)

- > This issue is to discuss feedback about whether this works well enough that the experimental flag should be removed and ship it.

**New Feature / API** (1)

- > We should try to reduce the requirement, and handle (in code) and new APIs we require for now.

**Performance Improvement** (3)

- * [#5515](https://github.com/Dart-Code/Dart-Code/issues/5515): The minimum version of VS Code for this version of the extension has been reduced from 1.96 to 1.75.
- > **#5515**: Reduce the required VS Code version `is enhancement`
  - _> Currently some web editors like Firebase Studio are on a lower version of VS Code than the minimum we specify in `package.json`, which means users get old versions of the extension._
- > We should try to reduce the requirement, and handle (in code) and new APIs we require for now.

**Replacement / Migration** (3)

- * [#5480](https://github.com/Dart-Code/Dart-Code/issues/5480): When developing in the Dart SDK repository in packages that use `package:test_reflective_loader` (such as `analyzer` or `analysis_server`), the **Go to Test** actions now navigate to the test method instead of the call to `defineReflectiveTests`. When a test fails, the error popup will also show at this new location.
- > I expected it to move to the right test.
  - _>_
- > then when you load the project you would instantly have access to DevTools for the visible app in the emulator. By attaching (instead of launching ourselves), if you have a multi-user session, both would be attached to the same instance, rather than one of them replacing the other.
  - _>_

---

### 110

**Performance Improvement** (1)

- > 2. `cd packages`, `get sparse-checkout init --cone`, `get sparse-checkout set packages/camera packages/google_maps_flutter` (this restricts checkout, so that things are faster and easier to repro)
  - _> 3. `code .`_

**Replacement / Migration** (1)

- > I ran some of these tests by right-clicking on the "test/src/computer" folder (in `analysis_server`), and then when I switched to the test runner, they appear as just the filename, whereas the other discovered tests all have relative paths from the root of the workspace folder.
  - _>_

---

### 108

**Breaking Change** (2)

- * [#5456](https://github.com/Dart-Code/Dart-Code/issues/5456): Because the Dart SDK repository now uses Pub Workspaces, the `dart.experimentalTestRunnerInSdk` setting has been removed and the test runner functionality is available when working in the Dart SDK repository automatically.
- * [#5090](https://github.com/Dart-Code/Dart-Code/issues/5090): The `dart.previewDtdLspIntegration` setting has been removed and the analysis server will now always connect to DTD when using a supported SDK version. If you are interested in integrating with the analysis server over DTD please [see this issue](https://github.com/dart-lang/sdk/issues/60377) about capabilities.

**Replacement / Migration** (6)

- [#5396](https://github.com/Dart-Code/Dart-Code/issues/5396)/[#5367](https://github.com/Dart-Code/Dart-Code/issues/5367)/[#5466](https://github.com/Dart-Code/Dart-Code/issues/5466): A new experiment allows embedding DevTools pages inside the sidebar instead of as editor tabs. Trying this out requires enabling an experiment flag and then using the hidden value `"sidebar"` in the `dart.devToolsLocation` setting:
- > ~~There is work in-progress to test out embedding DevTools in sidebar panels instead of editors. It's currently blocked on https://github.com/microsoft/vscode/issues/236494 because that causes us to "restore" bad URLs into the iframes when they load.~~
  - _>_
- * [#5447](https://github.com/Dart-Code/Dart-Code/issues/5447)/[#5448](https://github.com/Dart-Code/Dart-Code/issues/5448): [@davidmartos96](https://github.com/davidmartos96) contributed a fix to prefer launching `studio` over `stduio.sh` when started Android Studio to avoid a warning when Android Studio opens.
- > Android Studio displays warning when opened from VSCode because VSCode seems to launch with the shell script `studio.sh` instead of `studio` binary.
  - _> The line https://github.com/Dart-Code/Dart-Code/blob/master/src/shared/constants.ts#L23 let me think `studio.sh` has greater priority than `studio`. Maybe just swap ?_
- > Because it internally runs `dart [program]` instead of `dart run [program]`
  - _>_
- > 6. Observe that it opens in non-Chrome instead of Chrome
  - _>_

---

### 106

**Deprecation** (1)

- > - [x] Update the website to note which extension versions deprecate and remove support for older SDKs
  - _> - [x] Clean up legacy protocol code that's no longer used_

**Breaking Change** (1)

- [#5325](https://github.com/Dart-Code/Dart-Code/issues/5325): As [previously announced](https://groups.google.com/g/flutter-announce/c/JQHzM3FbBGI), support for Dart SDK v2.19 / Flutter SDK v3.7 and earlier has been removed in this version (v3.106) of the extension. If you need to use these older SDK versions you will need to install v3.104. The [SDK Compatibility page](/sdk-version-compatibility/) maintains a table of which extension versions support which SDKs.

**New Parameter / Option** (1)

- * [#5403](https://github.com/Dart-Code/Dart-Code/issues/5403): A new setting `dart.toolingDaemonAdditionalArgs` allows configuring additional arguments to pass to the Dart Tooling Daemon, for example to pass an explicit port with `--port`.

**Performance Improvement** (5)

- > **#5390**: Improve the summary bubble for failed tests when expected/actual values are simple/single-line `is enhancement` `in testing`
  - _> **Expected behavior**_
- * [#5328](https://github.com/Dart-Code/Dart-Code/issues/5328): The error message shown when the analysis server crashes has been improved, including a **Show Log** button that shows the server output.
- > **#5328**: Improve VS Code's error when the Dart analyzer crashes `is enhancement`
  - _> **Is your feature request related to a problem? Please describe.**_
- > Perhaps this should also recommend cleaning the Dart analyzer cache (deleting `~/.dartServer/` on macOS)
- * [#5376](https://github.com/Dart-Code/Dart-Code/issues/5376): The error message shown when running the analysis server from source with a mismatched SDK version has been improved.

**Replacement / Migration** (1)

- > I think it would be more useful if the red tag showed the actual result instead of the expected one. I looked through preferences to see if i could configure it but I did not find anything. What you do you think?

---

### 104

**Deprecation** (2)

- ![](/images/release_notes/v3.100/sdk_deprecation.png)
- In the next release of the extension, code supporting these SDK versions will be removed. A table showing which extension versions support which SDKs (and instructions on how to change extension version) is available on the [SDK Compatibility page](/sdk-version-compatibility/) if you need to continue to use unsupported SDKs.

**Breaking Change** (2)

- As [previously announced](https://groups.google.com/g/flutter-announce/c/JQHzM3FbBGI), support for older Dart/Flutter SDKs is being removed from the extension. This version of the extension (v3.104) is the last version that will work with SDKs earlier than Dart 3.0 and Flutter 3.10. If you’re using an affected SDK, a one-time notification will be shown.
- In the next release of the extension, code supporting these SDK versions will be removed. A table showing which extension versions support which SDKs (and instructions on how to change extension version) is available on the [SDK Compatibility page](/sdk-version-compatibility/) if you need to continue to use unsupported SDKs.

**New Parameter / Option** (1)

- [#5334](https://github.com/Dart-Code/Dart-Code/issues/5334)/[#5377](https://github.com/Dart-Code/Dart-Code/issues/5377)/[#5117](https://github.com/Dart-Code/Dart-Code/issues/5117): [@davidmartos96](https://github.com/davidmartos96) contributed new settings `dart.getFlutterSdkCommand` and `dart.getDartSdkCommand` that allow executing a command to locate the Dart/Flutter SDKs to use for a workspace. This improves compatibility with some SDK version managers (such as `mise` and `asdf`) because they can be queried for the current SDK instead of reading from `PATH` (or `package.json`).

**Performance Improvement** (1)

- [#5334](https://github.com/Dart-Code/Dart-Code/issues/5334)/[#5377](https://github.com/Dart-Code/Dart-Code/issues/5377)/[#5117](https://github.com/Dart-Code/Dart-Code/issues/5117): [@davidmartos96](https://github.com/davidmartos96) contributed new settings `dart.getFlutterSdkCommand` and `dart.getDartSdkCommand` that allow executing a command to locate the Dart/Flutter SDKs to use for a workspace. This improves compatibility with some SDK version managers (such as `mise` and `asdf`) because they can be queried for the current SDK instead of reading from `PATH` (or `package.json`).

**Replacement / Migration** (4)

- [#5334](https://github.com/Dart-Code/Dart-Code/issues/5334)/[#5377](https://github.com/Dart-Code/Dart-Code/issues/5377)/[#5117](https://github.com/Dart-Code/Dart-Code/issues/5117): [@davidmartos96](https://github.com/davidmartos96) contributed new settings `dart.getFlutterSdkCommand` and `dart.getDartSdkCommand` that allow executing a command to locate the Dart/Flutter SDKs to use for a workspace. This improves compatibility with some SDK version managers (such as `mise` and `asdf`) because they can be queried for the current SDK instead of reading from `PATH` (or `package.json`).
- * [#5401](https://github.com/Dart-Code/Dart-Code/issues/5401): When using a VS Code workspace (`.code-workspace` file), relative paths in settings are now resolved relative to the folder containing the workspace file instead of the first folder in the workspace.
- > The `cacheBust` param and all following are tacked on to the end instead of adding to the existing query parameters like `wasm=true`. Additionally, we shouldn't need the # sign which may be getting added by VS code.
- * [#5363](https://github.com/Dart-Code/Dart-Code/issues/5363): The debugger no longer incorrectly evaluates values for initializing parameters instead of class variables inside constructor bodies.

---

### 102

**Performance Improvement** (1)

- > **#5327**: Update syntax highlighting to improve code blocks in dartdocs `is enhancement` `in editor`
  - _> We want the fix for https://github.com/dart-lang/dart-syntax-highlight/pull/75 to fix this:_

**Replacement / Migration** (1)

- * [#5353](https://github.com/Dart-Code/Dart-Code/issues/5353): The “Peek Error” popup shown when a test fails now shows the full output of a test instead of only the last output event (which for Flutter integration tests is often just the bottom of an ascii box `==========================`).

---

### 100

**Deprecation** (2)

- [#5257](https://github.com/Dart-Code/Dart-Code/issues/5257)/[#5304](https://github.com/Dart-Code/Dart-Code/issues/5304): As [previously announced](https://groups.google.com/g/flutter-announce/c/JQHzM3FbBGI), support for older Dart/Flutter SDKs will be deprecated with Dart 3.6 and removed when Dart 3.7 releases next year. If you are using an affected SDK version (a Dart SDK before Dart 3.0 or a Flutter SDK before Flutter 3.10) you will see a notification.
- ![](/images/release_notes/v3.100/sdk_deprecation.png)

**Breaking Change** (2)

- [#5257](https://github.com/Dart-Code/Dart-Code/issues/5257)/[#5304](https://github.com/Dart-Code/Dart-Code/issues/5304): As [previously announced](https://groups.google.com/g/flutter-announce/c/JQHzM3FbBGI), support for older Dart/Flutter SDKs will be deprecated with Dart 3.6 and removed when Dart 3.7 releases next year. If you are using an affected SDK version (a Dart SDK before Dart 3.0 or a Flutter SDK before Flutter 3.10) you will see a notification.
- * [#5321](https://github.com/Dart-Code/Dart-Code/issues/5321): The temporary allowlist for allowing Pub packages to recommend their VS Code extensions has been removed.

**New Feature / API** (2)

- > This adds two new fields to `DartCapabilities` for `isUnsupportedNow` and `isUnsupportedSoon` to determine whether to warn the user about unsupported SDKs. This is a necessary step before we can remove any legacy code (such as the legacy analysis server integration, or activating DevTools from pub!).
- > Hi, given the Dart VS Code extension supports suggesting VS Code extensions based on the installed packages, it would be great to either remove [the allow list](https://github.com/Dart-Code/Dart-Code/blob/master/src/extension/sdk/dev_tools/manager.ts#L550) or have a clear process of how a new extension can be added there.

**New Parameter / Option** (1)

- > This adds two new fields to `DartCapabilities` for `isUnsupportedNow` and `isUnsupportedSoon` to determine whether to warn the user about unsupported SDKs. This is a necessary step before we can remove any legacy code (such as the legacy analysis server integration, or activating DevTools from pub!).

**Performance Improvement** (1)

- > **#5303**: Error in DocumentCache `is bug` `in testing`
  - _> I saw this while testing https://github.com/Dart-Code/Dart-Code/issues/5302, running the test file._

**Replacement / Migration** (4)

- > "Unsupported now" messages will always be shown as the intention is that the user will either upgrade their SDK or switch to an older extension.. this may seem annoying, but the extension will be broken in many ways when using an SDK that triggers this, so ignoring it is not an option - you must upgrade SDK or switch to an older extension.
- * [#5311](https://github.com/Dart-Code/Dart-Code/issues/5311): Using the `dart.customDevTools` setting to run DevTools from source now assumes the tool is named `dt` instead of the original name `devtools_tool`.
- > **#5311**: Switch customDevTools to assume `dt` instead of `devtools_tool` `is enhancement` `in devtools`
  - _> See https://github.com/flutter/devtools/pull/8410_
- * [#5235](https://github.com/Dart-Code/Dart-Code/issues/5235): The **Move To File** refactor now shows “Refactoring…” status notifications in the status bar, matching other kinds of refactors.

---

### v3-98

**New Parameter / Option** (1)

- * [#3628](https://github.com/Dart-Code/Dart-Code/issues/3628)/[#5263](https://github.com/Dart-Code/Dart-Code/issues/5263): [@FMorschel](https://github.com/FMorschel) contributed new settings for customizing the prefix (`dart.closingLabelsPrefix`) and font style (`dart.closingLabelsTextStyle`) of Closing Labels. ![](/images/release_notes/v3.98/closing_labels_customization.png)

**Performance Improvement** (3)

- > **#5270**: Improve error message for Linter warning: lower_case_with_underscores / dart(file_names) `is enhancement` `in editor`
  - _> **Is your feature request related to a problem? Please describe.**_
- > The problem is that sometimes when creating a new file, one might type in an uppercase character by accident. Dart-Code then immediately shows the `lower_case_with_underscores` warning. However, fixing the issue can be rather tricky, because VSCode doesn't want to change its internal cache of file names, when the only thing that changes about the file name is the casing.
- Various improvements have been made to the Dependencies Tree.

**Replacement / Migration** (3)

- * [#5302](https://github.com/Dart-Code/Dart-Code/issues/5302): When using VS Code 1.94, ANSI color codes once again show colors in the Debug Console instead of printing escape sequences.
- * [#5283](https://github.com/Dart-Code/Dart-Code/issues/5283): The “Build errors exist in your project” dialog has been updated to no longer refer to errors as “Build errors” and uses “Run Anyway” instead of “Debug Anyway” because it can also apply to running without debugging.
- * [#5272](https://github.com/Dart-Code/Dart-Code/issues/5272): When a background process like the analyzer or Flutter daemon terminates unexpectedly, the “Open Log” button on the prompt will now open the specific log for that process (if enabled) instead of a generic log of all events from all processes.

---

### v3-96

**New Parameter / Option** (1)

- * [#5213](https://github.com/Dart-Code/Dart-Code/issues/5213): A new setting `dart.enablePub` allows disabling Pub functionality including prompts for `pub get`, automatically running `pub get` and visibility of the menu and command entries for running Pub commands.

**Performance Improvement** (2)

- > The reason this is currently only enabled for pre-release SDKs is that the UX for the Preview option isn't great - all of the entries are unticked by default (and it can be tedious to tick them). I have an open PR for VS Code I hope may improve this at https://github.com/microsoft/vscode/pull/210175. If that (or something similar) doesn't land soon, we may wish to consider enabling this functionality anyway (or perhaps hiding the Preview button?).
- > **#5224**: Improve discoverability of additional args for testing `is enhancement` `in testing`
  - _> ## Is your feature request related to a problem? Please describe._

**Replacement / Migration** (8)

- * [#5100](https://github.com/Dart-Code/Dart-Code/issues/5100): The prompt to run `dart fix` now offers to run the **Dart: Fix All in Workspace** commands instead of recommending running `dart fix` from the terminal. See the [previous release notes](/releases/#fix-all-in-workspace-commands) for more details on the in-editor fix commands.
- * [#5218](https://github.com/Dart-Code/Dart-Code/issues/5218): An issue with the **Move to File** refactoring causing an invalidate state after creating new files has been resolved.
- > **#5218**: Move to file not moving to existing file even after agreeing to replace it `is bug` `in editor`
  - _> With this code sample:_
- > **#5231**: Switch to parsing the new Flutter version file `bin/cache/flutter.version.json` instead of the legacy one `version` and remove workaround `is enhancement`
  - _> See:_
- * [#5225](https://github.com/Dart-Code/Dart-Code/issues/5225): When using the latest versions of Flutter (currently only `master`), the Flutter sidebar will use DTD for communication with Dart-Code instead of `postMessage`. There are currently no functional differences between the two sidebars, but this is a step towards making [the APIs used by the sidebar](https://github.com/dart-lang/sdk/blob/main/pkg/dtd_impl/dtd_common_services_editor.md) available to other DTD clients, and the sidebar more generic so that it could be used by editors besides VS Code.
- > **#5225**: Switch to the DTD sidebar when using a new enough SDK `is enhancement` `in flutter sidebar`
  - _> - DevTools work done in https://github.com/flutter/devtools/commit/faeb2a3e0d49a01301ed85dd9bba989a88b4b762_
- > **#5232**: In a monorepo, when you select the debug session and select "Dart & Flutter...", all projects are shown, but all with the root folder name instead of the project name. `is bug` `in debugging`
  - _> In a monorepo, when you select the debug session and select "Dart & Flutter...", all projects are shown, but all with the root folder name instead of the project name._
- > In a monorepo, when you select the debug session and select "Dart & Flutter...", all projects are shown, but all with the root folder name instead of the project name.

---

### v3-94

**Performance Improvement** (4)

- * [#5155](https://github.com/Dart-Code/Dart-Code/issues/5155): Improvements have been made to extension shut down to reduce the chance of orphaned processes after closing VS Code.
- * [@FMorschel](https://github.com/FMorschel) contributed [#5203](https://github.com/Dart-Code/Dart-Code/issues/5203): Improved the descriptions on log settings that support substitutions like `~`.
- * [@FMorschel](https://github.com/FMorschel) contributed [#5188](https://github.com/Dart-Code/Dart-Code/issues/5188): Fixed typos and improved consistency of log settings descriptions.
- * [#5193](https://github.com/Dart-Code/Dart-Code/issues/5193): Many improvements have been made to breakpoints that should reduce the chance of seeing grey/unverified breakpoints until they are hit, or breakpoints that are displayed in the wrong location after hot restarts.

**Replacement / Migration** (3)

- > **#5164**: Stepping into Dart SDK sources in Flutter results in sources downloaded from the VM instead of used from disk `is bug` `in flutter` `in debugging`
  - _> Some integration tests are failing because when we step into SDK sources, we don't get back a path for the stack frames:_
- * [@rodrigogmdias](https://github.com/rodrigogmdias) contributed [#5175](https://github.com/Dart-Code/Dart-Code/issues/5175): A new command **Pub: Get Packages for All Projects** will fetch packages for all projects in the workspace instead of only the project for the active file.
- > With just the first issue fixed, we'll produce no edits instead of formatting the entire document. However, we should really produce an edit just for unwrapping the empty collection.

---

### v3-92

**New Feature / API** (1)

- > I was just able to repro this, and switching back to the Stable version seemed to fix it. My guess would be that it's related to https://github.com/Dart-Code/Dart-Code/commit/3855d1d94150745e4800b3f1eb9945a0e3726fe5 or https://github.com/Dart-Code/Dart-Code/commit/eea9929f7c90f2991c60b0415c5a3cae38e432fa (they do have some changes in the commands to support the new flags, the change was not isolated to the commands).

**New Parameter / Option** (1)

- > I was just able to repro this, and switching back to the Stable version seemed to fix it. My guess would be that it's related to https://github.com/Dart-Code/Dart-Code/commit/3855d1d94150745e4800b3f1eb9945a0e3726fe5 or https://github.com/Dart-Code/Dart-Code/commit/eea9929f7c90f2991c60b0415c5a3cae38e432fa (they do have some changes in the commands to support the new flags, the change was not isolated to the commands).

**Replacement / Migration** (5)

- > I prefer to not hardcode a default value here, and instead omit the `--web-renderer` argument by default. That way, we let the flutter tool decide what's the default. Is there a way to make the `dart.flutterWebRenderer` enum nullable?
- * [#5133](https://github.com/Dart-Code/Dart-Code/issues/5133): Several legacy settings have been moved to the **Legacy** section in the settings UI and had their descriptions updated to make it clear those settings may only work for older SDKs.
- * [#5142](https://github.com/Dart-Code/Dart-Code/issues/5142): The quick-fix for “Add missing switch cases” now adds all enum values instead of only the first.
- > The quick fix for `Add missing switch cases` only adds one case at a time, instead of all of the missing cases.
- > 5. Only one case is added, instead of all missing cases

---

### v3-90

**New Parameter / Option** (2)

- [#5029](https://github.com/Dart-Code/Dart-Code/issues/5029): A new setting **Dart: Close DevTools** (`dart.closeDevTools`) has been added to allow automatic closing of embedded DevTools windows like the Widget Inspector when a debug session ends. The `ifOpened` option will close only embedded windows that were opened automatically as a result of the **Dart: Open DevTools** (`dart.openDevTools`) setting.
- > I find it slightly annoying that I have to manually exit out of the embedded widget window when I'm done with a debug session to get back to the view I was in prior to starting the debug session.  I would like to propose a new settings flag that controls whether the debug window closes automatically upon debug session end or not.

**Replacement / Migration** (1)

- > **#5022**: Add "Fix All in Workspace" commands to apply fixes across the whole workspace instead of only current file `is enhancement` `in editor`
  - _> Seems we don't have an issue tracking this. We should support running "dart fix" for your workspace in the IDE, rather than telling users to run from the command line._

---

### v3-88

**Breaking Change** (1)

- * [#5105](https://github.com/Dart-Code/Dart-Code/issues/5105): The `dart.experimentalMacroSupport` setting has been removed and macro support is now controlled solely by SDK experiment flags.

**New Feature / API** (1)

- > The `dart.experimentalMacroSupport` setting was used to enable new APIs to get generated code from the server into VS Code. There's been enough testing that this flag is probably unnecessary now, however we should gate enabling these new APIs on a suitable version number where this API support is more stable/complete (perhaps 3.5.0-0, since 3.5 is what current bleeding-edge builds are).

**Performance Improvement** (2)

- * [#5018](https://github.com/Dart-Code/Dart-Code/issues/5018): Dart and Flutter processes are no longer spawned in shells where they are not required. This should reduce the chance of processing being orphaned when some processes aren’t shut down cleanly.
- > This may reduce the chances of leaving orphaned processes around.

**Replacement / Migration** (5)

- > **#5056**: Go to Augmentation CodeLen opens a new editor in the current group instead of jumping to an existing editor in another group `is bug` `in editor`
  - _> **Describe the bug**_
- > When using the "Run" code lens button, I'd like vscode to open the Test Results view. It sometimes opens the Debug Console and other times the only noticeable UI change is a badge number indicator showing on the Test Explorer icon. If I use the green button to the left in the "well" (I think that's what the area is called), then it does switch to the Test Results view.
- > removing the quotes (`"`) around the path added by the extension inside the path env variable fixes the issue. according to [this](https://serverfault.com/a/349216), paths inside the windows path env var shouldn't be quoted. they should instead use semicolons as delimiters. i can confirm that among all paths present on my machine (including ones with spaces), the dart/flutter's was the only quoted one
- > 1\) One of the intermediate folders was omitted (ex. instead of `test/impl/another/**` all tests are put into `test/another/**`). Which looks easy to fix unless you have 1000 tests that need to be updated + some test rely on the relative file paths which makes it a bit problematic. Although, I agree that it's mostly the consequences of my bad decisions and should not probably be covered by the extension feature.
- > For the sidebar, we can just reload the frame for now (since it will set itself back up automatically) and if we move to a new DTD API in future, we can add a theme change event to that.

---

### v3-86

**New Parameter / Option** (1)

- [#5031](https://github.com/Dart-Code/Dart-Code/issues/5031): A new setting `dart.hotReloadPatterns` allows setting custom globs for which modified files should trigger a Hot Reload:

**Performance Improvement** (2)

- > Changing such a file doesn't automatically trigger a hot reload so I have to manually press the yellow lightening button to verify whether my changes to those files look good. It would improve _quality of life_ if this could happen automatically.
- > 3. With a terminal open at your local Flutter installation, `git clean -dfx` to effectively clean out any cached files.

**Replacement / Migration** (1)

- * [#5048](https://github.com/Dart-Code/Dart-Code/issues/5048): Flutter Outline, CodeLens and some other features that rely on outline information from the Dart Analysis Server are now sent for newly-opened files instead of requiring a modification to the file to show up.

---

### v3-84

**Breaking Change** (1)

- * [#5001](https://github.com/Dart-Code/Dart-Code/issues/5001): Due to breaking changes in the code completion APIs, the `dart.useLegacyAnalyzerProtocol` setting is now ignored for Dart SDKs 3.3 and later. The LSP protocol will always be used for these newer SDKs.

**New Feature / API** (1)

- > Rather than migrating to the new APIs, we should disable using the legacy protocol on Dart 3.3 onwards. LSP has been stable and the default for a long time and we've not been updating the legacy client here to keep up with any new features.

**Performance Improvement** (2)

- * [#4954](https://github.com/Dart-Code/Dart-Code/issues/4954): Improvements have been made to the built-in flow for downloading Flutter. The built-in Git extension will now be included when trying to locate `git` for cloning and error messages have been improved.
- > **#4954**: Improve Flutter install flow when Git is not found `is enhancement` `in flutter`
  - _> When we don't detect an SDK, we prompt to install Flutter and try to locate Git._

**Replacement / Migration** (4)

- > - Make it clearer to the user that we failed to find Git (instead of silently going to the website)
- * [#4995](https://github.com/Dart-Code/Dart-Code/issues/4995): Automatic `toString()` invocations in the debugger (controlled by the `dart.evaluateToStringInDebugViews` setting) now evaluate up to 100 values per request instead of 11.
- > **#4995**: Debug `toString()` evaluates 11 values instead of 100 `is bug` `in debugging` `relies on sdk changes`
  - _> **Describe the bug**_
- * [#4877](https://github.com/Dart-Code/Dart-Code/issues/4877): The hover for `Enum.values` no longer incorrectly reports the type as `Enum` instead of `List<Enum>`.

---

### v3-82

**New Parameter / Option** (1)

- * [#4966](https://github.com/Dart-Code/Dart-Code/issues/4966): The `dart.previewSdkDaps` setting has been replaced by a new `dart.useLegacyDebugAdapters`. The new setting has the opposite meaning (`true` means to use the legacy adapters, whereas for the old setting that was `false`).

**Performance Improvement** (2)

- > **#4552**: Consider adding "Go to Super" to context menu for improved visibility `is enhancement` `in editor`
  - _> I have a class B and a super class A._
- * [#4899](https://github.com/Dart-Code/Dart-Code/issues/4899): The “Global evaluation not currently supported” message has been improved and no longer includes a verbose stack trace.

**Replacement / Migration** (2)

- > Having consistent highlighting that resembles a method instead of a keyword.
- * [#4952](https://github.com/Dart-Code/Dart-Code/issues/4952): [DevTools extensions](https://pub.dev/packages/devtools_extensions) and other DevTools pages that are not specifically known to Dart-Code can now be opened embedded instead of only in an external browser.

---

### v3-80

**Breaking Change** (1)

- > Since VS Code [has removed recommending extensions](https://github.com/microsoft/vscode/issues/188467) based on file extension we should consider showing a notification when a Flutter developer opens an ARB file offering to install the extension.

**New Feature / API** (1)

- > We need to only do this for SDKs newer than when the new API was added, and still use the old one for others.

**Performance Improvement** (1)

- > Here's a (zipped, to reduce the chance of anything messing with it) copy of the file from the video in the state that triggers it.

**Replacement / Migration** (1)

- * [#4885](https://github.com/Dart-Code/Dart-Code/issues/4885): For new versions of Flutter, launching an application will not overwrite any custom Pub root directories set via DevTools (by using the `addPubRootDirectories` service instead of `setPubRootDirectories`).

---

### v3-78

**New Parameter / Option** (1)

- To completely hide getters you can use the new setting `"dart.showGettersInDebugViews": false`.

**Performance Improvement** (3)

- [#2462](https://github.com/Dart-Code/Dart-Code/issues/2462): Also when using Flutter 3.16 / Dart 3.2, code completion has been improved to include more detailed signatures for all items instead of only the one currently selected.
- * [#4571](https://github.com/Dart-Code/Dart-Code/issues/4571): When using the new SDK debug adapters, formatting of Flutter errors in the Debug Console has been improved to have the same colouring and emphasizing of user stack frames in stack traces as the legacy debug adapters.
- > **#4186**: Improve colouring of clickable path links in dartdocs `is enhancement` `in editor` `in lsp/analysis server`
  - _> Split from https://github.com/Dart-Code/Dart-Code/issues/4181, raised by @gspencergoog. Clickable links would be nice if they were highlighted without having to hover/hold Ctrl._

**Replacement / Migration** (5)

- [#2462](https://github.com/Dart-Code/Dart-Code/issues/2462): Also when using Flutter 3.16 / Dart 3.2, code completion has been improved to include more detailed signatures for all items instead of only the one currently selected.
- > **#4234**: Allow getters to be executed lazily instead of up-front `is enhancement` `in debugging` `relies on sdk changes`
  - _> DAP now allows us to wrap expensive getters in an object and signal that it's to support lazy-fetching of expensive/potential-side-effect properties:_
- > And probably inferred single element pattern should be `(Type,)` instead of `(Type)`.
- * [#4827](https://github.com/Dart-Code/Dart-Code/issues/4827): The `dart.customDevTools` setting now uses `devtools_tool serve` instead of the legacy `build_e2e` script.
- > **#4827**: Update dart.customDevTools to support using "devtools_tool serve" instead of the old build_e2e script `is enhancement` `in devtools`
  - _> Currently the `dart.customDevTools` setting assumes we will run `dart ${dart.customDevTools.script}` to start DevTools, but the script has been replaced by `devtools_tool serve` in https://github.com/flutter/devtools/pull/6638_

---

### v3-76

**Performance Improvement** (1)

- >             SizedBox(), /// 👈 Use 'const' with the constructor to improve performance.

**Replacement / Migration** (1)

- * [#4818](https://github.com/Dart-Code/Dart-Code/issues/4818): Devices that are emulators will now show the emulator name (instead of device name) in the sidebar, matching what’s shown in other locations such as the device quick-pick.

---

### v3-74

**New Feature / API** (1)

- > The new widget should be parent of the `Text('a')`  branch and not of the entire switch expression

**Performance Improvement** (3)

- * [#4731](https://github.com/Dart-Code/Dart-Code/issues/4731): In remote workspaces (including web IDEs like Codespaces and IDX), the number of code completions included has been lowered to improve responsiveness. Typing additional characters will refresh the set of completions shown.
- > Similar to https://github.com/Dart-Code/Dart-Code/issues/4729, we should reduce `maxCompletionItems` to reduce payload sizes in remote workspaces. Ideally we'd reduce it for all sessions but it's not completely clear what the impact of ranking issues (such as https://github.com/Dart-Code/Dart-Code/issues/4618) would be, so trying it out in remote workspaces (a small portion of sessions) might help highlight any issues there.
- * [#4729](https://github.com/Dart-Code/Dart-Code/issues/4729): In remote workspaces, full documentation is no longer included for all items in code completion to improve responsiveness. This can be overridden using the `"dart.documentation"` setting.

**Replacement / Migration** (3)

- > **#4758**: "wrap with widget" wraps the entire switch expression instead of the current branch `is bug` `in editor` `in lsp/analysis server` `relies on sdk changes`
  - _> **Describe the bug**_
- > "wrap with widget" wraps the entire switch expression instead of the current branch
- > 7. the cursor now should've moved to the top of the file.

---

### v3-72

**Deprecation** (3)

- * [#4697](https://github.com/Dart-Code/Dart-Code/issues/4697): The **Dart: Open Observatory** command is now marked as deprecated and will be removed in a future update once removed from the SDK.
- > **#4697**: Visibly mark Observatory command(s) as deprecated `in commands`
  - _> The Observatory command shouldn't be removed yet because some users are still using this. After we have a version number for complete removal, we can remov eit (https://github.com/Dart-Code/Dart-Code/issues/4696). For now, we should show "Deprecated" in the name so it's clearer to users that they should be moving away from this._
- > The Observatory command shouldn't be removed yet because some users are still using this. After we have a version number for complete removal, we can remov eit (https://github.com/Dart-Code/Dart-Code/issues/4696). For now, we should show "Deprecated" in the name so it's clearer to users that they should be moving away from this.

**Breaking Change** (5)

- * [#4697](https://github.com/Dart-Code/Dart-Code/issues/4697): The **Dart: Open Observatory** command is now marked as deprecated and will be removed in a future update once removed from the SDK.
- > The Observatory command shouldn't be removed yet because some users are still using this. After we have a version number for complete removal, we can remov eit (https://github.com/Dart-Code/Dart-Code/issues/4696). For now, we should show "Deprecated" in the name so it's clearer to users that they should be moving away from this.
- * [#4701](https://github.com/Dart-Code/Dart-Code/issues/4701): Searching the Workspace Symbols list has been fixed when using the legacy analyzer protocol (`dart.useLegacyAnalyzerProtocol`). The legacy protocol is not recommended (and will eventually be removed) - if you feel you need to use it please [file an issue](https://github.com/Dart-Code/Dart-Code/issues) with the details.
- * [#4655](https://github.com/Dart-Code/Dart-Code/issues/4655): When using `editor.codeActionsOnSave` to run `source.fixAll`, unused parameters will no longer be removed. They will still be removed if you invoke the **Fix All** command explicitly.
- > `this.param` is removed automatically, because it is (as yet) unused.

**Performance Improvement** (1)

- > **#4702**: Improve the check for whether a project is Flutter to be more reliable `is enhancement` `in flutter`
  - _> This code does a basic regex to check for `sdk: flutter` in the pubspec.yaml to decide whether a project is a Flutter project or not:_

**Replacement / Migration** (5)

- [#4518](https://github.com/Dart-Code/Dart-Code/issues/4518): When using the latest Flutter release (v3.13), the Move to File refactoring is available without setting any experimental flags.
- > When you clone the Flutter SDK with the flow provided in VS Code, you don't get the option to switch to channels other than stable.
- > Recommendation: Users who install the SDK through the flow offered in VS Code should have the ability to switch to all the available channels (currently master, main, beta and stable).
- > Here, "Go to Test" on "(tearDownAll)" is navigating to line 33 of the left file, instead of the right one. The test I ran was on line 26 of the left file.
- > Flutter users should run `flutter pub get` instead of `dart pub get`.

---

### v3-70

**New Parameter / Option** (1)

- * [#4637](https://github.com/Dart-Code/Dart-Code/issues/4637): A new setting `dart.sdkSwitchingTarget` allows you to configure the SDK Picker to modify the selected SDK globally, instead of only for the current workspace.

**Performance Improvement** (3)

- * [#4106](https://github.com/Dart-Code/Dart-Code/issues/4106): The **Open Symbol in Workspace** search is now significantly faster for workspace with large numbers of projects.
- > Autocomplete is much faster for me when I use the old analyzer protocol:
- > With this change, imports will not be touched when using fix-all if it was invoked automatically by save. However, it's possible to retain the original behaviour by invoked listing the original fix, or (more efficiently) `source.organizeImports`) to run on-save:

**Replacement / Migration** (6)

- * [#4637](https://github.com/Dart-Code/Dart-Code/issues/4637): A new setting `dart.sdkSwitchingTarget` allows you to configure the SDK Picker to modify the selected SDK globally, instead of only for the current workspace.
- > **#4637**: Add a setting to allow the SDK switcher to write to global user settings instead of workspace settings `is enhancement` `in commands`
  - _> The current behaviour was convenient for me, but might not be what users prefer/expect._
- * [#4630](https://github.com/Dart-Code/Dart-Code/issues/4630): The “SDK configured in dart.[flutter]sdkPath is not a valid SDK folder” warning message now opens the specific settings file that configures the invalid path (instead of always User Settings).
- * [#4518](https://github.com/Dart-Code/Dart-Code/issues/4518)/[#4159](https://github.com/Dart-Code/Dart-Code/issues/4159)/[#1831](https://github.com/Dart-Code/Dart-Code/issues/1831): The new **Move to File** refactoring is no longer behind an experimental flag.
  - _* [#4573](https://github.com/Dart-Code/Dart-Code/issues/4573): Some stack traces printed to the Debug Console will no longer try to open files using incorrect relative paths when clicking on the filename on the right side._
- > I've recently switched from using IntelliJ to VSCode as my full time Flutter editor, and the main thing I've noticed is that the searches for symbols are incredibly slow, when they work at all.
- > 3. The main library has a file which imports 33 packages, including 8 from the Dart SDK. It has 49 `part` declarations for files within the repository. Most other files don't have imports, and instead use `part of` to inherit the global scope provided by the main file. Most of the other packages in this project do the same.

---

### v3-68

**Performance Improvement** (3)

- > [4:27:17 PM] [General] [Info] Returning cached results for project search
- * [#4553](https://github.com/Dart-Code/Dart-Code/issues/4553): The “Run All Tests” action handles excluded suites better and now produces shorter command lines (reducing the chance of “Command line too long” on Windows).
- * [#4420](https://github.com/Dart-Code/Dart-Code/issues/4420): The debug adapter now drops references to variables, scopes and stack frames when execution resumes to reduce memory usage over long debug sessions.

---

### v3-66

**New Parameter / Option** (1)

- * [#4556](https://github.com/Dart-Code/Dart-Code/issues/4556): A new setting `dart.analyzerAdditionalVmArgs` allows passing additional VM arguments when spawning the analysis server.

**Performance Improvement** (1)

- * [#4557](https://github.com/Dart-Code/Dart-Code/issues/4557): Multiple test suites are now run using relative instead of absolute paths. This reduces the chance of “Command line too long” errors on Windows when running a large selection of test suites (either explicitly, or because exclusions require each suite to be passed to `dart test`/`flutter test` individually). Further improvements to this will be made in a future release via [#4553](https://github.com/Dart-Code/Dart-Code/issues/4553).

**Replacement / Migration** (3)

- * [#4557](https://github.com/Dart-Code/Dart-Code/issues/4557): Multiple test suites are now run using relative instead of absolute paths. This reduces the chance of “Command line too long” errors on Windows when running a large selection of test suites (either explicitly, or because exclusions require each suite to be passed to `dart test`/`flutter test` individually). Further improvements to this will be made in a future release via [#4553](https://github.com/Dart-Code/Dart-Code/issues/4553).
- * [#4527](https://github.com/Dart-Code/Dart-Code/issues/4527): The default project names when using the **Dart: New Project** and **Flutter: New Project** commands have been updated to better reflect the kind of project. For example selecting the “package” template will provide a default name of `dart_package_1` instead of `dart_application_1`.
- > If I create a new Dart package project, the default project name is `dart_application_x` instead of `dart_package_x`. It should really be the latter.

---

### v3-64

**New Parameter / Option** (4)

- [#4021](https://github.com/Dart-Code/Dart-Code/issues/4021)/[#4487](https://github.com/Dart-Code/Dart-Code/issues/4487): A new setting `"dart.testInvocationMode"` has been added that allows you to choose how tests are executed from the test runner and CodeLens links.
- This could fail to run the correct test if groups/tests have dynamic names, unusual characters or similar/duplicated names. Selecting `"line"` in the new setting will instead (when supported by your version of `package:test`) run tests using their line number:
- [#1903](https://github.com/Dart-Code/Dart-Code/issues/1903): A new setting has been added that allows excluding SDK/package symbols from the Go to Symbol in Workspace (`cmd`+`T`) search which can considerably speed up the search for large workspaces.
- [#1831](https://github.com/Dart-Code/Dart-Code/issues/1831)[#4159](https://github.com/Dart-Code/Dart-Code/issues/4159)/[#4467](https://github.com/Dart-Code/Dart-Code/issues/4467): A new setting `"dart.experimentalRefactors"` has been added to allow gathering feedback of new refactors.

**Performance Improvement** (3)

- [#1903](https://github.com/Dart-Code/Dart-Code/issues/1903): A new setting has been added that allows excluding SDK/package symbols from the Go to Symbol in Workspace (`cmd`+`T`) search which can considerably speed up the search for large workspaces.
- > I want to be able to only list the symbols from files in my workspace, to speed up the search and greatly reduce the number of irrelevant results.
- > [10:46:10 AM] [General] [Info] Returning cached promise for getSupportedPlatforms()

**Replacement / Migration** (3)

- * [#4150](https://github.com/Dart-Code/Dart-Code/issues/4150): Tests with the same name except for an interpolated variable will all run together instead of only the selected test
- The first available refactor (for Dart 3.0 / Flutter 3.10) is “Move to File” that allows moving top level declarations to another (new or existing) file.
- * Imports added to the destination file may be to the declaration of moved references instead of the original imports being copied from the source file. This is a bug and a fix is in progress for a future release.

---

### v3-62

**Breaking Change** (2)

- * [#4417](https://github.com/Dart-Code/Dart-Code/issues/4417): Support for project templates from the legacy Stagehand Pub package has been removed. The **Dart: New Project** command is now only usable with SDKs that support `dart create`.
- * [#3936](https://github.com/Dart-Code/Dart-Code/issues/3936): Legacy colour previews shown in the gutter have been removed. These were already hidden once the server was providing inline color picker versions, but the temporary display of them was confusing so has been removed.

**Performance Improvement** (3)

- > [11:52:42] [General] [Info] Returning cached results for project search
- * [#4354](https://github.com/Dart-Code/Dart-Code/issues/4354): Refactor Code Actions now use the new “inline” and “move” groups where appropriate, improving the grouping/sorting from other code actions.
- > **#4273**: Improve messaging when trying to connect to an app in release mode `is enhancement` `in flutter` `relies on sdk changes`
  - _> When an app is running in release mode, and I run the "Open DevTools  in Web Browser" command, I get this warning:_

**Replacement / Migration** (3)

- > **#4377**: Switch to VS Code's telemetry classes `is enhancement`
  - _> https://code.visualstudio.com/updates/v1_75#_telemetry_
- * [#4447](https://github.com/Dart-Code/Dart-Code/issues/4447): Stopping a Dart CLI test session while at a breakpoint when using SDK DAPs now automatically resumes from the breakpoint instead of waiting.
- * [#4462](https://github.com/Dart-Code/Dart-Code/issues/4462): Code Actions are now available on all lines of a multiline diagnostic instead of only the first.

---

### v3-60

**New Parameter / Option** (1)

- * [#737](https://github.com/Dart-Code/Dart-Code/issues/737): A new setting `"dart.addSdkToTerminalPath"` enables automatically adding your current SDK to the `PATH` environment variable for built-in terminals. This works with quick SDK switching and ensures running `dart` or `flutter` from the terminal matches the version being used for analysis and debugging. To avoid losing terminal state, VS Code may require you to click an icon in existing terminal windows to restart them for this change to apply (this is not required for new terminals). This setting is opt-in today, but may become the default in a future release.

**Replacement / Migration** (1)

- * [#4400](https://github.com/Dart-Code/Dart-Code/issues/4400): Errors in the Variables panel no longer show “unknown” instead of the exception text when using the new SDK debug adapters.

---

### v3-58

**Breaking Change** (3)

- * [#4341](https://github.com/Dart-Code/Dart-Code/issues/4341): The test explorer no longer sometimes shows old test names that have been removed/renamed but were never run.
- > The test explorer of VSCode shows old test names that not longer exist. For example, in Dart, a test is created with the name Test 1. When this is renamed to Test 2, Test 1 and Test 2 appear in the Explorer text. Test 1 can of course no longer be executed correctly.
- > 2. Rename to Test 2

**New Feature / API** (1)

- > Equiv of https://dart-review.googlesource.com/c/sdk/+/279353. Although I'm not generally adding new features to the legacy DA, this is a trivial change and would help if people want to try out records prior to everyone being switched to the new DAs.

**New Parameter / Option** (2)

- > Flutter recently added an option to `flutter create` to create an empty project that doesn't have any comments, the code is just a hello world instead of the counter app, and there's no test directory.  The flag is `--empty`.
- * [#4119](https://github.com/Dart-Code/Dart-Code/issues/4119): A new setting `dart.documentation` controls how much dartdoc documentation is shown in hovers/code completions. Options are `"full"` (the default), `"summary"` (showing just the first paragraph) or `"none"` (no dartdocs are shown).

**Performance Improvement** (2)

- * [#2527](https://github.com/Dart-Code/Dart-Code/issues/2527)/[#4217](https://github.com/Dart-Code/Dart-Code/issues/4217)/[#3313](https://github.com/Dart-Code/Dart-Code/issues/3313): An improved Type Hierarchy is now available. It can be accessed from the editor context menu or using the **Types: Show Type Hierarchy** command in the command palette (`F1`).
- > **#4213**: Improve rendering of Uint8List (and friends) in the debugger `is enhancement` `in debugging` `relies on sdk changes`
  - _> ```dart_

**Replacement / Migration** (4)

- * [#4268](https://github.com/Dart-Code/Dart-Code/issues/4268): The **Flutter: New Project** command now has an additional template type “Application (empty)” which creates a basic Hello World app instead of the counter app.
- > Flutter recently added an option to `flutter create` to create an empty project that doesn't have any comments, the code is just a hello world instead of the counter app, and there's no test directory.  The flag is `--empty`.
- > It would be nice to add the option to the VSCode extension to allow people to create an empty project instead of one that has the counter app in it.  I'm not sure how that should manifest, it could either be an option setting that modifies the "Flutter: New Project" command, or an additional "Flutter: New Empty Project" command, I'm not sure which is more appropriate (maybe the latter?).
- > Equiv of https://dart-review.googlesource.com/c/sdk/+/279353. Although I'm not generally adding new features to the legacy DA, this is a trivial change and would help if people want to try out records prior to everyone being switched to the new DAs.

---

### v3-56

**Replacement / Migration** (2)

- > I prefer to avoid `var` whenever possible. When I use the `extract local variable` feature, it only extracts it as var:
- > I am using VSCode to debug my flutter app. This may have been doing it for a long time. I'm new to debugging. but I noticed as im steeping through the code every variable has a property called _identityHashCode and instead of a value if I hover over it it says this.

---

### v3-54

**Breaking Change** (1)

- > Even though it'd be asymmetric with adding a comment, I think it'd be nice if uncommenting removed either `//` *or* `///`.  This would be particularly useful if I'm writing a Dartdoc comment, press Enter, which automatically adds `///` to the next line, but don't actually want the next line to be a Dartdoc comment.

**New Parameter / Option** (3)

- > Splitting from #4271. Initially a new setting, added to the existing Flutter Create settings editor.
- * [#4119](https://github.com/Dart-Code/Dart-Code/issues/4119): A new setting `dart.documentation` allows selecting what level of documentation (`none`, `summary`, `full`) should appear in hovers and code completion. The default is `full` to match previous behaviour.
- > Flutter recently added an option to `flutter create` to create an empty project that doesn't have any comments, the code is just a hello world instead of the counter app, and there's no test directory.  The flag is `--empty`.

**Performance Improvement** (4)

- >   "editor.largeFileOptimizations": false,
- * [#4253](https://github.com/Dart-Code/Dart-Code/issues/4253): An issue that prevented Pub package names (used by the **Dart: Add Dependency** command) from being cached locally has been resolved.
- > **#4253**: Pub package name cache is not persisted `is bug` `in editor` `is performance`
  - _> The caching of the Pub package name cache is not working because of this code here:_
- > The caching of the Pub package name cache is not working because of this code here:

**Replacement / Migration** (4)

- * [#4290](https://github.com/Dart-Code/Dart-Code/issues/4290): Running the **Pub: Upgrade Packages** command will no longer sometimes run `pub get` instead of `pub upgrade`.
- > Flutter recently added an option to `flutter create` to create an empty project that doesn't have any comments, the code is just a hello world instead of the counter app, and there's no test directory.  The flag is `--empty`.
- > It would be nice to add the option to the VSCode extension to allow people to create an empty project instead of one that has the counter app in it.  I'm not sure how that should manifest, it could either be an option setting that modifies the "Flutter: New Project" command, or an additional "Flutter: New Empty Project" command, I'm not sure which is more appropriate (maybe the latter?).
- > The same issue would occur if the non-imported type is an argument of the method instead of a return type.

---

### v3-52

**Performance Improvement** (2)

- > **#4221**: Vscode refactoring: Convert Getter to Method applied to "widget", applies also to all flutter SDK & pub cache files `is bug` `in editor` `in lsp/analysis server` `relies on sdk changes`
  - _> Quite big warning, since doing this has opened hundreds of files from SDK/pub cache, in my Vscode, and (I don't which mistake I made) saved and corrupted all of them_
- > **#4213**: Improve rendering of Uint8List (and friends) in the debugger `is enhancement` `in debugging` `relies on sdk changes`
  - _> ```dart_

**Replacement / Migration** (2)

- > **#4209**: Use line/col information from source locations instead of mapping tokenPosTables `is enhancement` `in debugging`
  - _> While investigating #4208 I noticed that the responses from the VM have line/col information and we don't need to look it up from tokenPosTable (as of https://github.com/dart-lang/sdk/commit/2db8f37cfa22d5120d56c82eeddd3f3008f72ec3). Assuming the data is there, this may save us fetching a lot of scripts._
- > Also, I can't find a way to run (using VS Code's `launch.json`) normal widget tests with `flutter run test/widget_test.dart` (=running on device) instead of `flutter test test/widget_test.dart` (running in isolation). This might be another issue, though.

---

