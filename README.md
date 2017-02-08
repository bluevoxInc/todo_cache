# TodoCache

**Todo_Cache (optimized): Code is an extention of Elixir in Action Chapter 11.
Optimized to maximize transaction performance. 

This is stripped down code which only does reads/writes against a mnesia database.
The database schema and table is recreated for each session, so don't expect persistance between sessions.
(See Todo.Database.start_link)

## Operation

## Todo is now an application. Start it by typing either

$ iex -S mix (in an iex shell environment)

or 

$ mix run --no-halt (without an iex shell)


[wnorman@mrRoboto todo_cache]$ iex -S mix  
Erlang/OTP 18 [erts-7.2.1] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false]  

10:33:39.588 [info]  Application mnesia exited: :stopped  

10:33:39.589 [info]  Starting database worker 1  

10:33:39.589 [info]  Starting database worker 2  

10:33:39.590 [info]  Starting database worker 3  

10:33:39.592 [info]  Starting to-do cache  

10:33:39.594 [info]  Starting todo application web router on port 5454  
Interactive Elixir (1.4.0) - press Ctrl+C to exit (type h() ENTER for help)  

iex(1)> Application.started_applications  
[{:todo, 'todo', '0.2.0'}, {:mnesia, 'MNESIA  CXC 138 12', '4.13.2'},  
 {:plug,  
  'A specification and conveniences for composable modules between web applications',  
  '1.3.0'}, {:mime, 'A MIME type module for Elixir', '1.0.1'},  
  {:cowboy, 'Small, fast, modular HTTP server.', '1.0.4'},  
  {:cowlib, 'Support library for manipulating Web protocols.', '1.0.2'},  
  {:ranch, 'Socket acceptor pool for TCP protocols.', '1.2.1'},  
  {:gproc, 'GPROC', '0.5.0'}, {:logger, 'logger', '1.4.0'},  
  {:hex, 'hex', '0.15.0'}, {:inets, 'INETS  CXC 138 49', '6.1'},  
  {:ssl, 'Erlang/OTP SSL application', '7.2'},  
  {:public_key, 'Public key infrastructure', '1.1'},  
  {:asn1, 'The Erlang ASN1 compiler version 4.0.1', '4.0.1'},  
  {:crypto, 'CRYPTO', '3.6.2'}, {:mix, 'mix', '1.4.0'}, {:iex, 'iex', '1.4.0'},  
  {:elixir, 'elixir', '1.4.0'}, {:compiler, 'ERTS  CXC 138 10', '6.0.2'},  
  {:stdlib, 'ERTS  CXC 138 10', '2.7'}, {:kernel, 'ERTS  CXC 138 10', '4.1.1'}]  

#create new DB (./Mnesia.nonode@nohost):  
iex(2)> bills_list = Todo.Cache.server_process("bills_list")  

10:38:05.701 [info]  Starting to-do server for bills_list  
#PID<0.357.0>  


#same pid expected:  
iex(3)> bills_list = Todo.Cache.server_process("bills_list")  
#PID<0.357.0>  

#kill process, supervisor retarts:  
iex(4)> Process.exit(bills_list, :kill)  
true  

10:40:47.339 [info]  Starting to-do server for bills_list  

#new pid expected:  
iex(5)> bills_list = Todo.Cache.server_process("bills_list")  
#PID<0.362.0>  

#add entries:  
iex(6)> Todo.Server.add_entry(bills_list, %{date: {2017, 2, 1}, title: "Shopping"})  
:ok  
iex(7)> Todo.Server.add_entry(bills_list, %{date: {2017, 2, 1}, title: "movie"})   
:ok  

#read entries  
iex(8)> Todo.Server.entries(bills_list, {2017, 2, 1})    
[%{date: {2017, 2, 1}, title: "movie"},  
 %{date: {2017, 2, 1}, title: "Shopping"}]  


*************************************** WEB **************************

$ curl -d '' 'http://localhost:5454/add_entry?list=bills_list&date=20170123&title=Market'  
OK

$ curl -d '' 'http://localhost:5454/add_entry?list=bills_list&date=20170205&title=Dev%20meeting'  
OK

