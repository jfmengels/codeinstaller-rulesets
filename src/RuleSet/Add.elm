module RuleSet.Add exposing (pages, magicLinkAuth, magicLinkAuthMinimal)

{-| Rule sets for adding features to an existing application.

@docs pages, magicLinkAuth, magicLinkAuthMinimal

-}

import Install.ClauseInCase as ClauseInCase
import Install.FieldInTypeAlias as FieldInTypeAlias
import Install.Function.InsertFunction as InsertFunction
import Install.Function.ReplaceFunction as ReplaceFunction
import Install.Import as Import exposing (module_, qualified, withAlias, withExposedValues)
import Install.Initializer as Initializer
import Install.InitializerCmd as InitializerCmd
import Install.Subscription as Subscription
import Install.Type
import Install.TypeVariant as TypeVariant
import Regex
import Review.Rule exposing (Rule)
import String.Extra


{-| Given a list of page names, e.g. `["quotes", "jokes"]`, the
set of rules for adding pages to an existing application is returned:

    RuleSet.Add.pages [ "quotes", "jokes" ]

-}
pages : List String -> List Rule
pages pageNames =
    List.concatMap addPage pageNames


addPage : String -> List Rule
addPage page =
    let
        camelizedPageName =
            String.Extra.camelize page

        routeName =
            camelizedPageName ++ "Route"

        pageModuleName =
            "Pages." ++ camelizedPageName

        viewFunction_ =
            pageModuleName ++ ".view"
    in
    [ TypeVariant.makeRule "Route" "Route" [ routeName ]
    , ClauseInCase.init "View.Main" "loadedView" routeName ("generic model " ++ viewFunction_) |> ClauseInCase.makeRule
    , Import.qualified "View.Main" [ pageModuleName ] |> Import.makeRule
    ]


{-|

    Add magic link authentication

-}
magicLinkAuth : List Rule
magicLinkAuth =
    List.concat
        [ configAtmospheric
        , configUsers
        , configAuthTypes -- Problem??
        , configAuthFrontend -- Problem??
        , configAuthBackend

        --, configRoute
        , configView
        ]


configAtmospheric : List Rule
configAtmospheric =
    [ -- Add fields randomAtmosphericNumbers and time to BackendModel
      Import.qualified "Types" [ "Http" ] |> Import.makeRule
    , Import.qualified "Backend" [ "Atmospheric", "Dict", "Time", "Task", "MagicLink.Helper" ] |> Import.makeRule
    , FieldInTypeAlias.makeRule "Types"
        "BackendModel"
        [ "randomAtmosphericNumbers : Maybe (List Int)"
        , "time : Time.Posix"
        ]
    , TypeVariant.makeRule "Types"
        "BackendMsg"
        [ "GotAtmosphericRandomNumbers (Result Http.Error String)"
        , "SetLocalUuidStuff (List Int)"
        , "GotFastTick Time.Posix"
        ]
    , InitializerCmd.makeRule "Backend" "init" [ "Time.now |> Task.perform GotFastTick", "MagicLink.Helper.getAtmosphericRandomNumbers" ]
    , ClauseInCase.init "Backend" "update" "GotAtmosphericRandomNumbers randomNumberString" "Atmospheric.setAtmosphericRandomNumbers model randomNumberString" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "update" "SetLocalUuidStuff randomInts" "(model, Cmd.none)" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "update" "GotFastTick time" "( { model | time = time } , Cmd.none )" |> ClauseInCase.makeRule
    ]


