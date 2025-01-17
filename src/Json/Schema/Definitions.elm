module Json.Schema.Definitions exposing
    ( Schema(..), SubSchema, Schemata(..), Items(..), Dependency(..), Type(..), SingleType(..), blankSchema, blankSubSchema, ExclusiveBoundary(..)
    , decoder, encode
    , stringToType, getCustomKeywordValue
    )

{-| This module contains low-level structures JSON Schema build from.
Normally you wouldn't need to use any of those definitions.

If you really need this low-level API you might need [JSON Schema spec](http://json-schema.org/documentation.html) as guidance.

Feel free to open [issue](https://github.com/1602/json-schema) to describe your use-case, it will affect development roadmap of this library.


# Definitions

@docs Schema, SubSchema, Schemata, Items, Dependency, Type, SingleType, blankSchema, blankSubSchema, ExclusiveBoundary


# Decoding / encoding

@docs decoder, encode


# Misc

@docs stringToType, getCustomKeywordValue

-}

import Json.Decode as Decode exposing (Decoder, Value, andThen, bool, fail, field, float, int, lazy, list, nullable, string, succeed, value)
import Json.Decode.Pipeline as DecodePipeline exposing (optional, requiredAt)
import Json.Encode as Encode
import Util exposing (foldResults, resultToDecoder)


{-| Schema can be either boolean or actual object containing validation and meta properties
-}
type Schema
    = BooleanSchema Bool
    | ObjectSchema SubSchema


{-| This object holds all draft-6 schema properties
-}
type alias SubSchema =
    { type_ : Type
    , id : Maybe String
    , ref :
        Maybe String

    -- meta
    , title : Maybe String
    , description : Maybe String
    , default : Maybe Value
    , examples : Maybe (List Value)
    , definitions :
        Maybe Schemata

    -- numeric validations
    , multipleOf : Maybe Float
    , maximum : Maybe Float
    , exclusiveMaximum : Maybe ExclusiveBoundary
    , minimum : Maybe Float
    , exclusiveMinimum :
        Maybe ExclusiveBoundary

    -- string validations
    , maxLength : Maybe Int
    , minLength : Maybe Int
    , pattern : Maybe String
    , format :
        Maybe String

    -- array validations
    , items : Items
    , additionalItems : Maybe Schema
    , maxItems : Maybe Int
    , minItems : Maybe Int
    , uniqueItems : Maybe Bool
    , contains :
        Maybe Schema

    -- object validations
    , maxProperties : Maybe Int
    , minProperties : Maybe Int
    , required : Maybe (List String)
    , properties : Maybe Schemata
    , patternProperties : Maybe Schemata
    , additionalProperties : Maybe Schema
    , dependencies : List ( String, Dependency )
    , propertyNames :
        Maybe Schema

    -- misc validations
    , enum : Maybe (List Value)
    , const : Maybe Value
    , allOf : Maybe (List Schema)
    , anyOf : Maybe (List Schema)
    , oneOf : Maybe (List Schema)
    , not : Maybe Schema
    , source : Value
    }


{-| List of schema-properties used in properties, definitions and patternProperties
-}
type Schemata
    = Schemata (List ( String, Schema ))


{-| Items definition.
-}
type Items
    = NoItems
    | ItemDefinition Schema
    | ArrayOfItems (List Schema)


{-| Dependency definition.
-}
type Dependency
    = ArrayPropNames (List String)
    | PropSchema Schema


{-| Exclusive boundaries. Compatibility layer between draft-04 and draft-06 (keywords `exclusiveMinimum` and `exclusiveMaximum` has been changed from a boolean to a number to be consistent with the principle of keyword independence). Since we currently keep both draft-4 and draft-6 as same type definition, we have a union of `Bool` and `Float` here. It might be not a bad idea to separate type definitions for different drafts of JSON Schema, current API decision will be reconsidered when future versions of JSON Schema will arrive.
-}
type ExclusiveBoundary
    = BoolBoundary Bool
    | NumberBoundary Float


{-| Create blank JSON Schema `{}`.
-}
blankSchema : Schema
blankSchema =
    ObjectSchema blankSubSchema


{-| -}
blankSubSchema : SubSchema
blankSubSchema =
    { type_ = AnyType
    , id = Nothing
    , ref = Nothing
    , title = Nothing
    , description = Nothing
    , default = Nothing
    , examples = Nothing
    , definitions = Nothing
    , multipleOf = Nothing
    , maximum = Nothing
    , exclusiveMaximum = Nothing
    , minimum = Nothing
    , exclusiveMinimum = Nothing
    , maxLength = Nothing
    , minLength = Nothing
    , pattern = Nothing
    , format = Nothing
    , items = NoItems
    , additionalItems = Nothing
    , maxItems = Nothing
    , minItems = Nothing
    , uniqueItems = Nothing
    , contains = Nothing
    , maxProperties = Nothing
    , minProperties = Nothing
    , required = Nothing
    , properties = Nothing
    , patternProperties = Nothing
    , additionalProperties = Nothing
    , dependencies = []
    , propertyNames = Nothing
    , enum = Nothing
    , const = Nothing
    , allOf = Nothing
    , anyOf = Nothing
    , oneOf = Nothing
    , not = Nothing
    , source = Encode.object []
    }


{-| -}
encode : Schema -> Value
encode s =
    let
        optionally : (a -> Value) -> Maybe a -> String -> List ( String, Value ) -> List ( String, Value )
        optionally fn val key res =
            let
                result =
                    res
                        |> List.filter (\( k, _ ) -> k /= key)
            in
            case val of
                Just schema ->
                    ( key, fn schema ) :: result

                Nothing ->
                    result

        encodeItems : Items -> List ( String, Value ) -> List ( String, Value )
        encodeItems items res =
            case items of
                ItemDefinition id ->
                    ( "items", encode id ) :: res

                ArrayOfItems aoi ->
                    ( "items", aoi |> Encode.list encode ) :: res

                NoItems ->
                    res

        encodeDependency : Dependency -> Value
        encodeDependency dep =
            case dep of
                PropSchema ps ->
                    encode ps

                ArrayPropNames apn ->
                    apn |> Encode.list Encode.string

        encodeDependencies : List ( String, Dependency ) -> List ( String, Value ) -> List ( String, Value )
        encodeDependencies deps res =
            if List.isEmpty deps then
                res

            else
                ( "dependencies", deps |> List.map (\( key, dep ) -> ( key, encodeDependency dep )) |> Encode.object ) :: res

        singleTypeToString : SingleType -> String
        singleTypeToString st =
            case st of
                StringType ->
                    "string"

                IntegerType ->
                    "integer"

                NumberType ->
                    "number"

                BooleanType ->
                    "boolean"

                ObjectType ->
                    "object"

                ArrayType ->
                    "array"

                NullType ->
                    "null"

        encodeType : Type -> List ( String, Value ) -> List ( String, Value )
        encodeType t res =
            case t of
                SingleType st ->
                    ( "type", st |> singleTypeToString |> Encode.string ) :: res

                NullableType st ->
                    ( "type", [ "null" |> Encode.string, st |> singleTypeToString |> Encode.string ] |> Encode.list identity ) :: res

                UnionType ut ->
                    ( "type", ut |> Encode.list (singleTypeToString >> Encode.string) ) :: res

                AnyType ->
                    res

        encodeListSchemas : List Schema -> Value
        encodeListSchemas l =
            l
                |> Encode.list encode

        encodeSchemata : Schemata -> Value
        encodeSchemata (Schemata listSchemas) =
            listSchemas
                |> List.map (\( key, schema ) -> ( key, encode schema ))
                |> Encode.object

        encodeExclusiveBoundary : ExclusiveBoundary -> Value
        encodeExclusiveBoundary eb =
            case eb of
                BoolBoundary b ->
                    Encode.bool b

                NumberBoundary f ->
                    Encode.float f

        source : SubSchema -> List ( String, Value )
        source os =
            os.source
                |> Decode.decodeValue (Decode.keyValuePairs Decode.value)
                |> Result.withDefault []
    in
    case s of
        BooleanSchema bs ->
            Encode.bool bs

        ObjectSchema os ->
            [ encodeType os.type_
            , optionally Encode.string os.id "$id"
            , optionally Encode.string os.ref "$ref"
            , optionally Encode.string os.title "title"
            , optionally Encode.string os.description "description"
            , optionally identity os.default "default"
            , optionally (Encode.list identity) os.examples "examples"
            , optionally encodeSchemata os.definitions "definitions"
            , optionally Encode.float os.multipleOf "multipleOf"
            , optionally Encode.float os.maximum "maximum"
            , optionally encodeExclusiveBoundary os.exclusiveMaximum "exclusiveMaximum"
            , optionally Encode.float os.minimum "minimum"
            , optionally encodeExclusiveBoundary os.exclusiveMinimum "exclusiveMinimum"
            , optionally Encode.int os.maxLength "maxLength"
            , optionally Encode.int os.minLength "minLength"
            , optionally Encode.string os.pattern "pattern"
            , optionally Encode.string os.format "format"
            , encodeItems os.items
            , optionally encode os.additionalItems "additionalItems"
            , optionally Encode.int os.maxItems "maxItems"
            , optionally Encode.int os.minItems "minItems"
            , optionally Encode.bool os.uniqueItems "uniqueItems"
            , optionally encode os.contains "contains"
            , optionally Encode.int os.maxProperties "maxProperties"
            , optionally Encode.int os.minProperties "minProperties"
            , optionally (\list -> list |> Encode.list Encode.string) os.required "required"
            , optionally encodeSchemata os.properties "properties"
            , optionally encodeSchemata os.patternProperties "patternProperties"
            , optionally encode os.additionalProperties "additionalProperties"
            , encodeDependencies os.dependencies
            , optionally encode os.propertyNames "propertyNames"
            , optionally (Encode.list identity) os.enum "enum"
            , optionally identity os.const "const"
            , optionally encodeListSchemas os.allOf "allOf"
            , optionally encodeListSchemas os.anyOf "anyOf"
            , optionally encodeListSchemas os.oneOf "oneOf"
            , optionally encode os.not "not"
            ]
                |> List.foldl identity (source os)
                |> List.reverse
                |> Encode.object


{-| -}
decoder : Decoder Schema
decoder =
    let
        singleType =
            string
                |> andThen singleTypeDecoder

        multipleTypes =
            string
                |> list
                |> andThen multipleTypesDecoder

        booleanSchemaDecoder =
            Decode.bool
                |> Decode.andThen
                    (\b ->
                        if b then
                            succeed (BooleanSchema True)

                        else
                            succeed (BooleanSchema False)
                    )

        exclusiveBoundaryDecoder =
            Decode.oneOf [ Decode.bool |> Decode.map BoolBoundary, Decode.float |> Decode.map NumberBoundary ]

        objectSchemaDecoder =
            Decode.succeed SubSchema
                |> optional "type"
                    (Decode.oneOf [ multipleTypes, Decode.map SingleType singleType ])
                    AnyType
                |> DecodePipeline.custom
                    (Decode.map2
                        (\a b ->
                            if a == Nothing then
                                b

                            else
                                a
                        )
                        (field "$id" string |> Decode.maybe)
                        (field "id" string |> Decode.maybe)
                    )
                |> optional "$ref" (nullable string) Nothing
                -- meta
                |> optional "title" (nullable string) Nothing
                |> optional "description" (nullable string) Nothing
                |> optional "default" (value |> Decode.map Just) Nothing
                |> optional "examples" (nullable <| list value) Nothing
                |> optional "definitions" (nullable <| lazy <| \_ -> schemataDecoder) Nothing
                -- number
                |> optional "multipleOf" (nullable float) Nothing
                |> optional "maximum" (nullable float) Nothing
                |> optional "exclusiveMaximum" (nullable exclusiveBoundaryDecoder) Nothing
                |> optional "minimum" (nullable float) Nothing
                |> optional "exclusiveMinimum" (nullable exclusiveBoundaryDecoder) Nothing
                -- string
                |> optional "maxLength" (nullable nonNegativeInt) Nothing
                |> optional "minLength" (nullable nonNegativeInt) Nothing
                |> optional "pattern" (nullable string) Nothing
                |> optional "format" (nullable string) Nothing
                -- array
                |> optional "items" (lazy (\_ -> itemsDecoder)) NoItems
                |> optional "additionalItems" (nullable <| lazy (\_ -> decoder)) Nothing
                |> optional "maxItems" (nullable nonNegativeInt) Nothing
                |> optional "minItems" (nullable nonNegativeInt) Nothing
                |> optional "uniqueItems" (nullable bool) Nothing
                |> optional "contains" (nullable <| lazy (\_ -> decoder)) Nothing
                |> optional "maxProperties" (nullable nonNegativeInt) Nothing
                |> optional "minProperties" (nullable nonNegativeInt) Nothing
                |> optional "required" (nullable (list string)) Nothing
                |> optional "properties" (nullable (lazy (\_ -> schemataDecoder))) Nothing
                |> optional "patternProperties" (nullable (lazy (\_ -> schemataDecoder))) Nothing
                |> optional "additionalProperties" (nullable <| lazy (\_ -> decoder)) Nothing
                |> optional "dependencies" (lazy (\_ -> dependenciesDecoder)) []
                |> optional "propertyNames" (nullable <| lazy (\_ -> decoder)) Nothing
                |> optional "enum" (nullable nonEmptyUniqueArrayOfValuesDecoder) Nothing
                |> optional "const" (value |> Decode.map Just) Nothing
                |> optional "allOf" (nullable (lazy (\_ -> nonEmptyListOfSchemas))) Nothing
                |> optional "anyOf" (nullable (lazy (\_ -> nonEmptyListOfSchemas))) Nothing
                |> optional "oneOf" (nullable (lazy (\_ -> nonEmptyListOfSchemas))) Nothing
                |> optional "not" (nullable <| lazy (\_ -> decoder)) Nothing
                |> requiredAt [] Decode.value
    in
    Decode.oneOf
        [ booleanSchemaDecoder
        , objectSchemaDecoder
            |> Decode.andThen
                (\b ->
                    succeed (ObjectSchema b)
                )
        ]


nonEmptyListOfSchemas : Decoder (List Schema)
nonEmptyListOfSchemas =
    list (lazy (\_ -> decoder))
        |> andThen failIfEmpty


nonEmptyUniqueArrayOfValuesDecoder : Decoder (List Value)
nonEmptyUniqueArrayOfValuesDecoder =
    list value
        |> andThen failIfValuesAreNotUnique
        |> andThen failIfEmpty


failIfValuesAreNotUnique : List Value -> Decoder (List Value)
failIfValuesAreNotUnique l =
    succeed l


failIfEmpty : List a -> Decoder (List a)
failIfEmpty l =
    if List.isEmpty l then
        fail "List is empty"

    else
        succeed l


itemsDecoder : Decoder Items
itemsDecoder =
    Decode.oneOf
        [ Decode.map ArrayOfItems <| list decoder
        , Decode.map ItemDefinition decoder
        ]


dependenciesDecoder : Decoder (List ( String, Dependency ))
dependenciesDecoder =
    Decode.oneOf
        [ Decode.map ArrayPropNames (list string)
        , Decode.map PropSchema decoder
        ]
        |> Decode.keyValuePairs


nonNegativeInt : Decoder Int
nonNegativeInt =
    int
        |> andThen
            (\x ->
                if x >= 0 then
                    succeed x

                else
                    fail "Expected non-negative int"
            )


{-| Type property in json schema can be a single type or array of them, this type definition wraps up this complexity, also it introduces concept of nullable type, which is array of "null" type and a single type speaking JSON schema language, but also a useful concept to treat it separately from list of types.
-}
type Type
    = AnyType
    | SingleType SingleType
    | NullableType SingleType
    | UnionType (List SingleType)


{-| -}
type SingleType
    = IntegerType
    | NumberType
    | StringType
    | BooleanType
    | ArrayType
    | ObjectType
    | NullType


multipleTypesDecoder : List String -> Decoder Type
multipleTypesDecoder lst =
    case lst of
        [ x, "null" ] ->
            Decode.map NullableType <| singleTypeDecoder x

        [ "null", x ] ->
            Decode.map NullableType <| singleTypeDecoder x

        [ x ] ->
            Decode.map SingleType <| singleTypeDecoder x

        otherList ->
            otherList
                |> List.sort
                |> List.map stringToType
                |> foldResults
                |> Result.andThen (Ok << UnionType)
                |> resultToDecoder


{-| Attempt to parse string into a single type, it recognises the following list of types:

  - integer
  - number
  - string
  - boolean
  - array
  - object
  - null

-}
stringToType : String -> Result String SingleType
stringToType s =
    case s of
        "integer" ->
            Ok IntegerType

        "number" ->
            Ok NumberType

        "string" ->
            Ok StringType

        "boolean" ->
            Ok BooleanType

        "array" ->
            Ok ArrayType

        "object" ->
            Ok ObjectType

        "null" ->
            Ok NullType

        _ ->
            Err ("Unknown type: " ++ s)


singleTypeDecoder : String -> Decoder SingleType
singleTypeDecoder s =
    case stringToType s of
        Ok st ->
            succeed st

        Err msg ->
            fail msg


schemataDecoder : Decoder Schemata
schemataDecoder =
    Decode.keyValuePairs (lazy (\_ -> decoder))
        |> Decode.andThen (\x -> succeed <| List.reverse x)
        |> Decode.map Schemata


{-| Return custom keyword value by its name, useful when dealing with additional meta information added along with standard JSON Schema keywords.
-}
getCustomKeywordValue : String -> Schema -> Maybe Value
getCustomKeywordValue key schema =
    case schema of
        ObjectSchema os ->
            os.source
                |> Decode.decodeValue (Decode.keyValuePairs Decode.value)
                |> Result.withDefault []
                |> List.filterMap
                    (\( k, v ) ->
                        if k == key then
                            Just v

                        else
                            Nothing
                    )
                |> List.head

        _ ->
            Nothing
