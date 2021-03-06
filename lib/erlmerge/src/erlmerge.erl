%%%----------------------------------------------------------------------
%%% File    : erlmerge.erl
%%% Created : 16 Mar 2005 by Torbjorn Tornkvist <tobbe@tornkvist.org>
%%% Purpose : Installation tool for Erlang applications.
%%%----------------------------------------------------------------------
-module(erlmerge).

%% External exports
-export([run/0]).
-export([url/2]).

-export([get_all_app_files/0, parse_app_info/2]).


-define(elog(F,A), error_logger:info_msg("~p(~w): "++F, [?MODULE, ?LINE | A])).

-define(IS_BOOL(B), B == true ; B == false).

-define(DB_NAME, erlmerge).



-record(app, {
	  name,       % name of application: atom()
	  desc  = "", % description: string()
	  vsn,        % version number: string()
	  mods  = [], % included modules: list_of_atoms()
	  regs  = [], % registered names: list_of_atoms()
	  apps  = [], % dependency to other apps: list_of_atoms()
	  deps  = [], % deps. to other apps w.vsn.nr: [{App,Vsn},...]
	  c_deps = [],% compiled against these dependencies: [{App,Vsn},...]
	  env   = [], % application parameters and values
	  url   = "", % homepage: string()
	  loc   = "", % location: string()
	  other = [], % list of other versions, list of #app{}
	  installed = false, % is the app installed or not
	  original = false   % did this app exist when erlmerge was installed?
	 }).

%%% default values in erlmerge script
-record(options, {
	  cmd,
	  args,
	  elib_dir,
	  dryrun,
	  update,
	  url,	% url location for sync info
	  proxy,	% http proxy for url
	  url_timeout,	% timeout when connecting to url
	  make_used,	% make program used when building erlmerge
	  black_and_white	% no colour in printouts
	  }).

-record(s, {}).


%%%----------------------------------------------------------------------
%%% API
%%%----------------------------------------------------------------------
run() ->
    application:start(inets),
    Opts = get_opts(),
    #options{elib_dir=Lib_dir, cmd=Cmd} = Opts,
    add_libs_to_path( Lib_dir ),
    exec( Cmd, Opts ),
    init:stop().

get_opts() ->
    #options{cmd      = l2a(os:getenv("EM_CMD")),
	     %% Remove leading and trailing space
	     args     = string:strip(os:getenv("EM_ARGS")),
	     elib_dir = get_opts_safe_getenv("ERL_LIB_DIR"),
	     dryrun   = list2bool(os:getenv("EM_DRYRUN"), false),
	     update   = list2bool(os:getenv("EM_UPDATE"), false),
	     url      = get_opts_safe_getenv("EM_URL"),
	     proxy      = get_opts_safe_getenv("EM_PROXY"),
	     url_timeout      = get_opts_safe_getenv("EM_URL_TIMEOUT"),
	     make_used      = get_opts_safe_getenv("EM_MAKE_USED"),
	     black_and_white   = list2bool(os:getenv("EM_BLACK_AND_WHITE"), false)}.

get_opts_safe_getenv( Env_var ) ->
	case os:getenv( Env_var ) of
	false ->
		[];
	Value ->
		Value
	end.


exec(sync, P) ->
    #options{url=Url, proxy=Proxy, url_timeout=Timeout} = P,
    case url(Url, Proxy, Timeout) of
	{ok, File} ->
	    ElibDir = P#options.elib_dir,
	    SyncFname = sync_fname( ElibDir ),
	    file:write_file(SyncFname, l2b(File)),
	    DbFname = db_fname(ElibDir),
	    sync_db(SyncFname, DbFname);
	{error, econnrefused} ->
	    ?elog("Unable to connect with: ~p~n", [Url]);
	Else ->
	    ?elog("Failed to retrieve URL=~p, got: ~p~n", [Url, Else])
    end;
