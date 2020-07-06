module Main exposing (main)

import Auto.Button exposing (..)
import Auto.Colour exposing (..)
import Auto.Element exposing (..)
import Auto.ElmFlags exposing (..)
import Auto.FullElement exposing (..)
import Auto.Layout exposing (..)
import Auto.Update exposing (..)
import Basics.Extra exposing (..)
import Browser exposing (..)
import Collage exposing (..)
import Collage.Events as Collage
import Collage.Layout exposing (..)
import Collage.Render exposing (svgExplicit)
import Color exposing (..)
import Html exposing (..)
import Html.Attributes exposing (style)
import Html.Events exposing (..)
import Html.Events.Extra.Pointer as Pointer
import Json.Decode as JD
import Json.Encode as JE
import List exposing (..)
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Maybe exposing (..)
import Ports exposing (..)
import String exposing (..)
import Tuple exposing (..)
import Util exposing (..)
import Util.HorribleCrapThatMakesMeThinkMaybeElmIsIndeedWrong.ListSet as ListSet
import Util.IntVector2 as IntVec2 exposing (IntVector2)
import Util.Prog exposing (..)


main : Program JD.Value (Result JD.Error Model) Msg
main =
    prog
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        , decoder = Auto.ElmFlags.decode
        }



{- View -}


view : Model -> Document Msg
view model =
    { title = "Gamepad"
    , body =
        [ svgExplicit
            [ let
                ( x, y ) =
                    IntVec2.unVec model.layout.grid
              in
              viewBox 0 -y x y

            --TODO it would be preferable to apply this to the subcomponents instead,
            -- so that we could still pan and zoom in the gaps
            -- https://github.com/timjs/elm-collage/issues/22
            , style "touch-action" "none"
            ]
          <|
            stack <|
                List.map (viewElement model) model.layout.elements
        ]
    }


viewElement : Model -> FullElement -> Collage Msg
viewElement model element =
    shift (IntVec2.unVec element.location) <|
        case element.element of
            Button b ->
                let
                    shape =
                        case b.button of
                            Circle r ->
                                circle r

                            Rectangle v ->
                                uncurry rectangle <| IntVec2.unVec v
                in
                shape
                    |> styled
                        ( uniform <|
                            applyWhen (ListSet.member element.name model.pressed) darkColor <|
                                Color.fromRgba b.colour
                        , solid thick <| uniform black
                        )
                    |> Collage.on "pointerdown" (JD.succeed <| Update <| ButtonDown element.name)
                    |> Collage.on "pointerout" (JD.succeed <| Update <| ButtonUp element.name)

            Stick stick ->
                let
                    rBack =
                        stick.range + stick.radius

                    getOffset event =
                        let
                            v0 =
                                -- invert y coord and convert tuple to vector
                                uncurry vec2 <| mapSecond negate <| both (\t -> t - rBack) event.pointer.offsetPos

                            length =
                                min stick.range <| Vec2.length v0
                        in
                        Vec2.normalize v0 |> Vec2.scale (length / stick.range)

                    big =
                        circle stick.range
                            |> filled (uniform <| Color.fromRgba stick.backgroundColour)

                    small =
                        circle stick.radius |> filled (uniform <| Color.fromRgba stick.stickColour)

                    front =
                        -- invisible - area in which touches are registered
                        -- used to extrude envelope to cover everywhere 'small' might go
                        circle rBack
                            |> filled (uniform <| hsla 0 0 0 0)
                            |> Collage.on "pointermove"
                                (JD.map (Update << StickMove element.name << getOffset)
                                    Pointer.eventDecoder
                                )
                            |> Collage.on "pointerout" (JD.succeed <| Update <| StickMove element.name <| vec2 0 0)
                in
                stack [ front, small |> shift (unVec2 <| Vec2.scale stick.range model.stickPos), big ]



{- Model -}


type alias Model =
    { username : String
    , layout : Layout
    , stickPos : Vec2
    , pressed : ListSet.Set String
    }


type Msg
    = Update Update


init : ElmFlags -> ( Model, Cmd Msg )
init flags =
    ( { username = flags.username
      , layout = flags.layout
      , stickPos = vec2 0 0
      , pressed = ListSet.empty
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update u ->
            let
                model1 =
                    case u of
                        ButtonUp b ->
                            { model | pressed = ListSet.remove b model.pressed }

                        ButtonDown b ->
                            { model | pressed = ListSet.add b model.pressed }

                        StickMove t p ->
                            { model | stickPos = p }
            in
            ( model1
            , sendUpdate u
            )