$ curl -X POST 'http://localhost:5454/add_entry?list=bills_list&date=20170205&title=band%20practice'  
OK

$ curl 'http://localhost:5454/entries?list=bills_list&date=20170123'  
2017-1-23 Market  

$ curl 'http://localhost:5454/entries?list=bills_list&date=20170205'  
2017-2-5 band practice  
2017-2-5 Dev meeting  

****************************************** TEST ************************  
$ mix test  

11:01:07.686 [info]  Starting database worker 1  

11:01:07.686 [info]  Starting database worker 2  

11:01:07.686 [info]  Starting database worker 3  

11:01:07.690 [info]  Application mnesia exited: :stopped  

11:01:07.693 [info]  Starting to-do cache  

11:01:07.695 [info]  Starting todo application web router on port 5454  

11:01:07.739 [info]  Application todo exited: :stopped  
.
11:01:08.082 [info]  Application mnesia exited: :stopped  

11:01:08.240 [info]  Starting database worker 1  

11:01:08.240 [info]  Starting database worker 2  

11:01:08.240 [info]  Starting database worker 3  

11:01:08.240 [info]  Starting to-do cache  

11:01:08.240 [info]  Starting todo application web router on port 5454  

11:01:08.374 [info]  Starting to-do server for test  

11:01:08.384 [info]  Application todo exited: :stopped  
.
11:01:08.439 [info]  Starting to-do server for test_list  
.
11:01:08.484 [info]  Starting to-do cache  

11:01:08.484 [info]  Starting to-do server for bobs_list  

11:01:08.485 [info]  Starting to-do server for alices_list  
.
11:01:08.588 [info]  Application mnesia exited: :stopped  
.
11:01:08.768 [info]  Starting database worker 1  
.

Finished in 1.1 seconds  
6 tests, 0 failures  

%%%%%%%%%%%%%%%%%%%%%%%%%%--Mnesia Cluster--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
$ iex --sname n1@mrRoboto --cookie mycookie --erl "-config sys.config" -S mix
$ iex --sname n2@mrRoboto --cookie mycookie --erl "-todo port 5555 -config sys.config" -S mix
$ iex --sname n3@quantumDog --cookie mycookie --erl "-config sys.config" -S mix
$ iex --sname n4@quantumDog --cookie mycookie --erl "-todo port 5555 -config sys.config" -S mix

--ensure all nodes talking to each other:
iex(n1@mrRoboto)1> nodes = [node() | Node.list]
[:n1@mrRoboto, :n2@mrRoboto, :n3@quantumDog, :n4@quantumDog]

# initialize mnesia database
:rpc.multicall(:mnesia, :stop, [])
:mnesia.create_schema(nodes)
:rpc.multicall(:mnesia, :start, [])
{[:ok, :ok, :ok, :ok], []}

:mnesia.create_table(:todo_lists, [attributes: [:name, :list], disc_only_copies: [no>
:ok = :mnesia.wait_for_tables([:todo_lists], 5000)

--command line read transaction:
iex(n1@mrRoboto)3> :mnesia.transaction(fn ->                                     
...(n1@mrRoboto)3> :mnesia.read({:todo_lists, {"bills_list", {2017, 1, 23}}}) end)
{:atomic,
 [{:todo_lists, {"bills_list", {2017, 1, 23}},
    [%{date: {2017, 1, 23}, title: "Market"}]}]}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--Partitioned Network--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Closed lid on mrRoboto, add record on quantumDog:
Open lid, data inconsistent.

Restart:

$ iex --sname n1@mrRoboto --cookie mycookie --erl "-config sys.config" -S mix

and see:

08:08:03.592 [error] Mnesia(:n1@mrRoboto): ** ERROR ** mnesia_event got {inconsistent_database, :starting_partitioned_network, :n3@quantumDog}


08:08:03.593 [error] Mnesia(:n1@mrRoboto): ** ERROR ** mnesia_event got {inconsistent_database, :starting_partitioned_network, :n4@quantumDog}

Data now consistent.

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--libring--&&&&&&&&&&&&&&&&&&&&&&&&
Consistent hashing for locating processes. This is just a basic ring implementation,
which does nothing in the way of automatically managing processes when
the topology changes:

iex(n1@mrRoboto)12> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "bills_list"})
:n1@mrRoboto

iex(n1@mrRoboto)13> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "alices_list"})
:n2@mrRoboto

