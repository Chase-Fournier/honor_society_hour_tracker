# Plan 009: Make the app's UI coherent — align every screen to the Attendance-page design language

> **Executor instructions**: Follow this plan step by step. It is large; do it in
> the **batches** defined under "Steps" and run the verification after each batch.
> If anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done (or when you finish a batch and pause), update the status row in
> `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens lib/common`
> Written against the working tree at `a3682db` plus uncommitted changes (including
> the custom-nav-bar work). Re-locate any excerpt with `grep` before editing; on a
> structural mismatch for a given site, skip that site and note it — don't guess.

## Status

- **Priority**: P2
- **Effort**: L (multi-day; designed to be done in independent batches)
- **Risk**: MED (pure visual changes, but spread across ~17 files; easy to miss a theme)
- **Depends on**: none. Independent of Plans 001–008. If Plan 008 (god-file split)
  runs, coordinate on `homescreenpage.dart` — do whichever first, then re-check the other.
- **Category**: tech-debt (UI consistency)
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

The app has accreted several visual dialects: filter chips are built three
different ways, content cards range from flat-bordered to elevation-8 raised,
app-bar backgrounds vary per screen, and ~74 hardcoded `Colors.*` literals break
the 19-theme system. The result reads as several apps stitched together. The
**Attendance page** (`lib/screens/adminattendencepage.dart`) is the agreed target
look — flat cards with a hairline border and soft shadow, Material `FilterChip`
filters, a `bannerTheme` app bar, and all color from the `ColorScheme`. This plan
codifies that page's language as the reference and brings every other screen into
line. The payoff is a coherent product and a single card/chip pattern to maintain.

## The reference design system (codified from the Attendance page)

Use these exact recipes. They are extracted from `adminattendencepage.dart` and
the design tokens in `lib/common/app_design.dart`. **All colors come from
`Theme.of(context).colorScheme`; all radii/spacing from `AppDesign`.**

### R1 — AppBar
```dart
appBar: AppBar(
  elevation: 0,
  backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
  title: Text(
    '<Screen Title>',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 24.0,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  ),
  centerTitle: true,
),
```

### R2 — Filter chip (one per filter option)
```dart
FilterChip(
  label: Text(label),
  selected: isSelected,
  onSelected: (_) { /* haptics.selection(); setState(...) */ },
  backgroundColor:
      Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
  selectedColor: Theme.of(context).colorScheme.primaryContainer,
  checkmarkColor: Theme.of(context).colorScheme.primary,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
),
```
(The Attendance page currently writes `surfaceVariant.withOpacity(0.5)`; both
`surfaceVariant` and `withOpacity` are deprecated. Use
`surfaceContainerHighest.withValues(alpha: 0.5)` everywhere for the new standard —
see batch F.)

### R3 — Content card (an item: event, member, summary)
```dart
Container(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: AppDesign.borderLarge,
    border: Border.all(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  clipBehavior: Clip.antiAlias,
  child: /* content; if expandable, Theme(dividerColor: transparent) -> ExpansionTile */,
)
```

### R4 — Grouping/collection card (a container of items)
```dart
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: AppDesign.borderLarge,
    side: BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
      width: 1,
    ),
  ),
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
  child: /* Theme(dividerColor: transparent) -> ExpansionTile */,
)
```

### R5 — Item leading icon
```dart
CircleAvatar(
  radius: 20,
  backgroundColor: typeColor.withValues(alpha: 0.15),
  child: Icon(getIconForType(type, context), color: typeColor, size: 18),
)
```

### R6 — Empty state
Centered column: `Icon(Icons.event_busy, size: 64)` (muted), a `headlineSmall`
title, and (when a filter is active) a `TextButton.icon` "Clear filter".

### R7 — Elevation rule
Content/grouping cards are **`elevation: 0`** and use border + the R3 shadow for
depth. Do **not** use raised `Card(elevation: 1..8)` for content. (Exceptions that
stay raised: drag-feedback cards, `BottomAppBar`, dialogs — see Out of scope.)

