# TodoCache  

**Todo_Cache (enhanced): This code is designed to operate over multiple nodes, utilizing a shared  
mnesia database. The code features a node management system as provided by the Swarm library. This  
system, as configured here, monitors nodes as they come on/off line and manipulates live process  
locations accordingly to ensure a highly scalable system.  

This design is my approach to the discussion at the end chapter 12.2.2 -- Alternative Discovery.  

The code is also optimized to maximize transaction performance, as talked about at the end  
of chapter 11.3.4 -- Performance  

This code utilizes a multi-node mnesia database which is persistent between sessions.  

TODO: need to research how to handle and test for network partitions.  

*********************************************************************************************  

%%%%%%%%%%%%%%%%%%%%%%%%%%--Mnesia Cluster--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
Four nodes over two machines:  
$ iex --sname n1@192.168.1.12 --cookie mycookie -S mix  
$ iex --sname n2@192.168.1.12 --cookie mycookie --erl "-todo port 5555" -S mix  
$ iex --sname n3@192.168.1.14 --cookie mycookie -S mix
$ iex --sname n4@192.168.1.14 --cookie mycookie --erl "-todo port 5555" -S mix

--ensure all nodes talking to each other:  
iex(n2@192.168.1.12)3> nodes = [node() | Node.list]  
[:"n2@192.168.1.12", :"n4@192.168.1.14", :"n1@192.168.1.12",  
 :"n3@192.168.1.14"]  

-- initialize mnesia database  
:rpc.multicall(:mnesia, :stop, [])  
:mnesia.create_schema(nodes)  
:rpc.multicall(:mnesia, :start, [])  
{[:ok, :ok, :ok, :ok], []}  

:mnesia.create_table(:todo_lists, [attributes: [:name, :list], disc_only_copies: nodes])  
:ok = :mnesia.wait_for_tables([:todo_lists], 5000)  

--add some records:  

iex(n2@192.168.1.12)4> :mnesia.transaction(fn ->  
...(n2@192.168.1.12)4> :mnesia.write({:todo_lists, {"bills_list", {2017, 2, 11}}, [%{date: {2017, 2, 11}, title: "business meeting"}]})     
...(n2@192.168.1.12)4> end)  
{:atomic, :ok}  

iex(n1@192.168.1.12)3> :mnesia.transaction(fn ->                                                                                    
...(n1@192.168.1.12)3> :mnesia.write({:todo_lists, {"bills_list", {2017, 2, 14}}, [%{date: {2017, 2, 14}, title: "band practice"}]})   
...(n1@192.168.1.12)3> end)  

iex(n2@192.168.1.12)5> :mnesia.transaction(fn ->   
...(n2@192.168.1.12)5> :mnesia.write({:todo_lists, {"alices_list", {2017, 2, 14}},[%{date: {2017, 2, 14}, title: "yoga%20class"}]})     
...(n2@192.168.1.12)5> end)  
{:atomic, :ok}  

--command line read transaction:
iex(n2@192.168.1.12)6> :mnesia.transaction(fn ->                                     
...(n2@192.168.1.12)6> :mnesia.read({:todo_lists, {"bills_list", {2017, 2, 14}}}) end)  
{:atomic,  
 [{:todo_lists, {"bills_list", {2017, 2, 14}},  
    [%{date: {2017, 2, 14}, title: "band%20practice"}]}]}  

--query for all records  
iex(n2@192.168.1.12)8> :mnesia.transaction(fn ->                 
...(n2@192.168.1.12)8> :mnesia.match_object({:todo_lists, :_, :_})  
...(n2@192.168.1.12)8> end)                                       
{:atomic,
 [{:todo_lists, {"obamas_list", {2017, 2, 11}}, [%{date: {2017, 2, 11}, title: "coding session"}]},
  {:todo_lists, {"bills_list", {2017, 2, 14}}, [%{date: {2017, 2, 14}, title: "band practice"}]},
  {:todo_lists, {"bills_list", {2017, 2, 11}}, [%{date: {2017, 2, 11}, title: "business meeting"}]},
  {:todo_lists, {"alices_list", {2017, 2, 14}}, [%{date: {2017, 2, 14}, title: "yoga class"}]}]}

