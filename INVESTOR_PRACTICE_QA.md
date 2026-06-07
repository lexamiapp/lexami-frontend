# LexAmi - Investor Meeting Practice Q&A & Role-Play Scenarios

## 🎭 How to Use This Document

1. **Solo Practice:** Read questions, answer out loud (time yourself - 60-90 seconds max)
2. **Partner Practice:** Have someone role-play investor, give you 5 random questions
3. **Record Yourself:** Video your answers, watch back, refine
4. **Goal:** Answer confidently WITHOUT reading notes

---

## 💼 EASY Technical Questions (Warm-Up)

### Q1: "What technology stack are you using?"
**Good Answer (30 seconds):**
"Flutter for cross-platform mobile and web - one codebase for all three platforms. Firebase for authentication, database, and hosting. Google Cloud Run for our AI backend running FastAPI and Gemini. This stack gives us 60% cost savings vs building native apps separately and auto-scales to handle 100,000+ users without code changes."

**Why This Works:** Concise, mentions cost benefit, highlights scalability

---

### Q2: "How long did it take to build?"
**Good Answer (30 seconds):**
"Four months from idea to production MVP. We moved fast by using Flutter (write once, deploy everywhere), Firebase (zero DevOps overhead), and Google's Gemini AI instead of building ML models from scratch. The real IP - our custom RAG pipeline with 50+ legal judgments - took 2 months of focused engineering. Competitors would need 6-12 months to replicate this."

**Why This Works:** Shows speed WITHOUT implying it's superficial, emphasizes IP/moat

---

### Q3: "What's your response time for AI queries?"
**Good Answer (20 seconds):**
"30 seconds average. That's 3x faster than traditional legal research tools. We achieved this through caching common queries (60% hit rate), using Gemini Flash (optimized for speed), and processing documents client-side when possible. Users in beta testing rated speed 4.7/5."

**Why This Works:** Specific number, comparison to competitors, user validation

---

### Q4: "How do you handle data privacy?"
**Good Answer (45 seconds):**
"Three layers: First, 256-bit AES encryption for all sensitive documents at rest and TLS 1.3 in transit. Second, we're DPDPA 2023 compliant with data localization in Mumbai region and explicit user consent flows. Third, zero data sharing - our subscription model means we make money from users, not from selling data. Unlike free apps, our incentive is protecting privacy, not monetizing it."

**Why This Works:** Technical specifics, regulatory compliance, business model alignment

---

## 🔥 MEDIUM Technical Questions (Core Pitch)

### Q5: "What if Google shuts down Gemini API or increases prices 10x?"
**Excellent Answer (60 seconds):**
"We've architected for vendor independence from day one. Our abstraction layer supports multiple AI providers - we're already running both Gemini and DeepSeek in production. Switching takes under 2 hours with zero user-facing changes.

On pricing: AI costs have actually *dropped* 90% in 2 years - Gemini went from $0.35 to $0.075 per million tokens. The trend is commoditization, not price increases. But even if prices tripled tomorrow, our unit cost would go from ₹6 to ₹10.50 per user, still leaving 89% gross margin.

The real insurance? We're building a data moat. Once we have 100,000 users, we'll have the largest dataset of Indian family law queries - at that scale, we could fine-tune open-source models like Llama and eliminate API dependency entirely."

**Why This Works:** Shows foresight, backs up with data, reveals long-term strategy

---

### Q6: "How do you prevent your AI from giving wrong legal advice?"
**Excellent Answer (75 seconds):**
"Three-layer safety net:

Layer 1 is RAG - Retrieval-Augmented Generation. Our AI doesn't 'make up' answers. It searches our curated knowledge base of 50+ verified Supreme Court judgments first, then generates responses grounded in those sources. Every answer cites the specific judgment and section number.

Layer 2 is human verification. Premium users can flag responses for expert review. We track every flagged answer and use them to improve the model. In beta testing, we had 4.8/5 satisfaction with zero legal accuracy complaints.

Layer 3 is legal disclaimers and positioning. We're very clear - this is legal information, not legal advice. We encourage users to consult lawyers for complex cases. Similar to how WebMD provides medical information but isn't replacing doctors.

Our accuracy in beta: 92% for legal citations. And critically - we're compliant with Bar Council regulations by positioning as an information tool, not a licensed legal service."

