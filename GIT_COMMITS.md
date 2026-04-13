# Suggested Git commit names

## Option A — one squashed commit

`git commit -m "fix: harden financial logic, backup/restore, imports, and recurring payment consistency"`

## Option B — granular commits by bug block

1. `fix: preserve income account linkage when merging customization metadata`
2. `fix: include full notification preferences in backup export and restore`
3. `refactor: make income editor environment injection explicit and testable`
4. `fix: sync account and debt balances when importing expenses`
5. `fix: remap backup identities on restore to avoid cross-user UUID collisions`
6. `fix: block money account deletion when linked records still exist`
7. `fix: block credit card deletion when expenses still reference the debt`
8. `fix: enforce credit card spending limits across expense flows`
9. `fix: prevent money accounts from going negative across payment flows`
10. `fix: include reusable custom categories in backup and restore`
11. `fix: clear recurring payment paid state when linked expense is deleted`
12. `fix: sanitize orphan references during backup import and restore`
13. `fix: reject invalid financial states in backup restore and unsafe expense imports`
14. `fix: improve imported expense deduplication and remove duplicate merge logic`
15. `test: add regression coverage for financial state, backup, import, and recurring sync`

## Option C — cleaner release-style pair

- `git commit -m "fix: stabilize financial consistency across expenses, debts, transfers, and recurring payments"`
- `git commit -m "test: add regression suite for backup, restore, imports, and account safety rules"`
