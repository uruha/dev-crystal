require "kemal"
require "multi_auth"
require "base64"
require "json"

MultiAuth.config("github", "4da9cc8ec5c3db8a4c0b", "b6ccc7b0613741d8031e3305b1d8bac8082ae194")

def self.multi_auth(env)
  provider = env.params.url["provider"]
  redirect_uri = "#{Kemal.config.scheme}://#{env.request.host_with_port.as(String)}/auth/#{provider}/callback"
  MultiAuth.make(provider, redirect_uri)
end

get "/auth/:provider" do |env|
  env.redirect(multi_auth(env).authorize_uri)
end

get "/auth/:provider/callback" do |env|
  user = multi_auth(env).user(env.params.query)
  # user で取得できるもの
  # user.name
  # user.email
  # user.image
  # user.nickname

  enc_uname = Base64.encode({
    name: user.name,
    avatar: user.image
  }.to_json())
  auth_cookie = HTTP::Cookie.new(
    name: "github_auth",
    value: enc_uname,
    path: "/"
  )
  set_cookie = auth_cookie.to_set_cookie_header()
  env.response.headers["Set-Cookie"] = set_cookie
  env.redirect "/chatroom"
end

["/", "/articles"].each do |path|
  get path do |env|
    title = "index page"
    articles = [
      {"id" => 1, "title" => "記事 01", "body" => "記事01の内容だよ"},
      {"id" => 3, "title" => "title_3", "body" => "body_2"},
      {"id" => 2, "title" => "title_2", "body" => "body_3"}
    ]

    render "src/views/index.ecr", "src/views/layouts/layout.ecr"
  end
end

get "/hello/:name" do |env|
  title = "greeting"
  name = env.params.url["name"]
  render "src/views/hello.ecr", "src/views/layouts/layout.ecr"
end

SOCKETS = [] of HTTP::WebSocket

get "/chatroom" do |env|
  github_auth = env.request.cookies["github_auth"]?
  if github_auth
    user = JSON.parse(Base64.decode_string(github_auth.value))
    name = user["name"].as_s
    avatar = user["avatar"].as_s
    title = "Chat"
    render "src/views/chatroom.ecr"
  else
    env.redirect "/"
  end
end

ws "/chat" do |socket, ctx|
  SOCKETS << socket
  user = JSON.parse(Base64.decode_string(ctx.request.cookies["github_auth"].value))

  socket.on_message do |message|
    messageJson = JSON.parse(message)
    socketContext = JSON.build do |json|
      json.object do
        json.field "contents", messageJson
        json.field "user", user
      end
    end

    SOCKETS.each { |socket| socket.send socketContext }
  end

  socket.on_close do
    SOCKETS.delete socket
  end
end

static_headers do |response, filepath, filestat|
  if filepath =~ /\.html$/
    response.headers.add("Access-Control-Allow-Origin", "*")
  end

  response.headers.add("Content-Size", filestat.size.to_s)
end

Kemal.config.port = 2240
Kemal.run