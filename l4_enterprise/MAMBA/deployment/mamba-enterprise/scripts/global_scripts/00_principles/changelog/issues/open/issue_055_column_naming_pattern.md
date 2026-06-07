---
issue: "ISSUE_055"
title: "Column Naming Convention for Operations"
severity: "low"
component: "naming_conventions"
app: "shared"
created: "2025-08-23"
status: "open"
original_source: "recommendation/logs.md"
---

## Problem
Need standardized column naming convention for operations.

## Expected Behavior
Column names should follow pattern: `operation__columnname_by_at`
- Double underscore separator
- Clear indication of operation type
- Suffix indicating operation context

## Actual Behavior
Inconsistent column naming across operations.

## Proposed Resolution
Establish and document the naming pattern: `operation__columnname_by_at`