#' Target Segmentation UI Component
#'
#' @param id The ID of the module
#' @return A UI element
#' @export
targetSegmentationUI <- function(id) {
  ns <- NS(id)
  
  nav_panel(
    title = "Segmentation",
    icon = icon("object-group"),
    h2("Customer Segmentation"),
    fluidRow(
      column(
        width = 12,
        card(
          card_header("Segment Distribution"),
          plotOutput(ns("segment_distribution"))
        )
      )
    ),
    fluidRow(
      column(
        width = 12,
        card(
          card_header("Top Customers by Segment"),
          DT::dataTableOutput(ns("top_customers"))
        )
      )
    )
  )
}