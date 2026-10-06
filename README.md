# Monte Rei Events

Registration page for the Monte Rei owners and golf members day (24 October 2026).

- `public/index.html`: static page. Each guest opens a personal link (`/r/<token>`, or `/?t=<token>`) and answers via the Supabase RPCs `get_convidado` and `set_rsvp`.
- `db/001_participacao.sql`: schema changes (limits: 60 players, 100 lunch places).
- `vercel.json`: rewrites `/r/:token` to the page, blocks indexing.

The guest list (names and emails) is **not** stored in this repository. Import it straight into Supabase.

Deploy: import the repo in Vercel (no build step, output directory `public`), then add the domain montereievents.com.
