# Development Report — Wave 3 · Plan 13 — Login / Register (`/login`, `/register`)

**Branch:** `feat/wave3-page-auth`  
**Date:** 2026-08-10  
**Repo:** `front/financial-app`  
**Status:** ✅ Complete — merged to `develop`

---

## What was built

- **Auth Zod Schemas** (`lib/schemas/auth.ts`): Type-safe validation schemas for credentials and user registration fields.
- **`AuthSplit`** (`components/pages/auth/AuthSplit.tsx`): Split layout rendering side photography panel on `md` screens and form container.
- **`LoginForm`** (`components/pages/auth/LoginForm.tsx`): Login form supporting remember-me mapping to `ms-users` session policy, honest non-leaking error messages (`Email o contraseña incorrectos`), and preserving field values on failed attempts.
- **`PasswordRules`** (`components/pages/auth/PasswordRules.tsx`): Live password requirements checklist rendering `data-met` attributes per rule and accessible `role="status"` live region (`Requisitos de contraseña`).
- **`RegisterForm`** (`components/pages/auth/RegisterForm.tsx`): Two-step user registration form enforcing step 1 password checklist before enabling step 2, preserving step 1 values on back navigation, and inline duplicate email error handling (`aria-invalid="true"`).
- **Page & Layout Rewrites** (`app/(auth)/login/page.tsx`, `app/(auth)/register/page.tsx`, `app/(auth)/layout.tsx`): Integrated split layout and updated page bodies.
- **i18n**: Added `auth` namespace to `messages/es-AR.json` and `messages/en.json`.

---

## Test Results

```
Test Files  46 passed (46)
     Tests 152 passed (152)  ← 0 skipped
  Duration  3.26s
```

## Verification

| Check | Result |
|---|---|
| Unit gate | ✅ `LoginForm.test.tsx` and `RegisterForm.test.tsx` green |
| Types | ✅ `npx tsc --noEmit` 0 errors |
| i18n | ✅ `npm run i18n:check` exit 0 (55 keys) |
| No token reads | ✅ No `access_token` cookie read in JS |
| No OAuth stub | ✅ No Google OAuth placeholder button |
| Non-leaking errors | ✅ Identical error for wrong email or wrong password |
