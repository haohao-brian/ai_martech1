# metadata_turbo: optional per-company feature

Script: `scripts/update_scripts/ETL/all/all_ETL_metadata_turbo_0IM.R`

When `metadata_sources.turbo` is not configured in a company's `app_config.yaml`,
the script gracefully skips instead of erroring out. Only MAMBA currently uses
this feature.

Fixed 2026-04-10: replaced `stop(...)` with `message() + return(invisible())`
so `{targets}` doesn't treat non-applicable companies as failures.
