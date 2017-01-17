# TodoCache

**Todo_Cache: The Elixir in Action book exercises from chapter 7 through chapter 12.**

## Operation

## Todo is now an application. Start it by typing either

$ iex -S mix (in an iex shell environment)

or 

$ mix run --no-halt (without an iex shell)


[wnorman@mrRoboto todo_cache] $ iex -S mix
Erlang/OTP 18 [erts-7.2.1] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false]

Compiling 11 files (.ex)
Generated todo app
Starting process registry
Starting database worker 1
Starting database worker 2
Starting database worker 3
Starting to-do cache
Interactive Elixir (1.3.1) - press Ctrl+C to exit (type h() ENTER for help)

## get an overview of the application and dependencies that have been started automatically:

iex(1)> :application.which_applications
[{:todo, 'todo', '0.1.0'}, {:logger, 'logger', '1.3.1'},
 {:hex, 'hex', '0.14.1'}, {:inets, 'INETS  CXC 138 49', '6.1'},
 {:ssl, 'Erlang/OTP SSL application', '7.2'},
 {:public_key, 'Public key infrastructure', '1.1'},
 {:asn1, 'The Erlang ASN1 compiler version 4.0.1', '4.0.1'},
 {:crypto, 'CRYPTO', '3.6.2'}, {:mix, 'mix', '1.3.1'}, {:iex, 'iex', '1.3.1'},
 {:elixir, 'elixir', '1.3.1'}, {:compiler, 'ERTS  CXC 138 10', '6.0.2'},
 {:stdlib, 'ERTS  CXC 138 10', '2.7'}, {:kernel, 'ERTS  CXC 138 10', '4.1.1'}
]

#create new DB (./persist/bills_list):  
iex(2)> bills_list = Todo.Cache.server_process("bills_list")  
Starting to-do server for bills_list  
PID<0.124.0>  

#same pid expected:  
iex(3)> bills_list = Todo.Cache.server_process("bills_list")  
PID<0.124.0>  

#kill process, supervisor retarts:  
iex(4)> Process.exit(bills_list, :kill)  
Starting to-do server for bills_list  
true  

#new pid expected:  
iex(5)> bills_list = Todo.Cache.server_process("bills_list")  
PID<0.135.0>  

#add entries:  
iex(6)> Todo.Server.add_entry(bills_list, %{date: {2016, 12, 25}, title: "Christmas"})  
:ok  
PID<0.118.0>  
": storing bills_list"  

iex(7)> Todo.Server.add_entry(bills_list, %{date: {2017, 1, 1}, title: "New Year"})  
:ok  
PID<0.118.0>  
": storing bills_list"  

#list entries:  
iex(8)> Todo.Server.all_entries(bills_list)  
[%{date: {2016, 12, 25}, id: 1, title: "Christmas"},  
 %{date: {2017, 1, 1}, id: 2, title: "New Year"}]  

iex(9)> Todo.Server.add_entry(bills_list, %{date: {2016, 12, 21}, title: "School"})  
:ok  
PID<0.118.0>  
": storing bills_list"  

iex(10)> Todo.Server.all_entries(bills_list)                                    [%{date: {2016, 12, 25}, id: 1, title: "Christmas"},  
 %{date: {2017, 1, 1}, id: 2, title: "New Year"},  
  %{date: {2016, 12, 21}, id: 3, title: "School"}]  

#delete entry  
iex(11)> Todo.Server.delete_entry(bills_list, 3)  
:ok  
PID<0.118.0>  
": storing bills_list"  

iex(12)> Todo.Server.all_entries(bills_list)      
[%{date: {2016, 12, 25}, id: 1, title: "Christmas"},  
 %{date: {2017, 1, 1}, id: 2, title: "New Year"}]  

#find pid given DB name:  
iex(13)> Todo.Server.whereis("bills_list")    
PID<0.135.0>  

#create new DB/list:  
iex(14)> alices_list = Todo.Cache.server_process("alices_list")                 Starting to-do server for alices_list  
PID<0.154.0>  

iex(15)> Todo.Server.whereis("alices_list")                      
PID<0.154.0>  

iex(16)> Todo.Server.add_entry(alices_list, %{date: {2016, 12, 22}, title: "Dentist"})       
:ok  
PID<0.118.0>  
": storing alices_list"  

