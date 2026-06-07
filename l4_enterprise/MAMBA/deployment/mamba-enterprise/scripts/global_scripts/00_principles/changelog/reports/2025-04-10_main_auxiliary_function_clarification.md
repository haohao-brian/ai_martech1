# Implementation Record: Main Function and Auxiliary Function Clarification

Date: 2025-04-10
Author: Development Team
Principles Applied: R21, MP01

## Changes Made

1. Revised R21 from "One Function, One File Rule" to "One Main Function, One File Rule"
   - Updated title and core requirement
   - Added clear definitions for main functions and auxiliary functions
   - Updated examples to show both main and auxiliary functions in the same file
   - Added two organization patterns: top-down and bottom-up
   - Added "initialization first" pattern with auxiliary functions defined before main
   - Refined exceptions to match the new rule

2. Updated MP01 Primitive Terms and Definitions
   - Added formal definitions for Main Function and Auxiliary Function
   - Clarified the relationship between these function types
   - Established terminology for consistent reference in documentation

## NSQL Notation for Function Types

To clearly document these function types in the codebase, we've established NSQL notation conventions:

```
# File structure annotations
MAIN_FUNCTION(name: calculate_customer_value) {
  # The main entry point function that gives the file its name
  # Intended to be called by external code
  # Typically exported as part of the API
}

AUXILIARY_FUNCTION(name: calculate_single_product_value) {
  # Helper function used by the main function
  # Not intended to be called directly by external code
  # Implements a subtask of the main function
  CALLED_BY: calculate_customer_value
}
```

## Function Dependency Documentation

For more complex files with multiple auxiliary functions, dependencies can be documented:

```
# Function dependency documentation
FUNCTION_DEPENDENCY {
  MAIN: calculate_customer_value
  AUXILIARIES: [
    calculate_single_product_value,
    aggregate_product_values,
    normalize_currency
  ]
  CALL_GRAPH: {
    calculate_customer_value → calculate_single_product_value
    calculate_customer_value → aggregate_product_values
    calculate_single_product_value → normalize_currency
  }
}
```

## Benefits

1. **Improved Organization**: Allows related helper functions to stay with the main function they support
2. **Better Encapsulation**: Auxiliary functions can be kept private to the file
3. **Reduced File Proliferation**: Prevents excessive fragmentation of the codebase
4. **Clearer Documentation**: Establishes consistent terminology for function types
5. **Better Cohesion**: Keeps related functionality together while maintaining organization

## Guidance for Implementation

1. Each file should contain one clearly identified main function
2. The main function name should match the file name (without the fn_ prefix)
3. Auxiliary functions should be well-documented and clearly identified
4. Auxiliary functions should only support the main function in the file
5. When functionality grows too complex, consider refactoring into separate files

## Examples

### Top-Down Implementation (Main Function First)

```r
#' Calculate Customer Lifetime Value
#'
#' @description
#' Calculates the lifetime value of a customer based on transaction history
#' and customer attributes.
#'
#' @param customer_id The unique identifier for the customer
#' @param transactions Data frame of customer transactions
#' @param customer_metadata Additional customer attributes
#' @return Numeric value representing estimated lifetime value
#'
#' @examples
#' calculate_customer_lifetime_value("CUST123", transaction_df, metadata_df)
#'
calculate_customer_lifetime_value <- function(customer_id, transactions, customer_metadata) {
  # Main function implementation
  historical_value <- calculate_historical_value(transactions)
  churn_probability <- predict_churn_probability(customer_id, customer_metadata)
  future_value <- estimate_future_value(historical_value, churn_probability)
  
  return(historical_value + future_value)
}

#' Calculate Historical Value
#'
#' @description
#' Auxiliary function that calculates the historical value from transactions.
#'
#' @param transactions Data frame of customer transactions
#' @return Numeric value representing historical value
#'
calculate_historical_value <- function(transactions) {
  # Implementation of auxiliary function
  sum(transactions$revenue)
}

#' Predict Churn Probability
#'
#' @description
#' Auxiliary function that predicts the probability of customer churn.
#'
#' @param customer_id Customer identifier
#' @param customer_metadata Customer attributes
#' @return Probability of churn (0-1)
#'
predict_churn_probability <- function(customer_id, customer_metadata) {
  # Implementation of auxiliary function
  # ...
}

#' Estimate Future Value
#'
#' @description
#' Auxiliary function that estimates future value based on history and churn.
#'
#' @param historical_value Historical value
#' @param churn_probability Probability of churn
#' @return Estimated future value
#'
estimate_future_value <- function(historical_value, churn_probability) {
  # Implementation of auxiliary function
  # ...
}
```

### Bottom-Up Implementation (Auxiliary Functions First)

```r
#' Calculate Historical Value
#'
#' @description
#' Auxiliary function that calculates the historical value from transactions.
#'
#' @param transactions Data frame of customer transactions
#' @return Numeric value representing historical value
#'
calculate_historical_value <- function(transactions) {
  # Implementation of auxiliary function
  sum(transactions$revenue)
}

#' Predict Churn Probability
#'
#' @description
#' Auxiliary function that predicts the probability of customer churn.
#'
#' @param customer_id Customer identifier
#' @param customer_metadata Customer attributes
#' @return Probability of churn (0-1)
#'
predict_churn_probability <- function(customer_id, customer_metadata) {
  # Implementation of auxiliary function
  # ...
}

#' Estimate Future Value
#'
#' @description
#' Auxiliary function that estimates future value based on history and churn.
#'
#' @param historical_value Historical value
#' @param churn_probability Probability of churn
#' @return Estimated future value
#'
estimate_future_value <- function(historical_value, churn_probability) {
  # Implementation of auxiliary function
  # ...
}

#' Calculate Customer Lifetime Value
#'
#' @description
#' Calculates the lifetime value of a customer based on transaction history
#' and customer attributes. By placing this main function last, all its
#' dependencies (auxiliary functions) are already defined.
#'
#' @param customer_id The unique identifier for the customer
#' @param transactions Data frame of customer transactions
#' @param customer_metadata Additional customer attributes
#' @return Numeric value representing estimated lifetime value
#'
#' @examples
#' calculate_customer_lifetime_value("CUST123", transaction_df, metadata_df)
#'
calculate_customer_lifetime_value <- function(customer_id, transactions, customer_metadata) {
  # Main function implementation using previously defined auxiliaries
  historical_value <- calculate_historical_value(transactions)
  churn_probability <- predict_churn_probability(customer_id, customer_metadata)
  future_value <- estimate_future_value(historical_value, churn_probability)
  
  return(historical_value + future_value)
}
```

File name for either example would be: `fn_calculate_customer_lifetime_value.R`