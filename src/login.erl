-module (login).
-include_lib ("nitrogen_core/include/wf.hrl").
-compile(export_all).

main() -> #template { file="./site/templates/bare.html" }.

title() -> "Login".

body() -> 
    wf:wire(#api {name=login}),
    wf:wire(#api {name=logout}),
    [
        "
        <div class='container'>
            <div class='row'>
                <div class='col-sm'></div>
                <div class='col-sm'>
                    <div class='text-center'>
                        <main class='form-signin w-100 m-auto'>
                            <h1 class='h3 mb-3 fw-normal'>Sign in to Twitter</h1>
                            <div class='form-floating'>
                                <input type='text' id='username' autocomplete='off' class='form-control wfid_username wfid_temp770 textbox' value='' placeholder='Username' />
                            </div>
                            <br/>
                            <div class='form-floating'>
                                <input type='password' id='password' autocomplete='off' class='form-control password wfid_password wfid_temp2370 textbox' value='' placeholder='Password' />
                            </div>
                            <br/>
                            <input type='submit' value='Sign in' class='w-100 btn btn-lg btn-primary text-white' onclick='javascript: page.login(document.getElementById(`username`).value, document.getElementById(`password`).value);'>
                            <br/>
                            <br/>
                            <span>Don't have an account? <a href='/register'>Sign up</a></span>
                        </main>
                    </div>
                </div>
                <div class='col-sm'></div>
            </div>
        </div>
        ",
        #br{},
        #flash{}
    ].

script() ->
    ["
        page.logout();
    "].

api_event(logout, _, []) -> helper:logout();
api_event(login, _, [Username, Password]) -> helper:login(Username, Password).

event(_) -> ok.