-module(pico_socket_server).

%% Copyright (C) 1999, Bluetail AB
%% File    : pico_socket_server.erl
%% Author  : Joe Armstrong (joe@bluetail.com)
%% Purpose : Keeps track of a number of TCP sessions


%% start_server(Port, Fun, Max) -> bool().
%%   This server accepts up to Max connections on Port
%%   Each time data is received 
%%   Fun(Socket, Data) is called this should return
%%     {'EXIT', Why} ->
%%         close the socket, or, 
%%     Fun ->
%%         A new Fun to be called next time we get data

%% stop_server(Port) -> ok.
%% children(Port) -> [Pids]
 
-export([start_server/3, stop_server/1, children/1]).

%% Internal imports (used by spawn)

-export([cold_start/4,  start_child/3]).

%% Fun = fun(Socket, Binary) -> Fun'

%% raw server uses packet length 0

start_server(Port, Fun, Max) ->
    start_raw_server(Port, Fun, Max, 0).

port_name(Port) when integer(Port) ->
    list_to_atom("picoSocketServer_" ++ integer_to_list(Port)).

start_raw_server(Port, Fun, Max, PacketLength) ->
    Name = port_name(Port),
    case whereis(Name) of
	undefined ->
	    Pid = spawn_link(?MODULE, cold_start, 
			     [Port, Fun, Max, PacketLength]),
	    register(Name, Pid),
	    true;
	Pid ->
	    false
    end.

stop_server(Port) when integer(Port) ->
    Name = port_name(Port),
    case whereis(Name) of
	undefined ->
	    ok;
	Pid ->
	    exit(Pid, kill),
	    (catch unregister(Name)),
	    ok
    end.

children(Port) when integer(Port) ->
    port_name(Port) ! {children, self()},
    receive
	{session_server, Reply} -> Reply
    end.


cold_start(Port, Fun, Max, PacketLength) ->
    process_flag(trap_exit, true),
    io:format("Starting a port server on ~p...~n",[Port]),
    {ok, Listen} = gen_tcp:listen(Port, [binary,
					 {reuseaddr, true}, 
					 {packet, PacketLength},
					 {active, false}]),
    New = start_accept(Listen, Fun),
    socket_loop(Listen, New, [], Fun, Max).

%% Don't mess with the following code uless you really know what you're 
%% doing (and Thanks to Magnus for heping me get it right)

socket_loop(Listen, New, Active, Fun, Max) ->
    receive
	{started, New} ->
	    Active1 = [New|Active],
	    possibly_start_another(false, Listen, Active1, Fun, Max);
	{'EXIT', New, Why} ->
	    possibly_start_another(false, Listen, Active, Fun, Max);
	{'EXIT', Pid, Why} ->
	    Active1 = lists:delete(Pid, Active),
	    possibly_start_another(New, Listen, Active1, Fun, Max);
	{children, From} ->
	    From ! {session_server, Active},
	    socket_loop(Listen, New, Active, Fun, Max);
	Other ->
	    io:format("Here in loop:~p~n",[Other])
    end.

possibly_start_another(New, Listen, Active, Fun, Max) when pid(New) ->
    socket_loop(Listen, New, Active, Fun, Max);
possibly_start_another(false, Listen, Active, Fun, Max) ->
    case length(Active) of
	N when N < Max ->
	    New = start_accept(Listen, Fun),
	    socket_loop(Listen, New, Active, Fun, Max);
	_ ->
	    socket_loop(Listen, false, Active, Fun, Max)
    end.

start_accept(Listen, Fun) ->
    spawn_link(?MODULE, start_child, [self(), Listen, Fun]).

start_child(Parent, Listen, Fun) ->
    case gen_tcp:accept(Listen) of
	{ok, Socket} ->
	    Parent ! {started, self()},		    % tell the controller
	    inet:setopts(Socket, [{active, true}]), % before we activate socket
	    child_loop(Parent, Socket, Fun);
	Other ->
	    exit(oops)
    end.

child_loop(Parent, Socket, Fun) ->
    receive
	{tcp, Socket, Bin} ->
	    case (catch Fun(Socket, Bin)) of
		{'EXIT', Why} ->
		    print_exit(Why),
		    gen_tcp:close(Socket);
		Fun1 ->
		    child_loop(Parent, Socket, Fun1)
	    end;
	{tcp_closed, Socket} ->
	    %% io:format("child loop tcp_close:~n"),
	    exit(normal);
	{tcp_error, Socket, Reason} ->
	    %% io:format("child loop tcp_error:~p~n",[Reason]),
	    exit(normal);
	Other ->
	    %% io:format("child loop funny message ~p~n", [Other]),
	    exit(nyi)
    end.

print_exit(done) ->
    true;
print_exit(normal) ->
    trie;
print_exit(Why) ->
    io:format("child exited ~p~n", [Why]).
