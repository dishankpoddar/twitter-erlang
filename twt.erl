-module(twt).
-export([
    substring_from_indexes/3, 
    users_to_show_tweet/3, broadcast_tweet/2,
    server/5, start_server/0
    ]).


substring_from_indexes(_, [], SubstringList) ->
    SubstringList;
substring_from_indexes(String, SubstringIndexes, SubstringList) ->
    [[FirstIndex] | RestIndexes] = SubstringIndexes,
    StartIndex = element(1, FirstIndex) + 2,
    Length = element(2, FirstIndex) - 2,
    NewSubstringList = SubstringList ++ [string:substr(String, StartIndex, Length)],
    substring_from_indexes(String, RestIndexes, NewSubstringList).

broadcast_tweet(_, []) ->
    ok;
broadcast_tweet(Tweet, BroadcastUserList) ->
    [First | Rest] = BroadcastUserList,
    {_, {_, Address}} = First,
    Address ! Tweet,
    broadcast_tweet(Tweet, Rest).

users_to_show_tweet([], _, FilteredActiveUserList) ->
    FilteredActiveUserList;
users_to_show_tweet(UserList, ActiveUserList, FilteredActiveUserList) ->
    [First | Rest] = UserList,
    UserIsActive = dict:find(First, ActiveUserList),
    if
        UserIsActive =/= error ->
            {ok, ActiveUser} = UserIsActive,
            NewFilteredActiveUserList = dict:store(First, ActiveUser, FilteredActiveUserList);
        true ->
            NewFilteredActiveUserList = FilteredActiveUserList
    end,
    users_to_show_tweet(Rest, ActiveUserList, NewFilteredActiveUserList).

