-module(fanta_app).

-behaviour(application).

-export([
    start/2,
    stop/1
]).

start(_StartType, _StartArgs) ->
    application:ensure_all_started(hackney),

    Dispatch = cowboy_router:compile([
        {'_', [{"/fanout", fanta_fanout_handler, []}]}
    ]),

    {ok, _} = cowboy:start_clear(
      fanout_http_listener,
      #{
        socket_opts =>[
          {port, 8080},
          {keepalive, true},
          {backlog, 2048}
        ],
        num_acceptors => 1000,
        max_connections => infinity
      },
      #{
        env => #{
          dispatch => Dispatch
        }
      }
    ),

    fanta_sup:start_link().

stop(_State) ->
    ok.