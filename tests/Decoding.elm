module Decoding exposing (all)

import Expect
import Json.Decode as Decode
import Json.Encode as Encode exposing (Value)
import Json.Schema.Builder
    exposing
        ( SchemaBuilder
        , boolSchema
        , buildSchema
        , toSchema
        , withAdditionalItems
        , withAdditionalProperties
        , withAllOf
        , withAnyOf
        , withContains
        , withDefinitions
        , withItem
        , withItems
        , withNullableType
        , withOneOf
        , withPatternProperties
        , withPropNamesDependency
        , withProperties
        , withPropertyNames
        , withSchemaDependency
        , withTitle
        , withType
        , withUnionType
        )
import Json.Schema.Definitions as Schema exposing (Schema, decoder)
import Test exposing (Test, describe, test)


decodeValue : Decode.Decoder a -> Value -> Result String a
decodeValue decoder value =
    Decode.decodeValue decoder value
        |> Result.mapError Decode.errorToString


all : Test
all =
    describe "decoding of JSON Schema"
        [ test "type=integer" <|
            \() ->
                [ ( "type", Encode.string "integer" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withType "integer"
                        )
        , test "type=number" <|
            \() ->
                [ ( "type", Encode.string "number" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withType "number"
                        )
        , test "type=string" <|
            \() ->
                [ ( "type", Encode.string "string" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withType "string"
                        )
        , test "type=object" <|
            \() ->
                [ ( "type", Encode.string "object" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withType "object"
                        )
        , test "type=array" <|
            \() ->
                [ ( "type", Encode.string "array" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withType "array"
                        )
        , test "type=null" <|
            \() ->
                [ ( "type", Encode.string "null" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withType "null"
                        )
        , test "type=[null,integer]" <|
            \() ->
                [ ( "type"
                  , Encode.list Encode.string [ "null", "integer" ]
                  )
                ]
                    |> decodesInto
                        (buildSchema
                            |> withNullableType "integer"
                        )
        , test "type=[string,integer]" <|
            \() ->
                [ ( "type"
                  , Encode.list Encode.string [ "integer", "string" ]
                  )
                ]
                    |> decodesInto
                        (buildSchema
                            |> withUnionType [ "string", "integer" ]
                        )
        , test "title=smth" <|
            \() ->
                [ ( "title", Encode.string "smth" ) ]
                    |> decodesInto
                        (buildSchema
                            |> withTitle "smth"
                        )
        , test "definitions={foo=blankSchema}" <|
            \() ->
                [ ( "definitions", Encode.object [ ( "foo", Encode.object [] ) ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withDefinitions [ ( "foo", buildSchema ) ]
                        )
        , test "items=[blankSchema]" <|
            \() ->
                [ ( "items", Encode.list Encode.object [ [] ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withItems [ buildSchema ]
                        )
        , test "items=blankSchema" <|
            \() ->
                [ ( "items", Encode.object [] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withItem buildSchema
                        )
        , test "additionalItems=blankSchema" <|
            \() ->
                [ ( "additionalItems", Encode.object [] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withAdditionalItems buildSchema
                        )
        , test "contains={}" <|
            \() ->
                [ ( "contains", Encode.object [] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withContains buildSchema
                        )
        , test "properties={foo=blankSchema}" <|
            \() ->
                [ ( "properties", Encode.object [ ( "foo", Encode.object [] ) ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withProperties [ ( "foo", buildSchema ) ]
                        )
        , test "patternProperties={foo=blankSchema}" <|
            \() ->
                [ ( "patternProperties", Encode.object [ ( "foo", Encode.object [] ) ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withPatternProperties [ ( "foo", buildSchema ) ]
                        )
        , test "additionalProperties=blankSchema" <|
            \() ->
                [ ( "additionalProperties", Encode.object [] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withAdditionalProperties buildSchema
                        )
        , test "dependencies={foo=blankSchema}" <|
            \() ->
                [ ( "dependencies", Encode.object [ ( "foo", Encode.object [] ) ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withSchemaDependency "foo" buildSchema
                        )
        , test "dependencies={foo=[bar]}" <|
            \() ->
                [ ( "dependencies", Encode.object [ ( "foo", Encode.list Encode.string [ "bar" ] ) ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withPropNamesDependency "foo" [ "bar" ]
                        )
        , test "propertyNames={}" <|
            \() ->
                [ ( "propertyNames", Encode.object [ ( "type", Encode.string "string" ) ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withPropertyNames (buildSchema |> withType "string")
                        )
        , test "enum=[]" <|
            \() ->
                [ ( "enum", Encode.list Encode.object [] ) ]
                    |> decodeSchema
                    |> Expect.err
        , test "allOf=[]" <|
            \() ->
                [ ( "allOf", Encode.list Encode.object [] ) ]
                    |> decodeSchema
                    |> Expect.err
        , test "allOf=[blankSchema]" <|
            \() ->
                [ ( "allOf", Encode.list Encode.object [ [] ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withAllOf [ buildSchema ]
                        )
        , test "oneOf=[blankSchema]" <|
            \() ->
                [ ( "oneOf", Encode.list Encode.object [ [] ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withOneOf [ buildSchema ]
                        )
        , test "anyOf=[blankSchema]" <|
            \() ->
                [ ( "anyOf", Encode.list Encode.object [ [] ] ) ]
                    |> decodesInto
                        (buildSchema
                            |> withAnyOf [ buildSchema ]
                        )
        , describe "boolean schema"
            [ test "true always validates any value" <|
                \() ->
                    Encode.bool True
                        |> decodeValue Schema.decoder
                        |> Expect.equal (boolSchema True |> toSchema)
            , test "false always fails validation" <|
                \() ->
                    Encode.bool False
                        |> decodeValue Schema.decoder
                        |> Expect.equal (boolSchema False |> toSchema)
            ]
        ]


decodeSchema : List ( String, Value ) -> Result String Schema
decodeSchema list =
    Encode.object list
        |> decodeValue Schema.decoder


decodesInto : SchemaBuilder -> List ( String, Value ) -> Expect.Expectation
decodesInto sb list =
    list
        |> Encode.object
        |> decodeValue Schema.decoder
        |> Expect.equal (sb |> toSchema)
