dim\_store      ← one row per store; name/address live only here

dim\_product    ← one row per real product/version; uses product\_sk

dim\_date       ← one row per business date; weekday and month live here

fact\_revenue   ← millions of sales lines using only dimension keys + revenue

