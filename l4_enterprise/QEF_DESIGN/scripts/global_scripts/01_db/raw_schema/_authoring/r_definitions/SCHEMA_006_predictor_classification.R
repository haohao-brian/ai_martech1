# =============================================================================
# SCHEMA DEFINITION: Predictor Classification Metadata
# =============================================================================
# Schema ID: SCHEMA_006
# Table: df_predictor_classification
# Purpose: Source-driven classification metadata for D04 Poisson predictor_type
#          assignment;replaces name-heuristic classifier with metadata lookup
# Principle: DM_R054 v2.1.1 (Metadata Storage Policy - meta_data.duckdb only)
#            MP161 (Company-Scoped Schema Recognition - this is universal)
#            MP102 (ETL Output Standardization - source provenance propagation)
#            metadata-storage-policy spec (canonical reader pattern)
#            metadata-driven-predictor-type-classification spec
# Created: 2026-05-15
# =============================================================================

SCHEMA_006_predictor_classification <- list(
  schema_id = "SCHEMA_006",
  schema_name = "Predictor Classification Metadata",
  table_name = "df_predictor_classification",
  description = paste0(
    "Lookup table mapping (platform, column_name) -> predictor_type for ",
    "D04 Poisson regression classifier. Source provenance (review_agg / ",
    "product_attributes_gsheet / time_features / sales_meta) determines ",
    "predictor_type at ETL emit time;classifier reads this table rather ",
    "than applying brittle name heuristics. Lives in meta_data.duckdb per ",
    "DM_R054 v2.1.1, universal scope per MP161."
  ),
  version = "1.0",
  created_date = "2026-05-15",
  last_updated = "2026-05-15",
  storage_db = "meta_data.duckdb",
  bound_specs = c(
    "metadata-storage-policy",
    "predictor-type-metadata-table",
    "predictor-type-source-emit",
    "predictor-type-classifier-lookup"
  ),

  # ============================================================================
  # COLUMN DEFINITIONS
  # ============================================================================

  columns = list(

    # ---- COMPOSITE PRIMARY KEY (part 1) ----
    platform = list(
      type = "VARCHAR",
      required = TRUE,
      primary_key = TRUE,
      description = "Platform identifier matching active platform whitelist",
      example = "amz",
      valid_values = c("amz", "cbz", "eby", "shp", "tiktok"),
      note = "Set by ETL emit at JOIN time;matches Sys.getenv('DRV_PLATFORM') value used by D04 classifier"
    ),

    # ---- COMPOSITE PRIMARY KEY (part 2) ----
    column_name = list(
      type = "VARCHAR",
      required = TRUE,
      primary_key = TRUE,
      description = "Sales time series column name being classified",
      example = "review_count",
      note = paste0(
        "Preserves original column name verbatim from upstream source. ",
        "Supports non-ASCII names (e.g. Chinese review-decoded sentiment ",
        "columns like 偏光功能 or 紫外線防護);no normalization applied."
      )
    ),

    # ---- CLASSIFICATION ----
    predictor_type = list(
      type = "VARCHAR",
      required = TRUE,
      description = "Business classification for D04 Poisson UI module routing",
      example = "comment_attribute",
      valid_values = c(
        "time_feature",
        "product_attribute",
        "comment_attribute",
        "structural"
      ),
      ui_module_mapping = list(
        time_feature      = "poissonTimeAnalysis",
        product_attribute = "poissonFeatureAnalysis",
        comment_attribute = "poissonCommentAnalysis",
        structural        = "EXCLUDED"
      ),
      note = "Determined by ETL source provenance, not by name heuristic"
    ),

    # ---- SOURCE PROVENANCE ----
    source = list(
      type = "VARCHAR",
      required = TRUE,
      description = "Upstream source that produced this column during ETL JOIN",
      example = "review_agg",
      valid_values = c(
        "bridge_yaml",                # primary (post-refinement 2026-05-15): populated by meta_init from bridge yaml field_extractors
        "time_features_fastpath",     # primary: hardcoded time-feature emit in meta_init
        "structural_fastpath",        # primary: hardcoded structural emit in meta_init
        # Legacy sources from initial spec — preserved for backward-compat
        # diagnostics but no longer emitted by current pipeline. Per design.md
        # Refinement 2, meta_init is single producer.
        "review_agg",
        "product_attributes_gsheet",
        "time_features",
        "sales_meta"
      ),
      source_to_predictor_type_mapping = list(
        bridge_yaml               = "(derived from canonical name prefix)",
        time_features_fastpath    = "time_feature",
        structural_fastpath       = "structural",
        # Legacy
        review_agg                = "comment_attribute",
        product_attributes_gsheet = "product_attribute",
        time_features             = "time_feature",
        sales_meta                = "structural"
      ),
      note = paste0(
        "Bridge yaml is the primary metadata source post-refinement (2026-05-15);",
        " predictor_type for bridge_yaml rows derived from canonical name prefix",
        " (e.g. rating_* -> comment_attribute, feature_* -> product_attribute)."
      )
    ),

    # ---- AUDIT ----
    added_at = list(
      type = "TIMESTAMP",
      required = TRUE,
      description = "When this classification row was last upserted by ETL",
      example = "2026-05-15T10:00:00Z",
      default = "CURRENT_TIMESTAMP",
      note = "Updated on every upsert;helps audit ETL re-run cycles"
    )
  ),

  # ============================================================================
  # PRIMARY KEY
  # ============================================================================

  primary_key = list(
    type = "COMPOSITE",
    columns = c("platform", "column_name"),
    description = "Composite PK enforces uniqueness per (platform, column_name);same column name can have different classifications across platforms"
  ),

  # ============================================================================
  # INDEXES
  # ============================================================================

  indexes = list(
    idx_platform_type = list(
      columns = c("platform", "predictor_type"),
      description = "Speed up GROUP BY (platform, predictor_type) queries used by DRV diagnostics"
    ),
    idx_source = list(
      columns = "source",
      description = "Speed up audit queries filtering by upstream source"
    )
  ),

  # ============================================================================
  # CHECK CONSTRAINTS
  # ============================================================================

  check_constraints = list(
    predictor_type_valid = list(
      column = "predictor_type",
      sql = "predictor_type IN ('time_feature', 'product_attribute', 'comment_attribute', 'structural')",
      description = "Enforce predictor_type value set per spec predictor-type-metadata-table"
    ),
    source_valid = list(
      column = "source",
      sql = "source IN ('bridge_yaml', 'time_features_fastpath', 'structural_fastpath', 'review_agg', 'product_attributes_gsheet', 'time_features', 'sales_meta')",
      description = "Enforce source provenance value set; bridge_yaml + *_fastpath are current producers, legacy values preserved for backward-compat"
    )
  ),

  # ============================================================================
  # CREATE TABLE SQL (DuckDB)
  # ============================================================================

  create_sql_duckdb = "
    CREATE TABLE IF NOT EXISTS df_predictor_classification (
      platform VARCHAR NOT NULL,
      column_name VARCHAR NOT NULL,
      predictor_type VARCHAR NOT NULL,
      source VARCHAR NOT NULL,
      added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (platform, column_name),
      CHECK (predictor_type IN ('time_feature', 'product_attribute', 'comment_attribute', 'structural')),
      CHECK (source IN ('bridge_yaml', 'time_features_fastpath', 'structural_fastpath', 'review_agg', 'product_attributes_gsheet', 'time_features', 'sales_meta'))
    );

    CREATE INDEX IF NOT EXISTS idx_predictor_classification_platform_type
      ON df_predictor_classification(platform, predictor_type);
    CREATE INDEX IF NOT EXISTS idx_predictor_classification_source
      ON df_predictor_classification(source);
  ",

  # ============================================================================
  # CREATE TABLE SQL (PostgreSQL)
  # ============================================================================
  # Kept symmetrical with SCHEMA_005 even though current metadata storage is
  # DuckDB only;allows future move to Postgres without schema redefinition.

  create_sql_postgres = "
    CREATE TABLE IF NOT EXISTS df_predictor_classification (
      platform VARCHAR NOT NULL,
      column_name VARCHAR NOT NULL,
      predictor_type VARCHAR NOT NULL,
      source VARCHAR NOT NULL,
      added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (platform, column_name),
      CHECK (predictor_type IN ('time_feature', 'product_attribute', 'comment_attribute', 'structural')),
      CHECK (source IN ('bridge_yaml', 'time_features_fastpath', 'structural_fastpath', 'review_agg', 'product_attributes_gsheet', 'time_features', 'sales_meta'))
    );

    CREATE INDEX IF NOT EXISTS idx_predictor_classification_platform_type
      ON df_predictor_classification(platform, predictor_type);
    CREATE INDEX IF NOT EXISTS idx_predictor_classification_source
      ON df_predictor_classification(source);
  ",

  # ============================================================================
  # COMPLIANCE NOTES
  # ============================================================================

  compliance_notes = list(
    dm_r054_compliance = paste0(
      "Table SHALL reside in meta_data.duckdb per DM_R054 v2.1.1 (Metadata ",
      "Storage Policy). Not in app_data, raw_data, staged_data, ",
      "transformed_data, processed_data, or cleansed_data."
    ),

    mp161_compliance = paste0(
      "Schema is UNIVERSAL (per MP161 Company-Scoped Schema Recognition): ",
      "same shape across all 5 consuming companies (QEF_DESIGN / D_RACING / ",
      "MAMBA / WISER / kitchenMAMA). Rows differ per platform but never per ",
      "company. Schema authoring lives outside _authoring/companies/."
    ),

    mp102_compliance = paste0(
      "Source provenance (review_agg / product_attributes_gsheet / ",
      "time_features / sales_meta) is the sole driver of predictor_type ",
      "assignment per MP102 v1.2 ETL Output Standardization principle: ",
      "upstream knows the answer, downstream classifier only propagates."
    )
  )
)

