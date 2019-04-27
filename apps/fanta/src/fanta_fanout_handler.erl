-module(fanta_fanout_handler).
-behavior(cowboy_handler).

-export([
  init/2
]).

init(Req0 = #{method := <<"POST">>}, State) ->
  Req = case cowboy_req:has_body(Req0) of
    true ->
      {ok, Data, Req1} = cowboy_req:read_body(
        Req0,
        #{length => 1000000, period => 100}
      ),

      handle_fanout(Data, Req1);
    false ->
      cowboy_req:reply(400, #{}, <<"BAD INPUT!">>, Req0)
  end,

  {ok, Req, State};

init(Req0, State) ->
  Req = cowboy_req:reply(405, #{<<"allow">> => <<"POST">>}, Req0),
  {ok, Req, State}.

-spec handle_fanout(binary(), cowboy_req:req()) -> cowboy_req:req().
handle_fanout(Body, Req) ->
  #{
    <<"endpoints">> := Endpoints,
    <<"headers">> := Headers,
    <<"payload">> := Payload
  } = jsone:decode(Body),


  Pids = lists:map(
    fun(Endpoint) ->
      Pid = spawn(fanta_forward, send_payload, [self(), Endpoint, Headers, Payload]),
      monitor(process, Pid),
      Pid
    end, Endpoints
  ),

  Results = wait(Pids, []),

  ResultsJson = jsone:encode(Results),

  cowboy_req:reply(200, #{}, ResultsJson, Req).

-spec wait(list(), list()) -> list().

%% Nothing to wait for
wait([], State0) ->
  State0;

wait(Pids, State0) ->
  receive
    {response, Pid, Endpoint, Resp} = Msg ->
      case lists:member(Pid, Pids) of
        true ->
          State1 = [#{endpoint => Endpoint, resp => Resp} | State0],
          wait(Pids -- [Pid], State1);
        false ->
          logger:error("Unexpected message ~p", [Msg]),
          wait(Pids, State0)
      end;

    {'DOWN', _, process, _Pid, normal} ->
      %% Don't remove the process here because we want
      %% it's message to be processed first.
      wait(Pids, State0);

    {'DOWN', _, process, Pid, Reason} ->
      logger:error("Fanout process died ~p", [Reason]),
      wait(Pids -- [Pid], State0);

    Else ->
      logger:error("Unexpected message ~p", [Else]),
      wait(Pids, State0)
  after 300 ->
    State0
  end.