configUsers : List Rule
configUsers =
    [ Import.qualified "Types" [ "User" ] |> Import.makeRule
    , Import.config "Types" [ module_ "Dict" |> withExposedValues [ "Dict" ] ] |> Import.makeRule
    , FieldInTypeAlias.makeRule "Types"
        "BackendModel"
        [ "users: Dict.Dict User.EmailString User.User"
        , "userNameToEmailString : Dict.Dict User.Username User.EmailString"
        ]
    , FieldInTypeAlias.makeRule "Types" "LoadedModel" [ "users : Dict.Dict User.EmailString User.User" ]
    , Import.qualified "Backend" [ "Time", "Task", "LocalUUID" ] |> Import.makeRule
    , Import.config "Backend"
        [ module_ "MagicLink.Helper" |> withAlias "Helper"
        , module_ "Dict" |> withExposedValues [ "Dict" ]
        ]
        |> Import.makeRule
    , Import.qualified "Frontend" [ "Dict" ] |> Import.makeRule
    , Initializer.makeRule "Frontend" "initLoaded" [ { field = "users", value = "Dict.empty" } ]
    ]



-- HERE


{-|

    Add minimal wiring for magic link authentication

-}
magicLinkAuthMinimal : List Rule
magicLinkAuthMinimal =
    [ Import.qualified "Types" [ "Dict", "AssocList", "EmailAddress", "LocalUUID", "Auth.Common", "MagicLink.Types", "Session", "User" ] |> Import.makeRule
    , Import.qualified "Frontend" [ "Dict", "MagicLink.Types", "Auth.Common", "MagicLink.Frontend", "MagicLink.Auth", "Pages.SignIn" ] |> Import.makeRule
    , Import.qualified "Backend" [ "Dict", "AssocList", "Time", "Auth.Flow", "MagicLink.Auth", "MagicLink.Backend", "User", "LocalUUID" ] |> Import.makeRule
    , TypeVariant.makeRule "Types" "FrontendMsg" [ "AuthFrontendMsg MagicLink.Types.Msg" ]
    , TypeVariant.makeRule "Types" "BackendMsg" [ "AuthBackendMsg Auth.Common.BackendMsg" ]
    , TypeVariant.makeRule "Types" "ToBackend" [ "AuthToBackend Auth.Common.ToBackend" ]
    , FieldInTypeAlias.makeRule "Types" "LoadedModel" [ "magicLinkModel : MagicLink.Types.Model", "users: Dict.Dict User.EmailString User.User" ]
    , TypeVariant.makeRule "Types"
        "ToFrontend"
        [ "AuthToFrontend Auth.Common.ToFrontend"
        , "AuthSuccess Auth.Common.UserInfo"
        , "UserInfoMsg (Maybe Auth.Common.UserInfo)"
        , "GetLoginTokenRateLimited"
        , "RegistrationError String"
        , "UserRegistered User.User"
        , "SignInError String"

        --, "CheckSignInResponse (Result BackendDataStatus User.SignInData)"
        ]
    , FieldInTypeAlias.makeRule "Types"
        "BackendModel"
        [ "localUuidData : Maybe LocalUUID.Data"
        , "pendingAuths : Dict.Dict Lamdera.SessionId Auth.Common.PendingAuth"
        , "pendingEmailAuths : Dict.Dict Lamdera.SessionId Auth.Common.PendingEmailAuth"
        , "sessions : Dict.Dict SessionId Auth.Common.UserInfo"
        , "secretCounter : Int"
        , "sessionDict : AssocList.Dict SessionId String"
        , "pendingLogins : AssocList.Dict Lamdera.SessionId  {loginAttempts : Int , emailAddress : EmailAddress.EmailAddress , creationTime : Time.Posix , loginCode : Int  }"
        , "log : List ( Time.Posix, MagicLink.Types.LogItem )"
        , "sessionInfo : Dict.Dict SessionId Session.Interaction"
        , "users: Dict.Dict User.EmailString User.User"
        , "userNameToEmailString : Dict.Dict User.Username User.EmailString"
        , "time: Time.Posix"
        , "randomAtmosphericNumbers: Maybe (List Int)"
        ]
    , Initializer.makeRule "Frontend" "initLoaded" [ { field = "magicLinkModel", value = "Pages.SignIn.init loadingModel.initUrl" } ]
    , Initializer.makeRule "Backend"
        "init"
        [ { field = "randomAtmosphericNumbers", value = "Just [ 235880, 700828, 253400, 602641 ]" }
        , { field = "time", value = "Time.millisToPosix 0" }
        , { field = "sessions", value = "Dict.empty" }
        , { field = "userNameToEmailString", value = "Dict.empty" }
        , { field = "users", value = "Dict.empty" }
        , { field = "sessionInfo", value = "Dict.empty" }
        , { field = "pendingAuths", value = "Dict.empty" }
        , { field = "localUuidData", value = "LocalUUID.initFrom4List [ 235880, 700828, 253400, 602641 ]" }
        , { field = "pendingEmailAuths", value = "Dict.empty" }
        , { field = "secretCounter", value = "0" }
        , { field = "sessionDict", value = "AssocList.empty" }
        , { field = "pendingLogins", value = "AssocList.empty" }
        , { field = "log", value = "[]" }
        ]
    , ClauseInCase.init "Frontend" "updateLoaded" "AuthFrontendMsg authToFrontendMsg" "MagicLink.Auth.update authToFrontendMsg model.magicLinkModel |> Tuple.mapFirst (\\magicLinkModel -> { model | magicLinkModel = magicLinkModel })" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "updateFromFrontend" "AuthToBackend authMsg" "Auth.Flow.updateFromFrontend (MagicLink.Auth.backendConfig model) clientId sessionId authMsg model" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "update" "AuthBackendMsg _" "(model, Cmd.none)" |> ClauseInCase.makeRule
    , ReplaceFunction.init "Frontend" "tryLoading" tryLoading2
        |> ReplaceFunction.makeRule
    ]


