-module(epop_test).
-author('tobbe@serc.rmit.edu.au').
%%----------------------------------------------------------------------
%% File    : epop_test.erl
%% Created : 11 Mar 1998 by tobbe@serc.rmit.edu.au
%% Function: Some code for storing mail
%%----------------------------------------------------------------------
-vc('$Id$ ').
-export([store_mail/2]).

store_mail(User,Id) ->
    {Y,M,D} = date(),
    {Ms,S,Us} = erlang:now(),
    MsgID = lists:concat([Y,M,D,Ms,S,Us]),
    epop_dets:store_mail(User,MsgID,mail(User,Id)).

mail(User,1) ->
"
From tobbe@universe.serc.rmit.edu.au  Wed Mar 11 15:31:38 1998
Received: from universe.serc.rmit.edu.au (localhost [127.0.0.1])
        by universe.serc.rmit.edu.au (8.8.5/8.8.5) with ESMTP id PAA06105
        for <tobbe>; Wed, 11 Mar 1998 15:31:38 +1100 (EST)
Message-Id: <199803110431.PAA06105@universe.serc.rmit.edu.au>
From: Torbjorn Tornkvist <tobbe@serc.rmit.edu.au>
X-Mailer: MH 6.8.3
X-Erlang: http://www.erlang.se
To: " ++ User ++ 
"Subject: test
Date: Wed, 11 Mar 1998 15:31:38 +1100
Sender: tobbe@serc.rmit.edu.au


Hejsan pojkar !

F�r en vecka sedan fixade jag s� att tjejen (Lotta)
kunde l�sa mail hemifr�n via en POP3 server i Svedala
(se www.home.se). Jag blev (som vanligt) lite nyfiken
p� POP3 (Post Office Protocol version 3) protokollet
och strax s� hamnade jag p� ett sticksp�r (som vanligt ;-).

S� nu har jag implementerat ett full-blown (som Klacke brukar
s�ga) POP3 client/server paket. S� nu kan ni bli era
egna email-providers. Antar att n�sta steg blir att implementera
en SMTP server (sendmail.... ;-).

Hur som helst, innan jag l�gger upp det hela p� arkivet
s� har ni nu chansen att prova. Ni har alla f�tt ett
mail konto hos mig + ett par mail i era maildrops.
Ni har samma userid som p� CSLab och password �r detsamma
som userid'et. G�r s� h�r f�r att prova om ni kan l�sa mail:

 ...etc...

/Tobbe
";
mail(User,2) ->
"
From tobbe@universe.serc.rmit.edu.au  Wed Mar 11 15:31:38 1998
Received: from universe.serc.rmit.edu.au (localhost [127.0.0.1])
        by universe.serc.rmit.edu.au (8.8.5/8.8.5) with ESMTP id PAA06105
        for <tobbe>; Wed, 11 Mar 1998 15:31:38 +1100 (EST)
Message-Id: <199803110431.PAA06105@universe.serc.rmit.edu.au>
From: Torbjorn Tornkvist <tobbe@serc.rmit.edu.au>
X-Mailer: MH 6.8.3
X-Erlang: http://www.erlang.se
To: " ++ User ++
"Subject: hello
Date: Wed, 11 Mar 1998 15:31:38 +1100
Sender: tobbe@serc.rmit.edu.au


This is yet another test

Bye ! /Tobbe
".

