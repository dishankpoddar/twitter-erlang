-module (all).
-include_lib ("nitrogen_core/include/wf.hrl").
-compile(export_all).

main() -> 
    case wf:user() /= undefined of 
        true  -> main_authorized();
        false -> wf:redirect_to_login("/login")
    end.

main_authorized() -> #template { file="./site/templates/base.html" }.

user() -> wf:user().

title() -> "All Tweets".

body() -> 
    wf:wire(#api {name=fetch}),
    wf:wire(#api {name=subscribe}),
    wf:wire(#api {name=retweet}),
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
                    <h4>All Tweets</h4>
                    <div id='placeholder' class='wfid_placeholder wfid_temp2498'></div>
                </div>
                <div class='col-lg-2'></div>
            </div>
        </div>
        ",
        #br{}
    ].

script() ->
    ["
        page.fetch();
    "].

api_event(subscribe, _, [ToSubscribeUsername]) -> helper:subscribe(ToSubscribeUsername);
api_event(retweet, _, [RetweetID]) -> helper:retweet(RetweetID);
api_event(fetch, _, []) -> helper:query_all().

event(_) -> ok.