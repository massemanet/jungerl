%% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% The Initial Developer of the Original Code is Ericsson Utvecklings AB.
%% Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
%% AB. All Rights Reserved.''
%% 
%%     $Id$
%%
-module(gdict).

-export([new/3,
	 append/3,
	 append_list/3,
	 erase/2,
	 fetch/2,
	 fetch_keys/1,
	 filter/2,
	 find/2,
	 fold/3,
%%	 from_list/1,
	 is_key/2,
	 map/2,
%%	 merge/3,
	 store/3,
	 to_list/1,
	 update/3,
	 update/4,
	 update_counter/3]).


new(Name, Candidates, Workers) ->
    gen_leader:start(Name,Candidates, Workers, test_cb, dict:new(), []).

-define(store(Dict,Expr,Legend),
	gen_leader:leader_call(Dict, {store, fun(D) ->
						     Expr
					     end})).

-define(lookup(Dict, Expr, Legend),
	gen_leader:call(Dict, {lookup, fun(D) ->
					       Expr
				       end})).

%% dict functions that modify state:
append(Key, Value, Dict) ->
    ?store(Dict, dict:append(Key,Value,D), append).
append_list(Key, ValList, Dict) ->
    ?store(Dict, dict:append_list(Key,ValList,D), append_list).
erase(Key, Dict) ->
    ?store(Dict, dict:erase(Key,D), erase).
store(Key, Value, Dict) ->
    ?store(Dict, dict:store(Key,Value,D), store).
update(Key,Function,Dict) ->
    ?store(Dict, dict:update(Key,Function,D), update).
update(Key, Function, Initial, Dict) ->
    ?store(Dict, dict:update(Key,Function,Initial,D), update).
update_counter(Key, Incr, Dict) ->
    ?store(Dict, dict:update_counter(Key,Incr,D), update_counter).

%% dict functions that do not modify state (lookup functions)
%%
fetch(Key, Dict) ->	 ?lookup(Dict, dict:fetch(Key,D),	fetch).
fetch_keys(Dict) ->	 ?lookup(Dict, dict:fetch_keys(D),	fetch_keys).
filter(Pred, Dict) ->	 ?lookup(Dict, dict:filter(Pred,D),	filter).
find(Key, Dict) ->	 ?lookup(Dict, dict:find(Key,D),	find).
fold(Fun, Acc0, Dict) -> ?lookup(Dict, dict:fold(Fun,Acc0,D),	fold).
is_key(Key, Dict) ->	 ?lookup(Dict, dict:is_key(Key,D),	is_key).
map(Fun, Dict) ->	 ?lookup(Dict, dict:map(Fun,D),		map).
to_list(Dict) ->	 ?lookup(Dict, dict:to_list(D),		to_list).
