# PRIORITIES.md — Autonomous Loop Directives

## Current Phase: LGPD Done — Feature Expansion + Seed Data

### ✅ DONE: LGPD Phase 1 (all 3 verticals)
- foodtruck-ops / medical-ops / garage-ops all have:
  - ConsentRecord, DataSubjectRequest, PrivacyIncident models
  - Compliance dashboard (owner-only)
  - DSAR CRUD + Privacy policy page
  - LGPD locale keys (pt-BR + en)
  - Applied migration + all tests green
- DO NOT re-run the LGPD migration `20260826040000_create_lgpd_compliance_tables` — it is ALREADY applied.
- If a patch fails on `bin/db-prepare` / `GRANT CONNECT` / migration rerun — skip it, it's already done.

### Priority 1: medical-ops — Patient Follow-up Enhancements
- Expand discharge checklist with follow-up scheduling
- Add patient communication preferences (LGPD consent integration)
- Improve vital signs trends/charts
- Ensure all new features have specs

### Priority 2: garage-ops — Car-Fix Checklist Expansion
- Add checklist categories: diagnosis, parts, labor, quality-check
- Add checklist item priority/severity fields
- Add completion tracking and timestamps
- Ensure RLS + tenancy works

### Priority 3: Seed Data
- Create seed scripts for medical-ops (patients, appointments, encounters)
- Create seed scripts for garage-ops (vehicles, work orders, checklists)
- Use FactoryBot or direct SQL inserts within Tenancy blocks

### Priority 4: Loop Self-Monitoring
- Wire monitor.json to loop.py
- Add fleet health checks (router, docker, LM Studio servers)
- Auto-heal on failures

## Constraints
- Run `bin/ci` after every change
- Maintain 95% coverage per file
- Never break existing tests
- Follow existing code conventions
- All tenant queries must be wrapped in Tenancy.with_business