### R8 — No hardcoded colors
Never use `Colors.red/green/amber/blue/grey/...`. Map to roles:
`Colors.red`→`colorScheme.error`; success/green→`colorScheme.tertiary` (or a
`Colors.green` kept only if a literal "approved green" is intentional — see batch E
note); muted grey→`colorScheme.onSurfaceVariant`; surfaces→`colorScheme.surface*`.

## Current state — inventory of inconsistencies (evidence)

- **Chips built 3 ways.** Reference + `admineventspage.dart:85` + `adminlistspage.dart:799`
  use `FilterChip`. `homescreenpage.dart:342` (`_buildAnimatedFilterChip`, used via
  `_buildEventTypeChips` at :289) is a bespoke `GestureDetector`+`AnimatedContainer`
  pill that turns into a rounded rectangle on select, with `surfaceVariant.withOpacity(0.7)`.
- **Raised cards vs flat.** `settingspage.dart:408,537,620` (elevation 1/1/2),
  `societyadmindashboard.dart:788,821` (elevation 2), `societyselectionpage.dart:150,350,431`
  (3/2/2), `loginpage.dart:121,259`. Reference is elevation 0 + border (R3/R7).
- **AppBar background drift.** Reference uses `bannerTheme.backgroundColor`
  (`adminattendencepage.dart:137`). Deviations: `completedhourspage.dart:198`
  (`colorScheme.surface`), `leaderboardpage.dart:109` (`primaryContainer`),
  `leadershippage.dart:342` (`surface`), `adminleadershippage.dart:370` (`surface`),
  `accountsettingspage.dart:276` (no `bannerTheme` bg).
- **~74 hardcoded `Colors.*`** across 17 screen files (incl. a few in the reference
  page itself), breaking themes. Files listed in batch E.
- **Shared widgets underused.** `AppCard`/`AppSurfaceCard` exist in
  `lib/common/app_widgets.dart` but ~half the screens hand-roll Containers, and the
  reference card recipe (R3) isn't one of them — so there's no single source of truth.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze (gate, per file) | `flutter analyze lib/screens/<file>.dart` | No new errors/warnings |