configAuthTypes : List Rule
configAuthTypes =
    [ Import.qualified "Types" [ "AssocList", "Auth.Common", "LocalUUID", "MagicLink.Types", "Session", "Dict" ] |> Import.makeRule
    , TypeVariant.makeRule "Types"
        "FrontendMsg"
        [ "SignInUser User.SignInData"
        , "AuthFrontendMsg MagicLink.Types.Msg"
        , "SetRoute_ Route"
        , "LiftMsg MagicLink.Types.Msg"
        ]
    , TypeVariant.makeRule "Types"
        "BackendMsg"
        [ "AuthBackendMsg Auth.Common.BackendMsg"
        , "AutoLogin SessionId User.SignInData"
        , "OnConnected SessionId ClientId"
        ]
    , FieldInTypeAlias.makeRule "Types"
        "BackendModel"
        [ "localUuidData : Maybe LocalUUID.Data"
        , "pendingAuths : Dict Lamdera.SessionId Auth.Common.PendingAuth"
        , "pendingEmailAuths : Dict Lamdera.SessionId Auth.Common.PendingEmailAuth"
        , "sessions : Dict SessionId Auth.Common.UserInfo"
        , "secretCounter : Int"
        , "sessionDict : AssocList.Dict SessionId String"
        , "pendingLogins : MagicLink.Types.PendingLogins"
        , "log : MagicLink.Types.Log"
        , "sessionInfo : Session.SessionInfo"
        ]
    , TypeVariant.makeRule "Types"
        "ToBackend"
        [ "AuthToBackend Auth.Common.ToBackend"
        , "AddUser String String String"
        , "GetUserDictionary"
        ]
    , FieldInTypeAlias.makeRule "Types" "LoadedModel" [ "magicLinkModel : MagicLink.Types.Model" ]
    ]