iex(n1@mrRoboto)24> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "normans_list"})
:n3@quantumDog

iex(n1@mrRoboto)25> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "obamas_list"}) 
:n4@quantumDog

Kill :n4@quantumDog process and see that only the keys for :n4 are relocated.
iex(n1@mrRoboto)12> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "bills_list"})
:n1@mrRoboto

iex(n1@mrRoboto)13> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "alices_list"})
:n2@mrRoboto

iex(n1@mrRoboto)24> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "normans_list"})
:n3@quantumDog

iex(n1@mrRoboto)25> HashRing.Managed.key_to_node(:ring_todo, {:todo_list, "obamas_list"}) 
:n3@quantumDog

Recovery from a network partition however is another story. Here the ring remains unaware that the missing nodes
are back. 

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--Swarm--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
$ curl -X POST 'http://localhost:5454/add_entry?list=normans_list&date=20170207&title=job%20interview'
$ curl -X POST 'http://localhost:5454/add_entry?list=obamas_list&date=20170207&title=big%20vacation'
$ curl -X POST 'http://localhost:5454/add_entry?list=eds_list&date=20170207&title=algebra%20class'
$ curl -X POST 'http://localhost:5454/add_entry?list=bills_list&date=20170207&title=band%20practice'
$ curl -X POST 'http://localhost:5454/add_entry?list=alices_list&date=20170207&title=yoga%20class'

lists = ["normans_list","obamas_list","bills_list","alices_list","eds_list"]

Enum.each(lists, &IO.inspect {&1, Swarm.whereis_name(&1)})
{"bills_list", #PID<20947.395.0>}
{"obamas_list", #PID<0.385.0>}
{"alices_list", #PID<20946.403.0>}
{"normans_list", #PID<20947.396.0>}
{"eds_list", #PID<20945.389.0>}
:ok

--close a node:
iex(n1@mrRoboto)11> Enum.each(lists, &IO.inspect({&1, Swarm.whereis_name(&1)}))
{"bills_list", #PID<20947.395.0>}
{"obamas_list", #PID<0.385.0>}
{"alices_list", #PID<0.462.0>}
{"normans_list", #PID<20947.396.0>}
{"eds_list", #PID<20945.389.0>}
:ok

--start the node again:
iex(n1@mrRoboto)13> Enum.each(lists, &IO.inspect({&1, Swarm.whereis_name(&1)}))
{"bills_list", #PID<20947.395.0>}
{"obamas_list", #PID<0.385.0>}
{"alices_list", #PID<20946.396.0>}
{"normans_list", #PID<20947.396.0>}
{"eds_list", #PID<20945.389.0>}
:ok

--close lid:
iex(n1@mrRoboto)13> Enum.each(lists, &IO.inspect({&1, Swarm.whereis_name(&1)}))
{"bills_list", #PID<20947.395.0>}
{"obamas_list", :undefined}
{"alices_list", #PID<20946.396.0>}
{"normans_list", #PID<20947.396.0>}
{"eds_list", :undefined}
:ok

--open lid:
iex(n1@mrRoboto)13> Enum.each(lists, &IO.inspect({&1, Swarm.whereis_name(&1)}))
{"bills_list", #PID<20947.395.0>}
{"obamas_list", #PID<0.385.0>}
{"alices_list", #PID<20946.396.0>}
{"normans_list", #PID<20947.396.0>}
{"eds_list", #PID<20945.389.0>}
:ok

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Enum.each(lists, &IO.inspect({&1, GenServer.call({:via, :swarm, &1}, :what_node_name)}))
{"normans_list", :n1@mrRoboto}
{"obamas_list", :n1@mrRoboto}
{"bills_list", :n2@mrRoboto}
{"alices_list", :n1@mrRoboto}
{"eds_list", :n2@mrRoboto}
:ok



