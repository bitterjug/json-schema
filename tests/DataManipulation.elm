module DataManipulation exposing (all)

import Test exposing (Test, test, describe, only)
import Expect
import Json.Encode as Encode
import Json.Schema.Helpers as Helpers exposing (setValue)
import Json.Schema.Definitions exposing (Schema)
import Json.Schema.Builder exposing (toSchema, buildSchema, withType, withProperties, withDefinitions, withRef, withOneOf, withAnyOf)


all : Test
all =
    describe "data manipulation"
        [ describe "setValue"
            [ test "simple string value" <|
                \() ->
                    buildSchema
                        |> withType "string"
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/" (Encode.string "test"))
                        |> Expect.equal (Ok <| Encode.string "test")
            , test "string property in object" <|
                \() ->
                    buildSchema
                        |> withProperties
                            [ ( "foo", buildSchema |> withType "string" )
                            ]
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/foo" (Encode.string "bar"))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"foo":"bar"}""")
            , test "string property in nested object" <|
                \() ->
                    buildSchema
                        |> withProperties
                            [ ( "foo"
                              , buildSchema
                                    |> withProperties [ ( "bar", buildSchema |> withType "string" ) ]
                              )
                            ]
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/foo/bar" (Encode.string "baz"))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"foo":{"bar":"baz"}}""")
            , test "string property in deeply nested object" <|
                \() ->
                    buildSchema
                        |> withProperties
                            [ ( "foo"
                              , buildSchema
                                    |> withProperties
                                        [ ( "bar"
                                          , buildSchema
                                                |> withProperties [ ( "baz", buildSchema |> withType "string" ) ]
                                          )
                                        , ( "tar"
                                          , buildSchema |> withType "string"
                                          )
                                        ]
                              )
                            ]
                        |> toSchema
                        |> Result.andThen
                            (setValue
                                (Encode.object
                                    [ ( "goo", Encode.string "doo" )
                                    , ( "foo"
                                      , Encode.object
                                            [ ( "tar"
                                              , Encode.string "har"
                                              )
                                            , ( "bar"
                                              , Encode.object [ ( "zim", Encode.string "zam" ) ]
                                              )
                                            ]
                                      )
                                    ]
                                )
                                "#/foo/bar/baz"
                                (Encode.string "fiz")
                            )
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"goo":"doo","foo":{"tar":"har","bar":{"zim":"zam","baz":"fiz"}}}""")

            , test "array should remain array" <|
                \() ->
                    buildSchema
                        |> withType "array"
                        |> toSchema
                        |> Result.andThen (setValue (Encode.list [Encode.string "hello"]) "#/1" (Encode.string "world"))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """["hello","world"]""")

            , test "should work with $ref" <|
                \() ->
                    buildSchema
                        |> withDefinitions
                            [ ( "foo", buildSchema |> withType "array" )
                            ]
                        |> withProperties
                            [ ( "bar", buildSchema |> withRef "#/definitions/foo" )
                            ]
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/bar/0" (Encode.float 1.1))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"bar":[1.1]}""")
            , test "should work with oneOf" <|
                \() ->
                    buildSchema
                        |> withDefinitions
                            [ ( "foo", buildSchema |> withAnyOf
                                [ buildSchema |> withType "array"
                                , buildSchema |> withType "object"
                                ]
                              )
                            ]
                        |> withProperties
                            [ ( "bar", buildSchema |> withRef "#/definitions/foo" )
                            ]
                        |> toSchema
                        -- |> debugSchema
                        |> Result.andThen (setValue Encode.null "#/bar/0" (Encode.object [("hello", Encode.float 1.1)]))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"bar":[{"hello":1.1}]}""")

            ]
        ]

debugSchema : Result String Schema -> Result String Schema
debugSchema s =
    let
        a =
            case s of
                Ok schema ->
                    schema
                        |> Json.Schema.Definitions.encode
                        |> Encode.encode 4
                        |> Debug.log
                        |> (\f -> f "schema")
                Err s ->
                    Debug.log "error" s
    in
        s