---
name: frontend-component
description: Use when building, styling, or refactoring Next.js 15 / React 19 UI components, Zustand stores, TanStack Query hooks, or apiFetch integration.
---

# Frontend Component & State Skill

## Core Rules

1. **Architecture & Framework**:
   - Next.js 15 App Router (`app/`), React 19, TypeScript, Tailwind CSS v4, shadcn/ui.
   - Separate Server Components (page layouts, data fetching defaults) from Client Components (`'use client'`).

2. **API Integration & Auth**:
   - All client-side HTTP calls use `apiFetch` (`lib/api/client.ts`).
   - Handles automatic `401 Unauthorized` token refresh via mutex `refreshToken()` before retrying request.
   - JS never accesses JWT tokens directly — all tokens travel in HttpOnly cookies.

3. **State Management**:
   - **Server / Cache State**: TanStack Query (`useQuery`, `useMutation`) for remote data.
   - **UI / Client State**: Zustand stores (`lib/store/ui.store.ts`) for modal state, drawer toggles, and client UI preferences.

4. **Design Excellence**:
   - Use curated, modern dark/light themes, subtle micro-animations, accessible dialogs with `<DialogDescription>`, and dynamic loading skeletons.
