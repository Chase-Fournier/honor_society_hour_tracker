# Plan 010: Unify the Account Settings (profile) page cards to the R4 grouping-card design + standard width

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat ffab6c4..HEAD -- lib/screens/accountsettingspage.dart lib/common/app_widgets.dart`
> Written against the working tree at `ffab6c4`. If the excerpts/line numbers
> below don't match, re-locate them with the greps in the steps before editing;
> on a structural mismatch for a given site, STOP.

## Status

- **Priority**: P2
- **Effort**: S–M
- **Risk**: LOW–MED (visual + one layout-inset change on a single screen)
- **Depends on**: Plan 009 (UI consistency) — landed. This is a follow-up that brings
  the one screen 009 didn't fully cover (its card bodies) into line.
- **Category**: tech-debt (UI consistency)
- **Planned at**: commit `ffab6c4`, 2026-06-13

## Why this matters

The **Account Settings page** (`lib/screens/accountsettingspage.dart`) — the app's
"profile" screen — is internally inconsistent and narrower than the rest of the app:

- **Two different card widgets on one page.** `_buildProfileSection()` and
  `_buildEmailSection()` use the shared `AppSurfaceCard`, but `_buildPasswordSection()`
  is a **hand-rolled `Card`** with a different corner radius and the deprecated
  `surfaceVariant.withOpacity(0.3)`. So the Password card doesn't match the other two.
- **None of them carry the R4 grouping-card border** the rest of the app adopted in
  Plan 009, so the page reads as a different visual dialect.
- **The cards are too narrow.** They live in a `SingleChildScrollView` with
  `horizontal: 24` padding **and** each `Card` adds its own default ~4px margin, so on
  mobile they sit ~28px from each edge while the rest of the app's cards use a 16px
  inset. They render visibly narrower than cards on every other screen.

This plan unifies all three sections onto a single canonical **R4 grouping card**
(flat, hairline `outlineVariant` border, soft `secondaryContainer` tint — the
Attendance-page look), de-deprecates the tokens, and widens the cards to the standard
16px mobile inset.

## The reference design — R4 grouping card (from Plan 009 / `adminattendencepage.dart:807-815`)

```dart
Card(
  elevation: 0,
  margin: <caller-controlled>,
  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
  shape: RoundedRectangleBorder(
    borderRadius: AppDesign.borderLarge,            // circular(16)
    side: BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
      width: 1,
    ),
  ),
  child: <padded content>,
)
```

All colors come from `Theme.of(context).colorScheme`; radii from `AppDesign`. The chosen
look for this page is **R4** (confirmed with the requester).

## Current state — exact excerpts

All in `lib/screens/accountsettingspage.dart` unless noted.

- **Scroll-view padding** (the source of the extra horizontal inset), ~lines 301-306:
```dart
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal:
                    isWideScreen ? AppDesign.spacingL : AppDesign.spacingL,
                vertical: AppDesign.spacingL,
              ),
```
(`spacingL` = 24, `spacingM` = 16.)

- **Mobile layout** (the `else` branch) with stray no-op spacers, ~lines 359-370:
```dart
                  else
                    // Mobile layout (full width, sequential)
                    Column(
                      children: [
                        const SizedBox(width: AppDesign.spacingL),
                        _buildProfileSection(),
                        const SizedBox(width: AppDesign.spacingL),
                        _buildEmailSection(),
                        const SizedBox(height: AppDesign.spacingL),
                        _buildPasswordSection(),
                      ],
                    ),
