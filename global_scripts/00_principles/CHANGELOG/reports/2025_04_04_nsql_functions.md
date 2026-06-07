---
date: "2025-04-04"
title: "NSQL Function System"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "MP01": "Primitive Terms and Definitions"
  - "MP21": "Formal Logic Language"
---

# NSQL Function System

## Summary

This record defines the function system for Natural SQL Language (NSQL), establishing functions as a core component of the language. Functions in NSQL follow formal language conventions while maintaining human readability, enabling powerful operations within a consistent syntactic framework.

## Function Definition

### Core Concept

In NSQL, a function is a named operation that:
1. Takes zero or more arguments
2. Follows a standard calling syntax: `functionName(arg1, arg2, ...)`
3. Returns a value or performs a specific operation
4. May be used within expressions, conditions, or as standalone statements

### Function Word Class

Functions constitute a distinct word class in NSQL with these characteristics:

- **Syntax**: `functionName(arguments)`
- **Role**: Performs operations on data or provides information
- **Scope**: Can be used in expressions, conditions, path operations, or standalone
- **Return**: May return values that can be used in further operations

## Function Categories

NSQL functions are organized into these categories:

### 1. Type Functions

**Purpose**: Interrogate or manipulate data types.

**Examples**:
- `typeof(x)`: Returns the type of x
- `cast(x, "numeric")`: Converts x to numeric type
- `is_numeric(x)`: Tests if x is numeric
- `is_categorical(x)`: Tests if x is categorical

### 2. Aggregate Functions

**Purpose**: Perform calculations across groups of values.

**Examples**:
- `sum(x)`: Calculates the sum of values
- `average(x)`: Calculates the mean of values
- `count(x)`: Counts values or records
- `max(x)`: Returns maximum value
- `min(x)`: Returns minimum value
- `median(x)`: Returns median value

### 3. Transformation Functions

**Purpose**: Modify or reformat data.

**Examples**:
- `format(date, "yyyy-mm-dd")`: Formats dates
- `extract(text, pattern)`: Extracts matching content
- `replace(text, find, replace)`: Replaces text
- `concat(a, b, ...)`: Joins values together
- `split(text, delimiter)`: Splits text into parts

### 4. Analytical Functions

**Purpose**: Perform advanced analytical operations.

**Examples**:
- `rank(x)`: Assigns ranks to values
- `percentile(x, n)`: Calculates percentiles
- `moving_average(x, window)`: Calculates moving averages
- `correlation(x, y)`: Calculates correlation between variables
- `predict(model, data)`: Applies predictive models

### 5. Path Functions

**Purpose**: Manipulate or interrogate paths.

**Examples**:
- `parent(path)`: Returns the parent container of a path
- `basename(path)`: Returns the final component of a path
- `exists(path)`: Tests if a path exists
- `children(path)`: Lists all child elements of a path
- `resolve(path)`: Resolves a relative path to absolute

### 6. System Functions

**Purpose**: Interact with the execution environment.

**Examples**:
- `now()`: Returns current timestamp
- `user()`: Returns current user
- `log(message)`: Records a log message
- `evaluate(expr)`: Dynamically evaluates expressions
- `import(resource)`: Imports external resources

## Function Syntax and Behavior

### 1. Call Syntax

Functions in NSQL are called using parentheses:

```
functionName(arg1, arg2, ...)
```

Arguments may be:
- Literal values: `count(5)`
- Path references: `sum(orders.amount)`
- Expressions: `format(date + 7, "yyyy-mm-dd")`
- Nested functions: `sqrt(pow(x, 2) + pow(y, 2))`

### 2. Argument Passing

NSQL supports various argument passing mechanisms:

**Positional Arguments**:
```
format(date, "yyyy-mm-dd")
```

**Named Arguments**:
```
format(value=date, pattern="yyyy-mm-dd")
```

**Default Arguments**:
```
# format has default pattern="yyyy-mm-dd"
format(date)
```

**Variable Arguments**:
```
concat("a", "b", "c", "d", ...)
```

### 3. Function Composition

Functions can be composed in NSQL:

```
average(filter(sales.amount, where="sales.date > '2025-01-01'"))
```

### 4. Function Integration with Paths

Functions can be used with paths:

```
# Get function from path
calc.revenue(sales)

# Function operating on path
sum(df.amazon.sales.amount)

# Function returning path
parent(df.amazon.sales).description
```

## Type System Integration

Functions in NSQL are integrated with the type system:

