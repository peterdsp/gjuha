# Gjuha Product Research and Direction

Timeboxed discovery, 2026-10-03. Primary and recent secondary sources, with the
implementation decision each finding supports. Reviews are treated as qualitative
evidence, not proof of universal demand.

## Market and learner needs

Finding: Albanian has no Duolingo course. The practical alternatives are
template driven multi language apps (Ling, uTalk, 50Languages, LingoHut) plus
Pimsleur for audio. Ling is the strongest, built by native speakers with eight
game types and normal and slow audio. Pimsleur is audio and pronunciation first.
(Sources below, dated 2025 to 2026.)

Decision: compete on what template apps do not do well for a serious adult learner:
durable retention, honest progress, Standard Albanian with labeled regional
awareness, grounded grammar explanation, and an offline-first native iOS feel.
Do not reskin a generic competitor.

Uncertainty: app store reviews are qualitative. We do not claim universal demand.
The diaspora, partners and families, newcomers, and travelers are plausible
segments; the design serves adults who want to actually remember what they study.

## Learning science

Finding: spacing and retrieval practice have robust support. Kim and Webb (2022),
"The effects of spaced practice on second language learning: A meta-analysis",
Language Learning 72(1), 269 to 319, quantitatively examined 37 experimental studies
and confirmed a positive overall effect of spacing on L2 learning, while noting the
effect varies by learning type, learner, and practice activity, and that some
sub analyses were inconclusive due to few studies. (Correction: an earlier draft of
this note cited "48 experiments and 3,411 participants" and a blanket "medium to
large" effect; those specifics were not supported by the primary source and have
been removed.)

On algorithms: SM-2 (Wozniak, 1987, SuperMemo) is simple and deterministic;
SuperMemo reports high long term retention from its early SM-2 use, a figure from
the vendor rather than an independent trial.

FSRS needs two things kept separate, because an earlier draft of this note
conflated them. (Primary sources: the open spaced repetition "awesome-fsrs" wiki
pages "The Algorithm" and "ABC of FSRS", and the srs-benchmark README.)

1. The scheduling model. FSRS uses the DSR memory model (Difficulty, Stability,
   Retrievability); the ABC page defines Retrievability as the probability of
   recall at a moment, Stability as the days for that probability to fall from
   100% to 90%, and Difficulty on a 1 to 10 scale. Scheduling is a closed form:
   the next interval I = S * ln(r) / ln(0.9) for a current stability S and a target
   retention r (so I = S when r = 0.9). Given a fixed parameter set and a target
   retention, the next interval is mathematically determined, with no randomness.
   Current FSRS-6 has 21 parameters.

2. Parameter optimization (training). FSRS ships with DEFAULT parameters, found by
   running the optimizer over hundreds of millions of reviews from roughly ten
   thousand users, so it works with zero personal history. Separately, an optimizer
   can fit those parameters to one learner's own review log by machine learning.
   The step that depends on a sizeable personal review history is this optimization,
   NOT the scheduling.

So calling FSRS "not deterministic" (as the earlier draft did) is inaccurate.
Precisely: FSRS scheduling is deterministic for a given parameter set and target
retention; only the per learner parameter optimization is data dependent (and even
that is a deterministic fit of a given log). The claim that it "needs a sizeable
review history" applies to personalizing the parameters, not to running at all.

On the comparison: the open spaced repetition srs-benchmark evaluates FSRS against
baseline algorithms including SM-2, over roughly ten thousand Anki collections and
hundreds of millions of reviews. It is an author and community benchmark published
on GitHub, not an independent peer reviewed trial, so its results are treated here
as indicative rather than proof, and no specific per algorithm accuracy figures are
quoted from it in this note.

Decision: implement an SM-2 derived scheduler now, and do NOT migrate to FSRS for
this release. The justification is implementation simplicity, not a belief that SM-2
schedules better: SM-2 needs no optimizer, no parameter file, and no personal review
history to run, and it is fully deterministic, so it is unit testable with a fixed
clock and ships with zero training data. FSRS's own default parameters would also
run without history, but adopting FSRS means carrying its 21 parameter model and
(to realize its advantage) an optimizer and a store of review logs, which is
unnecessary weight at launch. The scheduler sits behind a small protocol boundary
(a value type), so FSRS can replace it later without touching the feature layer if a
review history ever justifies the move. Use retrieval practice (the learner produces
the answer) rather than recognition only, which the exercise engine already supports.

## Apple platform constraints (verified, primary sources, carried from Phase 3/4)

- Apple Foundation Models (on device, iOS 26+) support only the Apple Intelligence
  language set; Albanian is not supported, and safety guardrails apply only to
  supported languages. So the app never generates authoritative Albanian with the
  model. Grammar coaching is English only, grounded in reviewed dataset Albanian,
  with a deterministic offline fallback.
- Apple Speech (`SFSpeechRecognizer.supportedLocales()`) does not include Albanian,
  and there is no Albanian system TTS voice. Confirmed at runtime by test
  `appleSpeechProbeConfirmsAlbanianUnsupported`. So no on device Albanian ASR or
  synthetic listening audio. Speaking assessment stays disabled.

## Albanian specifics

- Orthography: ë and ç are distinct letters, not accents. Dropping them changes the
  word, so grading treats a dropped diacritic as a near miss (recognized, not
  accepted) with a targeted hint. This is already enforced by `AnswerNormalizer`.
- Standard Albanian (based on Tosk) is the taught variety. Gheg content is labeled
  and held for native review rather than mixed in silently.

## Sources

- https://www.langoly.com/albanian-apps
- https://www.alllanguageresources.com/learn-albanian-app/
- https://ling-app.com/blog/best-apps-to-learn-albanian/
- Kim, S. K., and Webb, S. (2022). The effects of spaced practice on second language
  learning: A meta-analysis. Language Learning, 72(1), 269 to 319.
  https://www.cambridge.org/core/product/C833408A4C3BAD939CA39EA734423BB7 (and the
  journal record). 37 experimental studies.
- SM-2: SuperMemo (Wozniak), treated as indicative vendor reported figures.
- FSRS, primary sources (open spaced repetition project): the "awesome-fsrs" wiki
  pages "The Algorithm" (DSR model origin, closed form interval
  I = S * ln(r) / ln(0.9), FSRS-6 = 21 parameters) and "ABC of FSRS" (DSR
  definitions; default parameters fit over hundreds of millions of reviews from
  ~10k users; the optimizer fits parameters to a user's own review history), and
  the srs-benchmark README (~10k Anki collections, hundreds of millions of reviews;
  SM-2 included as a baseline; an author and community benchmark, not an independent
  peer reviewed trial). The fsrs4anki wiki pages now redirect to awesome-fsrs.
- Azure Neural TTS Albanian voices sq-AL-AnilaNeural (female) and sq-AL-IlirNeural
  (male) are General Availability. Confirmed via Azure voice listings (for example
  https://json2video.com/ai-voices/azure/voices/sq-al-ilirneural/ and the Azure AI
  Speech catalog). This is the licensing path for shipped audio, still gated on
  authorization and native review.
- Apple Foundation Models and Speech documentation (verified in Phase 3/4, see
  `Documentation/Phase3_4/PHASE3_4_REPORT.md`).