%%%
exec(search, P) ->
    #options{args=Args, elib_dir=ElibDir, black_and_white=Bw} = P,
    Opts = db_ropts(),
    db_open(db_fname(ElibDir), Opts),
    LcaseWhat = lcase(Args),
    F = fun(A, Acc) -> 
		case match(A, LcaseWhat) of
		    true  -> [A|Acc];
		    false -> Acc
		end
	end,
    L = dets:foldl(F, [], ?DB_NAME),
    db_close(),
    print(lists:keysort(#app.name, L), not Bw);
%%%
exec(delete, P) ->
    #options{args=Args_atom, elib_dir=ElibDir, black_and_white=Bw} = P,
    Args = l2a(Args_atom),
    Opts = db_wopts(),
    db_open(db_fname(ElibDir), Opts),
    delete(Args, not Bw),
    db_close();
%%%
exec(install, P0) ->
    P = P0#options{args = string:tokens(P0#options.args, " ")},
    ElibDir = P#options.elib_dir,
    Opts = db_wopts(),
    db_open(db_fname(ElibDir), Opts),
    install(P),
    db_close();
%%%
exec(dump, P) ->
    io:format("Opts = ~p~n", [P]),
    Args = l2a(P#options.args),
    ElibDir = P#options.elib_dir,
    Opts = db_ropts(),
    db_open(db_fname(ElibDir), Opts),
    dump(Args),
    db_close();
%%%
exec(setup, P) ->
    Opts = db_wopts(),
    ElibDir = P#options.elib_dir,
    db_open(db_fname(ElibDir), Opts),
    As = get_all_app_files(),
    Ps = parse_app_info(As, true),
    store_app_info(Ps, true),
    db_close();
%%%
exec(suicide, P) ->
    ElibDir = P#options.elib_dir,
    Opts = db_ropts(),
    db_open(db_fname(ElibDir), Opts),
    rm_non_original_applications(ElibDir),
    db_close(),
    rm_erlmerge(ElibDir);
%%%
exec(Cmd, P) ->
    ?elog("Unknown command: ~p , Opts: ~p~n", [Cmd, P]).


rm_erlmerge(ElibDir) ->
    %% Remove packet database
    Dir = erlmerge_db_directory( ElibDir ),
    rm_all( Dir ),
    io:fwrite( "Removed: ~s~n", [Dir] ),
    %% Remove the application(s) , all versions
    Wildcard = filename:join( [ElibDir, "erlmerge-*"] ),
    lists:foreach( fun rm_all/1, filelib:wildcard(Wildcard) ),
    io:fwrite( "Removed: erlmerge application~n" ),
    %% Remove the erlmerge script (the link is removed from the script itself)
    Script = filename:join( [ElibDir, "..", "bin", "erlmerge"] ),
    ok = file:delete( Script ),
    io:fwrite( "Removed: ~s~n", [Script] ).
    


get_non_orig_apps() ->
    F = fun(A,Acc) when A#app.original == false ->
		[A|A#app.other] ++ Acc;
	   (_,Acc) ->
		Acc
	end,
    dets:foldl(F, [], ?DB_NAME).


install(P) ->
    case analyse_deps(P#options.args) of
	{ok, Apps} -> % list of {App,Vsn}
	    Packages_to_install = analyse_versions(P, Apps),
	    fetch_tar_balls_and_install(P, Packages_to_install);
	{error, Emsg} ->
	    ?elog("Analyse dependency failed: ~s~n", [Emsg]);
	{cycle, Cycle} ->
	    ?elog("Analyse dependency cycle found: ~p~n", [Cycle])
    end.
	    
%%% Check that we have all the necessary App versions.
%%% Fetch packages if needed.
%%% Finally, install everything.
analyse_versions(P, Apps) ->
    #options{dryrun=Dryrun, black_and_white=Bw} = P,
    In_colour = not Bw,
    Uapps = update_apps(P, Apps),
    case catch not_installed(Uapps) of
	{not_found, {App, Vsn}} ->
	    io:format(green("~nDependency check failed~n~n", In_colour), []),
	    io:format(green("Missing Application: ~p-~s~n", In_colour), [App, Vsn]),
	    [];
	[] ->
	    io:format(green("~nNothing to merge~n~n", In_colour), []),
	    [];
	L when Dryrun == false ->
	    L;
	L when Dryrun == true ->
	    io:format(green("~nThese are the packages that I would merge"
			    ", in order:~n~n", In_colour),[]),
	    F = fun(A) -> install_reason(A, In_colour) end,
	    lists:foreach(F, L),
	    []
    end.

%%% If the Update switch is on, then find the latest
%%% versions available of all the applications.
update_apps(P, Apps) when P#options.update == true ->
    F = fun({App,Vsn}) ->
		{ok, [A]} = db_lookup(App),
		case have_newer_version(A) of
		    {true, X} -> {X#app.name, X#app.vsn};
		    _         -> {App, Vsn}
		end
	end,
    lists:map(F, Apps);
update_apps(_, Apps) ->
    Apps.



%%% 
%%% Present a line such as:
%%%
%%%  [N  ] <App>-<NewVsn>             % A new application
%%%  [ U ] <App>-<Newvsn> [<OldVsn>]  % Update to newer version
%%%  [  R] <App>-<NewVsn>             % Rebuild due to updated deps
%%%
install_reason(A, In_colour) ->
    {ok, [Z]} = db_lookup(A#app.name),
    case have_newer_version(Z) of
	{true, A} ->
	    Name = a2l(A#app.name),
	    io:fwrite(green("[ ", In_colour)++cyan("U", In_colour)++
	    	green(" ] ~s-~s", In_colour)++blue(" [~s]~n", In_colour),
		      [Name, A#app.vsn, Z#app.vsn]);
	false ->
	    case changed_cdeps(A) of
		true ->
		    io:fwrite(green("[  ", In_colour)++yellow("R", In_colour)++
		    	green("] ~s-~s~n", In_colour),
			      [a2l(A#app.name), A#app.vsn]);
		false ->
		    %% Must be a new application!
		    io:fwrite(green("[", In_colour)++"N"++green("  ] ~s-~s~n", In_colour),
			      [a2l(A#app.name), A#app.vsn])
	    end
    end.

%%% Check if the current Application has got a newer
%%% version with a greater version number.
have_newer_version(A) ->
    F = fun(X, G) ->
		case ge(G#app.vsn, X#app.vsn) of
		    true  -> G;
		    false -> X
		end
	end,
    case lists:foldl(F, A, A#app.other) of
	A -> false;
	N -> {true, N}
    end.

%%% Check if any applications that we are depending
%%% on has been updated, or removed.
changed_cdeps(A) ->
    F = fun({App, Cvsn}, Bool) ->
		case db_lookup(App) of
		    {ok, [C]} ->
			case ge(Cvsn, C#app.vsn) of
			    true -> Bool;
			    _    -> true % New dep.app !!
			end;
		    _ ->
			true  % dep.app gone !?
		end
	end,
    lists:foldl(F, false, A#app.c_deps).

		

is_already_fetched(P, Fname) ->
    ElibDir = P#options.elib_dir,
    PathName = filename:join( [distfiles(ElibDir), Fname] ),
    case file:read_file_info(PathName) of
	{ok, _} -> true;
	_       -> false
    end.
    
distfiles(ElibDir) ->
    filename:join( [erlmerge_db_directory(ElibDir), "distfiles"] ).

%%% the name suggest something more than just a printout...
rm_fetched(P, _Fetched, NotFetched) -> 
    #options{black_and_white=Bw} = P,
    In_colour = not Bw,
    F = fun(A) ->
		io:format(green("Failed to retrieve:", In_colour)++" ~s.....", [A#app.loc])
	end,
    lists:foreach(F, NotFetched).


fname(Path) ->
    filename:basename( Path ).


%%% Check which of the needed applications that
%%% aren't already installed.
not_installed([{App,Vsn} = H|T]) ->
    case db_lookup(App) of
	{ok, [A]} when A#app.installed == false ->
	    case ge(A#app.vsn, Vsn) of
		true  -> [A | not_installed(T)];
		false -> throw({not_found, H})
	    end;
	{ok, [A]} when A#app.installed == true ->
	    case ge(A#app.vsn, Vsn) of
		true  ->
		    %% We have a valid version already installed.
		    %% Perhaps its depencies has changed?
		    case changed_cdeps(A) of
			true  -> [A | not_installed(T)];
			false -> not_installed(T)
		    end;
		false -> 
		    %% We do not have a valid version installed.
		    %% Perhaps we have a newer version that is valid?
		    case have_newer_version(A) of
			{true, X} ->
			    case ge(X#app.vsn, Vsn) of
				true  -> [X | not_installed(T)];
				false -> throw({not_found, H})
			    end;
			false ->
			    throw({not_found, H})
		    end
	    end;
	_ ->
	    throw({not_found, H})
    end;
not_installed([]) ->
    [].

ge(V1, V2) ->
    F = fun(X) -> list_to_integer(X) end,
    ge0(lists:map(F, string:tokens(V1,".")), 
	lists:map(F, string:tokens(V2,"."))).


ge0([Ha|_], [Hb|_]) when Ha>Hb -> true;
ge0([H|Ta], [H|Tb])            -> ge0(Ta,Tb);
ge0([], _)                     -> true;
ge0(_, _)                      -> false.


analyse_deps(L) ->
    G = digraph:new(),
    case catch analyse_deps(L, G) of
	true ->
	    case digraph_utils:is_acyclic(G) of
		true ->
		    case digraph_utils:topsort(G) of
			false ->
			    {ok, lists:map(fun(V) -> digraph:vertex(G,V) end, 
					   digraph:vertices(G))};
			Vertices ->
			    %% Return in nice topological order.
			    {ok, lists:map(fun(V) -> digraph:vertex(G,V) end, 
					   lists:reverse(Vertices))}
		    end;
		false ->
		    {cycle,
		     [digraph:vertex(G,V) || V <- digraph_utils:loop_vertices(G)]}
	    end;
	Else ->
	    Else
    end.

analyse_deps([H|T], G) ->
    case digraph_utils:is_acyclic(G) of
	true ->
	    case db_lookup(l2a(H)) of
		false ->
		    io:format("Application: ~p not found~n", [H]),
		    throw({error, "application not found: " ++ a2l( H )});
		{ok, [A]} ->
		    digraph:add_vertex(G, A#app.name, A#app.vsn),
		    F = fun({Da,Dv}) ->	
				digraph:add_vertex(G, Da, Dv),
				digraph:add_edge(G, A#app.name, Da),
				analyse_deps([Da], G)
			end,
		    lists:foreach(F, A#app.deps),
		    analyse_deps(T, G)
	    end;
	false ->
	    throw({cycle,
		   [digraph:vertex(G,V) || V <- digraph_utils:loop_vertices(G)]})
    end;
analyse_deps([], _) ->
    true.


print(L, In_colour) ->
	F = fun(A) ->
		#app{name=Name, vsn=Vsn, desc=Desc, installed=Installed} = A,
		io:fwrite("~n~s~p~n~s~s~n~s~s~n~s~p~n",
			[green("Name: ", In_colour), Name,
			green("Version: ", In_colour), Vsn,
			green("Description: ", In_colour), Desc,
			green("Installed: ", In_colour), Installed])
	end,
	lists:foreach(F, L).


%%% Remove information about non-installed applications.
clean_db() ->
    F = fun(A, Acc) when A#app.installed == false -> 
		[A|Acc];
	   (_, Acc) ->
		Acc
	end,
    Apps = dets:foldl(F, [], ?DB_NAME),
    db_del_objects(Apps).

green(Str, false)  -> Str;
green(Str, true)  -> start_colour(green) ++ Str ++ stop_colour(green).
yellow(Str, false) -> Str;
yellow(Str, true) -> start_colour(yellow) ++ Str ++ stop_colour(yellow).
blue(Str, false) -> Str;
blue(Str, true)   -> start_colour(blue) ++ Str ++ stop_colour(blue).
cyan(Str, false) -> Str;
cyan(Str, true)   -> start_colour(cyan) ++ Str ++ stop_colour(cyan).

%%% Find out by running 'od -c' on the emerge output
start_colour(green)  -> [27,91,51,50,109];  % 8#33 $[ $3 $2 $m
start_colour(yellow) -> [27,91,51,51,109];
start_colour(blue)   -> [27,91,51,52,109];
start_colour(cyan)   -> [27,91,51,53,109].

stop_colour(green)  -> end_colour();
stop_colour(yellow) -> end_colour();
stop_colour(blue)   -> end_colour();
stop_colour(cyan)   -> end_colour().

end_colour()   -> [27,91,51,57,59,52,57,59,48,48,109].


%%%----------------------------------------------------------------------
%%% Internal functions
%%%----------------------------------------------------------------------

dump(App) ->
    case db_lookup(App) of
	false ->
	    io:format("Application: ~p not found~n", [App]);
	{ok, [Val]} ->
	    %%db_insert(Val#app{loc = "http://localhost/esmb-1.0.tar.gz"}),
	    db_insert(Val),
	    io:format("Application: ~p~n~p~n", [App, Val])
    end.

delete(App, In_colour) ->
    case db_lookup(App) of
	false ->
	    io:fwrite("Application: ~p not found~n", [App]);
	{ok, [#app{installed = false}]} ->
	    io:fwrite("Application: ~p not installed~n", [App]);
	{ok, [Val]} ->
	    rm_all( code:lib_dir(App) ),
	    db_insert(Val#app{installed = false}),
	    io:fwrite(green("Deleted application: ", In_colour)++"~p~n", [App])
    end.

%%% We assume Str is in lower case
match(_A, "") -> true;
match(A, Str) ->
    case regexp:match(lcase(a2l(A#app.name)), Str) of
	{match, _, _} -> true;
	_ ->
	    case regexp:match(lcase(a2l(A#app.desc)), Str) of
		{match, _, _} -> true;
		_             -> false
	    end
    end.
	    
lcase([C|S])               -> [lcase(C) | lcase(S)];
lcase(C) when C>=$A, C=<$Z -> C + 32;
lcase(C)                   -> C.


url(Url, Timeout) ->
    Headers = [],
    Request = {Url, Headers},
    case http:request(get, Request, [{timeout, Timeout*1000}], []) of
	{ok, {{_, 200, _}, _Hdrs, L}} ->
	    {ok, L};
	{error, _Reason} = Error ->
	    Error;
	Else ->
	    {error, Else}
    end.

url( Url, [], Timeout ) ->
	url( Url, Timeout );
url( Url, Proxy, Timeout ) ->
	Options = [{proxy, {url_proxy(Proxy), ["localhost"]}}],
	ok = http:set_options( Options ),
	url( Url, Timeout ).

url_proxy( Proxy ) ->
	case regexp:split( Proxy, ":" ) of
	{ok, [Hostname]} ->
		{Hostname, 80}; % default port
	{ok, [Hostname, Port]} ->
		{Hostname, erlang:list_to_integer( Port )}
	end.
	
erlmerge_db_directory(ElibDir) ->
	filename:join( [ElibDir, "..", "erlmerge_DB"] ).

sync_fname(ElibDir) ->
	filename:join( [erlmerge_db_directory(ElibDir), "sync.erlmerge"] ).

sync_db(SyncFname, DbFname) ->
    case file:consult(SyncFname) of
	{ok, L} ->
	    Opts = db_wopts(),
	    db_open(DbFname, Opts),
	    clean_db(),
	    Ps = parse_app_info(L, false),
	    store_app_info(Ps),
	    db_close();
	_ ->
	    ?elog("Failed to open: ~s~n(need to be root?)~n", [SyncFname])
    end.


db_fname(ElibDir) ->	
	filename:join( [erlmerge_db_directory(ElibDir), "erlmerge.dets"] ).

db_wopts() ->
    [{type, set}, {keypos, #app.name}].

db_ropts() ->
    [{access,read}, {type, set}, {keypos, #app.name}].

%db_open(Fname) ->
%    db_open(Fname, [{type, bag}]).

db_open(Fname, Opts) ->
    {ok, _} = dets:open_file(?DB_NAME, [{file, Fname}|Opts]).

db_close() ->
    dets:close(?DB_NAME).

%db_insert(Key, Value) ->
%    dets:insert(?DB_NAME, {Key, Value}).

db_insert(A) when record(A, app) ->
    dets:insert(?DB_NAME, A).

db_del_object(A) when record(A, app) ->
    dets:delete_object(?DB_NAME, A).

db_del_objects(Objs) when list(Objs) ->
    lists:foreach(fun(A) -> db_del_object(A) end, Objs).


db_lookup(Key) ->
    case dets:lookup(?DB_NAME, Key) of
	[]  -> false;
	Val -> {ok, Val}
    end.


get_all_app_files() ->
    LibDir = code:lib_dir(),
    {ok, Apps} = file:list_dir(LibDir),
    F = fun(A, Acc) ->
		[A1|_] = string:tokens(A, "-"),
%		App = LibDir ++ "/" ++ A ++ "/ebin/" ++ A1 ++ ".app",
		App = filename:join( [LibDir, A, "ebin", lists:append( A1, ".app")] ),
		case file:consult(App) of
		    {ok, Res} -> Res ++ Acc;
		    _         -> Acc
		end
	end,
    lists:foldl(F, [], Apps).


parse_app_info(As, Installed) when ?IS_BOOL(Installed)  ->
    F = fun({application, Aname, L}) ->
		pappi(L, #app{name  = l2a(Aname),
			      installed = Installed})
	end,
    lists:map(F, As).

pappi([{description, Desc}|T], A) ->
    pappi(T, A#app{desc = Desc});
pappi([{vsn, Vsn}|T], A) ->
    pappi(T, A#app{vsn = Vsn});
pappi([{modules, Mods}|T], A) ->
    pappi(T, A#app{mods = Mods});
pappi([{registered, Regs}|T], A) ->
    pappi(T, A#app{regs = Regs});
pappi([{applications, Deps}|T], A) ->
    pappi(T, A#app{apps = Deps});
pappi([{dependencies, Deps}|T], A) ->
    pappi(T, A#app{deps = Deps});
pappi([{location, Loc}|T], A) ->
    pappi(T, A#app{loc = Loc});
pappi([{env, Env}|T], A) ->
    pappi(T, A#app{env = Env});
pappi([_|T], A) ->
    pappi(T, A); % unknown!
pappi([], A) ->
    A.

store_app_info(Ps) ->
    store_app_info(Ps, false).

store_app_info(Ps, Original) ->
    F = fun(A) -> 
		case db_lookup(A#app.name) of
		    false ->
			db_insert(A#app{original = Original});
		    {ok, [App]} when App#app.installed == true ->
			Other = App#app.other,
			db_insert(App#app{other = [A|Other]});
		    {ok, [App]} when App#app.installed == false ->
			db_del_object(App),
			db_insert(A)
		end
	end,
    lists:foreach(F, Ps).


l2b(L) when list(L)   -> list_to_binary(L);
l2b(B) when binary(B) -> B.

l2a(L) when list(L) -> list_to_atom(L);
l2a(A) when atom(A) -> A.

a2l(A) when atom(A) -> atom_to_list(A);
a2l(L) when list(L) -> L.

list2bool("true", _)  -> true;
list2bool("false", _) -> false;
list2bool(_, Default) -> Default.



fetch_tar_balls_and_install(_P, []) -> ok;
fetch_tar_balls_and_install(P, L) ->
    case fetch_tar_balls(P, L, [], []) of
	{Fetched, []}         -> unpack_and_make(P, Fetched);
	{Fetched, NotFetched} -> rm_fetched(P, Fetched, NotFetched)
    end.

fetch_tar_balls(P, [H|T], Fetched, NotFetched) ->
    #options{black_and_white=Bw} = P,
    In_colour = not Bw,
    Location = H#app.loc,
    Fname = fname(H#app.loc),
    case is_already_fetched(P, Fname) of
	true ->
	    io:fwrite(green("already retrieved:", In_colour)++" ~s~n", [Fname]),
	    fetch_tar_balls(P, T, [H|Fetched], NotFetched);
	false ->
	    #options{proxy=Proxy, url_timeout=Timeout, black_and_white=Bw} = P,
	    case url(Location, Proxy, Timeout) of
		{ok, File} ->
		    io:fwrite(green("retrieved:", In_colour)++" ~s~n", [Location]),
		    ElibDir = P#options.elib_dir,
		    PathName = filename:join( [distfiles(ElibDir), Fname] ),
		    file:write_file(PathName, l2b(File)),
		    fetch_tar_balls(P, T, [H|Fetched], NotFetched);
		{error, econnrefused} ->
		    io:format(green("Unable to connect with:", In_colour)++" ~p~n",
		    	[Location]),
		    fetch_tar_balls(P, T, Fetched, [H|NotFetched]);
		Else ->
		    io:fwrite(green("failed to retrieve:", In_colour)++" ~p, got: ~p~n",
		    	[Location, Else]),
		    fetch_tar_balls(P, T, Fetched, [H|NotFetched])
	    end
    end;
fetch_tar_balls(_P, [], Fetched, NotFetched) ->
    {lists:reverse(Fetched), % keep the order
     NotFetched}.

unpack_and_make(P, Fetched) ->
	#options{elib_dir=ElibDir, make_used=Make, black_and_white=Bw} = P,
	In_colour = not Bw,
	{ok, Current_directory} = file:get_cwd(),
	%% work in the lib directory
	ok = file:set_cwd( ElibDir ),
	Fun = fun (#app{loc=Loc, name=Name, vsn=Vsn} = App) ->
		Fname = fname( Loc ),
		PathName = filename:join( [distfiles( ElibDir ), Fname] ),
		%% Unpack the tar-ball
		io:fwrite( green("unpacking:", In_colour)++" ~s.....", [Fname] ),
		Application = lists:concat([Name,"-",Vsn]),
		case is_untar_ok( PathName ) of
		true ->
		    %% Run make
		    Installed = is_make_ok( Application, Make, In_colour ),
		    db_insert( App#app{installed = Installed} );
		false ->
		    io:fwrite( "failed unpacking: ~s.....", [Fname] )
		end
	end,
	lists:foreach( Fun, Fetched ),
	%% back to original directory
	ok = file:set_cwd( Current_directory ),
	io:fwrite( green("finished!", In_colour)++"~n" ).

is_untar_ok( Tarfile ) ->
	case erl_tar:extract( Tarfile, [compressed]) of
	ok ->
		true;
	{error, Reason} ->
		erl_tar:format_error( Reason ),
		false
	end.

is_make_ok( Application, Make, In_colour ) ->
	{ok, Current_directory} = file:get_cwd(),
	%% work in the application directory
	ok = file:set_cwd(Application),
	io:fwrite( green("compiling:", In_colour)++" ~s.....", [Application] ),
	Result = case filelib:is_regular( "Emakefile" ) of
		true ->	% Emakefile exists as regular file. use erlang make.
			case make:all() of
			up_to_date ->
				true;
			error ->
				false
			end;
		false ->	% try os make
			is_make_ok_os_alternatives( Application, Make )
		end,
	%% back to current directory
	ok = file:set_cwd(Current_directory),
	Result.

is_make_ok_os_alternatives( Application, [] ) ->
	is_make_ok_try_alternatives( Application, ["make"] );
is_make_ok_os_alternatives( Application, Make ) ->
	%% 1 use make available with operating system.
	%% 2 if 1 fails use gnumake used for erlmerge (if available).
	%% add the directory of gnumake to the path and try gnumake again.
	%% somebody using gnumake might also use other gnu specific programs.
	New_path = lists:append( ["PATH=", filename:dirname( Make ), ":$PATH"] ),
	Make2 = lists:append( [New_path, " ", filename:basename( Make )] ),
	is_make_ok_try_alternatives(Application, ["make", Make2]).
	
is_make_ok_try_alternatives( _Application, [] ) -> fail;
is_make_ok_try_alternatives( Application, [Make|T] ) ->
	io:fwrite( "with ~s~n", [Make]),
	%%?elog("~s~n", ["(cd " ++ ElibDir ++ "/" ++ Dir ++ "; make)"]),
	Res = os:cmd( lists:append([Make, " ; echo $?"]) ),
	Lines = string:tokens( Res, "\n" ),
	case erlang:length( Lines ) < 10 of
	true ->
		io:fwrite("~s~n", [Res]);
	false ->	% only write last few Lines
		io:fwrite("~n...deleted~n"),
		Fun = fun (Line) -> io:fwrite("~s~n", [Line]) end,
		lists:foreach( Fun, lists:nthtail(10, Lines) )
	end,
	%% check status (what echo $? produced)
	case erlang:list_to_integer(lists:last( Lines )) of
	0 ->
		true;
	_Else ->
		is_make_ok_try_alternatives( Application, T )
	end.


%%% is this applications or libraries?
rm_non_original_applications( ElibDir ) ->
	{ok, Current_directory} = file:get_cwd(),
	ok = file:set_cwd( ElibDir ),
	Fun = fun (#app{installed=true, name=Name, vsn=Vsn}) ->
				Application = lists:concat( [Name, "-", Vsn] ),
				rm_all( Application ),
				io:fwrite("Removed: ~s~n", [a2l( Name )]);
			(#app{installed=false}) -> ok
		end,
	lists:foreach( Fun, get_non_orig_apps() ),
	ok = file:set_cwd(Current_directory).

rm_all( Directory ) ->
	case filelib:is_dir( Directory ) of
	true ->
		{ok, Contents} = file:list_dir( Directory ),
		% create absolut path
		Fun = fun ( Name ) ->
				filename:join( [Directory, Name] )
			end,
		lists:foreach( fun rm_all/1, lists:map(Fun, Contents) ),
		ok = file:del_dir( Directory );
	false ->	% file
		ok = file:delete( Directory )
	end.


add_libs_to_path( Lib_dir ) ->
	Ebin_directories = filelib:wildcard( filename:join([Lib_dir, "*", ebin]) ),
	ok = code:add_pathsz( Ebin_directories ).
