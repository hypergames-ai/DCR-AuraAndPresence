// Presence.swift — DCR presence accounting: a minimal metrics engine.
//
// Units ledger:
//   Aura flow        person-attention per tick (the input flow)
//   ε (transducer)   installations per unit attention — the crystal-bundle's figure of merit
//   Presence stock   effective installed minds at cue c:  P(c) = Σᵢ pᵢ(c)   → "cue-minds"
//   Invocation       one unprompted retrieval at a live occasion (the yield quantum)
//   Probe            the conventional fixing of the quantum — declared ex ante, like the deed quantum
//
// Foundation-only, single file. Run: `swift Presence.swift`
// Deterministic under a fixed seed. (For bit-identical runs across launches, also set
// SWIFT_DETERMINISTIC_HASHING=1 — dictionary iteration order otherwise varies per process
// and changes the order in which the RNG is consumed.)

import Foundation

// MARK: - Deterministic RNG

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_B9B1
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Installation

/// One (entity, cue) association resident in a host mind. The continuous substrate.
struct Installation {
    /// Retrieval propensity at the standard occasion, in [0, 1].
    var p: Double = 0
    /// Modal density of the render, in [0, 1]. Grading dimension; multiplies encoding.
    var tangibility: Double = 0
    /// Chwe grade. `true` = settlement grade (minted by rites); decays on the slow constant.
    var commonKnowledge: Bool = false
}

// MARK: - Mind

struct Mind<Entity: Hashable, Cue: Hashable> {
    var installs: [Cue: [Entity: Installation]] = [:]

    subscript(cue: Cue, entity: Entity) -> Installation {
        get { installs[cue]?[entity] ?? Installation() }
        set { installs[cue, default: [:]][entity] = newValue }
    }
}

// MARK: - Probe (the conventional quantum)

/// Declared ex ante. Disputes about "how much presence" become disputes about
/// probe results, not metaphysics — the same service the deed quantum performs for acts.
struct Probe {
    /// p ≥ this ⇒ aided-grade installation (tailings).
    var aidedFloor: Double
    /// p ≥ this ⇒ unaided-grade — the cue-mind counts as installed.
    var unaidedFloor: Double
    // Top-of-mind is relational: max-p at the cue, and ≥ unaidedFloor.

    static let standard = Probe(aidedFloor: 0.05, unaidedFloor: 0.35)
}

// MARK: - Engine

struct PresenceEngine<Entity: Hashable, Cue: Hashable> {

    struct Config {
        var probe: Probe = .standard
        /// Per-tick decay, private grade (activation-like: fast leak).
        var lambdaPrivate: Double = 0.025
        /// Per-tick decay, settlement grade (brand-like: slow leak).
        var lambdaCommon: Double = 0.004
    }

    struct GradeBands {
        var topOfMind = 0   // high-grade ore
        var unaided = 0     // installed, but not first-retrieved
        var aided = 0       // tailings
    }

    private(set) var minds: [Mind<Entity, Cue>]
    private(set) var deeds: [Entity: Int] = [:]   // settlement-layer stub
    var config: Config
    private var rng: SplitMix64

    init(population: Int, config: Config = Config(), seed: UInt64 = 0xD37) {
        self.minds = Array(repeating: Mind(), count: population)
        self.config = config
        self.rng = SplitMix64(seed: seed)
    }

    // MARK: Flows in

    /// Aura flow through a crystal transducer.
    /// Saturating update per exposed mind: Δp = ε · tangibility · attention · (1 − p).
    mutating func expose(_ entity: Entity, at cue: Cue,
                         reach: Double, attention: Double,
                         epsilon: Double, tangibility: Double) {
        for i in minds.indices where Double.random(in: 0..<1, using: &rng) < reach {
            var inst = minds[i][cue, entity]
            inst.p = min(1, inst.p + epsilon * tangibility * attention * (1 - inst.p))
            inst.tangibility = max(inst.tangibility, tangibility)
            minds[i][cue, entity] = inst
        }
    }

