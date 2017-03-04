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
$ iex --name n1@192.168.1.12 --cookie mycookie -S mix  
$ iex --name n2@192.168.1.12 --cookie mycookie --erl "-todo port 5555" -S mix  
$ iex --name n3@192.168.1.14 --cookie mycookie -S mix
$ iex --name n4@192.168.1.14 --cookie mycookie --erl "-todo port 5555" -S mix

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

*************************************************************************
prototype mnesia table:

[wnorman@mrRoboto todo_cache] $ cd ../mnesia_proj/
[wnorman@mrRoboto mnesia_proj] $ iex --sname proto1 -S mix

iex(proto1@mrRoboto)3> :mnesia.stop

iex(proto1@mrRoboto)7> node() 
:proto1@mrRoboto
iex(proto1@mrRoboto)8> :mnesia.create_schema([node()])
:ok
iex(proto1@mrRoboto)9> :mnesia.start
:ok

iex(proto1@mrRoboto)11> :mnesia.create_table(TodoList, i
[attributes: [:name, :list, :modified], disc_only_copies: [node()]])
{:atomic, :ok}

# can this modified value be evaluated in unsplit? Yes.
iex(proto1@mrRoboto)15> t1 = :calendar.universal_time()
{{2017, 3, 1}, {13, 35, 13}}
iex(proto1@mrRoboto)16> t2 = :calendar.universal_time()
{{2017, 3, 1}, {13, 35, 20}}
iex(proto1@mrRoboto)17> t1 < t2
true
iex(proto1@mrRoboto)18> t2 < t1
false

# Add a few records:

iex(proto1@mrRoboto)19> :mnesia.transaction(fn ->
...(proto1@mrRoboto)19> :mnesia.write({TodoList, {"bills_list", {2017, 3, 11}}, [%{date: {2017, 3, 11}, title: "business meeting"}], :calendar.universal_time})
...(proto1@mrRoboto)19> end)
{:atomic, :ok}
iex(proto1@mrRoboto)20> :mnesia.transaction(fn ->                             ...(proto1@mrRoboto)20> :mnesia.write({TodoList, {"bills_list", {2017, 3, 1}}, [%{date: {2017, 3, 1}, title: "walk dog"}], :calendar.universal_time})       ...(proto1@mrRoboto)20> end)
{:atomic, :ok}
iex(proto1@mrRoboto)21> :mnesia.transaction(fn ->                             ...(proto1@mrRoboto)21> :mnesia.write({TodoList, {"bills_list", {2017, 3, 2}}, [%{date: {2017, 3, 2}, title: "shopping"}], :calendar.universal_time})
...(proto1@mrRoboto)21> end)
{:atomic, :ok}
iex(proto1@mrRoboto)22> :mnesia.transaction(fn ->
...(proto1@mrRoboto)22> :mnesia.match_object({TodoList, {"bills_list", :_}, :_, :_})
...(proto1@mrRoboto)22> end)
{:atomic,
 [{TodoList, {"bills_list", {2017, 3, 11}},
   [%{date: {2017, 3, 11}, title: "business meeting"}],
   {{2017, 3, 1}, {13, 42, 44}}},
  {TodoList, {"bills_list", {2017, 3, 1}},
   [%{date: {2017, 3, 1}, title: "walk dog"}], {{2017, 3, 1}, {13, 43, 25}}},
  {TodoList, {"bills_list", {2017, 3, 2}},
   [%{date: {2017, 3, 2}, title: "shopping"}], {{2017, 3, 1}, {13, 44, 9}}}]}
iex(proto1@mrRoboto)23>

# set timestamp within action command:
iex(proto1@mrRoboto)23> action = fn() -> apply(:mnesia, :write, [{TodoList, 
...(proto1@mrRoboto)23> {"bills_list", {2017, 3, 3}},  
...(proto1@mrRoboto)23> [%{date: {2017, 3, 3}, title: "band practice"}],
...(proto1@mrRoboto)23> :calendar.universal_time}])
...(proto1@mrRoboto)23> end
#Function<20.52032458/0 in :erl_eval.expr/5>

