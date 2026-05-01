# Migrations

SQL migration files go here. Use `sqlx migrate run` to apply them.

## Naming convention

```
<sequence>_<description>.sql
```

Example:
```
0001_create_users.sql
0002_create_groups.sql
```

## Notes

- All user-content columns must be `BYTEA` (ciphertext) — never `TEXT`.
- Use `uuid-ossp` extension for UUID primary keys (`gen_random_uuid()`).
- Timestamps should be `TIMESTAMPTZ`.