    /// A rite: installs *and* mints common knowledge among participants —
    /// everyone sees everyone seeing. The settlement-grade channel.
    mutating func rite(_ entity: Entity, at cue: Cue,
                       participation: Double, epsilon: Double, tangibility: Double = 0.9) {
        for i in minds.indices where Double.random(in: 0..<1, using: &rng) < participation {
            var inst = minds[i][cue, entity]
            inst.p = min(1, inst.p + epsilon * tangibility * (1 - inst.p))
            inst.tangibility = max(inst.tangibility, tangibility)
            inst.commonKnowledge = true
            minds[i][cue, entity] = inst
        }
    }

    /// Ledger entry on the settlement layer. Presence is mythos-credit; deeds settle it.
    mutating func record(deedsBy entity: Entity, count: Int = 1) {
        deeds[entity, default: 0] += count
    }

    /// n decay ticks. dp/dt = −λ·p, grade-dependent λ. Refresh or leak.
    mutating func tick(_ n: Int = 1) {
        let kPrivate = exp(-config.lambdaPrivate * Double(n))
        let kCommon = exp(-config.lambdaCommon * Double(n))
        for i in minds.indices {
            for (cue, var byEntity) in minds[i].installs {
                for (e, var inst) in byEntity {
                    inst.p *= inst.commonKnowledge ? kCommon : kPrivate
                    byEntity[e] = inst
                }
                minds[i].installs[cue] = byEntity
            }
        }
    }

    // MARK: The books

    /// Latent truth — only the simulator god sees this. P(c) = Σᵢ pᵢ. Unit: cue-minds.
    func census(at cue: Cue) -> [Entity: Double] {
        var stock: [Entity: Double] = [:]
        for m in minds {
            for (e, inst) in m.installs[cue] ?? [:] { stock[e, default: 0] += inst.p }
        }
        return stock
    }

    /// Grade classification of the latent field under the probe's declared floors.
    /// Bands are exclusive: total installed (unaided grade) = topOfMind + unaided.
    func grades(at cue: Cue) -> [Entity: GradeBands] {
        var out: [Entity: GradeBands] = [:]
        for m in minds {
            guard let byEntity = m.installs[cue], !byEntity.isEmpty else { continue }
            let top = byEntity.max { $0.value.p < $1.value.p }!
            for (e, inst) in byEntity {
                var g = out[e, default: GradeBands()]
                if inst.p >= config.probe.unaidedFloor {
                    if e == top.key { g.topOfMind += 1 } else { g.unaided += 1 }
                } else if inst.p >= config.probe.aidedFloor {
                    g.aided += 1
                }
                out[e] = g
            }
        }
        return out
    }

    /// Field estimation: administer the probe as an actual recall trial to n sampled minds.
    /// Each mind passes with probability p, so N·p̂ is an unbiased estimator of the census Σp —
    /// probe and ledger agree by construction. A seroprevalence survey for a memetic infection.
    mutating func survey(_ entity: Entity, at cue: Cue, sampleSize: Int)
        -> (estimate: Double, ci95: Double) {
        let n = min(sampleSize, minds.count)
        var hits = 0
        for i in minds.indices.shuffled(using: &rng).prefix(n) {
            if Double.random(in: 0..<1, using: &rng) < minds[i][cue, entity].p { hits += 1 }
        }
        let pHat = Double(hits) / Double(n)
        let se = (pHat * (1 - pHat) / Double(n)).squareRoot()
        let population = Double(minds.count)
        return (population * pHat, population * 1.96 * se)
    }

    /// Run k cue-occasions. Each installed entity independently comes to mind w.p. p;
    /// the invocation goes to the strongest retrieval; an empty set is a silent occasion.
    /// Retrieval rivalry lives here — displacement happens at the moment of decision.
    mutating func occasions(_ k: Int, at cue: Cue) -> (byEntity: [Entity: Int], silent: Int) {
        var counts: [Entity: Int] = [:]
        var silent = 0
        for _ in 0..<k {
            let i = Int.random(in: 0..<minds.count, using: &rng)
            var best: (entity: Entity, p: Double)? = nil
            for (e, inst) in minds[i].installs[cue] ?? [:] {
                if Double.random(in: 0..<1, using: &rng) < inst.p,
                   best == nil || inst.p > best!.p {
                    best = (e, inst.p)
                }
            }
            if let hit = best { counts[hit.entity, default: 0] += 1 } else { silent += 1 }
        }
        return (counts, silent)
    }

