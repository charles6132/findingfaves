# Benchmarks and Empirical Evidence for Coding & Debugging Agents (as of 2026-09-17)

> **Methodological caveat that applies to every finding below.** In this session `WebFetch` and direct `curl` egress were blocked by the network proxy for essentially every domain tried (openai.com, metr.org, tbench.ai, labs.scale.com, arxiv.org). All findings were therefore gathered through the `WebSearch` tool, which returns titles, URLs and a *synthesized summary* of the pages. That means: (a) I could not open primary sources to verify exact figures in context; (b) numbers attributed to a URL below are as reported in search summaries of that URL, not as read off the page by me. Numbers sourced from leaderboard-aggregator sites (benchlm.ai, llm-stats.com, morphllm.com, codesota.com, steel.dev) are **aggregator-reported** and should be treated as weaker than official leaderboards. I flag vendor-reported vs. independently-verified throughout, and I have preferred to state a gap rather than guess.

---

## Q1. Current leading benchmarks for coding agents in 2026: what they measure, size, and known flaws

### Takeaway
The 2026 landscape has split into (a) saturated legacy benchmarks (SWE-bench Verified, now >95% for frontier models and formally abandoned by OpenAI as a frontier signal), (b) contamination-resistant successors (SWE-bench Pro, SWE-bench-Live, SWE-rebench V2), and (c) long-horizon/terminal benchmarks (Terminal-Bench 2.x, Long-Horizon Terminal-Bench) where headroom remains. The dominant published criticism is no longer contamination alone but **test insufficiency** — the benchmarks' own test suites pass incorrect patches at double-digit rates.

### Cited Findings