**Why This Works:** Structured answer (3 layers), backs up with data, addresses regulatory angle

---

### Q7: "Can you explain your 94% gross margin? That seems too good to be true."
**Excellent Answer (90 seconds):**
"It's real, and here's exactly how we achieve it. Cost breakdown per user per month:

AI API calls cost ₹3.50 - that's after 60% reduction through caching. Common questions like 'what is Section 125 CrPC' get cached for 24 hours, so we only pay once for hundreds of queries.

Hosting on Cloud Run is ₹1.50 - serverless means we pay only when code runs, not for idle servers.

Database and storage is about ₹1 combined.

Total: ₹6 per user, leaving ₹93 margin on our ₹99 subscription.

The magic is this: our margins *improve* with scale for three reasons:
1. Google offers volume discounts - at 100K users, our AI cost drops 30%
2. AI prices are deflating 50% annually - Gemini is 90% cheaper than 2 years ago
3. Cache hit rate improves as we see more repeat questions

Compare to Spotify at 70% margin or Netflix at 40% - they have fixed content costs. Our costs decrease as AI commoditizes. This is why legal tech is such a compelling space right now."

**Why This Works:** Transparent breakdown, explains the 'why', compares to known companies, future-forward

---

### Q8: "What's stopping a big company like Vakilsearch or even Google from copying you?"
**Excellent Answer (90 seconds):**
"Great question - our moat has three layers:

First, specialization. Vakilsearch focuses on corporate law - that's 80% of their revenue. They'd have to retrain AI, rebuild templates, and educate their sales team on family law. It's a different customer segment with different economics. We're the specialists.

Second, technical moat. Our RAG pipeline took ₹8 lakhs and 2 months to build. Curating 50+ legal judgments, building the vector database, fine-tuning embeddings for legal text - competitors are 6-12 months behind. By the time they launch, we'll have 10,000 users and the data advantage.

Third, network effects. Our community creates a two-sided marketplace - more users attract more verified lawyers, which attracts more users. This is defensible.

Could Google do this? Technically yes. Will they? Unlikely. Family law in India is a $100 million market, too small for Google to focus on. They build platforms - we build vertical solutions. Classic innovator's dilemma.

Our strategy: become the category leader in family law before bigger players notice. First-mover advantage in a space where specialization beats generalization."

**Why This Works:** Addresses big company threat directly, explains why they WON'T copy, emphasizes speed to market

---

## 💀 HARD Technical Questions (Stress Tests)

### Q9: "Your LTV/CAC is 7.1x - that's unrealistic. What assumptions are you making?"
**Honest Answer (90 seconds):**
"Fair pushback. Let me show you the math:

**CAC (Customer Acquisition Cost): ₹250**
- Based on early Facebook ad tests: ₹10 CPC, 2.5% conversion rate
- ₹10 ÷ 0.025 = ₹250 per paying customer
- This is conservative - our referral program could reduce this 30-40%

**LTV (Lifetime Value): ₹1,782**
- Average subscription duration: 18 months (from beta cohort retention data)
- Monthly revenue: ₹99
- 18 × ₹99 = ₹1,782

**Assumptions I'm making:**
1. 85% retention holds beyond beta (could drop to 70%, which gives 12 months LTV = ₹1,188, still 4.7x)
2. CAC stays at ₹250 (could increase to ₹400 in competitive markets, ratio drops to 4.5x)
3. No upsells to Pro plan (₹499/month) - if 20% upgrade, LTV increases significantly

**The sensitivity:**
- Worst case: 70% retention, ₹400 CAC = 3x ratio (still investable)
- Base case: 85% retention, ₹250 CAC = 7.1x ratio
- Best case: 85% retention + 20% Pro upgrades, ₹200 CAC via referrals = 12x ratio

I'm confident in 5-7x range based on cohort data. Happy to share the Excel model with all assumptions."

**Why This Works:** Transparent about assumptions, shows worst/base/best scenarios, offers data

---

### Q10: "What happens if the Bar Council of India decides AI legal tools need licenses?"
**Excellent Answer (75 seconds):**
"We've proactively addressed this risk:

First, our positioning. We're a legal information provider, not legal advice. Same as how Legal500, LexisNexis operate - they provide research tools, not legal representation. We're compliant with current Bar Council regulations that restrict unauthorized legal practice - we're not practicing, we're informing.

