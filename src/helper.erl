-module (helper).
-include_lib ("nitrogen_core/include/wf.hrl").
-compile(export_all).


main_node() ->
    'dish@10.0.0.61'.


main() -> ok.

is_subscribed(SubscribedToUsername) ->
    Subscribed = get_subscribed_list(wf:user()),
    if
        Subscribed =/= error ->
            IsSubscribed = lists:member(SubscribedToUsername, element(2, Subscribed)),
            IsSubscribed;
        true ->
            false
    end.

show_tweet(Tweet) ->
    TweetID = dict:fetch("tweetid", Tweet),
    TweetText = dict:fetch("tweet", Tweet),
    User = dict:fetch("user", Tweet),
    RetweetUsername = dict:fetch("retweetusername", Tweet),
    if
        RetweetUsername == null ->
            Retweet = "";
        true ->
            Retweet = " retweeted " ++ RetweetUsername
    end,
    IsSubscribed = is_subscribed(User),
    if
        IsSubscribed ->
            Subscribed = "<span class='float-right'>Followed</span>";
        true ->
            Trail = "\")'>Follow</span>",
            AlmostSubscribed = string:concat("<span style='cursor:pointer' class='float-right' onclick='page.subscribe(\"",User),
            Subscribed = string:concat(AlmostSubscribed,Trail)
    end,
    wf:insert_top("placeholder", wf:f("
    <br/>
    <div class='card'>
        <div class='card-header'>
            @~s ~s ~s
        </div>
        <div class='card-body'>
            <p class='card-text'>
            ~s
            </p>
            <a class='btn btn-primary text-white' onclick='page.retweet(~w)'>Retweet</a>
        </div>
    </div>
", [User, Retweet, Subscribed, TweetText, TweetID])).

show_tweets([]) ->
    ok;
show_tweets([First | Rest]) ->
    show_tweet(First),
    show_tweets(Rest).

get_tweet_list() ->
    {server, main_node()} ! {gettweetlist, self()},
    receive
        Tweets ->
            Tweets
    after 10000 ->
        wf:flash("Server Failed.")
    end.

get_subscribed_list(Username) ->
    {server, main_node()} ! {getsubscribedlist, self()},
    receive
        SubscribedList ->
            dict:find(Username, SubscribedList)
    after 10000 ->
        wf:flash("Server Failed.")
    end.

get_tweet_by_tweet_id(_, []) ->
    null;
get_tweet_by_tweet_id(Id, Tweets) ->
    [First | Rest] = Tweets,
    TweetExists = dict:fetch("tweetid", First) == Id,
    if
        TweetExists ->
            First;
        true ->
            get_tweet_by_tweet_id(Id, Rest)
    end.

subscribe(ToSubscribeUsername) ->
    {server, main_node()} ! {subscribe, self(), wf:user(), ToSubscribeUsername},
    receive
        error ->
            wf:flash(wf:f("Already subscribed to user '~s'.", [ToSubscribeUsername]));
        success ->
            wf:flash(wf:f("Successfully subscribed to user '~s'.", [ToSubscribeUsername]))
    after 10000 ->
        wf:flash("Server Failed.")
    end.

tweet(Tweet) ->
    {server, main_node()} ! {sendtweet, self(), wf:user(), Tweet, null},
    receive
        {success, TweetDict} ->
            wf:flash("Tweet Successful."),
            show_tweet(TweetDict)
    after 10000 ->
        wf:flash("Server Failed.")
    end.

retweet(RetweetID) ->
    Tweets = get_tweet_list(),
    Tweet = get_tweet_by_tweet_id(RetweetID, Tweets),
    TempUser = dict:fetch("retweetusername", Tweet),
    if
        TempUser == null ->
            RTUser = dict:fetch("user", Tweet);
        true ->
            RTUser = TempUser
    end,
    {server, main_node()} ! {sendtweet, self(), wf:user(), dict:fetch("tweet", Tweet), RTUser},
    receive
        {success, TweetDict} ->
            wf:flash("Re-tweet Successful."),
            show_tweet(TweetDict)
    after 10000 ->
        wf:flash("Server Failed.")
    end.


filter_tweets_by_tag([], _, FilteredTweets) ->
    FilteredTweets;
filter_tweets_by_tag(Tweets, Tag, FilteredTweets) ->
    [First | Rest] = Tweets,
    Tags = dict:fetch("tags", First),
    TweetContainsTag = lists:member(Tag, Tags),
    if
        TweetContainsTag ->
            NewFilteredTweets = lists:append(FilteredTweets, [First]);
        true ->
            NewFilteredTweets = FilteredTweets
    end,
    filter_tweets_by_tag(Rest, Tag, NewFilteredTweets).

filter_tweets_by_mention([], FilteredTweets) ->
    FilteredTweets;
filter_tweets_by_mention(Tweets, FilteredTweets) ->
    [First | Rest] = Tweets,
    Mentions = dict:fetch("mentions", First),
    TweetContainsMention = lists:member(wf:user(), Mentions),
    if
        TweetContainsMention ->
            NewFilteredTweets = lists:append(FilteredTweets, [First]);
        true ->
            NewFilteredTweets = FilteredTweets
    end,
    filter_tweets_by_mention(Rest, NewFilteredTweets).


filter_tweets_by_subscribed_tweets([], _, FilteredTweets) ->
    FilteredTweets;
filter_tweets_by_subscribed_tweets(Tweets, Subscribed, FilteredTweets) ->
    [First | Rest] = Tweets,
    TweetAuthor = dict:fetch("user", First),
    SubscribedToTweet = lists:member(TweetAuthor, Subscribed),
    if
        SubscribedToTweet ->
            NewFilteredTweets = lists:append(FilteredTweets, [First]);
        true ->
            NewFilteredTweets = FilteredTweets
    end,
    filter_tweets_by_subscribed_tweets(Rest, Subscribed, NewFilteredTweets).

query_all() ->
    Tweets = get_tweet_list(),
    show_tweets(Tweets).

query_mentions() ->
    Tweets = get_tweet_list(),
    MentionedTweets = filter_tweets_by_mention(Tweets, []),
    show_tweets(MentionedTweets).

query_tags(Tag) ->
    Tweets = get_tweet_list(),
    TaggedTweets = filter_tweets_by_tag(Tweets, Tag, []),
    show_tweets(TaggedTweets).


query_subscribed() ->
    Tweets = get_tweet_list(),
    Subscribed = get_subscribed_list(wf:user()),
    if
        Subscribed =/= error ->
            SubscribedTweets = filter_tweets_by_subscribed_tweets(Tweets, element(2, Subscribed), []),
            show_tweets(SubscribedTweets);
        true ->
            wf:flash("Not subscribed to any other users")
    end.

register(Username, Password) ->
    {server, main_node()} ! {register, self(), Username, Password},
    receive
        error ->
            wf:flash(wf:f("Registration Failed. User '~s' already exists.", [Username]));
        {RegisteredUsername, _} ->
            wf:flash(wf:f("Registration Successful for '~s'.", [RegisteredUsername]))
    after 10000 ->
        wf:flash("Server Failed.")
    end.

login(Username, Password) ->
    {server, main_node()} ! {login, self(), Username, Password},
    receive
        error ->
            wf:flash(wf:f("Login Failed. User '~s' does not exist or incorrect password entered.", [Username]));
        {RegisteredUsername, UserToken} ->
            wf:flash(wf:f("Login Successful for '~s'. <a href='/feed'>Go to Feed</a>", [RegisteredUsername])),
            wf:user(Username),
            wf:session(username, Username),
            wf:session(token, UserToken)
    after 10000 ->
        wf:flash("Server Failed.")
    end.

logout() ->
    wf:logout(),
    wf:flash("Logged out.").