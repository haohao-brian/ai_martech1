#' Target Segmentation Server Component
#'
#' @param id The ID of the module
#' @param data_source The reactive data source
#' @return The module server function
#' @export
targetSegmentationServer <- function(id, data_source) {
  moduleServer(id, function(input, output, session) {
    # Create segment distribution plot
    output$segment_distribution <- renderPlot({
      req(data_source())
      df <- data_source()
      
      segment_summary <- df %>%
        group_by(segment) %>%
        summarise(
          count = n(),
          total_revenue = sum(revenue),
          avg_transactions = mean(transactions)
        )
      
      ggplot(segment_summary, aes(x = "", y = total_revenue, fill = segment)) +
        geom_bar(stat = "identity", width = 1) +
        coord_polar("y") +
        scale_fill_brewer(palette = "Set1") +
        theme_minimal() +
        theme(axis.title = element_blank()) +
        labs(title = "Revenue by Segment")
    })
    
    # Create top customers table
    output$top_customers <- DT::renderDataTable({
      req(data_source())
      df <- data_source()
      
      # Get top 5 customers by revenue in each segment
      top_customers <- df %>%
        group_by(segment) %>%
        arrange(desc(revenue)) %>%
        slice_head(n = 5) %>%
        ungroup() %>%
        select(segment, customer_id, name, revenue, transactions, last_purchase)
      
      # Format currency and dates for display
      top_customers$revenue <- sprintf("$%.2f", top_customers$revenue)
      
      DT::datatable(
        top_customers,
        options = list(pageLength = 10),
        rownames = FALSE
      )
    })
  })
}