1. **Parameter Types**: Functions specify expected parameter types
2. **Return Types**: Functions have defined return types
3. **Type Checking**: The NSQL parser validates argument types
4. **Type Coercion**: When appropriate, arguments are automatically converted

Example type specification:

```
"sum": {
  "parameters": [{"name": "values", "type": "numeric", "array": true}],
  "return_type": "numeric",
  "description": "Calculates the sum of numeric values"
}
```

## NSQL Dictionary Integration

Functions are documented in the NSQL dictionary with:

```json
{
  "typeof": {
    "word_class": "function",
    "category": "type_function",
    "parameters": [{"name": "object", "type": "any"}],
    "return_type": "string",
    "description": "Returns the type of the given object",
    "translation": {
      "R": "typeof(%object%)",
      "SQL": "TYPEOF(%object%)",
      "Python": "type(%object%).__name__"
    }
  },
  "sum": {
    "word_class": "function",
    "category": "aggregate_function",
    "parameters": [{"name": "values", "type": "numeric", "array": true}],
    "return_type": "numeric",
    "description": "Calculates the sum of numeric values",
    "translation": {
      "R": "sum(%values%, na.rm=TRUE)",
      "SQL": "SUM(%values%)",
      "Python": "sum(%values%)"
    }
  }
}
```

## Grammar Integration

The NSQL grammar incorporating functions:

```
<function_call> ::= <function_name> "(" [<argument_list>] ")"

<argument_list> ::= <argument> ["," <argument_list>]

<argument> ::= <named_argument> | <expression>

<named_argument> ::= <identifier> "=" <expression>

<expression> ::= <term> | <function_call> | <binary_operation>

<term> ::= <path> | <literal> | <variable>
```

## Examples

### Example 1: Type Function

**NSQL Statement**:
```
df.sales -> filter where typeof(amount) = "numeric" and amount > 0
```

**Translation (R)**:
```r
df_sales %>% filter(typeof(amount) == "numeric" & amount > 0)
```

### Example 2: Aggregate Functions

**NSQL Statement**:
```
df.sales -> group by region -> calculate 
  total = sum(amount),
  average = average(amount),
  count = count(*)
```

**Translation (SQL)**:
```sql
SELECT 
  region,
  SUM(amount) AS total,
  AVG(amount) AS average,
  COUNT(*) AS count
FROM sales
GROUP BY region
```

### Example 3: Transformation Functions

**NSQL Statement**:
```
df.customers -> transform as
  full_name = concat(first_name, " ", last_name),
  birth_year = extract(birth_date, "year")
```

**Translation (Python)**:
```python
df_customers.assign(
  full_name = df_customers.first_name + " " + df_customers.last_name,
  birth_year = df_customers.birth_date.dt.year
)
```

### Example 4: Path Functions

**NSQL Statement**:
```
if exists(df.temp.results) then
  df.temp.results -> transform to df.final.results as
    select *
    where quality_score > threshold
```

**Translation (R)**:
```r
if (exists("df_temp_results")) {
  df_temp_results %>%
    filter(quality_score > threshold) %>%
    assign("df_final_results", ., envir = .GlobalEnv)
}
```

## Implementation Considerations

1. **Function Registry**: NSQL maintains a registry of all available functions
2. **Extension Mechanism**: Custom functions can be registered and used
3. **Translation Rules**: Each function includes rules for translation to target languages
4. **Documentation**: Functions have standardized documentation format
5. **Validation**: Functions include validation rules for arguments

## Relationship to Other Principles

This function system relates to:

1. **MP21 (Formal Logic Language)**: Functions provide formal operations similar to logical functions
2. **MP01 (Primitive Terms and Definitions)**: Functions represent a primitive concept in the language
3. **P14 (Dot Notation Property Access)**: Functions work seamlessly with dot notation

## Benefits

1. **Expressiveness**: Functions enable complex operations in a readable form
2. **Standardization**: Common operations have consistent syntax
3. **Extensibility**: New functions can be added to extend the language
4. **Familiarity**: Syntax follows conventions from common programming languages
5. **Type Safety**: Function signatures enable type checking

## Conclusion

The function system provides a powerful, consistent mechanism for expressing operations in NSQL. By combining formal language structure with human readability, NSQL functions enable complex data operations while maintaining the language's core principles of clarity and precision.

The integration of functions with the word class system, type system, and path system creates a cohesive language framework that balances expressiveness with readability.