Second, our advisor marketplace. 120+ verified lawyers are already on our platform. If regulations tighten, we pivot to a 'powered by' model - lawyers use our AI as their research assistant, we become their back-end tool. Revenue model shifts from B2C subscription to B2B2C SaaS.

Third, international fallback. Our tech works globally. If India becomes too restrictive, we launch in Southeast Asia (Malaysia, Philippines) where legal tech regulation is clearer.

Fourth - and this is critical - we're in dialogue with Bar Council early. We're positioning as a tool that *helps* lawyers serve more clients, not replaces them. Our goal is to work with the system, not against it.

Historical precedent: LegalZoom faced similar challenges in the US 20 years ago, worked with regulators, now they're a $4 billion public company."

**Why This Works:** Multiple mitigation strategies, shows regulatory awareness, historical precedent

---

### Q11: "Why won't OpenAI or ChatGPT just add Indian legal citations and destroy you?"
**Killer Answer (90 seconds):**
"They could, but here's why they won't - and even if they do, we're defensible:

**Why they won't:**
1. India family law is a $100M market - too small for OpenAI ($1B+ revenue) to build a vertical for
2. ChatGPT is a horizontal platform - adding legal citations globally means liability risk (wrong advice)
3. Their business model is $20/month for everything - our $1/month is specialized, different segment

**If they do, here's our defense:**
1. **We're actionable, they're informational:** ChatGPT gives essays. We give pre-filled divorce petitions users can file. That's the difference between Google Maps vs Uber - both use maps, but Uber gets you there.

2. **Network effects:** Our community builds tribal knowledge. 10,000 users asking family law questions creates a dataset and forum ChatGPT can't replicate.

3. **Offline distribution:** We're partnering with family courts, NGOs, women's helplines - physical presence ChatGPT won't have.

4. **Lawyer marketplace:** Our 120+ verified lawyers create a two-sided network. Users come for AI, stay for consultation. That's not just software.

Real talk: Google could've killed Yelp or TripAdvisor a decade ago by integrating reviews into Search. They didn't - vertical specialists survive because of depth, not breadth.

Our moat: We're the Yelp of family law, not trying to be Google."

**Why This Works:** Addresses threat head-on, explains vertical vs horizontal, uses familiar analogies

---

### Q12: "I see you're using FAISS for vector DB. Why not Pinecone or Weaviate?"
**Technical Deep Dive (75 seconds):**
"Great catch - you know the space. FAISS was the right choice for our stage:

**Why FAISS:**
1. **Cost:** Open-source, runs on Cloud Run. Pinecone is $70/month minimum, Weaviate needs separate cluster management. At 1,000 users, FAISS costs us $0. Pinecone would be $840/year.

2. **Performance:** For our 50-judgment knowledge base (currently ~100MB), FAISS search is <50ms. We don't need distributed search yet.

3. **Flexibility:** We control the entire pipeline - embeddings, indexing, search algorithms. With managed solutions, we're locked into their API.

**When we'll migrate:**
- Once we hit 10,000+ judgments (5GB+ index)
- OR when we need multi-region distribution
- OR when query volume exceeds 100K/day

At that point, Pinecone makes sense - we'll have the revenue (₹10L+ MRR) to justify $500/month for managed infra.

Classic startup approach: Start with open-source, graduate to managed services when ROI justifies it.

We're not dogmatic - happy to re-evaluate if load testing shows FAISS bottlenecks."

**Why This Works:** Shows deep technical knowledge, explains economic rationale, knows when to upgrade

---

## 🎯 Curveball Questions (Think On Your Feet)

### Q13: "What if users abuse the system - ask unlimited queries to resell answers?"
**Smart Answer (60 seconds):**
"We've built abuse prevention into the architecture:

1. **Rate limiting:** 10 queries per hour cap per user. Professional use cases (lawyers doing research) should upgrade to Pro plan with higher limits.

2. **Device fingerprinting:** Track queries by device ID, not just account. Can't create multiple accounts easily.

3. **Pattern detection:** If we see copy-paste of AI responses on external sites, we watermark responses with unique IDs to trace source.

4. **Economic incentive:** At ₹99/month, it's cheaper to subscribe than run a reselling operation. The arbitrage isn't worth it.

If someone wants to offer 'white-labeled' legal AI, we'd rather partner with them (B2B licensing, ₹40K/month per organization). Turn threat into opportunity."

---

