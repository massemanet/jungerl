%%%----------------------------------------------------------------------
%%% File    : posix_drv.erl
%%% Summary : Simple POSIX system call driver
%%%
%%%
%%% NOTICE: This file was generated by the tools of the Erlang Driver
%%%         toolkit.  Do not edit this file by hand unless you know
%%%         what you're doing!
%%%
%%% Copyright (c) 2003, Scott Lystig Fritchie.  All rights reserved.
%%% See the file "../LICENSE" for license details.
%%%
%%%----------------------------------------------------------------------

-module(posix_drv).
-include("posix_drv.hrl").

%% Xref with erl_driver_tk.h's PIPE_DRIVER_TERM_* values
-define(T_NIL, 0).
-define(T_ATOM, 1).
-define(T_PORT, 2).
-define(T_INT, 3).
-define(T_TUPLE, 4).
-define(T_BINARY, 5).
-define(T_STRING, 6).
-define(T_LIST, 7).

%% External exports
-export([start/0, start_pipe/0]).
-export([shutdown/1]).
-export([debug/2]).
-export([
         getgid/1, 
         getegid/1, 
         getgrnam/2, 
         getgrgid/2, 
         getgroups/1, 
         getpwnam/2, 
         getpwuid/2, 
         getuid/1, 
         geteuid/1, 
         getlogin/1, 
         getpgrp/1, 
         getppid/1, 
         getsid/1, 
         kill/3, 
         lstat/2, 
         mkfifo/3, 
         mknod/4, 
         umask/2
        ]).

start() ->
    {ok, Path} = load_path(?DRV_NAME ++ ".so"),
    erl_ddll:start(),
    ok = erl_ddll:load_driver(Path, ?DRV_NAME),
    case open_port({spawn, ?DRV_NAME}, []) of
        P when port(P) ->
            {ok, P};
        Err ->
            Err
    end.

start_pipe() ->
    {ok, PipeMain} = load_path("pipe-main"),
    {ok, ShLib} = load_path("./posix_drv.so"),
    Cmd = PipeMain ++ "/pipe-main " ++ ShLib ++ "/posix_drv.so",
    case open_port({spawn, Cmd}, [exit_status, binary, use_stdio, {packet, 4}]) of
        P when port(P) ->
            {ok, P};
        Err ->
            Err
    end.

shutdown(Port) when port(Port) ->
    catch erlang:port_close(Port),
    %% QQQ I was under the impression you'd always get a message sent to
    %% you in this case, so this receive is to keep your mailbox from
    %% getting cluttered.  Hrm, well, sometimes the message does
    %% not arrive at all!
    receive
        {'EXIT', Port, normal} -> {ok, normal};
        {'EXIT', Port, Err}    -> {error, Err}
    after 0                    -> {ok, normall} % QQQ is 0 too small?
        
    end.

debug(Port, Flags) when port(Port), integer(Flags) ->
    case catch erlang:port_command(Port, <<?_DEBUG, Flags:32>>) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ too drastic?
    end.