iex(17)> Todo.Server.add_entry(alices_list, %{date: {2016, 12, 23}, title: "Movie"})    
:ok  
PID<0.118.0>  
": storing alices_list"  

iex(18)> Todo.Server.add_entry(alices_list, %{date: {2016, 12, 23}, title: "Shopping"})  
:ok  
PID<0.118.0>  
": storing alices_list"  

iex(19)> Todo.Server.all_entries(alices_list)                                   [%{date: {2016, 12, 22}, id: 1, title: "Dentist"},  
 %{date: {2016, 12, 23}, id: 2, title: "Movie"},  
  %{date: {2016, 12, 23}, id: 3, title: "Shopping"}]  

#update entry  
iex(20)> Todo.Server.update_entry(alices_list, %{date: {2016, 12, 23}, id: 3, title: "Shopping/Movie"})  
:ok  
PID<0.118.0>  
": storing alices_list"  

iex(21)> Todo.Server.all_entries(alices_list)                                   [%{date: {2016, 12, 22}, id: 1, title: "Dentist"},  
 %{date: {2016, 12, 23}, id: 2, title: "Movie"},  
  %{date: {2016, 12, 23}, id: 3, title: "Shopping/Movie"}]  

#modify entry date:  
iex(22)> Todo.Server.update_entry(alices_list, %{date: {2016, 12, 24}, id: 3, title: "Shopping/Movie"})  
:ok  
PID<0.118.0>  
": storing alices_list"  

iex(23)> Todo.Server.all_entries(alices_list)                                   [%{date: {2016, 12, 22}, id: 1, title: "Dentist"},  
 %{date: {2016, 12, 23}, id: 2, title: "Movie"},  
  %{date: {2016, 12, 24}, id: 3, title: "Shopping/Movie"}]  

#crash alice's Todo.Server and see it restart:  
iex(24)> Todo.Server.update_entry(alices_list, %{date: {2016, 12, 24}, title: "Shopping/Movie"})         
Starting to-do server for alices_list  
:ok  

#error message logged here:  
iex(25)>   
03:50:34.045 [error] GenServer {:todo_server, "alices_list"} terminating  
** (KeyError) key :id not found in: %{date: {2016, 12, 24}, title: "Shopping/Movie"}  
    (todo) lib/todo/list.ex:48: Todo.List.update_entry/2  
    (todo) lib/todo/server.ex:60: Todo.Server.handle_cast/2  
    (stdlib) gen_server.erl:615: :gen_server.try_dispatch/4  
    (stdlib) gen_server.erl:681: :gen_server.handle_msg/5  
    (stdlib) proc_lib.erl:240: :proc_lib.init_p_do_apply/3  
  Last message: {:"$gen_cast", {:update_entry, %{date: {2016, 12, 24}, title: "Shopping/Movie"}}}  
  State: {"alices_list", %Todo.List{auto_id: 4, entries: %{1 => %{date: {2016, 12, 22}, id: 1, title: "Dentist"}, 2 => %{date: {2016, 12, 23}, id: 2, title: "Movie"}, 3 => %{date: {2016, 12, 24}, id: 3, title: "Shopping/Movie"}}}}  

    nil  

#where is the new alices_list?  
iex(26)> alices_list = Todo.Server.whereis("alices_list")  
PID<0.184.0>              

#show it is functioning properly by listing the last state:  
iex(27)> Todo.Server.all_entries(alices_list)                                   [%{date: {2016, 12, 22}, id: 1, title: "Dentist"},  
     %{date: {2016, 12, 23}, id: 2, title: "Movie"},  
     %{date: {2016, 12, 24}, id: 3, title: "Shopping/Movie"}]  


# Let's see how the Process Registry is stashing processes:
iex(28)> Todo.ProcessRegistry.whereis_name({:todo_server,"bills_list"})
#PID<0.135.0>
 
iex(29)> Todo.ProcessRegistry.whereis_name({:database_worker,1})
#PID<0.129.0>

iex(30)> Todo.ProcessRegistry.whereis_name({:database_worker,2})
#PID<0.130.0>
 
iex(31)> Todo.ProcessRegistry.whereis_name({:database_worker,3})
#PID<0.131.0>

