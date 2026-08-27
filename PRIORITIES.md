# PRIORITIES.md — Autonomous Loop Directives

## Current Phase: LGPD Compliance + Feature Expansion

### Priority 1: LGPD Phase 2 — Extract to Shared Core
- Extract foodtruck-ops LGPD models (ConsentRecord, DataSubjectRequest, PrivacyIncident) to a shared engine or concern
- Apply to medical-ops and garage-ops
- Ensure RLS + tenancy works across all three verticals
- Run full test suite after each extraction

### Priority 2: medical-ops — Patient Follow-up Enhancements
- Expand discharge checklist with follow-up scheduling
- Add patient communication preferences (LGPD consent integration)
- Improve vital signs trends/charts
- Ensure all new features have specs

### Priority 3: garage-ops — Car-Fix Checklist Expansion
- Add checklist categories: diagnosis, parts, labor, quality-check
- Add checklist item priority/severity fields
- Add completion tracking and timestamps
- Ensure RLS + tenancy works

### Priority 4: Seed Data
- Create seed scripts for medical-ops (patients, appointments, encounters)
- Create seed scripts for garage-ops (vehicles, work orders, checklists)
- Use FactoryBot or direct SQL inserts within Tenancy blocks

### Priority 5: Loop Self-Monitoring
- Wire monitor.json to loop.py
- Add fleet health checks (router, docker, LM Studio servers)
- Auto-heal on failures

## Constraints
- Run `bin/ci` after every change
- Maintain 95% coverage per file
- Never break existing tests
- Follow existing code conventions
- All tenant queries must be wrapped in Tenancy.with_business
