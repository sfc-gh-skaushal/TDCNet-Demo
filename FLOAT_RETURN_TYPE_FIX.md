# FLOAT Return Type Compatibility Fix

## Problem
**Error:** `Declared return type 'FLOAT' is incompatible with actual return type 'NUMBER(38,6)'`

## Root Cause
In Snowflake, arithmetic operations (especially division) can result in `NUMBER(38,6)` data type rather than `FLOAT`. The `CALCULATE_PRIORITY_SCORE` function was declared to return `FLOAT` but the arithmetic expression was returning `NUMBER(38,6)`.

## Function Affected
- **Function:** `CALCULATE_PRIORITY_SCORE`
- **File:** `sql/cortex_models/fault_classification.sql`
- **Issue:** Arithmetic operations with division returning `NUMBER(38,6)` instead of `FLOAT`

## Solution
Added explicit type casting to ensure the function returns the declared `FLOAT` type:

### Before (causing error):
```sql
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    CASE FAULT_CATEGORY
        WHEN 'Cable Fault' THEN 0.8
        -- ... more cases ...
    END
    +
    LEAST(CUSTOMERS_AFFECTED / 1000.0, 0.2)  -- Division creates NUMBER(38,6)
    +
    LEAST(SERVICE_CALLS / 100.0, 0.1)        -- Division creates NUMBER(38,6)
    -- ... more arithmetic ...
$$;
```

### After (working):
```sql
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    (CASE FAULT_CATEGORY
        WHEN 'Cable Fault' THEN 0.8
        -- ... more cases ...
    END
    +
    LEAST(CUSTOMERS_AFFECTED / 1000.0, 0.2)
    +
    LEAST(SERVICE_CALLS / 100.0, 0.1)
    -- ... more arithmetic ...
    )::FLOAT  -- ✅ Explicit cast to FLOAT
$$;
```

## Technical Details
- **Root Issue:** Snowflake's division operator (`/`) can produce `NUMBER(38,6)` precision
- **Solution:** Explicit casting using `::FLOAT` ensures return type matches declaration
- **Impact:** No functional changes, only ensures type compatibility

## Files Modified
- `sql/cortex_models/fault_classification.sql` - Added explicit FLOAT casting to `CALCULATE_PRIORITY_SCORE` function

## Verification
✅ All SQL syntax validation tests pass
✅ Function return type now matches declaration
✅ No other functions affected (only one FLOAT return type in entire codebase)

## Impact on Demo
- No functional changes to priority scoring logic
- Maintains exact same calculation results
- Ensures compatibility with Snowflake's type system
- Function can now be created without compilation errors
