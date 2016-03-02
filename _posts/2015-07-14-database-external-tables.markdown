---
published: true
layout: post
category: Other
tags: 
  - database
desc: External tables in database systems
description: External tables in database systems
keywords: "PostgreSQL, GreenPlum, Cloudera, Impala, Drizzle"
woopra: exttables
---

### Motivation
As we are working on the Business Intelligence field we have seen many cases when existing BI tools failed to access exotic data sources. This is where we see a market gap that we want to fill. Our flagship product [VirtDB](http://www.virtdb.com) was created to solve this. 
 
 Looking back to the early days we had the idea to use an existing database engine so we can spare the implementation of ODBC/JDBC access and it also gives us database operations like joins, grouping, aggregates, etc...
  
### Selecting an engine
The next step was to decide which open source engine to extend. My favourite was [Drizzle](http://www.drizzle.org) that has lost its community and the project seem to be dead. This is a pitty, because it was a rewritten and better modularized [MySQL](http://www.mysql.com) engine. The next we checked was MySQL and finally we decided to go with [PostgreSQL](http://www.postgresql.org). Since PostgreSQL 9.1 it has introduced a so called Foreign Data Wrapper API which allows integrating external tables. The 9.3 and the next versions further improved this.
   
### Meta data handling
One major difference between external table APIs is how the database engine resolves the external table references. PostgreSQL goes to its catalog and looks up the table information. With MySQL you can add external tables without ever touching the disk because the API allows you to create "virtual" tables.
    
I prefer the MySQL way, so the source system table list can be generated programmatically. With PostgreSQL some magic is needed to create the FDW objects in the PostgreSQL catalog.
     
GreenPlum being a PostgreSQL fork works like a PostrgeSQL database. External table rerefernces are resolved from the catalog. So no dynamic metadata handling / virtual tables are possible with GP.
      
With Cloudera Impala it is possible to write a [thrift](http://thrift-tutorial.readthedocs.org/en/latest/) proxy in front of catalogd and resolve external tables from there and pass everything else to the catalogd behind. This way one can add external tables metadata without messing with the Hive meta store.
       
### Passing query filters
MySQL lost the battle with query predicate filters. It seemed to be non trivial to extract the predicates from the incoming query and pass only the supported predicates to the source system. With the PostgreSQL API this is feasible (although the C API it gives us is a bit old school for my taste). We tried GreenPlum database too which simply doesn't pass the predicates to the external table module. This is a huge problem if someone is only interested in a small part of the source system table.
        
Cloudera Impala passes the [query predicates](https://github.com/cloudera/Impala/blob/cdh5-trunk/common/thrift/ExternalDataSource.thrift) in a conjunctive normal form which is both nice and elegant.
         
### Scalability
We invested a lot of time into PostgreSQL and found that it does have a place in our portfolio for small installations. For large datasets we started working on a scalable solution. Our original choice was GreenPlum where we could reuse lots of original PostgreSQL efforts as well as it fits the scalability bill nicely. We have a working GreeenPlum based VirtDB without query predicates. This limits its usability in many scenarios.
          
### Cloudera Impala to the rescue
Impala fits our plans in many ways. It is scalable. It is modular and the modules are accessible through [thrift](https://thrift.apache.org). [Query predicates](https://github.com/cloudera/Impala/blob/cdh5-trunk/common/thrift/ExternalDataSource.thrift) are working nicely. Metadata handling can be dynamic through a thrift proxy. The SQL / ODBC support is not as nice as the others but we gain a lot of performance and simplicity on the other hand.
           
This is what we are working on with the VirtDB team. Expect announcement soon!