# time before transaction: 
iex(proto1@mrRoboto)24> t4 = :calendar.universal_time
{{2017, 3, 1}, {14, 8, 33}}

iex(proto1@mrRoboto)25> :mnesia.transaction(fn ->
...(proto1@mrRoboto)25> :ok = action.()
...(proto1@mrRoboto)25> end)
{:atomic, :ok}
iex(proto1@mrRoboto)26> :mnesia.transaction(fn ->     
...(proto1@mrRoboto)26> :mnesia.match_object({TodoList, {"bills_list", :_}, :_, :_})
...(proto1@mrRoboto)26> end)
{:atomic,
 [{TodoList, {"bills_list", {2017, 3, 11}},
   [%{date: {2017, 3, 11}, title: "business meeting"}],
   {{2017, 3, 1}, {13, 42, 44}}},
  {TodoList, {"bills_list", {2017, 3, 1}},
   [%{date: {2017, 3, 1}, title: "walk dog"}], {{2017, 3, 1}, {13, 43, 25}}},
  {TodoList, {"bills_list", {2017, 3, 2}},
   [%{date: {2017, 3, 2}, title: "shopping"}], {{2017, 3, 1}, {13, 44, 9}}},
  {TodoList, {"bills_list", {2017, 3, 3}},
   [%{date: {2017, 3, 3}, title: "band practice"}],
   {{2017, 3, 1}, {14, 9, 46}}}]}

# timestamp of record is greater than t4 which means stamp is not 
# applied until transaction is executed. 

********************************************************************
# New table definition for :todo_lists  
# Add a modified column that unsplit can key on to merger net split.  

#Connect all nodes and delete :todo_lists 
iex(n2@192.168.1.12)4> :mnesia.delete_table(:todo_lists)  
{:atomic, :ok}  
iex(n2@192.168.1.12)5> :mnesia.system_info(:tables)  
[:schema]  

iex(n1@192.168.1.12)4> nodes=[node()|Node.list]  
[:"n1@192.168.1.12", :"n2@192.168.1.12", :"n3@192.168.1.14",  
 :"n4@192.168.1.14"]  

:mnesia.create_table(:todo_lists, [attributes: [:name, :list, :modified], 
user_properties: [unsplit_method: {:unsplit_lib, :last_modified, []}], disc_only_copies: nodes]) 
{:atomic, :ok}

iex(n1@192.168.1.12)6> :mnesia.system_info(:tables)  
[:todo_lists, :schema]  

iex(n1@192.168.1.12)8> :mnesia.table_info(:todo_lists, :user_properties)
[unsplit_method: {:unsplit_lib, :last_modified, []}]

**************************************Handle Net Splits*************************************  
#Add unsplit:  

mix.exs  
 applications: [:libcluster, :logger, :gproc, :cowboy, :plug, :mnesia, :swarm, :unsplit],  
deps: {:unsplit, git: "https://github.com/uwiger/unsplit.git"},  

$ mix deps.get gives error:  
** (Mix) Command "git --git-dir=.git checkout --quiet HEAD" failed

