-module(erlambda).

-compile(export_all).

-import(erlambda_parser, [choice/1, seq/2, return/1, bind/2, between/3]).
-import(erlambda_parser, [many/1, one_of/1, string/1, lower/0, alpha_num/0]).
-import(erlambda_parser, [zero/0, chain_left1/2]).

repl() -> repl("lambda> ", false).

repl(Prompt) -> repl(Prompt, false).

repl(Prompt, ShowParseTree) ->
  Repl = fun () -> repl(Prompt, ShowParseTree) end,

  case io:get_line(Prompt) of
    eof              -> print_line("EOF");
    {error, _Reason} -> print_line("Error");
    Line             ->
      case string:strip(Line, right, $\n) of
        ""   -> Repl();
        ":q" -> print_line("Bye!");
        ":h" -> help(), Repl();
        ":t" -> repl(Prompt, not ShowParseTree);
        Data -> interpret(Data, ShowParseTree, Repl)
      end
  end.

print_line(String) ->
  io:format(String), io:format("\n").

help() ->
  print_line(string:join([
    "  :h -- this help",
    "  :q -- quit interpreter",
    "  :t -- toggle parse tree display"
  ], "\n")).

interpret(Data, ParseTree, Repl) ->
  Parse = expr(),
  case Parse(Data) of
    {} ->
      Expression = string:strip(Data, right, $\n),
      io:format("Error parsing expression: ~s~n", [Expression]);
    {Result, _} when     ParseTree -> display_result(Result, show_parse_tree);
    {Result, _} when not ParseTree -> display_result(Result, hide_parse_tree)
  end,
  Repl().

display_result(Result, show_parse_tree) ->
  io:format("Parse Tree:\n~p~n~n~s~n", [Result, show_value(Result)]);
display_result(Result, hide_parse_tree) ->
  io:format("~s~n", [show_value(Result)]).

show_value({lambda_abstraction, {V, E}}) ->
  "(|" ++ V ++ " -> " ++ show_value(E) ++ ")";
show_value({application, {A, B}}) ->
  show_value(A) ++ " " ++ show_value(B);
show_value({variable, E}) ->
  E.


%% Parser =====================================================================
expr() ->
  chain_left1(atom(), return(fun (A, B) ->
    {application, {A, B}}
  end)).

atom() ->
  choice([
    lambda_abstraction(),
    variable(),
    grouped_expression()
  ]).

%% A pompous name for "function definition".
lambda_abstraction() ->
  fun (Input) ->
    Parser = seq([
      symbol("|"),
      identifier(),
      symbol("->"),
      expr()
    ], fun ([_, Param, _, Body]) ->
      return({lambda_abstraction, {Param, Body}})
    end),
    Parser(Input)
  end.

variable() ->
  bind(identifier(), fun (V) ->
    return({variable, V})
  end).

grouped_expression() ->
  fun (Input) ->
    Parser = between(symbol("("), expr(), symbol(")")),
    Parser(Input)
  end.

token(Parser) ->
  Spaces = many(one_of(" \n\t")),
  seq([Parser, Spaces], fun ([Result, _]) ->
    return(Result)
  end).

symbol(Symbol) ->
  token(string(Symbol)).

ident() ->
  bind(lower(), fun (X) ->
    bind(many(alpha_num()), fun (Xs) ->
      return([X|Xs])
    end)
  end).

identifier() -> identifier([]).

identifier(Keywords) ->
  token(bind(ident(), fun (Ident) ->
    case lists:member(Ident, Keywords) of
      true -> zero();
      _    -> return(Ident)
    end
  end)).
