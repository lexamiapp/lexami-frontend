# LegalSathi (Nyay Mitra) - 6,000 User Launch Strategy

Launching with **6,000 users** immediately moves you out of "Hobby App" territory into "High-Traffic Startup" territory.

## 🚨 The Risk: The "Day 1 Crash"
If 6,000 users try to use the app at the same time (e.g., after a press release or viral post), your current single server **will crash**.
*   **Why?** If 500 people click "Analyze" at once, and each analysis takes 5 seconds, the 501st person has to wait 2500 seconds. They will get a "Timeout Error."

## 🛠️ The Fix: "Serverless" Architecture (Auto-Scaling)
You **must** move away from a single VPS (like testing on localhost) to **Serverless**.

### Recommended Stack for 6k Users:
1.  **Compute: Google Cloud Run** (or AWS Lambda)
    *   **Magic:** It automatically creates copies of your server.
    *   1 User = 1 Server copy.
    *   100 Concurrent Users = It instantly spins up 100 Server copies.
    *   **Cost:** You only pay when code is running.

2.  **Database: Supabase Pro / Firebase Blaze**
    *   Free tiers usually limit you to ~500 concurrent connections. You will hit this on Day 1.
    *   **Upgrade:** $25/month plan handles 6,000 users easily.

3.  **AI Quotas (CRITICAL)**
    *   Even "Paid" API keys have limits (e.g., 60 requests per minute).
    *   **Action:** You must apply for a **Quota Limit Increase** with Google/DeepSeek *before* launch day. Tell them: "We expect 6,000 users on launch day."

---

## 💰 "Day 1" Financial Projection (6,000 Users)

**Assumption:** 6,000 users sign up. 60% are active. They run average 10 queries each in the first month.

| Cost Driver | Monthly Estimate |
| :--- | :--- |
| **Server (Google Cloud Run)** | ~$60 - $100 (Auto-scaling CPU usage) |
| **Database (Supabase/Firebase)** | ~$25 (Pro Plan) |
| **AI API (Gemini Flash)** | ~$250 (Based on ~600k requests/tokens) |
| **Redis (Queue System)** | ~$15 (Managed Redis for stability) |
| **TOTAL MONTHLY COST** | **~$350 - $400 USD (₹30,000 - ₹34,000)** |

### 📉 Cost Per User
*   **Total Cost:** ₹34,000
*   **Users:** 6,000
*   **Cost per User:** **₹5.60 per month**

## 💡 Verdict
**Safe to Launch?** YES, but only if you use **Cloud Run (Serverless)**. DO NOT launch 6,000 users on a single EC2 instance or local laptop.

**Revenue Potential:**
Even at a dirt-cheap **₹49/month** introductory price:
*   Revenue: ₹2,94,000
*   Cost: ₹34,000
*   **Profit: ₹2.6 Lakhs in Month 1.**