# =============================================================================
# HELPER FUNCTION: Initialize predictor_classification table
# =============================================================================

#' Initialize Predictor Classification Table
#'
#' Creates the df_predictor_classification table if it doesn't exist.
#' Idempotent — safe to call repeatedly. Table starts empty;ETL emit
#' populates rows during 2TR phase JOIN steps.
#'
#' @param con DBI connection to meta_data.duckdb.
#' @param db_type Character. Database type ("duckdb" or "postgres"). Default "duckdb".
#'
#' @return TRUE if successful, error otherwise.
#' @export
fn_initialize_predictor_classification <- function(con, db_type = "duckdb") {

  if (db_type == "duckdb") {
    sql <- SCHEMA_006_predictor_classification$create_sql_duckdb
  } else if (db_type == "postgres") {
    sql <- SCHEMA_006_predictor_classification$create_sql_postgres
  } else {
    stop("Unsupported database type: ", db_type)
  }

  # CREATE TABLE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS = idempotent.
  # Split on ';' to execute each statement separately (DuckDB requires it).
  statements <- strsplit(sql, ";")[[1]]
  for (stmt in statements) {
    stmt_trimmed <- trimws(stmt)
    if (nchar(stmt_trimmed) > 0) {
      DBI::dbExecute(con, stmt_trimmed)
    }
  }

  message("df_predictor_classification table initialized successfully.")
  return(TRUE)
}
