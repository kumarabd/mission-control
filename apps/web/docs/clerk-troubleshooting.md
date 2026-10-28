# Clerk sign-in: "The External Account was not found"

This Clerk error (`external_account_not_found`) almost always comes from **Clerk Dashboard configuration** or **OAuth + required user fields**, not from agent-brain.

## 1. Clerk Dashboard — user requirements (most common)

If **Username** is required, Google/GitHub OAuth often fails for **new** users because the provider does not supply a username on first sign-in.

**Fix:** Clerk Dashboard → **Configure** → **Email, phone, username**

- Set **Username** to **Optional** (or off), **or**
- Use **Email + password** sign-in first to create the user, then link OAuth later.

Same for any other field marked **Required** that OAuth does not return.

## 2. Social connections

**User & Authentication** → **Social connections**

- Enable the provider you use (Google, GitHub, …).
- Complete OAuth client ID/secret (or use Clerk development credentials only on localhost).
- For production, use production OAuth apps and add redirect URLs Clerk shows in the dashboard.

## 3. Allowed origins (your Explorer URL)

**Configure** → **Domains** (or **Paths** / **Allowed origins**)

Add the exact origin where agent-web runs, e.g.:

- `https://explorer.nighthawklabs.org`
- `http://localhost:5173` (Vite dev)

Mismatch does not always show this exact message, but fix it before debugging OAuth.

## 4. Publishable key matches the instance

`VITE_CLERK_PUBLISHABLE_KEY` must be from the **same** Clerk application as the OAuth apps you configured:

- `pk_test_…` → Development instance
- `pk_live_…` → Production instance

Rebuild the agent-web image after changing the GitHub variable.

## 5. React Router routes (code)

Clerk **path** routing needs splat routes:

- `/login/*`
- `/signup/*`

Without `/*`, OAuth return URLs like `/login/sso-callback` 404 and flows break.

## 6. Quick test order

1. Sign up with **email + password** on `/signup` — if this works, backend and routes are fine; focus on OAuth/required fields.
2. Then try Google/GitHub again after username is optional.
3. In Clerk Dashboard → **Users**, confirm the user exists and has an external account linked.

## 7. agent-brain (after Clerk succeeds)

Clerk only handles browser login. You still need:

```yaml
explorer:
  clerkIssuer: "https://<your-clerk-frontend-api>"
```

on agent-brain so `POST /v1/explorer/auth/session` can mint the explorer JWT. A Clerk UI error is separate from that exchange failing (network tab → 401 on `/v1/explorer/auth/session`).
