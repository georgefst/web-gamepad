module Scratch exposing (..)

import Auto.Element exposing (..)
import Auto.ElmFlags exposing (..)
import Auto.ServerUpdate exposing (..)
import Auto.Shape exposing (..)
import Json.Decode as Json
import Loadable
import Main
import Task
import Time exposing (..)
import Tuple exposing (..)


main : Loadable.Program Json.Value Main.Model Main.Msgs Json.Error
main =
    let
        app =
            Main.app
    in
    Loadable.application
        { app
            | load =
                \_ _ _ ->
                    Main.load flags
                        |> Task.map
                            (mapFirst <| \m -> { m | logger = \s -> Debug.log s Cmd.none })
            , subscriptions =
                sub
                    (\x ->
                        [ Main.ServerUpdate <| SetIndicatorArcStart "0" <| x * 2 * pi
                        , Main.ServerUpdate <| SetIndicatorHollowness "0" x
                        ]
                    )
        }


{-| time in milliseconds to perform a full loop
-}
cycleLength : number
cycleLength =
    3000


{-| milliseconds per tick
-}
tick : number
tick =
    30


sub : (Float -> Main.Msgs) -> Main.Model -> Sub Main.Msgs
sub f model =
    every tick <|
        \t ->
            let
                tDiff =
                    modBy cycleLength <| posixToMillis t - posixToMillis model.startTime
            in
            f <|
                toFloat tDiff
                    / cycleLength


flags : ElmFlags
flags =
    { username = "GT"
    , layout =
        { elements =
            [ { location = { x = 0, y = 0 }
              , name = "0"
              , showName = False
              , element =
                    Indicator
                        { hollowness = 0.5
                        , arcStart = 0
                        , arcEnd = 4 * pi / 3
                        , colour = { red = 0.8, green = 0, blue = 0.5, alpha = 1 }
                        , shape = Circle 350
                        }
              }
            ]
        , viewBox = { x = -1000, y = -500, w = 2000, h = 1000 }
        }
    }
