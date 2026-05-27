# Supabase — notifications deployment

Everything the backend needs to send push notifications lives in this directory:

```
supabase/
├── config.toml                                  # CLI config
├── functions/send-push/index.ts                 # FCM HTTP v1 sender
└── migrations/
    ├── 20260526000001_device_tokens.sql           # token table + RLS
    ├── 20260526000002_notification_helpers.sql    # initial helpers (superseded)
    ├── 20260526000003_notification_triggers.sql   # meeting-notes / hours / swap triggers
    └── 20260526000004_use_vault_for_settings.sql  # helpers read from Vault
```

---

## One-time setup

1. **Install / log in** the CLI:
   ```sh
   brew install supabase/tap/supabase   # or see https://supabase.com/docs/guides/cli
   supabase login
   ```

2. **Link this repo** to your project (replace `<project-ref>` with the ID from the dashboard URL):
   ```sh
   supabase link --project-ref <project-ref>
   ```

3. **Apply the migrations**:
   ```sh
   supabase db push
   ```

   This creates `device_tokens`, the helper functions, and the three triggers.

4. **Add two Vault secrets** the trigger helpers read. Run **once** per
   environment in the SQL editor (replacing the placeholders):

   ```sql
   select vault.create_secret(
     'https://<project-ref>.functions.supabase.co',
     'edge_url',
     'Edge Functions base URL used by notification triggers');

   select vault.create_secret(
     '<service-role-key>',
     'service_role_key',
     'Used by notification triggers to call send-push');
   ```

   > Supabase-hosted Postgres doesn't grant `ALTER DATABASE … SET` to the SQL
   > editor role, so we use [Supabase Vault](https://supabase.com/docs/guides/database/vault)
   > instead. `send_push_to_users()` reads from `vault.decrypted_secrets`. The
   > service role key never leaves the database; the client app only ever sees
   > the anon key.
   >
   > To **update** a secret later, use
   > `select vault.update_secret('<id>', '<new-value>')` — find the ID via
   > `select id, name from vault.secrets;`.

5. **Set the function's secrets** (Firebase credentials):
   ```sh
   supabase secrets set FCM_PROJECT_ID=<firebase-project-id>
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat firebase-service-account.json)"
   ```

   Grab `firebase-service-account.json` from
   Firebase Console → Project Settings → Service Accounts → Generate New
   Private Key. **Do not commit this file** — add it to `.gitignore`.

6. **Deploy the function:**
   ```sh
   supabase functions deploy send-push
   ```

---

## How it works

```
┌────────────┐  insert/update  ┌─────────────────────┐
│ Notes      │ ───────────────▶│ notify_new_meeting_ │
│ swap_*     │                 │ note (trigger)      │
│ activity_* │                 └──────────┬──────────┘
└────────────┘                            │
                                          ▼
                              ┌───────────────────────────┐
                              │ send_push_to_users(uuid[],│
                              │   title, body, data)      │
                              └───────────┬───────────────┘
                                          │ pg_net.http_post
                                          ▼
                              ┌───────────────────────────┐
                              │ Edge Function: send-push  │
                              │   - mints FCM access token│
                              │   - fetches device_tokens │
                              │   - sends one FCM v1 call │
                              │     per token             │
                              │   - purges UNREGISTERED   │
                              └───────────────────────────┘
```

The three triggers in `20260526000003_notification_triggers.sql`:

| Trigger | When | Audience |
|---|---|---|
| `trg_notes_after_insert` | New row in `"Notes"` | All members of `society_id` |
| `trg_activity_logs_hours_notify` | Insert into `activity_logs` with `action_type in (attendance_*, manual_*)` | The row's `user_id` |
| `trg_swap_requests_after_insert/update` | Swap created or `status` changes | Requester or target as appropriate |

---

## Local testing

Run the function locally with the CLI:

```sh
supabase functions serve send-push --env-file .env.local
```

`.env.local` should contain `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_JSON`. Then:

```sh
curl -X POST http://localhost:54321/functions/v1/send-push \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <local anon or service-role key>" \
  -d '{
    "user_ids": ["<your-test-user-uuid>"],
    "title": "Local test",
    "body":  "Hello from supabase functions serve"
  }'
```

To exercise the triggers end-to-end, insert into one of the source tables:

```sql
-- Should push to every member of society 1
insert into public."Notes" (title, text, content, society_id, created_at)
values ('Trigger test', 'Plain text', '{}', 1, now());
```

---

## Operational notes

- **Dead-token cleanup** — `send-push` automatically deletes rows from
  `device_tokens` when FCM returns `UNREGISTERED` or `INVALID_ARGUMENT`.
- **Cold start** — first call per ~hour will JWT-sign and exchange for an
  OAuth access token. Subsequent calls reuse it from in-memory cache.
- **Retries** — `pg_net.http_post` is fire-and-forget; no retries on failure.
  If you need stronger guarantees, replace the helper with a queue (e.g.
  `pgmq`) and have the function poll it.
- **Throttling** — there's no batching today; one FCM call per token. The HTTP
  v1 API supports up to 500 messages per `:batchSend` call if you outgrow this.
- **Removing notifications** — `supabase functions delete send-push` and run a
  migration that drops the three triggers if you want to disable pushes
  without ripping out the table.
