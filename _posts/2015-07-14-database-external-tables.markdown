---
published: false
layout: post
category: database
tags: 
  - database
  - integration
desc: External tables in database systems
keywords: "PostgreSQL, GreenPlum, Cloudera, Impala, Drizzle"
---

### Motivation
As we are working on the Business Intelligence field we have seen many cases when existing BI tools failed to access exotic data sources. This is where we see a market gap that we want to fill. Our flagship product [VirtDB](http://www.virtdb.com) was created to solve this. 

Looking back to the early days we had the idea to use an existing database engine so we can spare the work of ODBC/JDBC access and it also gives us database operations like joins, grouping, aggregates, etc...

### Selecting an engine
The next step was to decide which open source engine to extend. My favourite was Drizzle that has lost its community and the project seem to be dead. This is a pitty, because it was a rewritten and better modularized MySQL engine. The next is checked was MySQL and finally we decided to go with PostgreSQL. Since PostgreSQL 9.1 it introduced a so called Foreign Data Wrapper API which allows integrating external tables. The 9.3 and the next versions further improved this.

### Meta data handling
While 





