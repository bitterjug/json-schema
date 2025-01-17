module Json.Schema.Helpers exposing
    ( ImpliedType
    , collectIds
    ,  typeToList
       --, implyType
       --, for

    , typeToString
    ,  whenObjectSchema
       --, makeJsonPointer
       -- , resolve
       --, resolveReference
       --, calcSubSchemaType

    )

import Dict
import Json.Decode as Decode
import Json.Encode as Encode
import Json.Schema.Definitions as Schema
    exposing
        ( Items(..)
        , Schema(..)
        , Schemata(..)
        , SingleType(..)
        , SubSchema
        , Type(..)
        )
import Ref exposing (SchemataPool, parseJsonPointer)


type alias ImpliedType =
    { type_ : Type
    , schema : SubSchema
    , error : Maybe String
    }


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


typeToString : Type -> String
typeToString t =
    case t of
        NullableType NullType ->
            "null"

        NullableType st ->
            "nullable " ++ singleTypeToString st

        SingleType s ->
            singleTypeToString s

        UnionType l ->
            l
                |> List.map singleTypeToString
                |> String.join ", "

        AnyType ->
            "any"


typeToList : Type -> List String
typeToList t =
    case t of
        NullableType NullType ->
            [ "null" ]

        NullableType st ->
            [ "nullable " ++ singleTypeToString st ]

        SingleType s ->
            [ singleTypeToString s ]

        UnionType l ->
            l
                |> List.map singleTypeToString

        AnyType ->
            []


whenObjectSchema : Schema -> Maybe SubSchema
whenObjectSchema schema =
    case schema of
        ObjectSchema os ->
            Just os

        BooleanSchema _ ->
            Nothing


makeJsonPointer : ( Bool, String, List String ) -> String
makeJsonPointer ( isPointer, ns, path ) =
    if isPointer then
        ("#" :: path)
            |> String.join "/"
            |> (++) ns

    else if List.isEmpty path then
        ns

    else
        path
            |> String.join "/"
            |> (++) (ns ++ "#")



