# UI work plan

Everything still open on the interface, in the order it will be done, with how
each item is verified. Written at the start of an automated session; ticked as
each lands.

The rule for every item: it is not done because the code changed. It is done
when it has been built, run, captured and looked at, and the capture agreed
with what the change claimed.

---

## Done before this plan

- [x] Palette from Albanian material, four appearances, every rendered pair at
      or above 4.5:1, asserted at runtime by `GjuhaContrastTests`
- [x] Compose palette generated from the iOS catalog, `--check` in the gate
- [x] Display type scale raised, tracking pulled in on large sizes only
- [x] Display type capped so it stops before overflowing at the largest sizes
- [x] The exercise prompt set as a statement
- [x] The Albanian word made the display element of a vocabulary row
- [x] Accent removed from a neutral zero
- [x] Every gradient removed from the home screen

## 1. Glyphs scale with their text

36 call sites set SF Symbols at a fixed point size, so at the larger
accessibility sizes the words grew and the status glyph, the chevron and the
review icon stayed where they were. Apple's typography guidance: meaningful
glyphs scale with the text.

- [x] `Font.gjuha.symbol(_:_:rounded:)`, anchored to the text style nearest
      the design size, capped at about 1.7x
- [x] All 36 call sites converted, including the App Intents snippet
- [x] Verified by unit test instead: capture could not drive the app at that
      size, so three tests assert a glyph grows, display type is capped and
      still grows, and body text is not capped

## 2. The direction reaches the rest of the app

The idea is that the marks Albanian adds to the Latin alphabet become the
display system. It currently shows on two screens.

- [x] Onboarding: the welcome is the hero statement, carrying its two
      e-diaereses at hero size
- [x] Lesson completion: the XP figure is the display element
- [x] Grammar: the Albanian in a conjugation table and in every worked
      example set above its gloss, the way the vocabulary row now is. The
      screenshot capture now walks into a guide, because the list above it
      showed none of what the screen is for
- [ ] Culture and dialect screens: same treatment where Albanian is shown

## 3. Widgets

They inherit the palette by name, so the colours are already right. Nothing
has been rendered.

- [ ] Each family rendered and looked at, light and dark
- [x] Widget text raised above Apple's 11 point floor (it had 10, 9 and 9
      point text) and glyphs scale in the regular families; the accessory
      families keep fixed sizes because the system sets their container
- [ ] Verified the snapshot still reads at the smallest family

## 4. App Intents snippet

- [ ] Snippet view matched to the new look
- [ ] Rendered, not only built

## 5. Android parity

The palette is generated from the same catalog. The type treatment is not.

- [x] Compose type scale added to match
- [x] The Albanian word made the display element of a word row
- [x] The exercise prompt set as a statement
- [x] Captured on the emulator and looked at; dark still to do

## 6. Verification sweep

- [ ] Light, dark and Increase Contrast, every screen, looked at
- [ ] The largest accessibility size, every screen
- [ ] Albanian locale, every screen
- [ ] Reduce Motion honoured
- [ ] VoiceOver: a screenshot cannot establish spoken names or focus order, so
      this is a device pass and is recorded as not run until someone runs it

## 7. Known, not caused by this work

- [ ] `testAchievementsStartLockedAndAreReachable` fails at the largest text
      size because the test reset on this branch never clears the achievement
      ledger. Fixed in `cf24cea`, waiting in PR #13. Do not fix it twice.
