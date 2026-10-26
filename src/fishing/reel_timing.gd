class_name ReelTiming
extends TimingCheck
## Landing a catch (Iteration 18, replacing the Iteration 13 tension bar): a
## needle goes round a dial at one constant speed; press the action key (or
## click the dial) while it is inside the target arc. Each good press is one
## check; the catch is landed after the checks its rarity asks for
## (FishingCatalog.reel_profile: 1 for common to 4 for very rare, with a
## narrower arc the rarer it is). After each good press the arc moves to a
## new place on the dial, well ahead of the needle.
##
## Inside the arc a smaller Perfect zone: a Perfect hit counts as a check and
## also nudges the fish's weight a little toward the top of its species'
## range when it is landed (FishingCatalog.landed_kg) - never its species or
## rarity.
##
## Misses: the line has LINE_CONTROL "turns of grip". A press outside the arc
## costs one; the catch escapes only when all are gone (three misses), so one
## slightly early press never loses a rare fish. Not pressing costs nothing:
## the needle just goes round again. Presses come at most every DEBOUNCE
## seconds (a held or bouncing key is one press). If nothing is pressed for
## IDLE_SECONDS the fish slips the hook. Real time, so 20x never rushes it.
##
## The dial mechanics live in TimingCheck (shared with the Magic Anchor);
## this class is the fishing encounter: checks and arc come from
## FishingCatalog.reel_profile(), a Perfect nudges the landed weight.