{-
   for : String -> Schema -> Maybe Schema
   for jsonPointer schema =
       jsonPointer
           |> parseJsonPointer
           |> List.foldl (weNeedToGoDeeper schema) (Just schema)


   implyType : Value -> Schema -> String -> ImpliedType
   implyType val schema subpath =
       let
           path =
               parseJsonPointer subpath

           actualValue =
               val
                   |> Decode.decodeValue (Decode.at path Decode.value)
                   |> Result.toMaybe
       in
           path
               |> List.foldl (weNeedToGoDeeper schema) (Just schema)
               |> Maybe.andThen whenObjectSchema
               |> Maybe.andThen (calcSubSchemaType actualValue schema)
               |> \x ->
                   case x of
                       Nothing ->
                           { type_ = AnyType
                           , schema = blankSubSchema
                           , error = Just <| "Can't imply type: " ++ subpath
                           }

                       Just ( t, os ) ->
                           { type_ = t
                           , schema = os
                           , error = Nothing
                           }

-}
{-
   calcSubSchemaType : Maybe Value -> Schema -> SubSchema -> Maybe ( Type, SubSchema )
   calcSubSchemaType actualValue schema os =
       (case os.ref of
           Just ref ->
               ref
                   |> resolveReference schema
                   |> Maybe.andThen whenObjectSchema

           Nothing ->
               Just os
       )
           |> Maybe.andThen
               (\os ->
                   case os.type_ of
                       AnyType ->
                           [ os.anyOf
                           , os.allOf
                           , os.oneOf
                           ]
                               |> List.map (Maybe.withDefault [])
                               |> List.concat
                               |> tryAllSchemas actualValue schema
                               |> \res ->
                                   if res == Nothing then
                                       if os.properties /= Nothing || os.additionalProperties /= Nothing then
                                           Just ( SingleType ObjectType, os )
                                       else if os.enum /= Nothing then
                                           os.enum
                                               |> deriveTypeFromEnum
                                               |> \t -> Just ( t, os )
                                       else if os == blankSubSchema then
                                           Just ( AnyType, os )
                                       else
                                           Nothing
                                   else
                                       res

                       UnionType ut ->
                           if ut == [ BooleanType, ObjectType ] || ut == [ ObjectType, BooleanType ] then
                               Just ( SingleType ObjectType, os )
                           else
                               Just ( os.type_, os )

                       x ->
                           Just ( x, os )
               )


   deriveTypeFromValue : Value -> Maybe Type
   deriveTypeFromValue val =
       case Decode.decodeValue Decode.string val of
           Ok _ ->
               Just <| SingleType StringType

           Err _ ->
               Nothing


   deriveTypeFromEnum : Maybe (List Value) -> Type
   deriveTypeFromEnum enum =
       enum
           |> Maybe.andThen List.head
           |> Maybe.andThen deriveTypeFromValue
           |> Maybe.withDefault AnyType
-}
{-
   resolve : Schema -> Schema -> Schema
   resolve rootSchema schema =
       schema
           |> whenObjectSchema
           |> Maybe.andThen
               (\os ->
                   os.ref
                       |> Maybe.andThen (resolveReference "" rootSchema)
               )
           |> Maybe.withDefault schema
-}
{-
   weNeedToGoDeeper : Schema -> String -> Maybe Schema -> Maybe Schema
   weNeedToGoDeeper rootSchema key schema =
       schema
           |> Maybe.andThen whenObjectSchema
           |> Maybe.andThen
               (\os ->
                   case os.ref of
                       Just r ->
                           resolveReference rootSchema r

                       Nothing ->
                           schema
               )
           |> Maybe.andThen (findProperty key rootSchema)
           |> Maybe.map (resolve rootSchema)



   findProperty : String -> Schema -> Schema -> Maybe Schema
   findProperty name rootSchema schema =
       let
           os =
               whenObjectSchema schema
       in
           os
               |> Maybe.andThen .properties
               |> Maybe.andThen
                   (\(Schemata pp) ->
                       pp
                           |> List.foldl
                               (\( key, s ) res ->
                                   if res /= Nothing || key /= name then
                                       res
                                   else
                                       Just s
                               )
                               Nothing
                   )
               |> (\r ->
                       if r == Nothing then
                           os
                               |> Maybe.andThen .additionalProperties
                       else
                           r
                  )
               |> (\r ->
                       if r == Nothing then
                           os
                               |> Maybe.andThen .anyOf
                               |> Maybe.andThen
                                   (\anyOf ->
                                       anyOf
                                           |> List.foldl
                                               (\s r ->
                                                   if r == Nothing then
                                                       s
                                                           |> resolve rootSchema
                                                           |> findProperty name rootSchema
                                                   else
                                                       r
                                               )
                                               Nothing
                                   )
                       else
                           r
                  )
               |> \r ->
                   if r == Nothing then
                       Just blankSchema
                   else
                       r


   findDefinition : String -> Schemata -> Maybe SubSchema
   findDefinition ref (Schemata defs) =
       defs
           |> List.foldl
               (\( key, def ) res ->
                   if res == Nothing && ("#/definitions/" ++ key) == ref then
                       whenObjectSchema def
                   else
                       res
               )
               Nothing


   tryAllSchemas : Maybe Value -> Schema -> List Schema -> Maybe ( Type, SubSchema )
   tryAllSchemas actualValue rootSchema listSchemas =
       listSchemas
           |> List.map (resolve rootSchema)
           |> List.foldl
               (\schema res ->
                   if res == Nothing then
                       case actualValue of
                           Just av ->
                               case Validation.validate Ref.defaultPool av rootSchema schema of
                                   Ok _ ->
                                       schema
                                           |> whenObjectSchema
                                           |> Maybe.andThen (calcSubSchemaType actualValue rootSchema)

                                   Err _ ->
                                       Nothing

                           Nothing ->
                               schema
                                   |> whenObjectSchema
                                   |> Maybe.andThen (calcSubSchemaType actualValue rootSchema)
                   else
                       res
               )
               Nothing
-}
{-
   getDefinition : Maybe Schemata -> String -> Maybe Schema
   getDefinition defs name =
       defs
           |> Maybe.andThen
               (\(Schemata x) ->
                   List.foldl
                       (\( key, prop ) result ->
                           if name == key then
                               Just prop
                           else
                               result
                       )
                       Nothing
                       x
               )
-}
{-
   debugSchema : String -> Maybe Schema -> Maybe Schema
   debugSchema msg schema =
       let
           a =
               case schema of
                   Just s ->
                       s
                           |> Schema.encode
                           |> Encode.encode 4
                           |> Debug.log
                           |> (\f -> f msg)

                   Nothing ->
                       Debug.log msg "Nothing"
       in
       schema


   debugSubSchema : String -> Maybe SubSchema -> Maybe SubSchema
   debugSubSchema msg schema =
       let
           a =
               case schema of
                   Just s ->
                       ObjectSchema s
                           |> Schema.encode
                           |> Encode.encode 4
                           |> Debug.log
                           |> (\f -> f msg)

                   Nothing ->
                       Debug.log msg "Nothing"
       in
       schema
-}


collectIds : Schema -> SchemataPool -> ( SchemataPool, String )
collectIds schema pool =
    let
        getNs : Maybe String -> String
        getNs uri =
            case uri of
                Just s ->
                    let
                        ( _, ns, _ ) =
                            parseJsonPointer s ""
                    in
                    ns

                Nothing ->
                    ""

        manageId : String -> Encode.Value -> SchemataPool -> List ( String, Encode.Value ) -> ( List ( String, Encode.Value ), ( SchemataPool, String ) )
        manageId ns source poolLocal obj =
            case List.filter (\( name, _ ) -> name == "id" || name == "$id") obj of
                ( _, val ) :: _ ->
                    val
                        |> Decode.decodeValue Decode.string
                        |> Result.map
                            (\id ->
                                let
                                    ( isPointer, newNs, path ) =
                                        parseJsonPointer id ns
                                in
                                case Decode.decodeValue Schema.decoder source of
                                    Ok schemaLocal ->
                                        ( obj, ( Dict.insert (makeJsonPointer ( isPointer, newNs, path )) schemaLocal poolLocal, newNs ) )

                                    Err _ ->
                                        ( obj, ( poolLocal, ns ) )
                            )
                        |> Result.withDefault ( obj, ( poolLocal, ns ) )

                _ ->
                    ( obj, ( poolLocal, ns ) )

        walkValue source ( poolLocal, ns ) =
            source
                |> Decode.decodeValue (Decode.keyValuePairs Decode.value)
                |> Result.withDefault []
                |> manageId ns source poolLocal
                |> (\( list, res ) -> List.foldl (\( _, val ) -> walkValue val) res list)
    in
    case schema of
        ObjectSchema { id, source } ->
            walkValue source ( pool, getNs id )

        _ ->
            ( pool, "" )
