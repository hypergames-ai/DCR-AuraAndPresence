# DCR Aura & Presence
When AI wearables hit their stride, attention-chasing on social media can escape the screen and spread into the real world. Real world attention/aura can be "measured" for people & brands by passive surveillance by AI wearables, CCTV, etc. (who's looking at/talking about whom) and leaderboards/loserboards shared to become common knowledge. The whole point of hypergames, or hyperreality games, is to generate presence for hyperreal constructs on these leaderboards! (and obviously, people will selfishly want to get _themselves_ on the leaderboards, too: a Bennett-hypergame) Hyperreality contests (sports & games) will be judged by charisma **and** competence, not just competence alone (pro-wrestling is an example of drama + prowess; kayfabe = hyperreality simulation).

This is a test to calculate Aura decay into Presence. (Aura is the fire in the fireplace, Presence is the heat from the fireplace-stones after fire is extinguished, where the felt heat cue-indexes the memory of the fire)

## Scenario
Ten startups pitch to investors, startups are baseline about equally "exciting" to the investors, no standouts. However, one startup charismatically juices up their pitch by presenting myths about themselves and what they are doing (origin myth: hyperreal Siren Songs, identity myths: branding, badging, song jingle, etc). This generates extra Aura in the moment, and residual Presence later on is higher. The goal is to calculate how "sticky" this startup is in investor's minds. 

(most investors are likely put off by gimmicks, but if done the "right" DCR way (think: Jimi Hendrix seamlessly incorporating gimmicks), the gimmicks become a charismatic and seamless part of the product, and the pitch would likely not be shut down mid-flight) 

## Description
This is a single-file Swift simulation of a **presence accounting engine** for the DCR framework. It models how an entity (a brand, product, startup, idea, etc.) accumulates, retains, and yields “installed minds” at a given **cue** — a category entry point or occasion where retrieval can happen.
### Units and framing
The header defines a ledger:
- **Aura flow**: person-attention per tick (the input).
- **ε (epsilon)**: the transducer’s figure of merit — installations per unit attention. Higher ε + higher tangibility = more effective encoding.
- **Presence stock** `P(c) = 𝚺 p(c)`: effective installed minds at cue \( c \), measured in “cue-minds.”
- **Invocation**: one unprompted retrieval at a live occasion (the yield quantum).
- **Probe**: a conventional, ex-ante fixing of what counts as an installation (aided vs unaided floors), analogous to a deed quantum. Disputes become empirical probe results rather than metaphysical ones.

The engine is deliberately minimal and Foundation-only, with a deterministic SplitMix64 RNG so runs are reproducible under a fixed seed.
### Core structures
- **Installation**: one (entity, cue) association living in a host mind.  
  - `p ∈ [0,1]`: retrieval propensity.  
  - `tangibility ∈ [0,1]`: modal density of the render (multiplies encoding).  
  - `commonKnowledge`: true if minted by a rite (settlement-grade); decays on the slow constant.
- **Mind**: sparse map of cue → entity → Installation.
- **Probe**: declares the conventional thresholds (standard: aided floor 0.05, unaided floor 0.35). Top-of-mind is relational: the highest-p entity at that cue that also meets the unaided floor.
- **PresenceEngine**: holds a population of minds, a simple deeds ledger (settlement-layer stub), config (probe + two decay rates), and the RNG.
### Dynamics
**Inflows**
- `expose`: Aura flow through a crystal transducer. For each mind reached with probability `reach`, applies a saturating update `Δp=ε⋅tangibility⋅attention⋅(1−p)` and takes the max tangibility seen. Private-grade only.
- `rite`: same saturating update, but also sets `commonKnowledge = true` among participants. This is the settlement-grade channel — “everyone sees everyone seeing.”

**Decay** (`tick`)
Exponential decay, grade-dependent:  `p ← p⋅e^(−λ⋅n)` 
where λ(private)​ is fast (activation-like) and λ(common)​ is slow (brand-like).

**Measurement / books**
- `census`: latent truth only the simulator sees — sum of _p_ across minds (cue-minds).
- `grades`: exclusive bands under the probe floors (top-of-mind / unaided / aided).
- `survey`: administers the probe as an actual recall trial to a sample; returns an unbiased estimate of the census plus 95% CI. Probe and latent ledger agree by construction.
- `occasions`: runs _k_ live occasions. Each installed entity comes to mind independently with probability _p_; the strongest retrieval wins (retrieval rivalry / displacement). Empty set = silent occasion. This is where invocation share is realized.
- `leverage`: presence stock per unit deed-depth. High values = unsecured mythos-credit.

### Demo
The Swift file runs a small scenario with 5,000 minds and the cue `"seed-stage: agentic infra"`:
```
== t = 0, post-pitch (high tide) ==
Census (latent Σp, in cue-minds):
  Hyperreal      1743.7
  Startup5        354.8
  Startup2        353.5
  Startup3        352.9
Survey, Hyperreal (probe trial, n=400):   1737.5 ± 233.3 cue-minds
Grades, Hyperreal: top-of-mind 1232 · unaided 0 · aided 3029
Invocation share (10k occasions): Hyperreal 35.1% · Startup1 3.8% · Startup3 3.6% · silent 34.4%
Leverage: Hyperreal 871.8  vs  Startup3 39.2

== t = 60, after the silence (low tide) ==
Census (latent Σp, in cue-minds):
  Hyperreal       804.1
  Startup5         79.2
  Startup2         78.9
  Startup3         78.7
Survey, Hyperreal (probe trial, n=400):    800.0 ± 179.6 cue-minds
Grades, Hyperreal: top-of-mind 1232 · unaided 0 · aided 3029
Invocation share (10k occasions): Hyperreal 16.5% · Startup4 1.4% · Startup6 1.3% · silent 72.4%
Leverage: Hyperreal 402.1  vs  Startup3 8.7
```
- Nine generic startups and one branded entity (“Hyperreal”) receive identical Aura flow, but Hyperreal has much higher tangibility (0.95 vs 0.25) and also stages a rite (participation 0.25, high ε).
- One rival quietly records deeds; Hyperreal records almost none.
- Reports are printed at t = 0 (high tide after the pitch) and after 60 ticks of silence (low tide).

Expected shape: at t = 0 the branded entity holds an order of magnitude more cue-minds; after silence the private-grade rivals leak below the aided floor while the rite-minted settlement grade largely survives, producing dangerously high leverage against a thin deed ledger. Latent residue and probe-visible installations can diverge — the unit is the probe’s, not nature’s.

In short, the file is a compact, runnable model of how presence (as installed retrieval propensity) is written by attention and rites, leaks at different rates by grade, is measured by a declared probe, and is ultimately settled against deeds. It operationalizes the distinction between private activation and common-knowledge settlement, and between latent stock and realized invocation under retrieval rivalry.