-- query for all records by list name  
iex(n2@192.168.1.12)9> :mnesia.transaction(fn ->                  
...(n2@192.168.1.12)9> :mnesia.match_object({:todo_lists, {"bills_list", :_}, :_})  
...(n2@192.168.1.12)9> end)  
{:atomic,  
 [{:todo_lists, {"bills_list", {2017, 2, 11}}, [%{date: {2017, 2, 11}, title: "businees meeting"}]},  
  {:todo_lists, {"bills_list", {2017, 2, 14}}, [%{date: {2017, 2, 14}, title: "band practice"}]}]}  

-- delete records from table:  
iex(n1@192.168.1.12)13> :mnesia.transaction(fn ->                    
...(n1@192.168.1.12)13> :mnesia.delete({:todo_lists, {"bills_list", {2017, 2, 11}}})  
...(n1@192.168.1.12)13> end)  
{:atomic, :ok}  


Note: Sometimes all nodes must be started before the :todo_lists table is loaded. I can continue to 
access the table if I shut down successive nodes however. If this happens, the table can be 
forced to load when less than the full number of nodes has been initialized by running:  
:mnesia.force_load_tables(:todo_lists)  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--Partitioned Network--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
This work is pending, I still don't have a handle on partitioning and how I should handle it in
this app.  

Closing lid on 192.168.1.12 causes machine to suspend.  

Closed lid on 192.168.1.12, add record on 192.168.1.14:    
Open lid, data inconsistent.  

Restart:  

$ iex --sname n1@192.168.1.12 --cookie mycookie -S mix  

and see:  

08:08:03.592 [error] Mnesia(:n1@192.168.1.12): ** ERROR ** mnesia_event got {inconsistent_database, :starting_partitioned_network, :n3@quantumDog}    


08:08:03.593 [error] Mnesia(:n1@192.168.1.12): ** ERROR ** mnesia_event got {inconsistent_database, :starting_partitioned_network, :n4@quantumDog}  

Data now consistent.  

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--libring--&&&&&&&&&&&&&&&&&&&&&&&&  
Consistent hashing for locating processes. This is just a basic ring implementation,  
which does nothing in the way of automatically managing processes when  
the topology changes. These are my notes for prototyping consistent hashing of processes 
before I adopted Swarm.  

iex(n1@192.168.1.12)12> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "bills_list"})  
:n1@192.168.1.12    

iex(n1@192.168.1.12)13> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "alices_list"})  
:n2@192.168.1.12  

iex(n1@192.168.1.12)24> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "normans_list"})  
:n3@192.168.1.14    

iex(n1@192.168.1.14)25> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "obamas_list"}) 
:n4@192.168.1.14    

Kill :n4@192.168.1.14 process and see that only the keys for :n4 are relocated.  
iex(n1@192.168.1.12)12> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "bills_list"})  
:n1@192.168.1.12    

iex(n1@192.168.1.12)13> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "alices_list"})  
:n2@192.168.1.12    

iex(n1@192.168.1.12)24> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "normans_list"})  
:n3@192.168.1.14    

iex(n1@192.168.1.12)25> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "obamas_list"})  
:n3@192.168.1.14    

Recovery from a network partition however is another story. Here the ring remains unaware that  
the missing nodes are back.  

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--Swarm--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  
Note: changed cluster to reference ip addresses rather than hostnames. 
Hostnames appear to give inconsistent results with the lid close (suspend) test.  

$ curl -X POST 'http://localhost:5454/add_entry?list=normans_list&date=20170207&title=job%20interview'  
$ curl -X POST 'http://localhost:5454/add_entry?list=obamas_list&date=20170207&title=big%20vacation'  
$ curl -X POST 'http://localhost:5454/add_entry?list=zachs_list&date=20170207&title=algebra%20class'  
$ curl -X POST 'http://localhost:5454/add_entry?list=bills_list&date=20170207&title=band%20practice'  
$ curl -X POST 'http://localhost:5454/add_entry?list=alices_list&date=20170207&title=yoga%20class'  

lists = ["normans_list","obamas_list","bills_list","alices_list","zachs_list"]  

iex(n3@192.168.1.14)57> Enum.each(lists, &IO.inspect({&1, Todo.Server.what_node_name(&1)}))  
{"normans_list", :"n4@192.168.1.14"}  
{"obamas_list", :"n3@192.168.1.14"}  
{"bills_list", :"n2@192.168.1.12"}  
{"alices_list", :"n3@192.168.1.14"}  
{"zachs_list", :"n1@192.168.1.12"}  
:ok  

