# TodoCach -- Scalable  

**Todo_Cache (scalable): This code is designed to operate over multiple nodes, utilizing a shared  
mnesia database. The code features a node management system, based on a consistent hash,  
as provided by the Swarm library, https://github.com/bitwalker/swarm, and Libcluster,  
https://github.com/bitwalker/libcluster.  This system monitors nodes as they come on/off line  
and manipulates live process locations to ensure a highly scalable system in real time.  

This design is my approach to the discussion at the end chapter 12.2.2 -- Alternative Discovery  
in the Elixir In Action book.    

The code is also optimized to maximize transaction performance, as talked about at the end  
of chapter 11.3.4 -- Performance   

This code utilizes a multi-node mnesia database which is configured for persistence between sessions.   

Network partitions are handled using the Reunion, https://github.com/snar/reunion. Custom code was  
written to handle the merging of database records created and/or modified during a split brain session.   
This merge code is based on the addition of a Vector Clock,  
https://github.com/sschneider1207/vector_clock, which is automaticaly created/updated for each  
database transaction.  

Many thanks to the developers of the excellent applications mentioned above.  

*********************************************************************************************  


