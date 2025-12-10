# Database Initialization

Place the Guacamole database schema SQL file here before first run.

## Generate the schema

```bash
docker run --rm guacamole/guacamole:1.6.0 /opt/guacamole/bin/initdb.sh --postgresql > initdb/001-schema.sql
```

This creates the required tables and default admin user.

## Default credentials

- Username: `guacadmin`
- Password: `guacadmin`

**Change these immediately after first login!**