--close lid:  
iex(n3@192.168.1.14)57> Enum.each(lists, &IO.inspect({&1, Todo.Server.what_node_name(&1)}))  
{"normans_list", :"n4@192.168.1.14"}  
{"obamas_list", :"n3@192.168.1.14"}  
{"bills_list", :undefined}  
{"alices_list", :"n3@192.168.1.14"}  
{"zachs_list", :"undefined}  
:ok  

--open lid (sometime the nodes don't reconnect so do Node.connect(:"n1@192.168.1.12")  
iex(n3@192.168.1.14)57> Enum.each(lists, &IO.inspect({&1, Todo.Server.what_node_name(&1)}))  
{"normans_list", :"n4@192.168.1.14"}  
{"obamas_list", :"n3@192.168.1.14"}  
{"bills_list", :"n2@192.168.1.12"}  
{"alices_list", :"n3@192.168.1.14"}  
{"zachs_list", :"n1@192.168.1.12"}  
:ok  

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--Amnesia--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  

--Create database:  
iex(n1@192.168.1.12)2> nodes = [node()|Node.list]    
[:"n1@192.168.1.12", :"n2@192.168.1.12", :"n3@192.168.1.14", :"n4@192.168.1.14"]  

iex(n1@192.168.1.12)3> TodoDatabase.create(disk_only: nodes)  
[:ok, :ok]  

--Add record:    

iex(n2@192.168.1.12)3> use Amnesia  
Amnesia.Helper  
iex(n2@192.168.1.12)4> use TodoDatabase  
[Amnesia, Amnesia.Fragment, Exquisite, TodoDatabase, TodoDatabase.TodoList,  
 TodoDatabase.TodoList]  

iex(n2@192.168.1.12)5> Amnesia.transaction do  
...(n2@192.168.1.12)5> %TodoList{name: {"bills_list", {2017,2,10}}, list: [{{2017,2,10},"Market"}]} |> TodoList.write  
...(n2@192.168.1.12)5> end  
%TodoDatabase.TodoList{list: [{{2017, 2, 10}, "Market"}],  
 name: {"bills_list", {2017, 2, 10}}}  

--Read record:  
iex(n2@192.168.1.12)6> Amnesia.transaction do                          
...(n2@192.168.1.12)6> TodoList.read({"bills_list", {2017, 2, 10}})    
...(n2@192.168.1.12)6> end  
%TodoDatabase.TodoList{list: [{{2017, 2, 10}, "Market"}],  
 name: {"bills_list", {2017, 2, 10}}}  

-- Amnesia has sparse documentation at this time, especially in the way of constructing 
advance queries. So I am removing from project.  I'll continue to use mnesia for now.  

&&&&&&&&&&&&&&&&&&&&&&&&&&&--add CRUD functionality--&&&&&&&&&&&&&  

--add delete entry code by date (deletes all data assigned to a given date:  
curl -X DELETE 'http://localhost:5454/delete_entry_by_date?list=normans_list&date=20170211  

--change code to execute a list of :mnesia functions under a transaction in database_worker:

--prototype:
iex(n1@192.168.1.12)40> actions = [  
...(n1@192.168.1.12)40> {"bill", fn() -> apply(:mnesia, :write, 
      [{:todo_lists, {"test_list", {2017, 2, 22}}, [%{date: {2017, 2, 22}, title: "any thing"}]}]) end},  
...(n1@192.168.1.12)40> {"bob", fn() -> apply(:mnesia, :delete, [{:todo_lists, {"test_list", {2017, 2, 16}}}]) end}]  
[{"bill", #Function<20.52032458/0 in :erl_eval.expr/5>},  
 {"bob", #Function<20.52032458/0 in :erl_eval.expr/5>}]  

iex(n1@192.168.1.12)41> :mnesia.transaction(fn ->  
...(n1@192.168.1.12)41> for {_, action} <- actions do   
...(n1@192.168.1.12)41> :ok = action.()  
...(n1@192.168.1.12)41> end  
...(n1@192.168.1.12)41> end)  
{:atomic, [:ok, :ok]} 

--add all_entries query:  
[wnorman@mrRoboto todo_cache] $ curl 'http://192.168.1.14:5555/all_entries?list=bills_list'  
2017-2-11 business meeting  
2017-2-14 band practice  
2017-2-15 Repair snow thrower  
2017-2-15 Dog walk  
2017-2-16 Return library books  