configAuthFrontend : List Rule
configAuthFrontend =
    [ Import.qualified "Frontend" [ "MagicLink.Types", "Auth.Common", "MagicLink.Frontend", "MagicLink.Auth", "Pages.SignIn", "Pages.Home", "Pages.Admin", "Pages.TermsOfService", "Pages.Notes" ] |> Import.makeRule
    , Initializer.makeRule "Frontend" "initLoaded" [ { field = "magicLinkModel", value = "Pages.SignIn.init loadingModel.initUrl" } ]
    , ClauseInCase.init "Frontend" "updateFromBackendLoaded" "AuthToFrontend authToFrontendMsg" "MagicLink.Auth.updateFromBackend authToFrontendMsg model.magicLinkModel |> Tuple.mapFirst (\\magicLinkModel -> { model | magicLinkModel = magicLinkModel })"
        |> ClauseInCase.withInsertAtBeginning
        |> ClauseInCase.makeRule
    , ClauseInCase.init "Frontend" "updateFromBackendLoaded" "GotUserDictionary users" "( { model | users = users }, Cmd.none )"
        |> ClauseInCase.withInsertAtBeginning
        |> ClauseInCase.makeRule

    --, ClauseInCase.init "Frontend" "updateFromBackendLoaded" "UserRegistered user" "MagicLink.Frontend.userRegistered model.magicLinkModel user |> Tuple.mapFirst (\\magicLinkModel -> { model | magicLinkModel = magicLinkModel })"
    --    |> ClauseInCase.withInsertAtBeginning
    --    |> ClauseInCase.makeRule
    , ClauseInCase.init "Frontend" "updateFromBackendLoaded" "GotMessage message" "({model | message = message}, Cmd.none)"
        |> ClauseInCase.withInsertAtBeginning
        |> ClauseInCase.makeRule
    , ClauseInCase.init "Frontend" "updateLoaded" "SetRoute_ route" "( { model | route = route }, Cmd.none )" |> ClauseInCase.makeRule
    , ClauseInCase.init "Frontend" "updateLoaded" "AuthFrontendMsg authToFrontendMsg" "MagicLink.Auth.update authToFrontendMsg model.magicLinkModel |> Tuple.mapFirst (\\magicLinkModel -> { model | magicLinkModel = magicLinkModel })" |> ClauseInCase.makeRule
    , ClauseInCase.init "Frontend" "updateLoaded" "SignInUser userData" "MagicLink.Frontend.signIn model userData" |> ClauseInCase.makeRule
    , TypeVariant.makeRule "Types"
        "ToFrontend"
        [ "AuthToFrontend Auth.Common.ToFrontend"
        , "AuthSuccess Auth.Common.UserInfo"
        , "UserInfoMsg (Maybe Auth.Common.UserInfo)"
        , "CheckSignInResponse (Result BackendDataStatus User.SignInData)"
        , "GetLoginTokenRateLimited"
        , "RegistrationError String"
        , "SignInError String"
        , "UserSignedIn (Maybe User.User)"
        , "UserRegistered User.User"
        , "GotUserDictionary (Dict.Dict User.EmailString User.User)"
        , "GotMessage String"
        ]
    , Install.Type.makeRule "Types" "BackendDataStatus" [ "Sunny", "LoadedBackendData", "Spell String Int" ]
    , ClauseInCase.init "Frontend" "updateLoaded" "LiftMsg _" "( model, Cmd.none )" |> ClauseInCase.makeRule
    , ReplaceFunction.init "Frontend" "tryLoading" tryLoading2
        |> ReplaceFunction.makeRule
    ]


