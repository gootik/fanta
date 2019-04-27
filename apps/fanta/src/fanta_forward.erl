-module(fanta_forward).

-export([
  send_payload/4
]).

-spec send_payload(pid(), map(), map(), binary()) -> {'response',pid(),map(),map()}.
send_payload(
    From,
    #{<<"host">> := Host, <<"port">> := Port, <<"path">> := Path} = Endpoint,
    Headers,
    Payload
) ->
  PoolName = start_pool(get_pool_name(Host, Port)),

  PortBin = integer_to_binary(Port),
  Url = <<Host/bitstring, ":", PortBin/bitstring, "/", Path/bitstring>>,
  {ok, ClientRef} = hackney:get(
    Url,
    maps:to_list(Headers),
    Payload,
    [async,
     {follow_redirect, false},
     {pool, PoolName}
%%     {recv_timeout, Timeout}
    ]
  ),

  Start = erlang:monotonic_time(millisecond),
  Resp0 = wait(ClientRef, #{body => <<>>}),
  End = erlang:monotonic_time(millisecond),

  Resp = maps:put(delay, End - Start, Resp0),
  From ! {response, self(), Endpoint, Resp}.

-spec wait(reference(), map()) -> map().
wait(Ref, State0) ->
  receive
    {hackney_response, Ref, {status, StatusInt, Reason}} ->
      State1 = maps:put(status, StatusInt, State0),
      State2 = maps:put(reason, Reason, State1),
      wait(Ref, State2);

    {hackney_response, Ref, {headers, Headers}} ->
      State1 = maps:put(headers, Headers, State0),
      wait(Ref, State1);

    {hackney_response, Ref, {redirect, _To, _Headers}} ->
      wait(Ref, State0);

    {hackney_response, Ref, done} ->
      State0;

    {hackney_response, Ref, Bin} ->
      #{body := Body} = State0,
      State1 = maps:put(body, <<Body/bitstring, Bin/bitstring>>, State0),
      wait(Ref, State1);


    {hackney_response, Ref, {error, _}} ->
      exit(timeout);

    Else ->
      logger:error("Unexpected message ~p:~p", [State0, Else]),
      State0
  end.

get_pool_name(Host, Port) ->
  PortBin = integer_to_binary(Port),
  HostClean = binary:replace(Host, <<".">>, <<"_">>),
  erlang:binary_to_atom(<<HostClean/bitstring, "_", PortBin/bitstring>>, utf8).

start_pool(Name) ->
  Options = [{timeout, 150000}, {max_connections, 1000}],
  ok = hackney_pool:start_pool(Name, Options),
  Name.