| Analyze (whole) | `flutter analyze` | No new errors; deprecation infos trend **down** |
| Find chip builders | `grep -rn "_buildAnimatedFilterChip\|FilterChip(" lib/screens` | — |
| Find raised cards | `grep -rn "elevation: [1-9]" lib/screens` | shrinks as you go |
| Find hardcoded colors | `grep -rn "Colors\.\(red\|green\|amber\|blue\|orange\|grey\|purple\|teal\|pink\|yellow\)" lib/screens` | shrinks as you go |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` (quote the space) | — |

> **Verification reality**: no test suite (`test/widget_test.dart` is empty), no CI.
> `flutter analyze` is the only automated gate; everything visual must be eyeballed
> (Test plan). Because these are appearance changes, take before/after screenshots
> per screen if you can run the app.

## Scope

**In scope** — visual alignment of these screens to R1–R8:
- `homescreenpage.dart`, `completedhourspage.dart`, `admineventspage.dart`,
  `adminlistspage.dart`, `societyadmindashboard.dart`, `settingspage.dart`,
  `accountsettingspage.dart`, `appearancepage.dart`, `notificationsettingspage.dart`,
  `leaderboardpage.dart`, `leadershippage.dart`, `adminleadershippage.dart`,
  `hourrequirmentpage.dart`, `continuouseventdetailpage.dart`,
  `continuouseventsubmissionspage.dart`, `activitylogpage.dart`.
- `lib/common/app_widgets.dart` (add the canonical card widget — batch A).

**Out of scope** (do NOT change appearance of):
- `adminattendencepage.dart` — it's the reference. (Only touch it in batch F to
  swap its own deprecated `surfaceVariant`/`withOpacity` for the R2/R3 forms.)
- `snake.dart` (self-contained game), `loginpage.dart` /
  `societyselectionpage.dart` (pre-login; lower priority — defer unless time).
- Drag-feedback `Card(elevation: 4)` in `admineventspage.dart:405`, the
  `BottomAppBar(elevation: 8)` in `customeventformpage.dart:531`, dialog elevations,
  and any `Colors.transparent/white/black` — these are intentional.
- Behavior/logic of any screen. **This plan changes only styling.**

## Git workflow

- Branch: `advisor/009-ui-consistency`
- **One commit per batch** (A–F), so review is tractable; subjects e.g.
  `UI: standardize filter chips`, `UI: flatten content cards`, etc.
- Do NOT push or open a PR unless instructed.

## Steps

> Do the batches in order. A first (it creates the shared widget the later batches
> can use). Each batch ends with `flutter analyze` on the files it touched.

### Batch A — Add a canonical card widget (single source of truth)

In `lib/common/app_widgets.dart`, add a widget that bakes in recipe R3 so screens
stop hand-rolling it:

```dart
/// Canonical content card — the Attendance-page look (flat, hairline border,
/// soft shadow). Use for list items (events, members, summaries).
class AppContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final Clip clipBehavior;
  const AppContentCard({
    Key? key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.clipBehavior = Clip.antiAlias,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

**Verify**: `flutter analyze lib/common/app_widgets.dart` → no errors.

### Batch B — Standardize filter chips on `FilterChip` (R2)

- In `homescreenpage.dart`, replace `_buildAnimatedFilterChip` (and its use in
  `_buildEventTypeChips`, plus the "Signed Up" chip added inline) with `FilterChip`
  per R2. Keep the haptic `selection()` call and the existing `onSelected`
  `setState` logic. Delete `_buildAnimatedFilterChip` once unused.
- In `admineventspage.dart:85` and `adminlistspage.dart:799`, update the
  `FilterChip` `backgroundColor` to `surfaceContainerHighest.withValues(alpha: 0.5)`
  (they currently use deprecated `surfaceVariant.withOpacity(0.5)`).

**Verify**:
- `grep -n "_buildAnimatedFilterChip" lib/screens/homescreenpage.dart` → no matches.
- `flutter analyze lib/screens/homescreenpage.dart lib/screens/admineventspage.dart lib/screens/adminlistspage.dart` → no new errors.

### Batch C — Flatten raised content cards to R3/R4/R7

For each raised content `Card`, set `elevation: 0` and add the R4 border (for
grouping cards) or convert list items to `AppContentCard`/R3. Sites:
`settingspage.dart:408,537,620`; `societyadmindashboard.dart:788,821`.
(Pre-login `societyselectionpage.dart` / `loginpage.dart` are deferred — see Out of
scope; only do them if time permits and the look clearly clashes.)

Do **not** flatten the out-of-scope intentional elevations listed above.

**Verify**: `grep -rn "elevation: [1-9]" lib/screens/settingspage.dart lib/screens/societyadmindashboard.dart` → only intentional exceptions remain (ideally none).

### Batch D — Normalize AppBars to R1

Change the app-bar `backgroundColor` (and title style if it deviates) to R1 in:
`completedhourspage.dart:198`, `leadershippage.dart:342`,
`adminleadershippage.dart:370`, `accountsettingspage.dart:276`, and
`leaderboardpage.dart:109`.

> `leaderboardpage` deliberately uses a `primaryContainer` bar today. If you judge
> that's an intentional accent (it's a celebratory screen), leave it and note the
> decision — otherwise align it. This is the one app bar where "align" is a
> judgment call; everything else should become `bannerTheme.backgroundColor`.

**Verify**: `grep -n "backgroundColor: Theme.of(context).colorScheme.surface" lib/screens/completedhourspage.dart lib/screens/leadershippage.dart lib/screens/adminleadershippage.dart` → no matches in the AppBar.

### Batch E — Replace hardcoded `Colors.*` with `ColorScheme` roles (R8)

Work file-by-file through:
`settingspage, appearancepage, societyjoinrequestpage, continuouseventsubmissionspage,
waitingpage, leaderboardpage, societyadmindashboard, continuouseventdetailpage,
admineventspage, homescreenpage, adminlistspage, activitylogpage, hourrequirmentpage,
JoinRequestsAdmin, customeventformpage, adminattendencepage`.

Mapping: `Colors.red`→`colorScheme.error`; muted `Colors.grey[...]`→
`colorScheme.onSurfaceVariant` (or `outlineVariant` for hairlines);
`Colors.amber`/status accents→`colorScheme.tertiary`. **Status semantics
exception**: a deliberate approved=green / rejected=red status pill may keep an
explicit green if the design intends a fixed traffic-light meaning — if so, leave
`Colors.green` for "approved" and `colorScheme.error` for "rejected", and note it.
Don't invent new accent colors.

Leave `Colors.transparent`, `Colors.white`, `Colors.black` (and `.withValues`
on them) as-is.

**Verify (progress)**: `grep -rn "Colors\.\(red\|amber\|blue\|orange\|grey\|purple\|teal\|pink\|yellow\)" lib/screens | wc -l` trends to ~0 (a small number of intentional status greens may remain, documented in the commit message).

### Batch F — De-deprecate the reference page's own tokens

In `adminattendencepage.dart` only, swap `surfaceVariant`→`surfaceContainerHighest`
and `withOpacity(x)`→`withValues(alpha: x)` so the reference matches R2/R3 exactly
and stops emitting deprecation infos. No layout/behavior change.

**Verify**: `flutter analyze lib/screens/adminattendencepage.dart` → fewer
`deprecated_member_use` infos than before; no new errors.

### Final: whole-project analyze

**Verify**: `flutter analyze` → no new errors/warnings vs. baseline; the total
`deprecated_member_use` and (from Plan 004, if landed) `avoid_print` counts are
lower, not higher.

## Test plan

No automated harness. This is visual; verify by running the app
(`flutter run`) and walking every in-scope screen in **light, dark, and at least
two named themes** (e.g. sunset, forest — they use hard-coded `ColorScheme`s, so
they're where hardcoded `Colors.*` regressions show):

- Filter chips look identical on Home, Events, Attendance, Members.
- Content cards have the same flat border + soft shadow everywhere; no raised cards
  remain (outside the documented exceptions).
- App bars share the same background on every in-scope screen.
- No element is invisible/low-contrast in any theme (the hardcoded-color tell).

## Done criteria

ALL must hold:

- [ ] `AppContentCard` exists in `lib/common/app_widgets.dart`
- [ ] `grep -n "_buildAnimatedFilterChip" lib/screens/homescreenpage.dart` → no matches; Home filters are `FilterChip`
- [ ] `grep -rn "elevation: [1-9]" lib/screens` → only documented exceptions remain
- [ ] In-scope app bars all use `bannerTheme.backgroundColor` (except a documented leaderboard accent, if kept)
- [ ] `grep -rn "Colors\.\(red\|amber\|blue\|orange\|grey\|purple\|teal\|pink\|yellow\)" lib/screens | wc -l` reduced to ~0 (remaining ones documented as intentional status colors)
- [ ] `flutter analyze` shows no new errors/warnings; deprecation count not higher
- [ ] App visually walked in light + dark + 2 named themes with no contrast regressions
- [ ] `plans/README.md` status row updated (mark partial if you stopped mid-batch)

## STOP conditions

Stop and report if:

- A "visual" change requires touching logic to compile (e.g. a color was feeding a
  conditional) — flag it rather than refactoring behavior here.
- Converting a card to `AppContentCard` changes layout because the original relied
  on `Card`'s implicit `InkWell`/margins — note it and keep that one as a
  hand-rolled R3 `Container` instead.
- You can't determine a sensible `ColorScheme` role for a hardcoded color (it
  encodes real status meaning) — leave it, list it, and ask.
- `flutter analyze` reports a new error a one-line fix can't resolve.

## Maintenance notes

- After this lands, the rule for reviewers: **new screens use `AppContentCard` (R3)
  / R4 grouping cards, `FilterChip` (R2), R1 app bars, and zero `Colors.*`
  literals.** Consider adding these as a short "UI conventions" section to
  `CLAUDE.md` so the conventions are enforced going forward.
- This plan deliberately leaves pre-login screens (`loginpage`,
  `societyselectionpage`) for a follow-up; they're lower-traffic and partly use
  `AppCard` already.
- If Plan 008 extracts widgets from `homescreenpage.dart`, the extracted widgets
  should already use R2/R3 — do 009's Home batches first, or re-check after.
- The reference page (`adminattendencepage.dart`) is the source of truth; if its
  look changes later, update R1–R8 here to match.
