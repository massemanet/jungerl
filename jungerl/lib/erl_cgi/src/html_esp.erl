%%% File    : html_esp.erl
%%% Author  : Tony Rogvall <tony@localhost.localdomain>
%%% Description : ESP generator from HTML documents
%%% Created :  5 May 2002 by Tony Rogvall <tony@localhost.localdomain>

-module(html_esp).

-export([parse/1,parse/2,file/1,tokenise/2]).
-import(lists, [map/2, reverse/1,member/2]).

-compile(export_all).

%% -define(debug,true).

-ifdef(debug).
-define(dbg(Fmt,Args), io:format(Fmt, Args)).
-else.
-define(dbg(Fmt,Args), ok).
-endif.


-record(state,
	{
	  %% default formatting function is just a dummy
	  fmt = fun(Tag,As,Cs) -> {Tag,As,Cs} end, 
	  %% default environment is empty [{Var,Value}]
	  env = [],
	  file = "*stdin*",
	  path = ""
	 }).


file(File) ->
    case file:read_file(File) of
	{ok,Bin} ->
	    parse(Bin,File);
	Error ->
	    Error
    end.

file_html(File) ->
    case file(File) of
	{ok,Esp} ->
	    io:put_chars(esp_html:format(Esp));
	Error ->
	    Error
    end.

file_esp(File) ->
    case file(File) of
	{ok,Esp} ->
	    io:format("~p\n",[Esp]);
	Error ->
	    Error
    end.

file_tokens(File) ->
    case file:read_file(File) of
	{ok,Bin} ->
	    St = #state { fmt = fun parse_fmt/3,
			  file = File,
			  env = []
			 },
	    case tokenise(Bin,St) of
		{ok,Ts} ->
		    lists:foreach(fun(T) -> io:format("~p\n", [T]) end, Ts);
		Error ->
		    Error
	    end;
	Error  -> Error
    end.

parse(Chars) ->
    parse(Chars, "*stdin*").

parse(Chars,File) ->
    St = #state { fmt = fun parse_fmt/3,
		  env = [],
		  file = File
		 },
    case tokenise(Chars,St) of
	{ok, Tokens} -> parse0(Tokens, St);
	Error -> Error
    end.

parse_fmt(Tag,As,Cs) ->
    {Tag,As,Cs}.

fmt(St,Tag,As,Cs) ->
    case St#state.fmt of
	undefined -> {Tag,As,Cs};
	Fun -> Fun(Tag,As,Cs)
    end.

parse0([{tag,'!doctype',Type}|Ts],St) -> 
    parse0(Ts,St);
parse0([{pcdata,Data}|Ts],St) -> 
    [] = skip_white(Data), %% only white space allowed
    parse0(Ts,St);
parse0([{tag,html,As}|Ts],St) ->
    case elem(html,As,Ts,[html], St) of
	{Html,[]} ->
	    {ok,{document,[Html]}};
	{Html,[{pcdata,Data}]} ->
	    [] = skip_white(Data),
	    {ok,{document,[Html]}}
    end;
