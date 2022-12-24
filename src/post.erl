-module (post).
-include_lib ("nitrogen_core/include/wf.hrl").
-compile(export_all).

main() -> 
    case wf:user() /= undefined of 
        true  -> main_authorized();
        false -> wf:redirect_to_login("/login")
    end.

main_authorized() -> #template { file="./site/templates/base.html" }.

user() -> wf:user().

title() -> "Post".

body() -> 
    wf:wire(#api {name=sendtweet}),
    [
        #flash{},
        "
        <div class='container'>
            <div class='row'>
                <div class='col-lg-3'>
                    <ul class='nav flex-column'>
                        <li class='nav-item'>
                            <a class='nav-link' href='/post'>Post</a>
                        </li>
                        <li class='nav-item'>
                            <a class='nav-link' href='/feed'>Feed</a>
                        </li>
                        <li class='nav-item'>
                            <a class='nav-link' href='/all'>All Tweets</a>
                        </li>
                        <li class='nav-item'>
                            <a class='nav-link' href='/mentions'>Mentions</a>
                        </li>
                        <li class='nav-item'>
                            <a class='nav-link' href='/following'>Following</a>
                        </li>
                        <li class='nav-item'>
                            <a class='nav-link' href='/tags?tag=project'>#project</a>
                        </li>
                        <li class='nav-item'>
                            <a class='nav-link' href='/tags?tag=test'>#test</a>
                        </li>
                    </ul>
                </div>
                <div class='col-md'>
                    <h4>Post a Tweet</h4>
                    <br/>
                    <div class='form-floating'>
                        <input type='text' class='form-control' id='floatingInput' placeholder='Whats Happening . . .'/>
                    </div>
                    <br/>
                    <a onclick='send_tweet()' class='w-100 btn btn-lg btn-primary text-white' type='submit'>
                        Tweet
                    </a>
                </div>
                <div class='col-lg-2'></div>
            </div>
        </div>
        ",
        #br{}
    ].

script() ->
    ["
        function send_tweet() {
            tweet_text = document.getElementById('floatingInput').value;
            if (tweet_text) {
                page.sendtweet(tweet_text);
            }
            else {
                alert('Write Tweet');
            }
        }
    "].

api_event(sendtweet, _, [Tweet]) -> helper:tweet(Tweet).

event(_) -> ok.