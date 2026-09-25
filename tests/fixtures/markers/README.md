# Marker fixture corpus

The cross-plane contract, as files (ADR-0010). The check plane writes markers and
the build plane executes them; a shared corpus is the only thing both planes can
be tested against, because they run in different languages on different hosts and
never meet at runtime.

It lives under `github/` because `.forgejo/scripts/overlay.sh` mirrors `github/`
onto the GitHub repo and nothing else. That is forced, not chosen: a corpus the
build plane cannot see is a corpus only one plane is tested against.

## Layout

```
markers/<mode>/valid/<job>.json
markers/<mode>/invalid/<what-is-wrong>.json
```

`<mode>` is `mirror`, `local` or `remote`, one per build mode. Every mode
directory must be non-empty — an empty one makes a data-driven suite pass having
tested nothing, so both planes assert the directories are populated with a plain
test rather than a generated one.

## What each half means

`valid/` files are byte-for-byte what `Save-JobMarker` produces. The check-plane
suite reconstructs each one from its own contents and compares bytes, so a change
to marker serialisation — key order, JSON depth, encoding, a new field — fails
here first and loudly. Do not hand-edit them: change `Save-JobMarker` and
regenerate.

`invalid/` files are hand-written and each is wrong in exactly one way, named for
it. Both planes must refuse every one of them. A reader that accepts a flat
marker, a null field or a missing bookkeeping field is a reader that will one day
build the wrong thing quietly.

The `invalid/` set deliberately includes the failure ADR-0009 exists to prevent:
`remote/invalid/unexpanded-ref.json` carries a `{app}` placeholder that resolution
should have replaced. The build plane must not expand it, must not default it, and
must not proceed.
