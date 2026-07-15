# Issue #8 Investigation Notes

## Issue Summary
GitHub Issue: https://github.com/Skylark-Software/Janua/issues/8
Reporter: jabofh
Date: 2026-07-13
Request: TOTP second-factor authentication, as available in upstream Guacamole.
Reporter attempted the Apache TOTP extension directly and suspected Janua's
image was missing the hooks for it.

## Analysis

janua-web is built `FROM guacamole/guacamole:1.6.0`, so it inherits the
upstream image's full extension mechanism:

- `/opt/guacamole/extensions/guacamole-auth-totp/` -- the TOTP extension jar
  ships in the image already.
- `/opt/guacamole/environment/TOTP_` -- the 1.6.0 entrypoint's env-var mapping
  includes the TOTP prefix, so `TOTP_ENABLED` / `TOTP_ISSUER` etc. are honored.
- Neither the `/janua` webapp-context rebrand nor the read-only
  `GUACAMOLE_HOME` mount interferes: the entrypoint copies the mounted home
  into a writable runtime home (`/tmp/guacamole-home.*`) and installs enabled
  extensions there.

**There are no missing hooks.** TOTP is enabled the same way as on upstream:
set `TOTP_ENABLED=true` on the web container.

## Verification (2026-07-15, meadowlark)

1. Started `janua-web:latest` with `TOTP_ENABLED=true` against the dev stack's
   postgres. Startup log confirms:
   `Extension "TOTP TFA Authentication Backend" (totp) loaded.`
2. Created a temporary DB user and authenticated via
   `POST /janua/api/tokens` -- response was the expected enrollment challenge
   (`TOTP.INFO_ENROLL_REQUIRED`) with secret, otpauth:// key URI, and QR code.
3. Reran with `TOTP_ISSUER=Janua` -- key URI issuer switched from
   `Apache Guacamole` to `Janua`. Recommend documenting this so enrollments
   are branded consistently.
4. Cleaned up the test container and temporary user.

## Likely cause of the reporter's failure

Guessing from "attempted to use the Apache solution directly": copying the
totp jar into a custom `GUACAMOLE_HOME/extensions` also works, but only if the
JDBC auth extension is present in the same effective home and the jar version
matches the webapp (1.6.0). The env-var route avoids all of that and is the
supported path.

## Action Items

- [x] Verify TOTP works on janua-web:latest (no code change needed)
- [x] Document `TOTP_ENABLED` / `TOTP_ISSUER` in README (this commit)
- [x] Add commented TOTP hooks to docker-compose.yml (this commit)
- [ ] Respond to issue #8 with the how-to
- [ ] Consider a `SETUP.md` step for enabling 2FA at install time
