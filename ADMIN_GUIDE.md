# Admin Managment Guide

This guide explains how to manage advisors (Lawyers/Counselors) using the Firebase Console. Since the app currently lacks a dedicated Admin UI, you will perform administrative tasks directly in the database backend.

## 1. Accessing the Admin Console
1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Select your project: **`legal-sathi-2025`** (or your specific project name).
3.  In the left sidebar, click on **Build** -> **Firestore Database**.

---

## 2. Reviewing New Advisor Applications

When a lawyer or counselor registers via the app, they are not immediately visible to users. You must review them first.

1.  In the Firestore Database, look for the **`advisors`** collection in the first column.
2.  Click on it. The second column lists all the Advisor IDs (documents).
3.  Click through the documents to see their details in the third column.
4.  **Key Fields to Check:**
    *   `name`: The advisor's full name.
    *   `category`: 'Advocate', 'Mediator', etc.
    *   `licenseNumber`: The ID they provided (e.g., Bar Council ID).
    *   `isVerified`: This will be `false` for new applicants.

---

## 3. How to Approve an Advisor

Once you have verified their credentials (e.g., by checking their License Number against an official registry):

1.  Find the advisor's document in the **`advisors`** collection.
2.  Locate the field named **`isVerified`**.
    *   *Note: If specific fields are missing, the registration might be incomplete.*
3.  Click the **pencil icon** (Edit) next to the `isVerified` field.
4.  Change the value from `false` (boolean) to **`true`** (boolean).
5.  Click **Update**.

✅ **Result:** The advisor will now immediately appear in the search results for all users in the app.

---

## 4. How to Reject or Ban an Advisor

If an advisor is fraudulent or you want to remove them:

**Option A: Soft Ban (Hide them)**
1.  Change `isVerified` back to **`false`**.
2.  They will instantly disappear from search results.

**Option B: Delete (Permanent)**
1.  Click the three dots (`...`) at the top of the advisor's document column.
2.  Select **Delete Document**.
3.  Confirm deletion. This cannot be undone.

---

## 5. Troubleshooting
*   **"I updated the field but they aren't showing up?"**
    *   Wait 1-2 minutes.
    *   Ask the user to pull-to-refresh the advisor list in the app.
    *   Ensure the `isVerified` field is a **Boolean** (true/false) and not a String ("true").

*   **"Where do I see their uploaded ID proof?"**
    *   Currently, the app stores text details. If image upload for ID cards was implemented, check the **Storage** tab in Firebase Console -> `advisor_docs/{advisorId}/`.