configAuthBackend : List Rule
configAuthBackend =
    -- 19 rules
    [ ClauseInCase.init "Backend" "update" "AuthBackendMsg authMsg" "Auth.Flow.backendUpdate (MagicLink.Auth.backendConfig model) authMsg" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "update" "AutoLogin sessionId loginData" "( model, Lamdera.sendToFrontend sessionId (AuthToFrontend <| Auth.Common.AuthSignInWithTokenResponse <| Ok <| loginData) )" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "update" "OnConnected sessionId clientId" "( model, Reconnect.connect model sessionId clientId )" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "update" "ClientConnected sessionId clientId" "( model, Reconnect.connect model sessionId clientId )" |> ClauseInCase.makeRule
    , Import.qualified "Backend"
        [ "AssocList"
        , "Auth.Common"
        , "Auth.Flow"
        , "MagicLink.Auth"
        , "LocalUUID"
        , "MagicLink.Backend"
        , "Reconnect"
        , "User"
        ]
        |> Import.makeRule
    , Initializer.makeRule "Backend"
        "init"
        [ { field = "randomAtmosphericNumbers", value = "Just [ 235880, 700828, 253400, 602641 ]" }
        , { field = "time", value = "Time.millisToPosix 0" }
        , { field = "sessions", value = "Dict.empty" }
        , { field = "userNameToEmailString", value = "Dict.empty" }
        , { field = "users", value = "Dict.empty" }
        , { field = "sessionInfo", value = "Dict.empty" }
        , { field = "pendingAuths", value = "Dict.empty" }
        , { field = "localUuidData", value = "LocalUUID.initFrom4List [ 235880, 700828, 253400, 602641 ]" }
        , { field = "pendingEmailAuths", value = "Dict.empty" }
        , { field = "secretCounter", value = "0" }
        , { field = "sessionDict", value = "AssocList.empty" }
        , { field = "pendingLogins", value = "AssocList.empty" }
        , { field = "log", value = "[]" }
        ]
    , ClauseInCase.init "Backend" "updateFromFrontend" "AuthToBackend authMsg" "Auth.Flow.updateFromFrontend (MagicLink.Auth.backendConfig model) clientId sessionId authMsg model" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "updateFromFrontend" "AddUser realname username email" "MagicLink.Backend.addUser model clientId email realname username" |> ClauseInCase.makeRule

    --, ClauseInCase.init "Backend" "updateFromFrontend" "RequestSignUp realname username email" "MagicLink.Backend.requestSignUp model clientId realname username email" |> ClauseInCase.makeRule
    , ClauseInCase.init "Backend" "updateFromFrontend" "GetUserDictionary" "( model, Lamdera.sendToFrontend clientId (GotUserDictionary model.users) )" |> ClauseInCase.makeRule
    , Subscription.makeRule "Backend" [ "Lamdera.onConnect OnConnected" ]
    ]



--configRoute : List Rule
--configRoute =
--    [ -- ROUTE
--      TypeVariant.makeRule "Route" "Route" [ "TermsOfServiceRoute", "Notes", "SignInRoute", "AdminRoute" ]
--    ]


configView =
    [ ClauseInCase.init "View.Main" "loadedView" "AdminRoute" adminRoute |> ClauseInCase.makeRule
    , ClauseInCase.init "View.Main" "loadedView" "TermsOfServiceRoute" "generic model Pages.TermsOfService.view" |> ClauseInCase.makeRule
    , ClauseInCase.init "View.Main" "loadedView" "Notes" "generic model Pages.Notes.view" |> ClauseInCase.makeRule
    , ClauseInCase.init "View.Main" "loadedView" "SignInRoute" "generic model (\\model_ -> Pages.SignIn.view Types.LiftMsg model_.magicLinkModel |> Element.map Types.AuthFrontendMsg)" |> ClauseInCase.makeRule

    --, ClauseInCase.init "View.Main" "loadedView" "CounterPageRoute" "generic model (generic model Pages.Counter.view)" |> ClauseInCase.makeRule
    , InsertFunction.init "View.Main" "generic" generic |> InsertFunction.makeRule
    , Import.qualified "View.Main" [ "Pages.SignIn", "Pages.Admin", "Pages.TermsOfService", "Pages.Notes", "User" ] |> Import.makeRule

    --, ReplaceFunction.init "View.Main" "headerRow" (asOneLine headerRow) |> ReplaceFunction.makeRule
    ]



-- VALUES USED IN THE RULES:


headerRow =
    """headerRow model = [ headerView model model.route { window = model.window, isCompact = True }, Pages.SignIn.headerView model.magicLinkModel model.route { window = model.window, isCompact = True } |> Element.map Types.AuthFrontendMsg ]"""