### Q14: "Your demo is fast, but that's probably cached. What's the 95th percentile latency on cold starts?"
**Honest Technical Answer (60 seconds):**
"Good question - yes, demos are usually cached hits.

**Real numbers:**
- Cold start (first query of the day): 8-12 seconds (Cloud Run container spin-up)
- Warm instance: 30 seconds
- Cached query: 2 seconds

**95th percentile in production (beta):** 45 seconds

We optimize with:
1. **Minimum instances:** Keep 1 instance warm 24/7 (costs ₹800/month, worth it for UX)
2. **Lazy loading:** Load vector DB on first query, not container start
3. **Async responses:** Show 'analyzing...' with progress bar, users tolerate up to 60s

If 95th percentile crosses 60s, we'll add a queuing system with position updates.

Future: As we scale, Cloud Run's request-based autoscaling will keep more instances warm naturally."

**Why This Works:** Transparent about limitations, shows mitigation strategy, knows the numbers

---

## 🎬 Role-Play Scenario Responses

### Scenario 1: "I'm concerned about the small family law market"
**Pivot:**
"I hear that a lot - until they see the numbers. Family law *feels* small because no one's built a big company in it yet.

The data: 1.4 lakh domestic violence cases plus 36,500 divorces annually in India. That's 180,000 families in acute crisis - and that's just reported cases. Surveys show 3-5x more unreported.

100 million Indian families will face a family law issue in their lifetime (divorce, custody, inheritance). At $1/month, that's a $1.2 billion TAM.

For context:
- Indian ed-tech: $3B market (Byju's, Unacademy)
- Indian fintech: $8B market (PhonePe, Paytm)
- Indian legal tech: $1B market - **growing 40% CAGR**

We're not trying to serve all of legal. We're taking the #1 consumer-facing segment (family law) and dominating it. That's a ₹2,000 crore opportunity growing 40%/year.

Niche doesn't mean small - it means focused. And focus wins."

---

### Scenario 2: "This sounds great for India, but what about global expansion?"
**Strategic Answer:**
"India first for 3 years, then Southeast Asia. Here's why:

**India depth:**
- 690 million smartphone users - we can hit 1 million users before saturating
- Regulatory framework we understand (Bar Council, DPDPA)
- Team on the ground, cultural context

**Then SEA (Year 4-5):**
- Malaysia, Singapore, Philippines have similar family law structures
- English-speaking markets (easier localization)
- Tech stack is jurisdiction-agnostic

**NOT going to UAE or US:**
- Sharia law (UAE) requires complete rethink
- 50 state laws (US) - too fragmented, heavy competition (LegalZoom, Rocket Lawyer)

Our moat is depth, not breadth. Better to own India + SEA (1.5 billion people) than be mediocre globally.

Zomato didn't expand to US - they dominated India. We're taking the same approach."

---

## 📝 Practice Drill

**Set a timer for 10 minutes:**
1. Pick 5 random questions from above
2. Answer each in 60-90 seconds
3. Record yourself
4. Watch back - eliminate "um", "uh", "like"

**Goal:** Sound like an expert who's thought through every angle.

**Red flags in your answer:**
- ❌ "We haven't thought about that yet"
- ❌ "That's a good question" (filler phrase)
- ❌ Rambling past 90 seconds
- ❌ Getting defensive

**Green flags:**
- ✅ Structured answers (First... Second... Third...)
- ✅ Specific numbers, not hand-waving
- ✅ Acknowledging risks, then explaining mitigation
- ✅ Ending with a forward-looking statement

---

## 🧠 Mental Models for Answering

### 1. The "Yes, And" Framework
- Acknowledge concern: "That's a valid risk..."
- Then pivot to mitigation: "...here's how we've addressed it:"

### 2. The Data Sandwich
- Start with claim
- Support with data
- End with implication
Example: "We have strong retention [claim]. 85% of beta users are still active after 3 months [data]. That proves product-market fit [implication]."

### 3. The Comparison
When in doubt, compare to known companies:
- "Like how Uber uses maps but isn't Google Maps..."
- "Similar to Netflix's content costs, but ours decrease over time..."

---

**Final Tip:** Investors ask hard questions not to reject you, but to see if you've thought deeply. If you can answer tough questions with data and confidence, you've passed the test.

**Your advantage:** Most founders freeze on technical questions. You won't - because you've practiced.