parse0([{tag,Tag,Attr} | Ts],St) ->
    {Flow,_} = repeat(fun(T) -> html:is_flow(T) end, Ts, [body,html],St),
    {ok,{document,Flow}}.
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% element parsing
%% elem(Tag, Attributes, Tokens, Parents)
%%
%% return {Tokens', {Tag,Attributes,Children}}
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
%% EXTENSION <erl>#PCDATA</erl>
%%
elem(erl,As,Ts,Ps,St) ->
    {{erl,Attr,Cs},Ts1} = el(erl,As,Ts,fun(T) -> T == pcdata end,Ps,St),
    String = flatten_pcdata(Cs),
    {ok,Tokens,Ln} = erl_scan:string(String),
    {ok,Exprs} = erl_parse:parse_exprs(Tokens++[{dot,'.'}]),
    {{erl,As,Exprs},Ts1};

%%
%% <!ENTITY % html.content "HEAD, BODY">
%% <!ELEMENT HTML O O (%html.content;)    -- document root element -->
%%
elem(html,As,Ts,Ps,St) ->
    ?dbg("~s<~p>\n", [indent(Ps),html]),
    {E1,Ts1} = require(head, Ts,Ps,St),
    case ent(fun(T) -> (T == body) or (T == frameset) end, Ts1,Ps,St) of
	{[E2],Ts2} ->
	    {fmt(St,html,attrlist(html,As),[E1,E2]), elem_end(html,Ts2,Ps)};
	{[],Ts2} ->
	    exit({bad_tag,html,Ps})
    end;

%%
%% <!ELEMENT HEAD O O (%head.content;) +(%head.misc;) -- document head -->
%%
%% FIXME: head.content = TITLE & BASE?
%% i.e one TITLE and optionally one BASE in any order
%% 
elem(head,As,Ts,Ps,St) ->
    el(head,As,Ts,fun(T) -> html:is_head_misc(T) or 
				html:is_head_content(T) end,Ps,St);

%%
%% <!ELEMENT BODY O O (%flow)+ +(INS|DEL) -- document body -->
%%
%% FIXME: INS and DEL is not handled
%%
elem(body,As,Ts,Ps,St) -> el(body,As,Ts, html:flow(),Ps,St);

elem(title, As, Ts,Ps,St) ->
    el(title,As,Ts,fun(T) -> T == pcdata end,Ps,St);

%%
%% <!ELEMENT META - O EMPTY               -- generic metainformation -->
%%
elem(meta,As,Ts,Ps,St) -> el0(meta,As,Ts,Ps,St);

%%
%% <!ELEMENT BASE - O EMPTY               -- document base URI -->
%%
elem(base,As,Ts,Ps,St) -> el0(base,As,Ts,Ps,St);

%%
%% <!ELEMENT LINK - O EMPTY               -- a media-independent link -->
%%
elem(link,As,Ts,Ps,St)  -> el0(link,As,Ts,Ps,St);

elem(noscript, As, Ts,Ps,St) -> el(noscript,As,Ts,html:block(),Ps,St);

elem(object, As, Ts,Ps,St) -> el(object,As,Ts,
			   fun(T) -> html:is_flow(T) or (T == param) end,Ps,St);

elem(param, As, Ts,Ps,St) -> el0(param,As,Ts,Ps,St);

elem(img, As, Ts,Ps,St) -> el0(img,As,Ts,Ps,St);


elem(style,As,Ts,Ps,St) ->
    %% FIXME: handle commented styles
    el(style,As,Ts,fun(T) -> T == pcdata end,Ps,St);

elem(script,As,Ts,Ps,St) ->
    %% FIXME: handle commented scripts
    el(style,As,Ts,fun(T) -> T == pcdata end,Ps,St);


elem(form, As, Ts,Ps,St) -> el(form,As,Ts,
			    fun(T) -> html:is_flow(T) and (T =/= form) end,Ps,St);
%%
%% <!ELEMENT TABLE - -
%%     (CAPTION?, (COL*|COLGROUP*), THEAD?, TFOOT?, TBODY+)>
%%
elem(table,As,Ts0,Ps,St) ->
    ?dbg("~s<~p>\n", [indent(Ps),table]),
    {E1,Ts1} = optional(caption,Ts0,Ps,St),
    {E2,Ts2} = repeat(fun(Tag) -> (Tag == col) or (Tag == colgroup) end,
		      Ts1,Ps,St),
    {E3,Ts3} = optional(thead, Ts2,Ps,St),
    {E4,Ts4} = optional(tfoot, Ts3,Ps,St),    
    {E5,Ts5} = optional(tbody, Ts4,Ps,St),
    {E6,Ts6} = repeat(fun(T) -> T == tr end, Ts5,Ps,St),
    Ts7 = elem_end(table,Ts6,Ps),
    { fmt(St,table,attrlist(table,As),E1++E2++E3++E4++E5++E6), Ts7};

%%
%% <!ELEMENT TBODY    O O (TR)+           -- table body -->    
%%
elem(tbody, As, Ts,Ps,St) -> el(tbody,As,Ts,fun(T) -> T == tr end,Ps,St);

%%
%% <!ELEMENT THEAD    - O (TR)+           -- table header -->
%%
elem(thead, As, Ts,Ps,St) -> el(thead,As,Ts,fun(T) -> T == tr end,Ps,St);

%%
%% <!ELEMENT TFOOT    - O (TR)+           -- table footer -->
%%
elem(tfoot, As, Ts,Ps,St) -> el(tfoot,As,Ts,fun(T) -> T == tr end,Ps,St);

%%
%% <!ELEMENT TR       - O (TH|TD)+        -- table row -->
%%
elem(tr, As, Ts,Ps,St) -> el(tr,As,Ts,fun(T) -> (T == th) or (T == td) end,Ps,St);

%%
%% <!ELEMENT (TH|TD)  - O (%flow;)* -- table header cell, table data cell-->
%%
elem(th, As, Ts,Ps,St)  -> el(th,As,Ts,html:flow(),Ps,St);
elem(td, As, Ts,Ps,St) ->  el(td,As,Ts,html:flow(),Ps,St);

%%
%% <!ELEMENT CAPTION  - - (%inline;)*     -- table caption -->
%%
elem(caption, As, Ts,Ps,St)  -> el(caption,As,Ts,html:inline(),Ps,St);
elem(col, As, Ts,Ps,St)     -> el0(col,As,Ts,Ps,St);
elem(colgroup, As, Ts,Ps,St) -> el(colgroup,As,Ts,fun(T) -> T == col end,Ps,St);

%% Frames

%%
%% <!ELEMENT FRAMESET - - ((FRAMESET|FRAME)+ & NOFRAMES?) -- window subdivision-->
%%
elem(frameset,As,Ts,Ps,St) ->
    el(frameset,As,Ts, 
       fun(T) ->
	       (T == frameset) or (T == frame) or (T == noframes)
       end,Ps,St);

elem(frame, As, Ts,Ps,St) -> el0(frame,As,Ts,Ps,St);

elem(iframe, As, Ts,Ps,St) -> el(iframe,As,Ts, html:flow(),Ps,St);

elem(noframes,As,Ts,Ps,St) -> el(noframes,As,Ts, html:flow(),Ps,St);

%%
%% LAYER, ILAYER and NOLAYER
%%
elem(layer,As,Ts,Ps,St) ->   el(layer, As, Ts, html:flow(),Ps,St);

elem(ilayer, As,Ts,Ps,St) -> el(ilayer, As, Ts, html:flow(),Ps,St);

elem(nolayer,As,Ts,Ps,St) -> el(nolayer, As, Ts, html:flow(),Ps,St);

%% Lists
elem(ul, As, Ts,Ps,St) -> el(ul,As,Ts,fun(T) -> T == li end,Ps,St);
elem(ol, As, Ts,Ps,St) -> el(ol,As,Ts,fun(T) -> T == li end,Ps,St);
elem(li, As, Ts,Ps,St) -> el(li,As,Ts,html:flow(),Ps,St);
elem(dl, As, Ts,Ps,St) -> el(dl,As,Ts,fun(T) -> (T == dt) or (T == dd) end,Ps,St);
elem(dt, As, Ts,Ps,St) -> el(dt,As,Ts,html:inline(),Ps,St);
elem(dd, As, Ts,Ps,St) -> el(dd,As,Ts,html:flow(),Ps,St);

%%
%% %fontstyle
%% <!ELEMENT (%fontstyle;|%phrase;) - - (%inline;)*>
%%

elem(tt,As, Ts,Ps,St)     -> el(tt,As,Ts,html:inline(),Ps,St);
elem(i,As, Ts,Ps,St)      -> el(i,As,Ts,html:inline(),Ps,St);
elem(b,As, Ts,Ps,St)      -> el(b,As,Ts,html:inline(),Ps,St);
elem(u,As, Ts,Ps,St)      -> el(u,As,Ts,html:inline(),Ps,St);
elem(s,As, Ts,Ps,St)      -> el(s,As,Ts,html:inline(),Ps,St);
elem(strike,As, Ts,Ps,St) -> el(strike,As,Ts,html:inline(),Ps,St);
elem(big,As, Ts,Ps,St)    -> el(big,As,Ts,html:inline(),Ps,St);
elem(small,As, Ts,Ps,St)  -> el(small,As,Ts,html:inline(),Ps,St);

%%
%% <!ELEMENT (%heading;)  - - (%inline;)* -- heading -->
%% 
elem(h1,As,Ts,Ps,St)      -> el(h1,As,Ts,html:inline(),Ps,St);
elem(h2,As,Ts,Ps,St)      -> el(h2,As,Ts,html:inline(),Ps,St);
elem(h3,As,Ts,Ps,St)      -> el(h3,As,Ts,html:inline(),Ps,St);
elem(h4,As,Ts,Ps,St)      -> el(h4,As,Ts,html:inline(),Ps,St);
elem(h5,As,Ts,Ps,St)      -> el(h5,As,Ts,html:inline(),Ps,St);
elem(h6,As,Ts,Ps,St)      -> el(h6,As,Ts,html:inline(),Ps,St);

%%
%% <!ELEMENT ADDRESS - - (%inline;)* -- information on author -->
%%
elem(address,As,Ts,Ps,St) -> el(address,As,Ts,html:inline(),Ps,St);

%%
%% %phrase
%% <!ELEMENT (%fontstyle;|%phrase;) - - (%inline;)*>
%%

elem(em,As,Ts,Ps,St)      -> el(em,As,Ts,html:inline(),Ps,St);
elem(strong,As,Ts,Ps,St)  -> el(strong,As,Ts,html:inline(),Ps,St);
elem(dfn,As,Ts,Ps,St)     -> el(dfn,As,Ts,html:inline(),Ps,St);
elem(code,As,Ts,Ps,St)    -> el(code,As,Ts,html:inline(),Ps,St);
elem(samp,As,Ts,Ps,St)    -> el(samp,As,Ts,html:inline(),Ps,St);
elem(kbd,As,Ts,Ps,St)     -> el(kbd,As,Ts,html:inline(),Ps,St);
elem(var,As,Ts,Ps,St)     -> el(var,As,Ts,html:inline(),Ps,St);
elem(cite,As,Ts,Ps,St)    -> el(cite,As,Ts,html:inline(),Ps,St);
elem(abbr,As,Ts,Ps,St)    -> el(abbr,As,Ts,html:inline(),Ps,St);
elem(acronym,As,Ts,Ps,St) -> el(acronum,As,Ts,html:inline(),Ps,St);

%%
%% <!ELEMENT BLOCKQUOTE - - (%block;|SCRIPT)+ -- long quotation -->
%%
elem(blockquote,As,Ts,Ps,St) -> 
    el(blockquote,As,Ts, fun(T) -> html:is_block(T) or (T == script) end,Ps,St);
%%
%% <!ELEMENT Q - - (%inline;)*            -- short inline quotation -->
%%
elem(q,As,Ts,Ps,St) ->  el(q,As,Ts,html:inline(),Ps,St);

%%
%% <!ELEMENT (SUB|SUP) - - (%inline;)*    -- subscript, superscript -->
%%
elem(sub,As,Ts,Ps,St) -> el(sub,As,Ts,html:inline(),Ps,St);
elem(sup,As,Ts,Ps,St) -> el(sup,As,Ts,html:inline(),Ps,St);

%%
%% <!ELEMENT P - O (%inline;)*            -- paragraph -->
%%
elem(p,As,Ts,Ps,St) -> el(p,As,Ts,html:inline(),Ps,St);

%%
%% <!ELEMENT BR - O EMPTY                 -- forced line break -->
%%
elem(br,As,Ts,Ps,St) -> el0(br,As,Ts,Ps,St);

%%
%% <!ELEMENT PRE - - (%inline;)* -(%pre.exclusion;) -- preformatted text -->
%%
elem(pre,As,Ts,Ps,St) ->
    el(pre,As,Ts,fun(T) -> html:is_inline(T) and not 
			       html:is_pre_exclusion(T) end,Ps,St);

%%
%% <!ELEMENT DIV - - (%flow;)*         -- generic language/style container -->
%%
elem('div',As,Ts,Ps,St) -> el('div', As, Ts, html:flow(),Ps,St);

%%
%% <!ELEMENT CENTER - - (%flow;)*       -- shorthand for DIV align=center -->
%%
elem(center,As,Ts,Ps,St) -> el(center, As, Ts, html:flow(),Ps,St);

%%
%% <!ELEMENT SPAN - - (%inline;)*      -- generic language/style container -->
%%
elem(span,As,Ts,Ps,St) -> el(span, As, Ts, html:inline(),Ps,St);

%%
%% <!ELEMENT BDO - - (%inline;)*          -- I18N BiDi over-ride -->
%%
elem(bdo,As,Ts,Ps,St) -> el(bdo, As, Ts, html:inline(),Ps,St);

%%
%% <!ELEMENT BASEFONT - O EMPTY           -- base font size -->
%%
elem(basefont,As,Ts,Ps,St) -> el0(basefont, As, Ts,Ps,St);

%%
%% <!ELEMENT FONT - - (%inline;)*         -- local change to font -->
%%
elem(font,As,Ts,Ps,St) -> el(font, As, Ts, html:inline(),Ps,St);

%%
%% <!ELEMENT HR - O EMPTY -- horizontal rule -->
%%
elem(hr, As, Ts,Ps,St) -> el0(hr, As, Ts,Ps,St);

%%
%% <!ELEMENT A - - (%inline;)* -(A)       -- anchor -->
%%
elem(a, As, Ts,Ps,St) -> 
    el(a, As, Ts, fun(T) -> html:is_inline(T) and (T =/= a) end,Ps,St);

%%
%% <!ELEMENT MAP - - ((%block;)+ | AREA+) -- client-side image map -->
%%
elem(map, As,Ts,Ps,St) ->
    el(map, As, Ts, fun(T) -> html:is_block(T) or (T == area) end,Ps,St);

%%
%% <!ELEMENT AREA - O EMPTY               -- client-side image map area -->
%%
elem(area, As,Ts,Ps,St) -> el0(area, As, Ts,Ps,St);

%%
%% <!ELEMENT TEXTAREA - - (#PCDATA)       -- multi-line text field -->
%%
elem(textarea,As,Ts,Ps,St) -> el(textarea,As,Ts,fun(T) -> T == pcdata end,Ps,St);

%%
%% <!ELEMENT FIELDSET - - (#PCDATA,LEGEND,(%flow;)*) -- form control group -->
%%
elem(fieldset,As,Ts,Ps,St) ->
    el(fieldset,As,Ts,
       fun(T) -> (T == pcdata) or (T == legend) or html:is_flow(T) end,Ps,St);
%%
%% <!ELEMENT LEGEND - - (%inline;)*       -- fieldset legend -->
%%
elem(legend,As,Ts,Ps,St) -> el(legend,As,Ts,html:inline(),Ps,St);

%% <!ELEMENT BUTTON - -
%%     (%flow;)* -(A|%formctrl;|FORM|ISINDEX|FIELDSET|IFRAME)
%%     -- push button -->
elem(button,As,Ts,Ps,St) ->
    el(button,As,Ts,
       fun(T) -> html:is_flow(T) and
		     (T =/= a) and (not html:is_formctrl(T)) and
		     (T =/= form) and (T =/= isindex) and
		     (T =/= fieldset) and (T =/= iframe)
       end,Ps,St);
%%
%% <!ELEMENT LABEL - - (%inline;)* -(LABEL) -- form field label text -->
%%
elem(label,As,Ts,Ps,St) ->
    el(label,As,Ts, fun(T) -> html:is_inline(T) and (T =/= label) end,Ps,St);

%%
%% <!ELEMENT INPUT - O EMPTY              -- form control -->
%%
elem(input, As, Ts,Ps,St) -> el0(input, As, Ts,Ps,St);


%%
%% <!ELEMENT SELECT - - (OPTGROUP|OPTION)+ -- option selector -->
%%
elem(select,As,Ts,Ps,St) ->
    el(select,As,Ts,fun(T) -> (T == optgroup) or (T == option) end,Ps,St);

%%
%% <!ELEMENT OPTGROUP - - (OPTION)+ -- option group -->
%%
elem(optgroup,As,Ts,Ps,St) ->
    el(optgroup,As,Ts,fun(T) -> (T == option) end,Ps,St);

%%
%% <!ELEMENT OPTION - O (#PCDATA)         -- selectable choice -->
%%
elem(option,As,Ts,Ps,St) ->
    el(option,As,Ts,fun(T) -> T == pcdata end,Ps,St);

elem(pcdata,Data,Ts,Ps,St) ->
    ?dbg("~s#PCDATA(~p)\n", [indent(Ps),Data]),
    {{pcdata,Data},Ts}.



%% check for end tag or optional end tag
elem_end(Tag,Ts=[{pcdata,Data},{tag_end,Tag}|Ts1],Ps) ->
    case skip_white(Data) of
	[] -> 
	    ?dbg("~s</~p>\n", [indent(Ps),Tag]),
	    Ts1;
	_ ->
	    elem_end_opt(Tag,Ts,Ps)
    end;
elem_end(Tag,[{tag_end,Tag}|Ts1],Ps) ->
    ?dbg("~s</~p>\n", [indent(Ps),Tag]),
    Ts1;
elem_end(Tag,Ts,Ps) ->
    elem_end_opt(Tag,Ts,Ps).

elem_end_opt(Tag,Ts,Ps) ->
    case html:end_tag_optional(Tag) of
	true ->
	    ?dbg("~s<+~p> FAIL=~p\n", [indent(Ps),Tag,hd(Ts)]),
	    Ts;
	false ->
	    ?dbg("~s<-~p> FAIL=~p\n", [indent(Ps),Tag,hd(Ts)]),
	    exit({bad_tag,Tag,Ps})
    end.
    
%%
%% el0: just a tag without end-tag
%%

el0(Tag,As,Ts,Ps,St) ->
    ?dbg("~s<~p>\n", [indent(Ps),Tag]),
    { fmt(St,Tag,As,[]), Ts}.

%%
%% el: repeat IsEntity predicate for all entities
%%     until end-tag (if not optional)
%%
el(Tag,As,Ts,IsEntity,Ps,St) ->
    ?dbg("~s<~p>\n", [indent(Ps),Tag]),
    {Cs,Ts1} = repeat(IsEntity,Ts,Ps,St),
    Ts2 = elem_end(Tag,Ts1,Ps),
    { fmt(St,Tag,As,Cs),Ts2}.


indent(Ps) ->
    lists:duplicate(length(Ps)*2,$\s).
    
%%
%% repeat element 
%% repeat(BoolFun, Entity, Parents)
%%
repeat(IsEntity,Ts,Ps,St) ->
    case ent(IsEntity,Ts,Ps,St) of
	{[],Ts1} -> {[],Ts1};
	{[Elem],Ts1} ->
	    {Es,Ts2} = repeat(IsEntity,Ts1,Ps,St),
	    {[Elem|Es],Ts2}
    end.

repeat0(IsEntity, Ts,Ps,St) ->
    case ent(IsEntity,Ts,Ps,St) of
	{[],Ts1} -> {[],Ts1};
	{[Elem],Ts1} ->
	    {Es,Ts2} = repeat0(IsEntity,Ts1,Ps,St),
	    {[Elem|Es],Ts2}
    end.

%% Do optional FIRST element 
optional(Tag,Ts,Ps,St) ->
    ent(fun(T) -> T == Tag end, Ts,Ps,St).

%% Do require FIRST element
require(Tag,Ts,Ps,St) ->
    case ent(fun(T) -> T == Tag end, Ts,Ps,St) of
	{[],Ts1} ->
	    exit({bad_tag,Tag,Ps});
	{[Elem],Ts1} ->
	    {Elem,Ts1}
    end.


ent(IsEntity,[{pcdata,Data}|Ts],Ps,St) ->
    case IsEntity(pcdata) of
	true ->
	    case member(pre,Ps) orelse member(erl,Ps) orelse 
		member(textarea,Ps) of
		true ->
		    {Elem,Ts1} = elem(pcdata,Data,Ts,[pcdata|Ps],St),
		    {[Elem],Ts1};
		false ->
		    case pcdata(Data) of
			[] -> ent(IsEntity,Ts,Ps,St);
			Data1 -> 
			    {Elem,Ts1} = elem(pcdata,Data1,Ts,[pcdata|Ps],St),
			    {[Elem],Ts1}
		    end
	    end;
	false ->
	    case skip_white(Data) of
		[] -> ent(IsEntity, Ts,Ps,St);
		_ -> {[],[{pcdata,Data}|Ts]}
	    end
    end;
ent(IsEntity,[{tag,erl,Attr}|Ts],Ps,St) ->
    %% <erl>...</erl> Must be ok everywhere
    Ts1 = skip_linebreak(Ts),
    {Elem,Ts2} = elem(erl,Attr,Ts1,[erl|Ps],St),
    {[Elem],Ts2};
ent(IsEntity,[{tag,'!--',_}|Ts],Ps,St) ->
    ent(IsEntity, Ts,Ps,St);
ent(IsEntity,[{tag,Tag,Attr}|Ts],Ps,St) ->
    case IsEntity(Tag) of
	true ->
	    Ts1 = skip_linebreak(Ts),
	    {Elem,Ts2} = elem(Tag,Attr,Ts1,[Tag|Ps],St),
	    {[Elem],Ts2};
	false ->
	    {[],[{tag,Tag,Attr}|Ts]}
    end;
ent(IsEntity,Ts,Ps,St) ->
    {[],Ts}.

%% remove line break after start tag
skip_linebreak([{pcdata,Data}|Ts]) ->
    case lnbreak(Data) of
	{true,[]} -> Ts;
	{true,Data1} -> [{pcdata,Data1}|Ts];
	false -> [{pcdata,Data}|Ts]
    end;
skip_linebreak(Ts) -> Ts.

lnbreak([$\s|Ts]) -> lnbreak(Ts);
lnbreak([$\t|Ts]) -> lnbreak(Ts);
lnbreak([$\n|Ts]) -> {true,Ts};
lnbreak([$\r|Ts]) -> lnbreak(Ts);
lnbreak(Ts) -> false.
    
	    
attrlist(Tag,As) ->
    %% Fixme: Do a complete check of attributes for the Tag
    As.

%%
%%
%%
flatten_pcdata({pcdata,Data}) ->
    Data;
flatten_pcdata([{pcdata,Data}|Cs]) ->
    Data ++ flatten_pcdata(Cs);
flatten_pcdata([]) -> "".


%% Normalize pcdata, i.e remove multiple space
%% and \s\t\n\r between characters
pcdata(Cs) ->
    case pcdata0(Cs) of
	%% [$\s|Cs1] -> Cs1;
	Cs1 -> Cs1
    end.

pcdata0([$\s|Cs]) -> pcdata_sp(Cs);
pcdata0([$\n|Cs]) -> pcdata_sp(Cs);
pcdata0([$\r|Cs]) -> pcdata_sp(Cs);
pcdata0([$\t|Cs]) -> pcdata_sp(Cs);
pcdata0([C|Cs]) -> [C|pcdata0(Cs)];
pcdata0([]) -> [].

pcdata_sp([$\s|Cs]) -> pcdata_sp(Cs);
pcdata_sp([$\n|Cs]) -> pcdata_sp(Cs);
pcdata_sp([$\r|Cs]) -> pcdata_sp(Cs);
pcdata_sp([$\t|Cs]) -> pcdata_sp(Cs);
pcdata_sp([C|Cs]) -> [$\s|pcdata0([C|Cs])];
pcdata_sp([]) -> [$\s].


%% FIXME: add code to handle unicode encoding, add line numbers
tokenise(Cs,St) when binary(Cs) ->
    tokenise(binary_to_list(Cs),St);
tokenise(Cs,St) ->
    tokenise(Cs,[],St).

tokenise([$<|Cs], Acc, St) ->
    case collect_names(Cs) of
        {[[$/|Name]], [$>|Cs1]} ->
	    tokenise(Cs1, [{tag_end,to_name(Name)} | Acc],St);
        {[[$/|Name]|_], [$>|Cs1]} ->
	    {error, {bad_end_tag, to_name(Name)}};
	{["!--#"++Cmd|Args], [$>|Cs1]} ->
	    tokenise_ssi(Cmd,Args,Cs1,Acc,St);
        {[Name|Args], [$>|Cs1]} ->
            Tag = to_name(Name),
	    tokenise(skip_white(Tag,Cs1), [{tag,Tag,Args}|Acc],St);
        {_, [$>|Cs1]} ->
	    {error, no_tag};
        {_, Cs1} ->
	    {error, end_of_tag}
    end;
tokenise([C|Cs], Acc, St) ->
    {Raw, Cs1} = collect_raw([C|Cs]),
    tokenise(Cs1, [{pcdata,Raw}|Acc],St);
tokenise([], Acc, St) ->
    {ok, reverse(Acc)}.

ssi_path(St) ->
    case St#state.path of
	"" ->
	    case os:getenv("PATH_TRANSLATED") of
		false -> case os:getenv("PATH_INFO") of
			     false -> ".";
			     Path -> filename:dirname(Path)
			 end;
		Path -> filename:dirname(Path)
	    end;
	Path ->
	    Path
    end.

ssi_var(Var,St) ->
    case lists:keysearch(Var, 1, St#state.env) of
	false -> 
	    %% FIXME: NOT according to spec!!!
	    case os:getenv(Var) of
		false -> "";
		Val -> Val
	    end;
	{value, {_, Val}} -> Val
    end.

ssi_data(Cs0, Cs1, Acc, St0, St1) ->
    case tokenise(Cs0,Acc,St0) of
	{ok,Ts0} -> %% Ts0 = [Initial] ++ [Included]
	    %% Use St1 (i.e switch back to old file)
	    case tokenise(skip_white('!--#', Cs1), [], St1) of
		{ok,Ts1} -> %% Ts1 = [Final]
		    {ok, Ts0++Ts1}; %% [Initial]++[Include]++[Final]
		Error ->
		    Error
	    end;
	Error ->
	    Error
    end.

tokenise_ssi("include", [{file,File}|_], Cs, Acc, St) ->
    %% FIXME: remove ../
    %% FIXME: add virtual
    AbsFile = filename:join(ssi_path(St), File),
    AbsPath = filename:dirname(AbsFile),
    case file:read_file(AbsFile) of
	{ok,Bin} ->
	    St1 = St#state { path = AbsPath },
	    ssi_data(binary_to_list(Bin), Cs, Acc, 
		     St#state { path = AbsPath }, St);
	Error ->
	    tokenise(skip_white('!--#', Cs), Acc, St)
    end;
tokenise_ssi("echo", [{var,Var}|_], Cs, Acc, St) ->
    Value = ssi_var(Var,St),
    ssi_data(Value, Cs, Acc, St, St);
tokenise_ssi("exec", [{cmd,Cmd}|_], Cs, Acc, St) ->
    Value = os:cmd(Cmd),
    ssi_data(Value, Cs, Acc, St, St);
tokenise_ssi(_, Args, Ts, Acc,St) ->
    tokenise(skip_white('!--#', Ts), Acc,St).

%% collect names is called after we hit <
collect_names(Str) ->
    Str1 = skip_white(Str),
    case Str1 of
        [$>|T] -> {[], [$>|T]};
        [] ->     {[], []};
        _ ->
            case collect_name(Str1) of
                {"!--", Str2} ->
                    {Data, Str3} = collect_to($>, Str2),
                    {["!--" | {comment, Data}], Str3};
                {Name, Str2} ->
                    {Args, Str3} = collect_args(Str2),
                    {[Name|Args], Str3}
            end
    end.

%% Args = ( name = arg | name)* | 
collect_args(Str) ->
    Str1 = skip_white(Str),
    case Str1 of
        [$>|T] -> {[], [$>|T]};
        [] ->     {[], []};
        _ ->
            {Name, Str2} = collect_name(Str1),
            Str3 = skip_white(Str2),
            case Str3 of
                [$=|Str4] ->
                    {Val, Str5} = collect_name(skip_white(Str4)),
                    {ArgT, Str6} = collect_args(Str5),
                    {[{to_name(Name),to_val(Val)}|ArgT], Str6};
                [$>|Str4] ->
                    {[to_name(Name)],[$>|Str4]};
                Str4 ->
                    {ArgT, Str5} = collect_args(skip_white(Str4)),
                    {[to_name(Name)|ArgT], Str5}
            end
    end.


to_name(Str) ->
    list_to_atom(to_lower(Str)).

%% hanle erl: values
to_val("erl:"++ErlValue) ->
    {ok,Tokens,Ln} = erl_scan:string(ErlValue),
    {ok,Exprs} = erl_parse:parse_exprs(Tokens++[{dot,'.'}]),
    {erl,Exprs};
to_val(Value) -> 
    Value.

to_lower([H|T]) when $A =< H, H =< $Z -> [(H-$A)+$a|to_lower(T)];
to_lower([H|T])                       -> [H|to_lower(T)];
to_lower([])                          -> [].


skip_white(p, T)   -> skip_white(T);
skip_white(_,   T) -> T.

skip_white([$\s|T]) ->skip_white(T);
skip_white([$\n|T]) ->skip_white(T);
skip_white([$\r|T]) ->skip_white(T);
skip_white([$\t|T]) ->skip_white(T);
skip_white(T) -> T.


collect_to(X, List) -> collect_to(X, List, []).

collect_to(X, [X|T], Acc) -> {reverse(Acc), [X|T]};
collect_to(X, [], Acc)    -> {reverse(Acc), [X]};
collect_to(X, [H|T],Acc)  -> collect_to(X, T, [H|Acc]).

collect_name([$\"|T]) -> collect_quoted_name(T, []);
collect_name(Str)    -> collect_name(Str, []).

collect_name([$ |T], L)  -> {reverse(L), T};
collect_name([$>|T], L)  -> {reverse(L), [$>|T]};
collect_name([$=|T], L)  -> {reverse(L), [$=|T]};
collect_name([$\n|T], L) -> {reverse(L), T};
collect_name([13|T], L)  -> {reverse(L), T};
collect_name([H|T], L)   -> collect_name(T, [H|L]);
collect_name([], L)      -> {reverse(L), []}.


collect_quoted_name([$\\,$\"|T], L) -> collect_quoted_name(T, [$\"|L]); 
collect_quoted_name([$\"|T], L)     -> {reverse(L), T};
collect_quoted_name([$\n|T], L)     -> collect_quoted_name(T, [$\n|L]);
collect_quoted_name([$\r|T], L)     -> collect_quoted_name(T, [$\n|L]);
collect_quoted_name([H|T], L)       -> collect_quoted_name(T, [H|L]);
collect_quoted_name([], L)          -> {reverse(L), []}.

%% collect_raw(Str) -> {Raw', Str'}
collect_raw(Str) -> collect_raw(Str, []).

collect_raw([$\\,$<|T], L) -> collect_raw(T, [$<|L]);
collect_raw([$\n|T], L)    -> collect_raw(T, [$\n|L]);
collect_raw([$\r|T], L)    -> collect_raw(T, [$\r|L]);
collect_raw([$<|T], L)     -> {reverse(L), [$<|T]};
collect_raw([$&|T], L) ->
    {NT, Name} = collect_amp(T, []),
    case translate_amp(Name) of
        error -> collect_raw(T, [$&|L]);
        Code ->  collect_raw(NT, [Code | L])
    end;
collect_raw([H|T], L) ->
    collect_raw(T, [H|L]);
collect_raw([], L) ->
     {reverse(L), []}.

collect_amp([$ | T], L)   -> {T, reverse(L)};
collect_amp([$\n | T], L) -> {T, reverse(L)};
collect_amp([$\r | T], L) -> {T, reverse(L)};
collect_amp([$; | T], L)  -> {T, reverse(L)};
collect_amp([H | T], L)   -> collect_amp(T, [H|L]);
collect_amp([], L)        -> {[], reverse(L)}.

translate_amp([$# | Ds]) ->
    amp_digits(Ds, 0);
translate_amp(Name) ->
    html:value(Name).


amp_digits([X | Xs], N) when X >= $0, X =< $9 ->
    amp_digits(Xs, N*10 + (X-$0));
amp_digits([], N) ->
    if
        N >= 0, N =< 8 -> error;
        N >= 127, N =< 159 -> error;
        N > 255 -> error;
        true -> N
    end.