    /// Mythos leverage: presence stock per unit deed-depth.
    /// High values = unsecured mythos-credit (Certain Doom mode at org scale).
    func leverage(_ entity: Entity, at cue: Cue) -> Double {
        (census(at: cue)[entity] ?? 0) / Double(1 + (deeds[entity] ?? 0))
    }
}

// MARK: - Demo: ten startups, one crystal-bundle

let cue = "seed-stage: agentic infra"   // one category entry point — presence is cue-indexed

var engine = PresenceEngine<String, String>(population: 5_000, seed: 42)

let branded = "Hyperreal"
let rivals = (1...9).map { "Startup\($0)" }

// Pitch day. Equal Aura flow (same stage, same attention) — unequal transducers.
for s in rivals {
    engine.expose(s, at: cue, reach: 0.8, attention: 1.0, epsilon: 0.35, tangibility: 0.25)
}
engine.expose(branded, at: cue, reach: 0.8, attention: 1.0, epsilon: 0.35, tangibility: 0.95)

// The branded founders also stage a rite — jingle performed live, room watching itself watch.
engine.rite(branded, at: cue, participation: 0.25, epsilon: 0.5)

// Meanwhile one rival quietly ships. Deeds land on the ledger; presence does not follow by itself.
engine.record(deedsBy: "Startup3", count: 8)
engine.record(deedsBy: branded, count: 1)

func pad(_ s: String) -> String { s.padding(toLength: 12, withPad: " ", startingAt: 0) }
func fmt(_ x: Double) -> String { String(format: "%8.1f", x) }

func report(_ label: String) {
    print("\n== \(label) ==")
    print("Census (latent Σp, in cue-minds):")
    for (e, p) in engine.census(at: cue).sorted(by: { $0.value > $1.value }).prefix(4) {
        print("  \(pad(e)) \(fmt(p))")
    }
    let (est, ci) = engine.survey(branded, at: cue, sampleSize: 400)
    print("Survey, \(branded) (probe trial, n=400): \(fmt(est)) ± \(String(format: "%.1f", ci)) cue-minds")
    if let g = engine.grades(at: cue)[branded] {
        print("Grades, \(branded): top-of-mind \(g.topOfMind) · unaided \(g.unaided) · aided \(g.aided)")
    }
    let yield = engine.occasions(10_000, at: cue)
    let shares = yield.byEntity.sorted { $0.value > $1.value }.prefix(3)
        .map { "\($0.key) \(String(format: "%.1f", 100 * Double($0.value) / 10_000))%" }
        .joined(separator: " · ")
    print("Invocation share (10k occasions): \(shares) · silent \(String(format: "%.1f", 100 * Double(yield.silent) / 10_000))%")
    print("Leverage: \(branded) \(String(format: "%.1f", engine.leverage(branded, at: cue)))  vs  Startup3 \(String(format: "%.1f", engine.leverage("Startup3", at: cue)))")
}

report("t = 0, post-pitch (high tide)")

// Sixty ticks of silence. The tank leaks; settlement grade leaks slower.
engine.tick(60)

report("t = 60, after the silence (low tide)")

// Expected shape of the result:
//   t=0  — branded holds an order of magnitude more cue-minds; rivals hold tailings.
//   t=60 — rivals' private-grade presence has leaked below the aided floor entirely;
//          branded survives almost solely through its rite-minted settlement grade,
//          and its leverage reads as dangerously high against a one-deed ledger.
//          The probe-visible quantum and the latent census diverge for the rivals:
//          latent residue > 0, installed minds ≈ 0. The unit is the probe's, not nature's.