server(UserList, ActiveUserList, SubscriberList, SubscribedList, Tweets) ->
    receive
        {register, From, Username, Password} ->
            ExistingUser = dict:find(Username, UserList),
            if
                ExistingUser =/= error ->
                    From ! error;
                true ->
                    NewUserList = dict:store(Username, crypto:hash(sha256, Password), UserList),
                    From ! {Username, dict:fetch(Username, NewUserList)},
                    server(NewUserList, ActiveUserList, SubscriberList, SubscribedList, Tweets)
            end;
        {login, From, Feed, Username, InputPassword} ->
            ExistingUser = dict:find(Username, UserList),
            if
                ExistingUser == error ->
                    From ! error;
                true ->
                    {ok, HashedPassword} = ExistingUser,
                    PasswordCorrect = crypto:hash(sha256, InputPassword) == HashedPassword,
                    if
                        PasswordCorrect ->
                            UserToken = string:trim(base64:encode_to_string(base64:encode(crypto:hash(sha256, string:trim(string:concat(Username, base64:encode_to_string(base64:encode(crypto:strong_rand_bytes(32)))), trailing, "=0")))), trailing, "=0"),
                            NewActiveUser = {UserToken, Feed},
                            NewActiveUserList = dict:store(Username, NewActiveUser, ActiveUserList),
                            From !  {Username, UserToken},
                            server(UserList, NewActiveUserList, SubscriberList, SubscribedList, Tweets);
                        true ->
                            From ! error
                    end
            end;
        {checkuser, From, Username, UserToken} ->
            From ! element(1,dict:fetch(Username, ActiveUserList)) == UserToken;
        {getuserlist, From} ->
            From ! UserList;
        {gettweetlist, From} ->
            From ! Tweets;
        {getsubscriberlist, From} ->
            From ! SubscriberList;
        {getsubscribedlist, From} ->
            From ! SubscribedList;
        {getactiveuserlist, From} ->
            From ! ActiveUserList;
        {sendtweet, From, Username, Tweet, RetweetUsername} ->
            TweetID = length(Tweets) + 1,
            PaddedTweet = string:concat(Tweet, " "),
            FindMentions = re:run(PaddedTweet, "@.*?[ @#]", [global]),
            if
                FindMentions =/= nomatch ->
                    {match, MentionIndexes} = FindMentions,
                    Mentions = substring_from_indexes(PaddedTweet, MentionIndexes, []); % Generate list of user mentions
                true ->
                    Mentions = []
            end,
            FindTags = re:run(PaddedTweet, "#.*?[ @#]", [global]),
            if
                FindTags =/= nomatch ->
                    {match, TagIndexes} = FindTags,
                    Tags = substring_from_indexes(PaddedTweet, TagIndexes, []); % Generate list of tags
                true ->
                    Tags = []
            end,
            TweetDict = dict:new(),
            TweetDict1 = dict:store("tweetid", TweetID, TweetDict),
            TweetDict2 = dict:store("tweet", Tweet, TweetDict1),
            TweetDict3 = dict:store("user", Username, TweetDict2),
            TweetDict4 = dict:store("mentions", Mentions, TweetDict3),
            TweetDict5 = dict:store("tags", Tags, TweetDict4),
            TweetDict6 = dict:store("retweetusername", RetweetUsername, TweetDict5),
            NewTweets = lists:append(Tweets, [TweetDict6]),
            BroadcastUserList = users_to_show_tweet(Mentions, ActiveUserList, dict:new()),
            SubscriberListForUsername = dict:find(Username, SubscriberList),
            if
                SubscriberListForUsername == error ->
                    FinalBroadcastUserList = BroadcastUserList;
                true ->
                    {ok, CurrentSubscriberListForUsername} = SubscriberListForUsername,
                    FinalBroadcastUserList = users_to_show_tweet(CurrentSubscriberListForUsername, ActiveUserList, BroadcastUserList)
            end,
            From ! {success, TweetDict6},
            broadcast_tweet(TweetDict6, dict:to_list(FinalBroadcastUserList)),
            server(UserList, ActiveUserList, SubscriberList, SubscribedList, NewTweets);
        {subscribe, From, Username, ToSubscribeUsername} ->
            SubscriberListForUsername = dict:find(ToSubscribeUsername, SubscriberList),
            if
                SubscriberListForUsername == error ->
                    NewSubscriberListForUsername = [Username],
                    SubscriberFlag = success;
                true ->
                    {ok, CurrentSubscriberListForUsername} = SubscriberListForUsername,
                    IsSubscriber = lists:member(Username, CurrentSubscriberListForUsername),
                    if
                        IsSubscriber ->
                            NewSubscriberListForUsername = CurrentSubscriberListForUsername,
                            SubscriberFlag = error;
                        true ->
                            NewSubscriberListForUsername = lists:append(CurrentSubscriberListForUsername, [Username]),
                            SubscriberFlag = success
                    end
            end,
            NewSubscriberList = dict:store(ToSubscribeUsername, NewSubscriberListForUsername, SubscriberList),

            SubscribedListForUsername = dict:find(Username, SubscribedList),
            if
                SubscribedListForUsername == error ->
                    NewSubscribedListForUsername = [ToSubscribeUsername],
                    SubscribedFlag = success;
                true ->
                    {ok, CurrentSubscribedListForUsername} = SubscribedListForUsername,
                    IsSubscribed = lists:member(ToSubscribeUsername, CurrentSubscribedListForUsername),
                    if
                        IsSubscribed ->
                            NewSubscribedListForUsername = CurrentSubscribedListForUsername,
                            SubscribedFlag = error;
                        true ->
                            NewSubscribedListForUsername = lists:append(CurrentSubscribedListForUsername, [ToSubscribeUsername]),
                            SubscribedFlag = success
                    end
            end,
            NewSubscribedList = dict:store(Username, NewSubscribedListForUsername, SubscribedList),
            if
                (SubscriberFlag == success) and (SubscribedFlag == success) ->
                    Flag = success;
                true ->
                    Flag = error
            end,
            From ! Flag,
            server(UserList, ActiveUserList, NewSubscriberList, NewSubscribedList, Tweets)
    end,
    server(UserList, ActiveUserList, SubscriberList, SubscribedList, Tweets).

start_server() ->
    register(server, spawn(twt, server, [dict:new(), dict:new(), dict:new(), dict:new(), []])).