$ vi deps/unsplit/rebar.config  
change  
{deps, [{edown, ".*", {git, "https://github.com/esl/edown", "HEAD"}}  
to  
{deps, [{edown, ".*", {git, "https://github.com/uwiger/edown"}}  


# Start all four nodes and add a few values to Todo List. Simulate a net split by closing  
# the lid of machine two. After a few minutes, open the lid. See that the nodes are split.  
 
iex(n4@192.168.1.14)6> nodes=[node()|Node.list]  
[:"n4@192.168.1.14", :"n3@192.168.1.14"]  

#Reconnect  
iex(n4@192.168.1.14)7> Node.connect(:"n2@192.168.1.12")  
true  
inconsistency. Context = running_partitioned_network; Node = :"n2@192.168.1.12"  
 
have lock...  
IslandA = ['n3@192.168.1.14','n4@192.168.1.14'];  
IslandB = ['n1@192.168.1.12','n2@192.168.1.12']  
nodes_of(todo_lists) = ['n1@192.168.1.12','n2@192.168.1.12','n4@192.168.1.14','n3@192.168.1.14']  
Affected tabs = [todo_lists]  
Methods = [{todo_lists,['n1@192.168.1.12','n2@192.168.1.12','n4@192.168.1.14','n3@192.168.1.14'],  
 {unsplit_lib,last_modified,[]}}]  
 
Held locks = [{'n4@192.168.1.14',[{{schema,'______WHOLETABLE_____'},  
    write,  
    {tid,510,<0.436.0>}},  
    {{todo_lists,'______WHOLETABLE_____'},  
    write,  
    {tid,510,<0.436.0>}}]},  
    {'n2@192.168.1.12',[{{schema,'______WHOLETABLE_____'},  
    write,  
    {tid,510,<0.436.0>}},  
    {{todo_lists,'______WHOLETABLE_____'},  
    write,  
    {tid,510,<0.436.0>}}]}]  
stitching: [{todo_lists,['n1@192.168.1.12','n2@192.168.1.12','n4@192.168.1.14','n3@192.168.1.14'],  
 {unsplit_lib,last_modified,[]}}]  
 do_stitch({todo_lists,['n1@192.168.1.12','n2@192.168.1.12','n4@192.168.1.14','n3@192.168.1.14'],  
 {unsplit_lib,last_modified,[]}}, 'n2@192.168.1.12').  
 'n2@192.168.1.12' has a copy of todo_lists? -> true  
Calling unsplit_lib:last_modified(init, [todo_lists,[name,list,modified]])Starting merge of todo_lists ([name,list,modified]) 
 -> {ok,{todo_lists,4}}
 Res = {ok,['n2@192.168.1.12']}
 inconsistency. Context = starting_partitioned_network; Node = 'n2@192.168.1.12'
 have lock...
 'n2@192.168.1.12' already stitched, it seems. All is well.
 Res = ok
 inconsistency. Context = running_partitioned_network; Node = 'n1@192.168.1.12'
 have lock...
 'n1@192.168.1.12' already stitched, it seems. All is well.
 Res = ok
 inconsistency. Context = starting_partitioned_network; Node = 'n1@192.168.1.12'
 have lock...
 'n1@192.168.1.12' already stitched, it seems. All is well.
 Res = ok
 Got event: {mnesia_system_event,{mnesia_up,'n2@192.168.1.12'}}
 Got event: {mnesia_system_event,{mnesia_up,'n1@192.168.1.12'}}
 Got event: {mnesia_system_event,{mnesia_up,'n4@192.168.1.14'}}
  
**************************************************************************************  
# Close lid of machine two again  
# Reopen and observe a split in the clusters  
# Add two new values, one for each machine  

$ curl -X POST 'http://192.168.1.12:5555/add_entry?list=bills_list&date=20170308&title=first%20transaction'  

$ curl -X POST 'http://192.168.1.14:5555/add_entry?list=bills_list&date=20170308&title=second%20transaction' 

$ curl 'http://192.168.1.12:5555/all_entries?list=bills_list'2017-3-5 dog walk
2017-3-5 band practice
2017-3-6 coding session
2017-3-7 return library book
2017-3-8 first transaction

$ curl 'http://192.168.1.14:5555/all_entries?list=bills_list'
2017-3-5 dog walk
2017-3-5 band practice
2017-3-6 coding session
2017-3-7 return library book
2017-3-8 second transaction

# Observe  
Held locks = [{'n2@192.168.1.12',[{{schema,'______WHOLETABLE_____'},
                                   write,
                                   {tid,528,<0.575.0>}},
                                  {{todo_lists,'______WHOLETABLE_____'},
                                   write,
                                   {tid,528,<0.575.0>}}]},
              {'n3@192.168.1.14',[{{schema,'______WHOLETABLE_____'},
                                   write,
                                   {tid,528,<0.575.0>}},
                                  {{todo_lists,'______WHOLETABLE_____'},
                                   write,
                                   {tid,528,<0.575.0>}}]}]
stitching: [{todo_lists,['n1@192.168.1.12','n2@192.168.1.12',
                         'n4@192.168.1.14','n3@192.168.1.14'],
                        {unsplit_lib,last_modified,[]}}]
do_stitch({todo_lists,['n1@192.168.1.12','n2@192.168.1.12','n4@192.168.1.14',
                       'n3@192.168.1.14'],
                      {unsplit_lib,last_modified,[]}}, 'n3@192.168.1.14').
'n3@192.168.1.14' has a copy of todo_lists? -> true
Calling unsplit_lib:last_modified(init, [todo_lists,[name,list,modified]])Starting merge of todo_lists ([name,list,modified])
 -> {ok,{todo_lists,4}}
last_version_entry({[{todo_lists,{<<"bills_list">>,{2017,3,8}},
                                 [#{date => {2017,3,8},
                                    title => <<"first transaction">>}],
                                 {{2017,3,2},{20,32,20}}}],
                    [{todo_lists,{<<"bills_list">>,{2017,3,8}},
                                 [#{date => {2017,3,8},
                                    title => <<"second transaction">>}],
                                 {{2017,3,2},{20,34,21}}}]})
compare({[{todo_lists,{<<"bills_list">>,{2017,3,8}},
                      [#{date => {2017,3,8},title => <<"first transaction">>}],
                      {{2017,3,2},{20,32,20}}}],
         [{todo_lists,{<<"bills_list">>,{2017,3,8}},
                      [#{date => {2017,3,8},title => <<"second transaction">>}],
                      {{2017,3,2},{20,34,21}}}]})
 -> {ok,[{write,{todo_lists,{<<"bills_list">>,{2017,3,8}},
                            [#{date => {2017,3,8},title => <<"second transaction">>}],
                            {{2017,3,2},{20,34,21}}}}],
        same,
        {todo_lists,4}}
Res = {ok,['n3@192.168.1.14']}
inconsistency. Context = starting_partitioned_network; Node = 'n3@192.168.1.14'
have lock...
'n3@192.168.1.14' already stitched, it seems. All is well.
Res = ok
inconsistency. Context = running_partitioned_network; Node = 'n4@192.168.1.14'
have lock...
'n4@192.168.1.14' already stitched, it seems. All is well.
Res = ok
inconsistency. Context = starting_partitioned_network; Node = 'n4@192.168.1.14'
have lock...
'n4@192.168.1.14' already stitched, it seems. All is well.
Res = ok
Got event: {mnesia_system_event,{mnesia_up,'n4@192.168.1.14'}}
Got event: {mnesia_system_event,{mnesia_up,'n3@192.168.1.14'}}
Got event: {mnesia_system_event,{mnesia_up,'n2@192.168.1.12'}}


$ curl 'http://192.168.1.14:5555/all_entries?list=bills_list'
2017-3-5 dog walk
2017-3-5 band practice
2017-3-6 coding session
2017-3-7 return library book
2017-3-8 second transaction

$ curl 'http://192.168.1.12:5555/all_entries?list=bills_list'
2017-3-5 dog walk
2017-3-5 band practice
2017-3-6 coding session
2017-3-7 return library book
2017-3-8 second transaction

# This only keeps the last record entered into the table.  
# It ignors all previous transactions. Not very useful.  

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@-- VClock --@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  

iex(n1@192.168.1.12)8> :mnesia.create_table(Test, [attributes: [:name, :list, :vclock],
...(n1@192.168.1.12)8> user_properties: [unsplit_method: {:unsplit_lib, :vclock, [:vclock]}], disc_only_copies: nodes])
{:atomic, :ok}
iex(n1@192.168.1.12)9> :mnesia.read_table_property(Test, :unsplit_method)      
{:unsplit_method, {:unsplit_lib, :vclock, [:vclock]}}  

iex(n1@192.168.1.12)10> my_vclock_1 = :unsplit_vclock.fresh
[]

my_vclock_2 = :unsplit_vclock.increment(node(), my_vclock_1)
["n1@192.168.1.12": {1, 541868556}]

iex(n1@192.168.1.12)13> action = fn() ->                                
...(n1@192.168.1.12)13> apply(:mnesia, :write,                          
...(n1@192.168.1.12)13> [{Test, {"bills_list", {2017, 3, 3}},           
...(n1@192.168.1.12)13> [%{date: {2017, 3, 3}, title: "band practice"}],
...(n1@192.168.1.12)13> my_vclock_2}])                                  
...(n1@192.168.1.12)13> end
#Function<20.52032458/0 in :erl_eval.expr/5>
iex(n1@192.168.1.12)14> :mnesia.activity(:transaction, action)
:ok

iex(n1@192.168.1.12)16> :mnesia.activity(:transaction, fn ->
...(n1@192.168.1.12)16> :mnesia.match_object({Test, :_, :_, :_}) end)
[{Test, {"bills_list", {2017, 3, 3}},
  [%{date: {2017, 3, 3}, title: "band practice"}],
  ["n1@192.168.1.12": {1, 541868556}]}]

iex(n1@192.168.1.12)21> {:atomic, [{t,n,l,v}]} = :mnesia.transaction(
  fn -> :mnesia.wread({Test, {"bills_list", {2017, 03, 03}}}) end)
{:atomic,
 [{Test, {"bills_list", {2017, 3, 3}},
   [%{date: {2017, 3, 3}, title: "band practice"}],
   ["n1@192.168.1.12": {1, 541868556}]}]}

iex(n1@192.168.1.12)22> v
["n1@192.168.1.12": {1, 541868556}]

trans = fn() ->  
case :mnesia.wread({Test, {"bills_list", {2017, 3, 3}}}) do
  [{t,n,l,v}] ->   
    v2 = :unsplit_vclock.increment(node(), v)  
    :mnesia.write({t, n, l, v2})    
  _ ->      
    :mnesia.abort("No such record")  
  end   
end

#Function<20.52032458/0 in :erl_eval.expr/5>
iex(n1@192.168.1.12)26> :mnesia.transaction(trans)   
{:atomic, :ok}

iex(n1@192.168.1.12)32> {:atomic, [{t,n,l,v}]} = :mnesia.transaction(fn -> :mnesia.wread({Test, {"bills_list", {2017, 03, 03}}}) end)
{:atomic,
 [{Test, {"bills_list", {2017, 3, 3}},
   [%{date: {2017, 3, 3}, title: "band practice"}],
   ["n1@192.168.1.12": {2, 541877859}]}]}

iex(n1@192.168.1.12)35> my_vclock_2
["n1@192.168.1.12": {1, 541868556}]
iex(n1@192.168.1.12)36> v
["n1@192.168.1.12": {2, 541877859}]

iex(n1@192.168.1.12)38> :unsplit_vclock.descends(v, my_vclock_2)
true

activity = fn ->                                     
:mnesia.write({Test, {"bills_list", {2017, 03, 04}}, 
[%{date: {2017, 03, 04}, title: "band practice"}],   
:unsplit_vclock.fresh})                              
end
#Function<20.52032458/0 in :erl_eval.expr/5>
:mnesia.activity(:transaction, activity, [], Todo.Vclock)
Test
{Test, {"bills_list", {2017, 3, 4}},
 [%{date: {2017, 3, 4}, title: "finish book"}], []}
:write
:write

# set vclock within action command:
action = fn() -> apply(Todo.Vclock, :write, [{Test,
{"bills_list", {2017, 3, 4}},
[%{date: {2017, 3, 4}, title: "finish book"}]}])
end

:mnesia.transaction(fn ->
:ok = action.()
end)
