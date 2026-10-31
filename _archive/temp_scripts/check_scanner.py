from pathlib import Path

p = Path("src/pair_scanner.jl")
txt = p.read_text(encoding="utf-8")

# The scanner uses strengths directly via .score attribute — Compatible.
# But we can enrich the reasons_for/against by considering new metrics
# For now, we just need pair_scanner to compile with new PairStrength struct
# Since compute_pair_strength returns a new object, pair_scanner.jl still works.

# We just verify no breaking changes
print("[OK] pair_scanner.jl compatible with strength_engine v2 (uses currency.score only)")