getgid(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETGID>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getegid(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETEGID>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getgrnam(Port,
     Name
        ) when port(Port) -> % TODO: Add additional constraints here
    {NameBinOrList, NameLen} = serialize_contiguously(Name, 1),
    IOList_____ = [ <<?_GETGRNAM,
            NameLen:32/integer>>,               % I/O list length
          NameBinOrList,
          <<
        >> ],
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getgrgid(Port,
     Gid
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETGRGID,
          Gid:32/unsigned-integer
        >>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getgroups(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETGROUPS>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getpwnam(Port,
     Login
        ) when port(Port) -> % TODO: Add additional constraints here
    {LoginBinOrList, LoginLen} = serialize_contiguously(Login, 1),
    IOList_____ = [ <<?_GETPWNAM,
            LoginLen:32/integer>>,              % I/O list length
          LoginBinOrList,
          <<
        >> ],
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getpwuid(Port,
     Uid
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETPWUID,
          Uid:32/unsigned-integer
        >>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getuid(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETUID>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

geteuid(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETEUID>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getlogin(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETLOGIN>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getpgrp(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETPGRP>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getppid(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETPPID>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

getsid(Port
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_GETSID>>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

kill(Port,
     Pid, 
     Sig
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_KILL,
          Pid:32/integer, 
          Sig:32/integer
        >>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

lstat(Port,
     Path
        ) when port(Port) -> % TODO: Add additional constraints here
    {PathBinOrList, PathLen} = serialize_contiguously(Path, 1),
    IOList_____ = [ <<?_LSTAT,
            PathLen:32/integer>>,               % I/O list length
          PathBinOrList,
          <<
        >> ],
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

mkfifo(Port,
     Path, 
     Mode
        ) when port(Port) -> % TODO: Add additional constraints here
    {PathBinOrList, PathLen} = serialize_contiguously(Path, 1),
    IOList_____ = [ <<?_MKFIFO,
            PathLen:32/integer>>,               % I/O list length
          PathBinOrList,
          <<
          Mode:32/integer
        >> ],
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

mknod(Port,
     Path, 
     Mode, 
     Dev
        ) when port(Port) -> % TODO: Add additional constraints here
    {PathBinOrList, PathLen} = serialize_contiguously(Path, 1),
    IOList_____ = [ <<?_MKNOD,
            PathLen:32/integer>>,               % I/O list length
          PathBinOrList,
          <<
          Mode:32/integer, 
          Dev:32/integer
        >> ],
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

umask(Port,
     Numask
        ) when port(Port) -> % TODO: Add additional constraints here
    IOList_____ = <<?_UMASK,
          Numask:32/integer
        >>,
    case catch erlang:port_command(Port, IOList_____) of
        true -> get_port_reply(Port);
        Err  -> throw(Err)              % QQQ Is this too drastic?
    end.

    
%%%
%%% Internal functions.
%%%

load_path(File) ->
    case lists:filter(fun(D) ->
                              case file:read_file_info(D ++ "/" ++ File) of
                                  {ok, _} -> true;
                                  _ -> false
                              end
                      end, code:get_path()) of
        [Dir|_] ->
            {ok, Dir};
        [] ->
            io:format("Error: ~s not found in code path\n", [File]),
            {error, enoent}
    end.

%%%
%%% QQQ Note that an 'xtra_return' that only returns one item in its
%%%     tuple will return {Port, ok, {Thingie}}, so we'll return
%%%     {ok, {Thingie}}, which is *sooooooo* maddening because I keep
%%%     forgetting the extra tuple wrapper.  So, if there's only one
%%%     thingie in the return tuple, strip it off!
%%%

get_port_reply(Port) when port(Port) ->
    receive
        {Port, ok} = T -> proc_reply(T);
        {Port, ok, {M}} = T -> proc_reply(T);
        {Port, ok, M} = T -> proc_reply(T);
        {Port, error, {Reason}} = T -> proc_reply(T);
        {Port, error, Reason} = T -> proc_reply(T);
        %% Pipe driver messages
        {Port, {data, Bytes}} -> proc_reply(pipedrv_deser(Port, Bytes));
        {'EXIT', Port, Reason} -> throw({port_error, Reason});  % QQQ too drastic?
        {Port, Reason} -> throw({port_error, Reason})   % QQQ too drastic?
    end.

%% This function exists to provide consistency of replies 
%% given by linked-in and pipe drivers.  The "receive" statement
%% in get_port_reply/1 is specific because we want it to be
%% very selective about what it will grab out of the mailbox.
proc_reply({Port, ok}) when port(Port) ->
    ok;
proc_reply({Port, ok, {M}}) when port(Port) ->
    {ok, M};
proc_reply({Port, ok, M}) when port(Port) ->
    {ok, M};
proc_reply({Port, error, {Reason}}) when port(Port) ->
    {error, Reason};
proc_reply({Port, error, Reason}) when port(Port) ->
    {error, Reason}.


%%% QQQ io_list_len() is an extremely useful function.  BEAM has got this
%%% implemented quite efficiently in C.  It would be *fabulous* to be able
%%% to use it from Erlang via a BIF.

io_list_len(B) when binary(B) -> {B, size(B)};
io_list_len(L) when list(L) -> io_list_len(L, 0).
io_list_len([H|T], N) ->
    if
        H >= 0, H =< 255 -> io_list_len(T, N+1);
        list(H) -> io_list_len(T, io_list_len(H,N));
        binary(H) -> io_list_len(T, size(H) + N);
        true -> throw({error, partial_len, N})
    end;
io_list_len(H, N) when binary(H) -> 
    size(H) + N;
io_list_len([], N) -> 
    N.

%%% QQQ We need to make the binary thing we're passing in contiguous
%%% because the C function we're calling is expecting a single
%%% contiguous buffer.  If IOList is ["Hello, ", <<"World">>, "!"],
%%% that binary in the middle element will end up with the argument
%%% spanning three parts of an ErlIOVec.  If that happens, then we'd
%%% have to have the driver do the dirty work of putting the argument
%%% into a single contiguous buffer.  Frankly, we're lazy, and this
%%% code is short and won't be much slower than doing it in C.

%%% 2nd arg: if 1, NUL-terminate the IOList

serialize_contiguously(B, 0) when binary(B) ->
    {B, size(B)};
serialize_contiguously([B], 0) when binary(B) ->
    {B, size(B)};
serialize_contiguously(IOList, 1) ->
    serialize_contiguously([IOList, 0], 0);
serialize_contiguously(IOList, 0) ->
    B = list_to_binary(IOList),
    {B, size(B)}.


%% pipedrv_deser/2 -- Deserialize the term that the pipe driver is
%% is returning to Erlang.  The pipe driver doesn't know it's a pipe
%% driver, it thinks it's a linked-in driver, so it tries to return
%% an arbitrary Erlang term to us.  The pipe-main program is sneaky:
%% it has a driver_output_term() function that serializes the term
%% that the driver built.  With the help of a list-as-stack, we
%% deserialize that term.

pipedrv_deser(Port, B) ->
    pipedrv_deser(Port, B, []).

pipedrv_deser(Port, <<>>, []) ->
    throw(icky_i_think);
pipedrv_deser(Port, <<>>, [T]) ->
    T;
pipedrv_deser(Port, <<?T_NIL:8, Rest/binary>>, Stack) ->
    pipedrv_deser(Port, Rest, [foo___foo_nil___|Stack]);
pipedrv_deser(Port, <<?T_ATOM:8, Len:8, Rest/binary>>, Stack) ->
    <<A:Len/binary, Rest2/binary>> = Rest,
    pipedrv_deser(Port, Rest2, [list_to_atom(binary_to_list(A))|Stack]);
pipedrv_deser(Port, <<?T_PORT:8, P:32/unsigned, Rest/binary>>, Stack) ->
    %% The pipe driver tried sending us a port, but it cannot know what
    %% port ID was assigned to this port, so we'll assume it is Port.
    pipedrv_deser(Port, Rest, [Port|Stack]);
pipedrv_deser(Port, <<?T_INT:8, I:32/signed, Rest/binary>>, Stack) ->
    pipedrv_deser(Port, Rest, [I|Stack]);
pipedrv_deser(Port, <<?T_TUPLE:8, N:8, Rest/binary>>, Stack) ->
    {L, NewStack} = popN(N, Stack),
    pipedrv_deser(Port, Rest, [list_to_tuple(L)|NewStack]);
pipedrv_deser(Port, <<?T_LIST:8, N:32, Rest/binary>>, Stack) ->
    {L, NewStack} = popN(N, Stack),
    pipedrv_deser(Port, Rest, [L|NewStack]);
pipedrv_deser(Port, <<?T_BINARY:8, Len:32/signed, Rest/binary>>, Stack) ->
    <<Bin:Len/binary, Rest2/binary>> = Rest,
    pipedrv_deser(Port, Rest2, [Bin|Stack]);
pipedrv_deser(Port, <<?T_STRING:8, Len:32/signed, Rest/binary>>, Stack) ->
    <<Bin:Len/binary, Rest2/binary>> = Rest,
    pipedrv_deser(Port, Rest2, [binary_to_list(Bin)|Stack]);
pipedrv_deser(Port, X, Y) ->
    throw({bah, X, Y}).

popN(N, Stack) ->
    popN(N, Stack, []).
popN(0, Stack, Acc) ->
    {Acc, Stack};
popN(N, [foo___foo_nil___|T], Acc) ->
    %% This is the nonsense we put on the stack to represent NIL.  Ignore it.
    popN(N - 1, T, Acc);
popN(N, [H|T], Acc) ->
    popN(N - 1, T, [H|Acc]).


%%%
%%% Begin code included via <custom_erl> tags
%%%


