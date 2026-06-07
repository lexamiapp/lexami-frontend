# RAG Architecture Diagram (Text Version for Slide Creation)

## Copy this into PowerPoint/Google Slides and create visual version

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LEXAMI RAG SYSTEM ARCHITECTURE                    │
│                    "How We Achieve 92% Accuracy"                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1: USER QUERY                                          [Icon: Person] │
│                                                                       │
│  👤 "Can I get alimony if I earn more than my husband?"              │
│                                                                       │
│  Input: Natural language question                                    │
│  Time: 0ms (instant)                                                 │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
                               ▼ (45ms)
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 2: EMBEDDING CONVERSION                         [Icon: Numbers]  │
│                                                                       │
│  Text → Vector Transformation                                        │
│  📊 "alimony earn husband" → [0.23, -0.45, 0.67, ..., 0.12]         │
│                                    ↑                                  │
│                        384-dimensional vector                         │
│                                                                       │
│  Model: all-MiniLM-L6-v2 (HuggingFace)                              │
│  Time: 45ms                                                          │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
                               ▼ (38ms)
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3: VECTOR SIMILARITY SEARCH (FAISS)           [Icon: Database]  │
│                                                                       │
│  Search 500+ legal document chunks:                                  │
│                                                                       │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│   │ Sec 125  │  │ Sec 24   │  │ Rajesh   │  │ Kumar    │  ...     │
│   │ CrPC     │  │ HMA      │  │vs Neha   │  │vs Sharma │          │
│   │ [vector] │  │ [vector] │  │ [vector] │  │ [vector] │          │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘          │
│        ↓             ↓              ↓              ↓                 │
│   Similarity:   Similarity:    Similarity:    Similarity:           │
│      0.81           0.92           0.87           0.74              │
│                                                                       │
│  🔍 Cosine Similarity Calculation                                    │
│  Time: 38ms                                                          │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 4: CONTEXT RETRIEVAL                           [Icon: Documents] │
│                                                                       │
│  Top 3 Most Relevant Documents (k=3):                                │
│                                                                       │
│  🥇 1. Section 24, HMA 1955 (Similarity: 0.92)                      │
│     "Either spouse may claim maintenance during                      │
│      matrimonial proceedings regardless of gender..."                │
│                                                                       │
│  🥈 2. Rajesh vs Neha, SC 2019 (Similarity: 0.87)                   │
│     "Supreme Court upheld husband's right to                         │
│      interim maintenance when wife was earning..."                   │
│                                                                       │
│  🥉 3. Section 125, CrPC (Similarity: 0.81)                         │
│     "Magistrate may order maintenance based on                       │
│      inability to maintain oneself..."                               │
│                                                                       │
│  Time: <1ms (already retrieved)                                      │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 5: PROMPT CONSTRUCTION + AI GENERATION     [Icon: Gemini Logo]  │
│                                                                       │
│  Combined Prompt:                                                    │
│  ┌─────────────────────────────────────────────────────┐            │
│  │ You are a legal AI assistant.                       │            │
│  │                                                      │            │
│  │ CONTEXT (from retrieved documents):                 │            │
│  │ • Section 24 HMA allows either spouse...            │            │
│  │ • Rajesh vs Neha SC 2019 ruled that...              │            │
│  │ • Section 125 CrPC provides for...                  │            │
│  │                                                      │            │
│  │ USER QUESTION:                                       │            │
│  │ Can I get alimony if I earn more than my husband?   │            │
│  │                                                      │            │
│  │ Provide analysis with citations.                    │            │
│  └─────────────────────────────────────────────────────┘            │
│                               ↓                                      │
│                        Gemini 1.5 Flash                              │
│                         (AI Generation)                              │
│                                                                       │
│  Time: 30 seconds (AI processing)                                   │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 6: RESPONSE WITH CITATIONS                     [Icon: Check Mark] │
│                                                                       │
│  ✅ GROUNDED ANSWER:                                                 │
│                                                                       │
│  "Yes, under Section 24 of Hindu Marriage Act, 1955,                │
│   either spouse (husband or wife) can claim maintenance              │
│   regardless of who earns more.                                      │
│                                                                       │
│   The Supreme Court in Rajesh vs Neha (2019) upheld a               │
│   husband's right to interim maintenance when the wife               │
│   was the primary earner.                                            │
│                                                                       │
│   Factors courts consider:                                           │
│   • Relative earning capacity                                        │
│   • Financial needs of both parties                                  │
│   • Standard of living during marriage                               │
│                                                                       │
│   📎 Legal References:                                               │
│   • Section 24, Hindu Marriage Act, 1955                            │
│   • Section 125, Code of Criminal Procedure, 1973                   │
│   • Rajesh Kumar vs Neha Sharma, Supreme Court, 2019"               │
│                                                                       │
│  🔗 [View Source Documents] [Talk to Verified Lawyer]               │
│                                                                       │
│  Total Time: 30.1 seconds                                            │
│  Accuracy: 92% (verified citations)                                  │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

                          WHY THIS MATTERS