```
(The two `SizedBox(width: ...)` do nothing inside a `Column`; the `SizedBox(height: ...)`
makes the email↔password gap larger than the profile↔email gap.)

- **`_buildProfileSection()`** ~line 386: `return AppSurfaceCard(\n  child: Form(...`
- **`_buildEmailSection()`** ~line 495: `return AppSurfaceCard(\n  child: Column(...`
- **`_buildPasswordSection()`** ~lines 619-627 (the hand-rolled card):
```dart
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... password form content ...
```

- **`AppSurfaceCard`** lives in `lib/common/app_widgets.dart:52`. It is **also used by
  `societyadminpage.dart` (3×) and `continuouseventdetailpage.dart` (1×)** — do NOT
  modify or delete it; it stays as-is for those callers.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze (gate) | `flutter analyze lib/screens/accountsettingspage.dart lib/common/app_widgets.dart` | No new errors/warnings |
| Confirm no raw Card left on page | `grep -n "return Card(\|AppSurfaceCard(" lib/screens/accountsettingspage.dart` | none after Steps 2-3 |
| Confirm new widget wired | `grep -n "AppGroupingCard" lib/screens/accountsettingspage.dart` | 3 usages |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` (quote the space) | — |

> **Verification reality**: no test suite. Gate is `flutter analyze`. The visual result
> (cards match each other + the app, full width) is verified manually — see Test plan.

## Scope

**In scope**:
- `lib/common/app_widgets.dart` — ADD a new `AppGroupingCard` widget (Step 1).
- `lib/screens/accountsettingspage.dart` — swap the three section cards to
  `AppGroupingCard` and fix the mobile inset (Steps 2-5).

**Out of scope** (do NOT touch):
- `AppSurfaceCard` itself — other screens use it. Leave it unchanged.
- `societyadminpage.dart`, `continuouseventdetailpage.dart` — other `AppSurfaceCard`
  callers; not part of this change.
- The wide-screen (`isWideScreen`) and medium-screen (`isMediumScreen`) layout
  *structure* — only the shared scroll-view horizontal padding changes (Step 4); leave
  the `Row`/fixed-width `Container` branches otherwise as-is.
- Any form logic, validators, controllers, or save handlers. **This plan changes only
  the card widgets and spacing.**

## Git workflow

- Branch: `advisor/010-profile-card-consistency`
- One commit, subject e.g. `UI: unify Account Settings cards to R4 grouping card`.
- Stage only the two files by name (`git add lib/common/app_widgets.dart lib/screens/accountsettingspage.dart`) — do NOT `git add -A` (avoids dragging in `.claude/worktrees/*` gitlinks).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1 — Add the canonical `AppGroupingCard` (R4) to `app_widgets.dart`

Add this class next to `AppContentCard` (which already exists from Plan 009) in
`lib/common/app_widgets.dart`:

```dart
/// Grouping/section card — the Attendance-page R4 look (flat, hairline border,
/// soft secondary tint). Use for sections that group content/forms. Single
/// source of truth so screens stop hand-rolling it.
class AppGroupingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  const AppGroupingCard({
    Key? key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.padding = AppDesign.paddingLarge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: margin,
      color: scheme.secondaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
```

**Verify**: `flutter analyze lib/common/app_widgets.dart` → no errors (it may report
"unused" until Steps 2-3 wire it; no *errors*).

### Step 2 — Convert Profile and Email sections to `AppGroupingCard`

In `_buildProfileSection()` (~386) and `_buildEmailSection()` (~495), change only the
wrapper widget — keep the entire `child:` subtree unchanged. Pass a vertical-only margin
(the scroll view supplies the horizontal inset after Step 4):

- `return AppSurfaceCard(` → `return AppGroupingCard(\n      margin: const EdgeInsets.symmetric(vertical: 8),`

So each becomes:
```dart
    return AppGroupingCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: /* unchanged */,
    );
```

### Step 3 — Convert the Password section to `AppGroupingCard`

In `_buildPasswordSection()` (~619), replace the hand-rolled `Card(...) → Padding(all(24))`
wrapper with `AppGroupingCard` (whose default padding is already `paddingLarge` = 24).
Keep the inner `Column(...)` content verbatim:

```dart
    return AppGroupingCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... existing password form content, unchanged ...
        ],
      ),
    );
```

Remove the now-gone `Card(... color: surfaceVariant.withOpacity(0.3) ...)` and its
inner `Padding(padding: const EdgeInsets.all(24), ...)` — `AppGroupingCard` provides
both the surface styling and the 24px padding.

**Verify**:
- `grep -n "AppSurfaceCard(\|return Card(" lib/screens/accountsettingspage.dart` → no matches.
- `grep -n "AppGroupingCard" lib/screens/accountsettingspage.dart` → 3 matches.
- `grep -n "surfaceVariant.withOpacity" lib/screens/accountsettingspage.dart` → no matches.

### Step 4 — Widen the mobile cards to the 16px standard inset

In the `SingleChildScrollView` padding (~301-306), change the horizontal value so mobile
(and medium) use 16 while wide stays 24:

```dart
              padding: EdgeInsets.symmetric(
                horizontal:
                    isWideScreen ? AppDesign.spacingL : AppDesign.spacingM,
                vertical: AppDesign.spacingL,
              ),
```

(Only the second branch changes: `AppDesign.spacingL` → `AppDesign.spacingM`. Net mobile
inset becomes 16, matching the rest of the app, since the cards now carry no horizontal
margin.)

### Step 5 — Even out the mobile section spacing

In the mobile `else` `Column` (~359-370), delete the three stray spacers (two no-op
`SizedBox(width: ...)` and the one `SizedBox(height: ...)`), so the cards' own
`vertical: 8` margins produce uniform gaps:

```dart
                  else
                    // Mobile layout (full width, sequential)
                    Column(
                      children: [
                        _buildProfileSection(),
                        _buildEmailSection(),
                        _buildPasswordSection(),
                      ],
                    ),
```

(Leave the medium/wide branches as they are.)

### Step 6 — Analyze

**Verify**: `flutter analyze lib/screens/accountsettingspage.dart lib/common/app_widgets.dart`
→ no new errors/warnings; no "unused element `AppGroupingCard`".

## Test plan

No automated harness. Run the app (`flutter run`) and open Account Settings (Settings →
Account Settings) in **light, dark, and 2 named themes** (e.g. sunset, forest):

- All three cards (Profile, Email, Password) look **identical** in style — same flat
  fill, same hairline border, same corner radius.
- The cards are the **same width as cards on other screens** (Home/Attendance) — ~16px
  from each edge on a phone, not visibly inset/narrow.
- Vertical gaps between the three cards are uniform.
- No element is low-contrast in any theme.

## Done criteria

ALL must hold:

- [ ] `AppGroupingCard` exists in `lib/common/app_widgets.dart`
- [ ] `grep -n "AppGroupingCard" lib/screens/accountsettingspage.dart` → 3 matches
- [ ] `grep -n "AppSurfaceCard(\|return Card(" lib/screens/accountsettingspage.dart` → no matches
- [ ] `grep -n "surfaceVariant.withOpacity" lib/screens/accountsettingspage.dart` → no matches
- [ ] Mobile scroll-view horizontal padding is `spacingM` (16), not `spacingL` (24)
- [ ] `AppSurfaceCard` in `app_widgets.dart` is unchanged; `societyadminpage.dart` / `continuouseventdetailpage.dart` untouched
- [ ] `flutter analyze` (the two files) → no new errors/warnings
- [ ] `git status` shows only the two in-scope files modified
- [ ] App visually walked: three cards match + standard width (operator step)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- A section's `child:` subtree won't compile under `AppGroupingCard` without changing
  layout/logic (e.g. it relied on `Card`'s implicit `InkWell`) — note it and keep that
  one section as a hand-rolled R4 `Container` instead of guessing.
- `AppSurfaceCard` turns out to take parameters here (padding/onTap) that change the
  look when swapped — match them via `AppGroupingCard`'s `padding`/`margin` and note it.
- `flutter analyze` reports a new error a one-line fix can't resolve.
- The medium/wide branches break visually because of the scroll-padding change — if so,
  revert Step 4 to per-branch values (`isWideScreen ? spacingL : spacingM`, and leave
  medium at `spacingL`) and report.

## Maintenance notes

- `AppGroupingCard` is now the canonical R4 widget (parallel to `AppContentCard` = R3).
  New grouped/section content should use it instead of hand-rolling a `Card`, and other
  screens still on `AppSurfaceCard` can migrate to it opportunistically in a later slice.
- A reviewer should confirm zero behavior change to the forms (same controllers,
  validators, save handlers) — this is a pure widget-wrapper + spacing change.
- If the Attendance reference page's R4 recipe changes later, update `AppGroupingCard`
  to match.