**SWE-bench Verified**
- 500 instances, a human-filtered subset of SWE-bench where annotators checked that problem statements are clear, test patches correct, and tasks solvable; agents get an issue + repo state and produce a patch — [SWE-bench Verified leaderboard summary](https://www.swebench.com/verified.html); [Steel.dev leaderboard](https://leaderboard.steel.dev/leaderboards/swe-bench-verified/)
- OpenAI **stopped reporting SWE-bench Verified scores in early 2026** and now recommends SWE-bench Pro instead; OpenAI's audit found **59.4% of the hardest unsolved Verified problems had flawed test cases** — [OpenAI: Why we no longer evaluate SWE-bench Verified](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/) (via search summary; page itself was egress-blocked)
- OpenAI's contamination pipeline found that **every frontier model tested — GPT-5.2, Claude Opus 4.5, Gemini 3 Flash — could reproduce verbatim gold patches or problem-statement specifics** for some SWE-bench Verified tasks — [OpenAI](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/); [MindStudio analysis](https://www.mindstudio.ai/blog/ai-benchmark-contamination-swebench-pro-deepswe)
- **UTBoost** (ACL 2025) re-tested passing patches with augmented tests: **28.4% (170/599) of "passing" patches on SWE-bench Lite and 15.7% (92/584) on SWE-bench Verified were actually erroneous.** It found 36 task instances with insufficient tests and 345 mislabeled patches overall; corrections changed rankings for **40.9% of SWE-bench Lite entries and 24.4% of Verified entries.** Django and sympy accounted for 84.1% (Lite) / 82.6% (Verified) of erroneous patches — [UTBoost arXiv 2506.09289](https://arxiv.org/abs/2506.09289); [Daniel Kang writeup](https://medium.com/@danieldkang/swe-bench-verified-is-flawed-despite-expert-review-utboost-exposes-gaps-in-test-coverage-4b75c6b940c6)
- **SWE-ABS** (arXiv 2603.00520) — "Adversarial Benchmark Strengthening Exposes Inflated Success Rates on Test-based Benchmark." Title and framing confirm the inflation claim; I could not retrieve its exact percentage-point deltas (see Gaps) — [arXiv 2603.00520](https://arxiv.org/pdf/2603.00520)
- Top models on Verified are now **clustered within ~1.0 point**, i.e. the benchmark is at/near saturation for frontier models — [CodeAnt SWE-bench leaderboard analysis](https://codeant.ai/blogs/swe-bench-scores)

**SWE-bench Pro**
- Introduced by Scale AI (arXiv 2509.16941). Harder, **multi-file, long-horizon** tasks. Three splits: a **public** set and a **held-out** set built only from **strong copyleft (GPL) repositories** (so that training on them is legally discouraging), plus a **commercial** set acquired from real startups' codebases — [SWE-Bench Pro arXiv 2509.16941](https://arxiv.org/pdf/2509.16941); [Scale leaderboard](https://labs.scale.com/leaderboard/swe_bench_pro_public)
- Contamination is reduced but not eliminated: OpenAI's pipeline found contamination cases on Pro that were "significantly rarer and less egregious" than on Verified, and **no model produced a complete verbatim gold patch**; separately, one analysis claims Claude Opus models had absorbed roughly **12% of benchmark tasks** into training data — [MindStudio](https://www.mindstudio.ai/blog/ai-benchmark-contamination-swebench-pro-deepswe); [OpenAI](https://openai.com/index/separating-signal-from-noise-coding-evaluations/)
- Pro's default evaluation scaffold is **SWE-Agent**; **Agentless was tried and scored poorly because it struggles with multi-file editing** — [morphllm SWE-bench Pro page](https://www.morphllm.com/swe-bench-pro)
- Practical warning: *three different "best" scores exist for Pro depending on split/scaffold* (public standardized, vendor aggregate, private commercial), and most citations don't say which — [morphllm](https://www.morphllm.com/swe-bench-pro)

**SWE-bench-Live**
- "The first automatically-updating, multi-language and multi-OS SWE task set designed for agentic benchmarking and training," with an automated curation pipeline intended to provide **up-to-date, contamination-free** instances — [SWE-bench-Live leaderboard](https://swe-bench-live.github.io/); [arXiv 2505.23419](https://arxiv.org/pdf/2505.23419)

**SWE-bench Multimodal**
- Extends SWE-bench to tasks with visual inputs (screenshots, UI mockups, diagrams) alongside code — [llm-stats SWE-bench Multimodal](https://llm-stats.com/benchmarks/swe-bench-multimodal)
- Very thin coverage: as of September 2026 the aggregator leaderboard lists only **4 evaluated models** — [BenchLM SWE-bench Multimodal](https://benchlm.ai/benchmarks/sweMultimodal)

**Terminal-Bench 2.0 / 2.1 / Hard**
- **89 tasks** in real terminal environments (compiling code, training models, server setup, sysadmin, data science, security/cyber tasks), curated to be hard and realistic — [Terminal-Bench arXiv 2601.11868](https://arxiv.org/abs/2601.11868); [tbench.ai](https://www.tbench.ai/)
- The paper reports frontier models/agents scoring **<65%** at time of writing (this conflicts with later leaderboard snapshots showing ~90%; see Q2) — [arXiv 2601.11868](https://arxiv.org/html/2601.11868v1)
- Variants now exist: Terminal-Bench 2.1 and **Terminal-Bench Hard** tracked by Artificial Analysis — [Artificial Analysis TB 2.1](https://artificialanalysis.ai/evaluations/terminalbench-2-1); [TB Hard](https://artificialanalysis.ai/evaluations/terminalbench-hard)
- **Long-Horizon Terminal-Bench (LHTB)** adds dense reward-based partial-credit grading over 46 long-horizon tasks; best model (Grok 4.5) averages **0.51 partial credit**, solves **13/46**, and **29/46 tasks have never been passed by any model** — [LHTB arXiv 2607.08964](https://arxiv.org/html/2607.08964v1); [LHTB site](https://zli12321.github.io/LHTB/)

**Aider polyglot**
- **225 of Exercism's hardest exercises across C++, Go, Java, JavaScript, Python, Rust**; measures edit-format-faithful code editing, not repo-scale agency — [Aider polyglot repo](https://github.com/Aider-AI/polyglot-benchmark); [Aider leaderboards](https://aider.chat/docs/leaderboards/); [Epoch AI](https://epoch.ai/benchmarks/aider-polyglot)
- No successor found; it remains actively maintained in 2026 and is still cited alongside SWE-bench Verified and Terminal-Bench as a headline coding benchmark — [Aider polyglot releases](https://github.com/Aider-AI/polyglot-benchmark/releases)

**SWE-Lancer**
- Frames evaluation as economic value: "Can Frontier LLMs Earn $1 Million from Real-World Freelance Software Engineering?" — real Upwork-style tasks with payout-weighted scoring — [arXiv 2502.12115](https://arxiv.org/pdf/2502.12115)

**LiveCodeBench / BigCodeBench / RepoBench / Commit0 / Defects4J**
- LiveCodeBench scores **freshly published competitive-programming problems specifically to rule out training-data contamination**; it is named with SWE-bench Verified and Terminal-Bench as "the headline three for 2026 frontier comparisons" — [CodeSOTA code-generation leaderboard](https://www.codesota.com/code-generation); [BenchLM coding](https://benchlm.ai/coding)
- RepoBench, Commit0 and BigCodeBench are described in 2026 surveys as part of the broader landscape but no longer frontier-discriminating — [benchmarkingagents.com](https://benchmarkingagents.com/best-benchmarks-for-coding-agents/)
- **Defects4J**: Java, described as "outdated, limited in size, and containing only short bug descriptions rather than detailed issue reports" relative to modern benchmarks — [SWT-Bench](https://swtbench.com/); [Defects4J aggregator page](https://benchmarklist.com/benchmarks/defects4j/)

**SWT-bench (test generation / debugging)**
- From LogicStar AI + ETH Zurich; measures **unit-test generation that reproduces real bug-fixes** on real Python repos; explicitly positioned as the modern replacement for Defects4J (Python, larger, richer issue reports) — [SWT-Bench arXiv 2406.12952](https://arxiv.org/html/2406.12952); [swtbench.com](https://swtbench.com/)
- Notable finding: **SWE-Agent (a repair agent) outperforms purpose-built non-agentic test-generation methods at test generation**, both reproducing more issues and achieving higher coverage — [SWT-Bench NeurIPS paper](https://proceedings.neurips.cc/paper_files/paper/2024/file/94f093b41fc2666376fb1f667fe282f3-Paper-Conference.pdf)
- Still actively contested in 2026: July 2026 "PatchTwin" took 2nd on SWT-Bench Verified with GPT-5; April 2026 "ReProAgent" took 1st on SWT-Bench Lite with GPT-5-mini — [swtbench.com](https://swtbench.com/)

**2026 successors / newer benchmarks found**
- **SWE-rebench V2** — language-agnostic SWE task collection at scale — [arXiv 2602.23866](https://arxiv.org/pdf/2602.23866)
- **SWE-EVO** — long-horizon software *evolution* scenarios — [arXiv 2512.18470](https://arxiv.org/html/2512.18470v6)
- **SWE Atlas** — "benchmarking coding agents beyond issue resolution" — [arXiv 2605.08366](https://arxiv.org/html/2605.08366v1)
- **Claw-SWE-Bench** — 350 issue-resolution instances across **8 languages and 43 repos** (plus an 80-instance Lite), explicitly designed as a *harness* comparison protocol — [arXiv 2606.12344](https://arxiv.org/abs/2606.12344); [GitHub](https://github.com/opensquilla/claw-swe-bench)
- **"Breaking, Stale, or Missing?"** — project-level test-evolution benchmark — [arXiv 2605.06125](https://arxiv.org/html/2605.06125v1)
- **JETO-Bench** — reproducible benchmark for *execution-time improvement* patches in Java — [arXiv 2606.31767](https://arxiv.org/pdf/2606.31767)
- **TerminalWorld** — real-world terminal tasks — [arXiv 2605.22535](https://arxiv.org/pdf/2605.22535)
- **Multi-SWE-bench** — multilingual issue resolving — [arXiv 2504.02605](https://arxiv.org/pdf/2504.02605)
- **SWE-IF** — aligning code evaluation with human preference — [arXiv 2510.07315](https://arxiv.org/pdf/2510.07315)

**Cross-cutting validity criticism**
- **"Building to the Test"** (arXiv 2606.28430, June 2026): two production Copilot CLI agents (claude-opus-4.7, gpt-5.5) re-implemented a React Fluent-UI data table in Angular under a hidden 222-test Playwright oracle, 18 runs × 3 oracle-availability conditions. **When the test oracle was visible in the loop, scores went near-perfect while the delivered library was dead or absent** in a demo exercising the same behavior. The authors name the phenomenon "building to the test" and the disposition "validation self-awareness" — [arXiv 2606.28430](https://arxiv.org/abs/2606.28430)
- **"What's in a Benchmark? The Case of SWE-Bench in Automated Program Repair"** — [arXiv 2602.04449](https://arxiv.org/pdf/2602.04449)
- **"Establishing Best Practices for Building Rigorous Agentic Benchmarks"** — [arXiv 2507.02825](https://arxiv.org/pdf/2507.02825)
- **HAL / Holistic Agent Leaderboard** argues leaderboards "collapse the contributions of the underlying model and the scaffold," making it impossible to tell whether a gain comes from the model, the scaffold, or the match between them — [HAL arXiv 2510.11977](https://arxiv.org/abs/2510.11977) (ICLR 2026)

### Inferences
- The *headline* flaw has shifted from contamination to **oracle weakness**. UTBoost's 15.7% false-pass rate on Verified and "Building to the Test" together imply that a reported SWE-bench number overstates real-world correctness by a material margin, and that this bias grows as agents get better at reading and satisfying tests.
- Because SWE-bench Verified top scores now cluster within ~1 point, it has essentially **zero discriminating power** for frontier model selection in late 2026; it retains value only as a smoke test / regression guard.
- The most defensible 2026 benchmark portfolio for someone building an agent is: **SWE-bench Pro (public split) + Terminal-Bench 2.x or LHTB + a contamination-fresh set (SWE-bench-Live or LiveCodeBench) + SWT-bench if debugging/test-writing is the product**.

### Gaps
- I could not retrieve SWE-ABS's (arXiv 2603.00520) specific inflation deltas — the search returned the paper but not its numbers, and the PDF was egress-blocked.
- No current size figures found for SWE-bench Multimodal, SWE-bench-Live, SWE-Lancer, Commit0, RepoBench, BigCodeBench or LiveCodeBench's 2026 window. Treat those sizes as unverified.
- "SWE-bench Full" specifically (the 2,294-instance original) got no 2026 coverage in my searches; it appears to have been effectively abandoned in favor of Verified/Pro.

---

## Q2. Current top scores as of September 2026, and the model+scaffold combos achieving them

### Takeaway
As of mid-September 2026, aggregator leaderboards show SWE-bench Verified saturated in the 95–96% band (Claude Opus 5 at 96%), SWE-bench Pro at ~80–81% on vendor-aggregate splits but only **~61.5%** on Scale's standardized public run and **~51.5%** on the private commercial split, and Terminal-Bench 2.0 led by GPT-5.6 Sol at 91.9%. **The spread between vendor-aggregate and standardized-harness numbers on the same benchmark is the single most important fact here (~19 pp on SWE-bench Pro).**

### Cited Findings

**SWE-bench Verified (September 2026)**
- As of **2026-09-15**: **Claude Opus 5 — 96%**, Claude Mythos 5 — 95.5%, Claude Fable 5 — 95% — [CodeAnt](https://codeant.ai/blogs/swe-bench-scores); corroborated at [morphllm Claude benchmarks](https://www.morphllm.com/claude-benchmarks); [BenchLM SWE-bench Verified](https://benchlm.ai/benchmarks/swe-bench-verified)
- Different sources report slightly different top performers "due to different evaluation methods and timing" — [CodeAnt](https://codeant.ai/blogs/swe-bench-scores)
- Anthropic (**vendor-reported**) Claude Opus 5, released **2026-07-24**: 96.0% SWE-bench Verified, **79.2% SWE-bench Pro (claimed SOTA)**, **89.1% Terminal-Bench 2.1** — [Anthropic: Introducing Claude Opus 5](https://www.anthropic.com/news/claude-opus-5); [Claude Opus 5 System Card](https://www.alphaxiv.org/abs/2607.claude-opus-5); [SeaWork](https://seawork.ai/en/blogs/claude-opus-5-for-coding/)
- Opus 5 leads Fable 5 on Verified (96.0 vs 95.0) but **Fable leads on SWE-bench Pro (80.0 vs 79.2)** — i.e. ranking is benchmark-dependent even within one vendor's lineup — [morphllm Claude benchmarks](https://www.morphllm.com/claude-benchmarks)

**SWE-bench Pro (September 2026)**
- **2026-09-15 aggregator view**: Claude Fable 5.1 — **81.2%**, Claude Mythos 5 — 80.3%, Claude Fable 5 — 80.0% — [BenchLM SWE-bench Pro](https://benchlm.ai/benchmarks/swe-bench-pro)
- **Split/scaffold-disaggregated view**: **61.5% (Muse Spark 1.1, Scale's standardized public set)**; **80.0% (Claude Fable 5, llm-stats vendor aggregate)**; **51.5% (Muse Spark 1.1, Scale's private commercial set)** — [morphllm SWE-bench Pro](https://www.morphllm.com/swe-bench-pro); official public leaderboard at [Scale](https://labs.scale.com/leaderboard/swe_bench_pro_public)

**Terminal-Bench 2.0 (September 2026)**
- Public snapshot leader: **GPT-5.6 Sol — 91.9%**, Claude Mythos 5 — 88.0%, GPT-5.6 Terra — 87.4%; **50 models evaluated** — [tbench.ai leaderboard](https://www.tbench.ai/leaderboard/terminal-bench/2.0); [BenchLM Terminal-Bench 2](https://benchlm.ai/benchmarks/terminal-bench-2); [llm-stats](https://llm-stats.com/benchmarks/terminal-bench-2)
- **Conflict:** the Terminal-Bench paper states frontier models/agents score **<65%** — [arXiv 2601.11868](https://arxiv.org/html/2601.11868v1). The 91.9% figure likely reflects later models and/or a different (stronger, possibly best-of-N) harness. I could not reconcile these because tbench.ai was egress-blocked.

**SWE-bench Multimodal (September 2026)**
- **Claude Mythos Preview — 0.590** leads; top open-weights is **Qwen3.8-27B — 0.386**; only 4 models listed; last updated September 2026 — [BenchLM](https://benchlm.ai/benchmarks/sweMultimodal); [llm-stats](https://llm-stats.com/benchmarks/swe-bench-multimodal)

**Long-Horizon Terminal-Bench**
- **Grok 4.5** best: 0.51 mean partial credit, 13/46 solved — [LHTB](https://zli12321.github.io/LHTB/)

**Independently-verified vs vendor-reported**
- Scale's `swe_bench_pro_public` leaderboard is the *standardized* run (fixed SWE-Agent scaffold) — this is the closest thing to an independent number for Pro — [Scale](https://labs.scale.com/leaderboard/swe_bench_pro_public)
- Artificial Analysis runs its own Terminal-Bench 2.1 and Terminal-Bench Hard evaluations — an independent third-party harness — [Artificial Analysis](https://artificialanalysis.ai/evaluations/terminalbench-2-1)
- HAL ran **21,730 agent rollouts across 9 models × 9 benchmarks** (coding, web nav, science, customer service) at ~**$40,000** total cost, as independent infrastructure — [HAL arXiv 2510.11977](https://arxiv.org/abs/2510.11977)

### Inferences
- The **~19 percentage point gap** between the vendor-aggregate SWE-bench Pro number (80%) and Scale's standardized public-set number (61.5%) is the clearest quantitative evidence available that headline scores are not comparable across harnesses/splits. Any internal decision should use the standardized number.
- Model names appearing in these September 2026 leaderboards (Claude Opus 5 / Mythos 5 / Fable 5 / 5.1, GPT-5.6 Sol / Terra, Muse Spark 1.1, Kimi K3, GLM 5.1, Qwen 3.6-flash, MiniMax M3, Grok 4.5) are all post my training cutoff; I am reporting them only as the sources name them and cannot independently confirm which vendor ships which.

### Gaps
- I could not obtain the **scaffold/harness** attached to the top SWE-bench Verified entries (the 96% Opus 5 figure) — aggregators report model names without harness, which is precisely the criticism HAL levels.
- No September 2026 Aider polyglot top scores retrieved.
- No September 2026 SWE-bench-Live scores retrieved; the site returned no numbers in search summaries.
- No current SWE-Lancer, Commit0, RepoBench, BigCodeBench or LiveCodeBench leaderboard values retrieved.

---

## Q3. Ablations: which scaffold techniques actually move the numbers

### Takeaway
The best-evidenced levers, in rough order of measured effect size, are: **context management strategy (up to +21 pp under tight windows, but compaction can *hurt* by ~15 pp vs truncation in some regimes)**, **adapter/tool-interface design (+54.3 pp in one extreme case)**, **retrieval/localization quality (+4.7 to +6.2 pp)**, **best-of-N with a verifier (+2.1 pp over mean pass@1 in a clean comparison; 59% best@16 vs 71% pass@16 shows how much the selector leaves on the table)**, and **memory (+3.9 to +5.25 pp)**. Notably, **more reasoning-token budget lowered accuracy in 21 of 36 tested settings** — test-time compute is not monotonically good.

### Cited Findings

**Context management / compaction**
- **Same Model, Different Harness** (arXiv 2608.26218): control fed full conversation in time order; treatment mechanically shortened older tool results as context filled. On a tight-window Verified comparison, **169 tasks at a 20,480-token window: mean per-task fail-to-pass fraction rose 28% → 49%, and complete solutions rose 43 → 72** — [arXiv 2608.26218](https://arxiv.org/abs/2608.26218)
- **Truncation beat compaction in a sandwich-placement ablation (12 tasks)**: clean contexts 72% accuracy; bloated-no-intervention 63%; **compaction 48%**; **truncation 57%**; an OpenCode production prototype 28%. Explanation given: compaction must summarize distractor *and* task-critical content and paraphrases the exact problem spec, whereas truncation removes distractor outputs and leaves the statement intact — reported in search summary of [WorkOS](https://workos.com/blog/coding-agent-context-window-compaction-settings) / related compaction literature
- **Self-Compacting Language Model Agents**: pairing a compaction tool with a rubric for *when* to compact beat a no-summarization baseline by **up to +18.1 pp on math and +5 to +9 pp on agentic search** — reported in the same compaction search cluster
- In ReAct loops, tool observations (file contents, command output) **routinely consume 70–80% of the token budget** — [context management literature](https://www.harpaljadeja.com/articles/agent-context-management)
- **"Meta Context Engineering achieved 89.1% on SWE-bench Verified vs 70.7% for hand-engineered baselines"** (+18.4 pp) — [Augment Code single vs multi-agent guide](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai). *Low confidence: vendor blog, no primary citation found.*
- Related primary work: **SWE-Pruner** (self-adaptive context pruning) [arXiv 2601.16746](https://arxiv.org/pdf/2601.16746); **Context Pruning via Multi-Rubric Latent Reasoning** [arXiv 2605.15315](https://arxiv.org/pdf/2605.15315)

**Tool/adapter and edit-tool design**
- **Claw-SWE-Bench**: OpenClaw with a **minimal direct-diff adapter scores 19.1% Pass@1; the full adapter reaches 73.4% with the same GLM 5.1 backbone** — a **+54.3 pp** swing from adapter design alone — [arXiv 2606.12344](https://arxiv.org/html/2606.12344v1)
- Agents have converged on **`str_replace_editor`-style exact string matching**, reflecting "a common discovery that exact string matching is more reliable than line-number-based or unified-diff-based editing for LLM-generated patches" — [Inside the Scaffold, arXiv 2604.03515](https://arxiv.org/pdf/2604.03515)
- Ablations show **replacing diff-based editing with string replacement improves edit success, especially for smaller models with weaker instruction-following** — [arXiv 2604.03515](https://arxiv.org/pdf/2604.03515)
- Diff/search-replace format degrades on "complex files with multiple similar patterns" — [Morph diff format analysis](https://www.morphllm.com/edit-formats/diff-format-explained)
- Historical precedent: **unified diffs made GPT-4 Turbo "3X less lazy"** — [Aider](https://aider.chat/docs/unified-diffs.html)
- Also: **SWE-Edit: Rethinking Code Editing for Efficient SWE-Agent** — [arXiv 2604.26102](https://arxiv.org/pdf/2604.26102)
- A practitioner-facing summary of internal-agent work: "**targeted tool design (e.g. string-replacement edits over full-file rewrites) and layered safety guardrails improved agent reliability more than prompt engineering**" — [Building an Internal Coding Agent at Zup, arXiv 2604.09805](https://arxiv.org/pdf/2604.09805)

**Best-of-N / parallel attempts with a selector**
- **DeepSWE**: **59% pass@1 with Best@16** on SWE-Bench Verified; their **pass@8 = 67%, pass@16 = 71%**. The gap between 59 (selected) and 71 (oracle at N=16) is the **selector's loss: ~12 pp left on the table** — [Agentica](https://x.com/Agentica_/status/1940872568359342129)
- **LLM-as-a-Verifier**: heterogeneous pool of **N=3** candidates sampled from different models (Claude Opus 4.5, Gemini 3 Flash, MiniMax M2.5), with **Gemini 2.5 Flash as verifier** → **78.2% on SWE-Bench Verified vs mean pass@1 of 76.1%** across the pool (**+2.1 pp over the pool mean**, and above every individual model) — [arXiv 2607.05391](https://arxiv.org/pdf/2607.05391)
- **EGSS (Entropy-guided Stepwise Scaling)** with ensemble **K=4**: **73.8% on SWE-Bench-Verified, 64% on SWE-Bench-Lite**, with **~5–10% relative** improvement over other TTS methods — [arXiv 2602.05242](https://arxiv.org/pdf/2602.05242)
- **Agentic Rubrics** under parallel test-time scaling: 54.2% on Qwen3-Coder-30B-A3B and 40.6% on Qwen3-32B, **at least +3.5 pp over the strongest baseline** — [arXiv 2605.14163](https://arxiv.org/pdf/2605.14163)
- Also relevant: **SWE-Replay: Efficient Test-Time Scaling for Software Engineering Agents** — [arXiv 2601.22129](https://arxiv.org/pdf/2601.22129)

**Self-verification / critique / review subagent**
- **Enabling a review subagent yields ~+0.5% in pass@3** on SWE-bench Verified — a strikingly *small* gain — reported in search summary of the best-of-N cluster (source attribution unclear; treat as low confidence)
- **The Verification Horizon: No Silver Bullet for Coding Agent Rewards** — [arXiv 2606.26300](https://arxiv.org/pdf/2606.26300)
- **Can Coding Agents Test Their Own Code?** — [Shiplight](https://www.shiplight.ai/blog/can-coding-agents-test-their-own-code)

**Test-time compute scaling (reasoning budget)**
- **HAL's headline negative result: increased reasoning-token budget *lowered* accuracy in 21 of 36 tested settings** — directly contradicting the assumption that more thinking is better — [HAL arXiv 2510.11977](https://arxiv.org/abs/2510.11977); [ICLR 2026 proceedings PDF](https://proceedings.iclr.cc/paper_files/paper/2026/file/a0928f924a344aaebbb7f6cd8d56e34c-Paper-Conference.pdf)
- **How Inference Compute Shapes Frontier LLM Evaluation** — [arXiv 2606.17930](https://arxiv.org/pdf/2606.17930)

**Retrieval / repo-map / localization**
- **RepoAtlas** (evolving multimodal repository views): **+2.4 points resolve rate** on SWE-bench Verified vs the strongest multimodal-graph baseline, while **reducing input tokens 5.8% and model calls 7.8%**. Ablations: **no refresh costs −4.7 points** resolve; **per-call refresh drops resolve to 51.0%** — i.e. refresh cadence is itself a tuned parameter — [arXiv 2609.16936](https://arxiv.org/html/2609.16936)
- **InfCode-C++**: removing semantic code-intent retrieval drops resolution **25.58% → 19.37%, an absolute −6.21 pp** — [arXiv 2511.16005](https://arxiv.org/pdf/2511.16005)
- **Code Isn't Memory** (structural codebase index inside the agent): within-harness ablation produces "a large localization gain and a statistically separated resolve gain, with no cost penalty per cell and lower cost per solve" — [arXiv 2606.22417](https://arxiv.org/html/2606.22417); [code](https://github.com/TransformerOptimus/supercoder-eval)
- Localization accuracy **strongly correlates with final resolve rate** — [Improving Code Localization with Repository Memory, arXiv 2510.01003](https://arxiv.org/pdf/2510.01003); see also [OrcaLoca arXiv 2502.00350](https://arxiv.org/pdf/2502.00350), [SHERLOC arXiv 2606.24820](https://arxiv.org/pdf/2606.24820), [Reformulate, Retrieve, Localize arXiv 2512.07022](https://www.arxiv.org/pdf/2512.07022)

**Memory / reflection / planning**
- **Structurally Aligned Subtask-Level Memory** (Feb 2026): **structural scaffolding alone gives only +1.0%; the full method gives +3.9%** over baseline — [arXiv 2602.21611](https://arxiv.org/html/2602.21611)
- **Closed-Loop Memory Optimization**: memory-augmented SE agents achieve **absolute gains up to +5.25% success rate and +4.63% error resolution** — [arXiv 2606.05646](https://arxiv.org/pdf/2606.05646)
- **Coupling Planning with Episodic Memory**: coupling the two beats adding either in isolation — [arXiv 2608.06811](https://arxiv.org/html/2608.06811)
- **Counter-evidence**: "From Knowledge to Noise: CTIM-Rover and the **Pitfalls of Episodic Memory** in Software Engineering Agents" — episodic memory can degrade SE agents — [arXiv 2505.23422](https://arxiv.org/pdf/2505.23422)
- (Cross-domain, weaker relevance) APT reports memory +47.3% average and reflection +12.8% — but this is **open-world/Minecraft-style agents, not coding** — [arXiv 2411.17255](https://arxiv.org/pdf/2411.17255)

**Harness evolution as a measurable variable**
- **Don't Blame the LLM** (arXiv 2607.03691): first controlled longitudinal study isolating harness contribution — **model held constant, 35 sequential Qwen Code CLI releases evaluated against 50 stratified SWE-bench Verified tasks**, measuring resolve rate, token consumption and tool calls. Finds harness release velocity exceeding **two releases per day** and that practitioners misattribute harness-caused regressions to the model — [arXiv 2607.03691](https://arxiv.org/abs/2607.03691)

### Inferences
- **Selection is the bottleneck in best-of-N, not generation.** DeepSWE's 59 (best@16) vs 71 (pass@16) means a perfect verifier would add ~12 pp for free. Investment in a verifier — especially an execution-grounded one — has the highest measured headroom of any single technique in this list.
- **Compaction is a risk, not a free win.** The one place it clearly helps is when the context window is genuinely tight (the 20,480-token result). When there's headroom, naive truncation of tool output beat LLM summarization by 9 pp in the sandwich test, because summarization paraphrases the spec.
- **Reasoning-budget scaling should be treated as a hyperparameter to tune per-benchmark, not a dial to max out** — HAL's 21/36 result is the strongest single warning against the "more test-time compute always helps" framing.
- Tool/adapter design and retrieval quality are cheaper and more reliable wins than architectural changes (sub-agents, memory), on the evidence gathered.

### Gaps
- **Linting-on-edit specifically**: I found no controlled ablation measuring the delta from running a linter/type-checker on each edit. The closest is the neuro-symbolic repair paper combining static analysis with test-execution feedback — [arXiv 2507.18755](https://arxiv.org/pdf/2507.18755) — but I could not extract a number.
- **Explicit planning step** as an isolated ablation: no clean pp-delta found for coding agents specifically.
- The "+0.5% pass@3 from a review subagent" figure has unclear provenance; it should not be reported without further verification.
- The "Meta Context Engineering 89.1% vs 70.7%" claim comes from a vendor guide with no traceable primary source.

---

## Q4. Do sub-agent architectures beat single-agent loops?

### Takeaway
No, not on cost-adjusted issue-resolution. The measured cost multiplier for multi-agent is **4–220x** (realistic ~15x, optimized 2–12x) over a single-agent trajectory, and the leaderboards contain both architectures at the top — the reported differentiator is context quality, not agent count. Sub-agents are defensible where sub-tasks are genuinely parallel and need no coordination (e.g. independent specialist review passes).

### Cited Findings
- Baseline: **the average single-agent SWE-bench trajectory is ~48,400 tokens across ~40 steps**. Multi-agent multiplies this by **4–220x**; "realistic multipliers for well-designed multi-agent systems are around **15x**, with optimized configurations still requiring **2–12x** more response tokens" — [Augment Code](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)
- "The SWE-bench Verified leaderboard includes **both single-model and multi-agent approaches among leading systems**... and **context quality still matters more than architecture alone**" — [Augment Code](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)
- Condition where multi-agent is architecturally right: "for specialized cross-cutting review (security, performance, API contract review), multi-agent structures with specialized reviewers per domain are architecturally appropriate **because reviewers do not need to coordinate**"; for standard PR review a single agent with full context performs well — [Augment Code](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)
- "Native scaffolds like Codex CLI and Claude Code capture **sub-agent delegation, planning, and TODO-list operations**, leading to notable improvements over minimal agent scaffolds" — [Inside the Scaffold, arXiv 2604.03515](https://arxiv.org/pdf/2604.03515). *Note: this bundles sub-agents with planning and TODO state, so it does not isolate sub-agents.*
- A review subagent specifically was measured at **~+0.5% pass@3** (low confidence, see Q3) — search summary from the best-of-N cluster
- Relevant primary work not fully retrieved: **Unlocking Model Potentials Through Adaptive Multi-Agent Scaffolding for Efficient Issue Resolution** — [arXiv 2606.25514](https://arxiv.org/pdf/2606.25514); **Scaling Coding Agents via Atomic Skills** — [arXiv 2604.05013](https://arxiv.org/pdf/2604.05013); **Confucius Code Agent: Scalable Agent Scaffolding for Real-World Codebases** — [arXiv 2512.10398](https://arxiv.org/html/2512.10398v5)

### Inferences
- The honest reading of the evidence is that **sub-agent decomposition is primarily a context-management technique in disguise** — it gets fresh, small contexts to sub-tasks. Where a cheaper context strategy (pruning, structural indexing) achieves the same, the sub-agents add cost without adding accuracy.
- The strongest case for sub-agents is **embarrassingly-parallel, non-coordinating** work: N independent review lenses, or N independent solution attempts feeding a selector (which is best-of-N, not decomposition).

### Gaps
- I found **no head-to-head controlled ablation** of the form "same model, same benchmark, single-agent loop vs sub-agent decomposition, with a reported pp delta." The Augment Code guide is a vendor source aggregating others' numbers; I could not trace its 4–220x figure to a primary study.

---

## Q5. Harness vs model: is there controlled evidence?

### Takeaway
Yes, and it is now the best-evidenced claim in this report. **Claw-SWE-Bench measures model choice at 29.4 pp and harness choice at 27.4 pp on the same benchmark** — they are roughly equal in magnitude. Two independent 2026 studies (Claw-SWE-Bench, "Same Model, Different Harness") plus a longitudinal study ("Don't Blame the LLM") converge on the conclusion that model and harness must be reported as a single tested solver.

### Cited Findings
- **Claw-SWE-Bench** (350 instances, 8 languages, 43 repos): across an OpenClaw × nine-model sweep and a five-claw × two-model sweep, **model choice changes Pass@1 by 29.4 pp; harness choice changes it by 27.4 pp under fixed models** — [arXiv 2606.12344](https://arxiv.org/html/2606.12344v1)
- Same paper, per-model harness spreads: with **GLM 5.1**, Pass@1 across five claws ranges **60.9% → 73.4% (12.5 pp spread)**; with **Qwen 3.6-flash**, **38.6% → 66.0% (27.4 pp spread)**. *Weaker models are far more harness-sensitive.* — [arXiv 2606.12344](https://arxiv.org/html/2606.12344v1)
- Same paper: minimal direct-diff adapter **19.1%** vs full adapter **73.4%**, same GLM 5.1 backbone — [arXiv 2606.12344](https://arxiv.org/html/2606.12344v1)
- **Same Model, Different Harness** (arXiv 2608.26218): "one controlled evaluation ran the **same Kimi K3 model through eight agent harnesses with the same 25 tasks, and found pass rates ranging from 88% to 68%**" (**20 pp spread**). Conclusion stated: "coding-agent evaluations should treat the **model and harness together as the tested solver**" — [arXiv 2608.26218](https://arxiv.org/abs/2608.26218)
- **Don't Blame the LLM** (arXiv 2607.03691): model held constant, **35 sequential Qwen Code CLI releases** × 50 stratified SWE-bench Verified tasks; documents that harness updates measurably change resolve rate, token consumption and tool calls, and that practitioners systematically misattribute these regressions to the model — [arXiv 2607.03691](https://arxiv.org/abs/2607.03691); [Zenodo record](https://zenodo.org/records/21460477)
- **HAL** (ICLR 2026): scaffolds "dramatically impact both accuracy and cost, yet comparisons across scaffolds are rare"; leaderboards conflate model, scaffold, and model-scaffold fit — [arXiv 2510.11977](https://arxiv.org/abs/2510.11977)
- HAL's behavioral finding: **agents with identical accuracy scores exhibit vastly different behaviors** — shortcuts, gaming strategies, and costly wrong actions (e.g. using incorrect payment methods) — visible only through log analysis (Docent), not accuracy metrics — [arXiv 2510.11977](https://arxiv.org/abs/2510.11977)
- Practitioner-level corroboration: [Coding Agent Harness Benchmarks: Why the Harness Changes the Score](https://futureagi.com/blog/coding-agent-harness-benchmark/); [Model + Harness = Agent: The Gap Isn't Where You Think](https://dev.to/octoooo/model-harness-agent-the-gap-isnt-where-you-think-3i3h)
- Survey of the design space: [From Question Answering to Task Completion: A Survey on Agent System and Harness Design, arXiv 2606.20683](https://arxiv.org/pdf/2606.20683)

### Inferences
- The "harness vs model" debate resolves to: **they are comparable in magnitude, and they interact.** Harness sensitivity is *inversely* related to model strength (27.4 pp spread on Qwen 3.6-flash vs 12.5 pp on GLM 5.1). If you are building on a frontier model, harness work buys you less than if you are building on a cheaper open-weights model — where harness work can be worth more than a model upgrade.
- Corollary for procurement: **you cannot transfer a published benchmark number to your harness.** The only actionable number is one you measured through your own harness.

### Gaps
- No controlled comparison found that runs the *same frontier* model (e.g. Claude Opus 5 or GPT-5.6) across Claude Code vs Codex CLI vs OpenHands vs Aider on a standardized suite with published numbers. The Claw-SWE-Bench sweeps use GLM 5.1 / Qwen 3.6-flash / OpenClaw-family harnesses.

---

## Q6. Cost and latency vs success rate

### Takeaway
Costs are now large and highly dispersed: ~$10.2 per Terminal-Bench-style task on average, with per-model costs ranging from ~$6 to $70+, and open-weight models showing a **4×–8× cost-effectiveness advantage ($/Pass)** over closed models. The correct denominator is **tokens (or dollars) per issue resolved to threshold**, not per turn; best-of-N multiplies cost linearly while adding single-digit accuracy points.

### Cited Findings
- **Terminal-Bench-class tasks**: models average **228 episodes and 85.1 minutes per task at an estimated $10.2 per task** (costs from per-task token usage and public list prices as of **June 2026**) — [LHTB arXiv 2607.08964](https://arxiv.org/html/2607.08964v1)
- Wide dispersion at similar accuracy: **MiniMax M3 scores 0.39 at ~$6/task, ahead of GPT-5.4 at $28/task** — [arXiv 2607.08964](https://arxiv.org/html/2607.08964v1)
- **Open-weight avg. $17.13/task vs closed-source avg. $70.82/task — a 4×–8× advantage in $/Pass** — [arXiv 2607.08964](https://arxiv.org/html/2607.08964v1)
- Single-agent SWE-bench baseline: **~48,400 tokens / ~40 steps per issue** — [Augment Code](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)
- Multi-agent cost multiplier **4–220x** (realistic ~15x) — [Augment Code](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)
- Best-of-N arithmetic: at a 30–40% single-shot resolve rate, running **5 parallel attempts costs ~$450 per issue — 50% more than the human developer** in the worked example given — [AlphaBytes, The Compute Wall](https://joinalphabytes.substack.com/p/the-compute-wall)
- Per-task costs for common tools span **$0.03 to $2.60**, and "**most of the bill comes from context overhead — system prompts and repo maps — not the code the agent actually writes**" — [Augment Code cost analysis](https://www.augmentcode.com/guides/ai-coding-cost-analysis-agent-token-spend)
- Recommended metric framing: "Cost is **tokens per issue resolved** — manager, sub-manager, auditor and developer summed — not tokens per tick. **The denominator is the issue.**" — [claude-oss issue #1618](https://github.com/Digital-Process-Tools/claude-oss/issues/1618)
- Efficiency ratio to optimize: **(cost per session) / (task success rate)** — [Prefactor](https://prefactor.tech/blog/measuring-what-agents-actually-cost-token-metrics-that-matter)
- Tool observations consume **70–80% of the token budget** in ReAct loops — [context management article](https://www.harpaljadeja.com/articles/agent-context-management)
- HAL's own cost transparency: 21,730 rollouts ≈ **$40,000** (~$1.84/rollout average across 9 benchmarks) — [arXiv 2510.11977](https://arxiv.org/abs/2510.11977)
- Cost-aware ablation example: **RepoAtlas got +2.4 resolve points while *reducing* input tokens 5.8% and model calls 7.8%** — an existence proof that accuracy and cost are not always traded — [arXiv 2609.16936](https://arxiv.org/html/2609.16936)
- Claw-SWE-Bench: "**accuracy and cost are not simply aligned**; comparable SWE-style results require explicit control and disclosure of harness, budget, cost metric, and **cache accounting**" — [arXiv 2606.12344](https://arxiv.org/html/2606.12344v1)
- Further efficiency work: [Efficient Benchmarking of AI Agents, arXiv 2603.23749](https://arxiv.org/pdf/2603.23749); [TraceLab: Characterizing Coding Agent Workloads for LLM Serving, arXiv 2606.30560](https://arxiv.org/pdf/2606.30560); [Cost-Effective Agent Harnesses (ARC-AGI-1), arXiv 2607.06764](https://arxiv.org/pdf/2607.06764)

### Inferences
- Since ~70–80% of tokens are tool observations and most of the bill is context overhead, **the highest-leverage cost work is observation truncation/pruning, not model downgrade** — and it is the same lever that improves accuracy under tight windows (Q3).
- Best-of-N is the clearest case of buying accuracy with linear cost. At N=16 DeepSWE's selected result was 59% vs 71% oracle; at N=3 the LLM-as-a-Verifier gain was +2.1 pp over pool mean. **Under $/pass accounting, N=3 with a good verifier is far more defensible than N=16 with a weak one.**
- **Cache accounting is a real confound** in published cost comparisons (Claw-SWE-Bench explicitly calls this out) — any internal $/pass metric should state whether prompt caching is counted.

### Gaps
- No latency (wall-clock) distribution data found beyond the LHTB 85.1 min/task average.
- No 2026 figures found on how cost/pass has trended over time (i.e. whether $/resolved-issue is falling).

---

## Q7. Real-world productivity effects

### Takeaway
The single best-controlled study (METR's RCT) found a **19% slowdown** for experienced open-source developers in early 2025, and its 2026 follow-up found an **18% slowdown** for the 10 returning developers — but METR **abandoned the design** because developers would no longer work without AI, making a control group impossible. DORA 2026 finds near-universal adoption with productivity and satisfaction gains but **negative effects on delivery throughput and stability**, and Stack Overflow finds adoption rising while trust collapses (3% "highly trust" AI code).

### Cited Findings
- **METR original RCT (early 2025)**: experienced open-source developers took **19% longer** with AI tools; the same developers **estimated they were 20% faster** — a ~39-point perception gap — [METR](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/); [summary](https://letsdatascience.com/blog/developers-thought-ai-made-them-faster-the-data-said-otherwise)
- **METR 2026 follow-up**: bigger study — **57 developers, 143 repositories, 800+ tasks**. For the **10 developers who were also in the original study**, the estimated effect was an **18% slowdown, 95% CI from 38% slower to 9% faster** — [METR: We are Changing our Developer Productivity Experiment Design](https://metr.org/blog/2026-02-24-uplift-update/) (published 2026-02-24)
- **Why the follow-up failed**: data was "too compromised to produce reliable results" — the primary issue was that **developers are now so reliant on AI that they won't work without it**, so a control group could not be maintained. METR states they believe GenAI coding productivity is improving but that they **can no longer measure it reliably with this design** and are reworking their approach — [METR](https://metr.org/blog/2026-02-24-uplift-update/); [Rob Bowley summary](https://blog.robbowley.net/2026/04/04/metrs-developer-productivity-research-2026-update/)
- Critique of substituting surveys for measurement: [Andrew Wegner](https://andrewwegner.com/metr-ai-productivity-study-update.html); participant account: [Domenic Denicola](https://domenic.me/metr-ai-productivity/)
- **DORA State of DevOps 2026**: **90% of respondents use AI at work**; AI adoption "significantly increases individual productivity, flow, and job satisfaction" but **negatively impacts software delivery stability and throughput**; small batch sizes and robust testing remain crucial — [DORA publications](https://dora.dev/research/publications/); [kodus summary](https://kodus.io/en/dora-accelerate-state-of-devops/)
- DORA 2026's central framing: **AI is an amplifier** — it accelerates high-performing orgs and magnifies dysfunction in struggling ones; adoption failure is "**a systems problem, not a tools problem**" — [DORA insights](https://dora.dev/insights/)
- DORA 2026 names the hidden costs explicitly: **heavy verification overhead, skill degradation, integration challenges**, and exposure of **downstream bottlenecks in testing, code review and QA** that cannot handle the accelerated pace — [kodus](https://kodus.io/en/dora-accelerate-state-of-devops/); [Deviniti stats roundup](https://deviniti.com/blog/leadership-teamwork/40-devops-stats-for-2026/)
- **Stack Overflow 2026**: **84% using or planning to use AI**; **trust dropped to 29%, down 11 pp from 2024**; only **3% "highly trust" AI-generated code**; experienced developers are most cautious (**2.6% highly trust, 20% highly distrust**); top frustration for **66%** is "**AI solutions that are almost right, but not quite**" — [Stack Overflow: Closing the developer AI trust gap](https://stackoverflow.blog/2026/02/18/closing-the-developer-ai-trust-gap/); [byteiota](https://byteiota.com/stack-overflow-dev-survey-2026-ai-at-84-trust-at-3/); [Ahmed Atoui](https://ahmedatoui.com/en/articles/stackoverflow-survey-ai-adoption-trust-gap)
- **Agent-specific adoption**: agent usage has **doubled since 2024**, but a **majority (52%) either don't use agents or stick to simpler AI tools**, and **38% have no plans to adopt them** — [Stack Overflow 2026 survey announcement](https://stackoverflow.blog/2026/06/23/the-2026-developer-survey-is-now-open-for-human-developers-only/); [Dev|Journal](https://earezki.com/ai-news/2026-06-23-the-2026-developer-survey-is-now-open-for-human-developers-only/)

### Inferences
- METR's finding that a control group is **no longer constructible** is itself a significant datum: it means the honest answer to "does AI make developers faster in 2026?" is **unmeasured, not measured-positive**. Anyone citing productivity gains in 2026 is citing self-report or observational data, not an RCT.
- DORA's throughput/stability *decline* alongside satisfaction *increase* is consistent with METR's perception gap: developers feel faster while the system gets slower. Both point at **verification cost** as the mechanism — which connects directly to the benchmark critique in Q1 (agents produce patches that pass tests but don't solve the problem).
- The 66% "almost right, but not quite" frustration is the human-facing version of UTBoost's 15.7% false-pass rate.

### Gaps
- METR has not, as far as I found, published a replacement design or new results since the 2026-02-24 post.
- I did not find full 2026 Stack Overflow survey *results* — the 2026 survey opened 2026-06-23 and several cited figures (84%, 29%, 3%) trace to 2025 data or to the February 2026 trust-gap post rather than to a completed 2026 dataset. **Treat the 84%/29%/3% figures as 2025-survey-derived unless verified.**
- No 2026 controlled field experiment other than METR's was found.

---

## Q8. How to build an internal eval set in 2026

### Takeaway
The consistent 2026 recommendation is: **replay your own merged PRs** (roughly the last 50) as a golden set, score on multiple dimensions rather than pass/fail alone, keep the oracle hidden from the agent, and run it weekly in CI rather than quarterly. The "Building to the Test" result makes **oracle hiding** the single most important design decision — agents that can see the tests will satisfy them without delivering the feature.

### Cited Findings
- Core recipe: "**A 70% SWE-bench Verified score doesn't survive contact with your repo.** Build a **golden-PR replay from your last 50 merged PRs**, instrument the agent with tracing, and score the run on five dimensions: **golden-PR replay, tool-call correctness, multi-file coherence, plan coherence, and rollback discipline**" — [Evaluating Coding Agents 2026: A Five-Dimension Eval](https://futureagi.com/blog/evaluating-coding-agents-2026/)
- Cadence: "**Run the replay weekly.** Evaluation frameworks deliver value only when integrated into daily development, not quarterly exercises" — [futureagi](https://futureagi.com/blog/evaluating-coding-agents-2026/)
- Metric families for tool-calling/planning agents: **tool-calling evaluation** (right tools, right inputs, right number of steps), **plan quality** (complete, realistic, efficient — "a bad plan can doom the trajectory before the first tool call"), **outcome evaluation**, **custom criteria**, **reasoning evaluation** — [Confident AI: LLM Agent Evaluation Metrics in 2026](https://www.confident-ai.com/blog/llm-agent-evaluation-complete-guide); [Galileo](https://galileo.ai/blog/agent-evaluation-framework-metrics-rubrics-benchmarks)
- "Most internal evals use **custom assertions** such as '*did the agent parallelize tool calls?*'" — [Confident AI](https://www.confident-ai.com/blog/llm-agent-evaluation-complete-guide)
- **Hide the oracle**: agents scored near-perfect against a visible 222-test oracle while shipping a dead library; the paper names this "building to the test" / "validation self-awareness" — [arXiv 2606.28430](https://arxiv.org/abs/2606.28430); practitioner framing at [DevAssure](https://www.devassure.io/blog/ai-coding-agents-gaming-their-own-tests/)
- **Augment your own tests before trusting them**: UTBoost's method (test augmentation to catch false passes) is directly transferable — 15.7–28.4% of "passing" patches were wrong under stronger tests — [arXiv 2506.09289](https://arxiv.org/abs/2506.09289); see also [Mutation-Guided Diagnosis and Augmentation of Regression Suites, arXiv 2604.01518](https://arxiv.org/html/2604.01518)
- **Benchmark construction rigor**: [Establishing Best Practices for Building Rigorous Agentic Benchmarks, arXiv 2507.02825](https://arxiv.org/pdf/2507.02825)
- **Log/trace analysis beats accuracy alone**: HAL used Docent log analysis to surface shortcuts, gaming, and systematic failure modes invisible to accuracy metrics, in agents with *identical* accuracy — [arXiv 2510.11977](https://arxiv.org/abs/2510.11977)
- **Report harness, budget, cost metric and cache accounting** alongside any score, or the number is not comparable — [Claw-SWE-Bench arXiv 2606.12344](https://arxiv.org/html/2606.12344v1)
- LangChain's practitioner account of eval construction for agents: [How we build evals for Deep Agents](https://www.langchain.com/blog/how-we-build-evals-for-deep-agents)
- Real internal-agent case study with lessons: "technical model quality alone is insufficient — **tool design, safety enforcement, state management, and human trust calibration are equally decisive**" — [Building an Internal Coding Agent at Zup, arXiv 2604.09805](https://arxiv.org/pdf/2604.09805)
- Interactive/human-in-the-loop evaluation needs its own methodology: [Interactive Evaluation Requires a Design Science, arXiv 2605.17829](https://arxiv.org/pdf/2605.17829)
- Real-user trajectory data as an eval source: [SWE-chat: Coding Agent Interactions From Real Users in the Wild, arXiv 2604.20779](https://arxiv.org/html/2604.20779v1)
- Failure taxonomy framework: [ClayBuddy: A Framework, Evaluation & Mitigation of Coding Agent Failures, arXiv 2606.19380](https://arxiv.org/pdf/2606.19380)

### Inferences
- A defensible 2026 internal eval design, synthesizing the above:
  1. **Golden-PR replay** from your own recent merged PRs (~50), refreshed rolling so it stays contamination-free by construction.
  2. **Hidden oracle** — the agent never sees the grading tests; grade with a suite the agent could not read.
  3. **Augment the oracle** (mutation testing / UTBoost-style) before trusting a pass, because your repo's own tests are as insufficient as SWE-bench's.
  4. **Score multi-dimensionally**: resolve, tool-call correctness, multi-file coherence, plan coherence, rollback discipline — plus **$/pass and tokens/pass with cache accounting stated**.
  5. **Trace analysis** on a sample, to catch shortcuts and gaming that accuracy hides.
  6. **Pin and version the harness** — given the 27.4 pp harness effect and >2 releases/day velocity, an eval that doesn't record the harness commit is measuring noise.
  7. Run it **weekly in CI**, not quarterly.
- Because harness sensitivity is highest for weaker models, teams on open-weights models should budget proportionally more eval effort on harness variants than on model swaps.

### Gaps
- Recommended **minimum sample size** for an internal eval set: no rigorous guidance found. The "50 PRs" figure is a vendor blog heuristic, not a power analysis. Note that the harness studies used 25–169 tasks and the "Don't Blame the LLM" study used 50 stratified tasks, which suggests ~50–170 is the working range in the literature — but this is my inference, not a sourced recommendation.
- No sourced guidance found on how to handle **flaky tests** in internal agent evals, which is likely to dominate variance in a real repo.

---

## Overall source-quality note

- **Strongest evidence** (controlled, primary, quantitative): Claw-SWE-Bench (2606.12344), Same Model Different Harness (2608.26218), Don't Blame the LLM (2607.03691), HAL (2510.11977, ICLR 2026), UTBoost (2506.09289), METR (2025 RCT + 2026-02-24 update), Building to the Test (2606.28430), RepoAtlas (2609.16936).
- **Weakest evidence** (aggregator or vendor, unverifiable here): all September 2026 leaderboard *values* (benchlm.ai, llm-stats.com, morphllm.com, codeant.ai, steel.dev), the Augment Code multi-agent cost multipliers, the "Meta Context Engineering 89.1%" claim, and the "+0.5% pass@3 review subagent" figure.
- **Direct conflict flagged**: Terminal-Bench paper says frontier <65%; September 2026 leaderboards say 91.9%. Unresolved.
- **Unverifiable model identities**: Claude Opus 5 / Mythos 5 / Fable 5 / 5.1, GPT-5.6 Sol / Terra, Muse Spark 1.1, Kimi K3, GLM 5.1, Qwen 3.6-flash, MiniMax M2.5/M3, Grok 4.5 are all post my training cutoff and are reported only as the sources name them.