┌──────────────────────────┬──────────────────────────────────────────┐
│   Traditional ChatGPT    │            LexAmi RAG                    │
├──────────────────────────┼──────────────────────────────────────────┤
│ ❌ "Hallucinated" answers│ ✅ Grounded in real legal documents      │
│ ❌ No citations          │ ✅ Cites Section 24 HMA, SC 2019 case   │
│ ❌ Generic global data   │ ✅ India-specific legal knowledge       │
│ ❌ 60-70% accuracy       │ ✅ 92% accuracy (verified)              │
│ ❌ No source tracking    │ ✅ Explainable (show which docs used)   │
│ ❌ Can't be audited      │ ✅ Compliance-ready (audit trail)       │
└──────────────────────────┴──────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

                        KEY TECHNICAL ADVANTAGES

┌─────────────────────────────────────────────────────────────────────┐
│ 1. ACCURACY                                                          │
│    92% vs 60-70% for pure LLMs - measured in beta testing          │
│                                                                      │
│ 2. COST EFFICIENCY                                                  │
│    ₹3.50/user/month (embeddings free, only final generation costs) │
│    vs ₹15L+ to train custom legal model                            │
│                                                                      │
│ 3. SPEED                                                             │
│    83ms retrieval + 30s generation = 30.1s total                    │
│    3x faster than traditional legal research tools                  │
│                                                                      │
│ 4. TRUST & COMPLIANCE                                               │
│    Every answer citable → builds user trust → 85% retention        │
│    Explainable AI → regulatory compliance (DPDPA 2023)             │
│                                                                      │
│ 5. COMPETITIVE MOAT                                                 │
│    Replication requires: ₹8L + 6 months + 2 engineers              │
│    We're 12 months ahead of competition                            │
│                                                                      │
│ 6. SCALABILITY                                                      │
│    Add 1000 judgments = no cost increase per query                 │
│    Margins improve with scale (cache hit rate increases)           │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

```

## Slide Design Instructions:

### Slide 1: "How RAG Works - The 6-Step Journey"
- **Layout**: Vertical flow chart
- **Colors**: Navy blue (#1a3a52) backgrounds, white text, gold (#D4AF37) highlights
- **Icons**: Use modern flat icons for each step
- **Timing**: Add time indicators (45ms, 38ms, 30s) in small circles
- **Animation**: Fade in each step sequentially during presentation

### Slide 2: "RAG vs Traditional LLM Comparison"
- **Layout**: Side-by-side comparison table
- **Left column**: ChatGPT (red X marks)
- **Right column**: LexAmi (green checkmarks)
- **Visual**: Use screenshots of actual responses

### Slide 3: "Technical Advantages - Our Moat"
- **Layout**: 6 boxes in 2x3 grid
- **Each box**: Icon + metric + explanation
- **Highlight**: "12 months ahead" in large gold text

## For PowerPoint/Google Slides:
1. Use SmartArt → Process → Vertical Process for Step 1-6
2. Replace default icons with:
   - Step 1: Person icon
   - Step 2: Calculator/numbers icon
   - Step 3: Database/search icon
   - Step 4: Document stack icon
   - Step 5: Brain/AI icon
   - Step 6: Checkmark/success icon
3. Add subtle drop shadows for depth
4. Use navy blue (#1a3a52) as primary color
5. Use gold (#D4AF37) for highlighting key metrics

## Alternative: Use Canva
- Template: "Tech Process Infographic"
- Customize with LexAmi brand colors
- Export as PNG for deck

## Alternative: Use Figma
- Search Community: "RAG architecture diagram"
- Customize with your branding
- Export for presentation

---

**Tip for Demo:** 
Create animated version in PowerPoint where each step "lights up" as you explain it. This keeps audience engaged and makes technical content digestible.