adminRoute =
    "if User.isAdmin model.magicLinkModel.currentUserData then generic model Pages.Admin.view else generic model Pages.Home.view"


generic =
    """generic : Types.LoadedModel -> (Types.LoadedModel -> Element Types.FrontendMsg) -> Element Types.FrontendMsg
generic model view_ =
    Element.column
        [ Element.width Element.fill, Element.height Element.fill ]
        [ Element.row [ Element.width (Element.px model.window.width), Element.Background.color View.Color.blue ]
            [ ---
              Pages.SignIn.headerView model.magicLinkModel
                model.route
                { window = model.window, isCompact = True }
                |> Element.map Types.AuthFrontendMsg
            , headerView model model.route { window = model.window, isCompact = True }
            ]
        , Element.column
            (Element.padding 20
                :: Element.scrollbarY
                :: Element.height (Element.px <| model.window.height - 95)
                :: Theme.contentAttributes
            )
            [ view_ model -- |> Element.map Types.AuthFrontendMsg
            ]
        , footer model.route model
        ]
"""


viewFunction =
    """view model =
    Html.div [ style "padding" "50px" ]
        [ Html.button [ onClick Increment ] [ text "+" ]
        , Html.div [ style "padding" "10px" ] [ Html.text (String.fromInt model.counter) ]
        , Html.button [ onClick Decrement ] [ text "-" ]
        , Html.div [] [Html.button [ onClick Reset, style "margin-top" "10px"] [ text "Reset" ]]
        ] |> Element.html   """


tryLoading1 =
    """tryLoading : LoadingModel -> ( FrontendModel, Cmd FrontendMsg )
tryLoading loadingModel =
    Maybe.map
        (\\window ->
            case loadingModel.route of
                _ ->
                    let
                        authRedirectBaseUrl =
                            let
                                initUrl =
                                    loadingModel.initUrl
                            in
                            { initUrl | query = Nothing, fragment = Nothing }
                    in
                    ( Loaded
                        { key = loadingModel.key
                        , now = loadingModel.now
                        , counter = 0
                        , window = window
                        , showTooltip = False
                        , users = Dict.empty
                        , route = loadingModel.route
                        , message = "Starting up ..."
                        }
                    , Cmd.none
                    )
        )
        loadingModel.window
        |> Maybe.withDefault ( Loading loadingModel, Cmd.none )"""


tryLoading2 =
    """tryLoading : LoadingModel -> ( FrontendModel, Cmd FrontendMsg )
tryLoading loadingModel =
    Maybe.map
        (\\window ->
            case loadingModel.route of
                _ ->
                    let
                        authRedirectBaseUrl =
                            let
                                initUrl =
                                    loadingModel.initUrl
                            in
                            { initUrl | query = Nothing, fragment = Nothing }
                    in
                    ( Loaded
                        { key = loadingModel.key
                        , now = loadingModel.now
                        , counter = 0
                        , window = window
                        , showTooltip = False
                        , magicLinkModel = Pages.SignIn.init authRedirectBaseUrl
                        , route = loadingModel.route
                        , message = "Starting up ..."
                        , users = Dict.empty
                        }
                    , Cmd.none
                    )
        )
        loadingModel.window
        |> Maybe.withDefault ( Loading loadingModel, Cmd.none )"""



-- Function to compress runs of spaces to a single space


asOneLine : String -> String
asOneLine str =
    str
        |> String.trim
        |> compressSpaces
        |> String.split "\n"
        -- |> List.filter (\s -> s /= "")
        |> String.join " "


compressSpaces : String -> String
compressSpaces string =
    userReplace " +" (\_ -> " ") string


userReplace : String -> (Regex.Match -> String) -> String -> String
userReplace userRegex replacer string =
    case Regex.fromString userRegex of
        Nothing ->
            string

        Just regex ->
            Regex.replace regex replacer string
